import 'dart:async';
import 'dart:io';

import 'package:disciplefy_bible_study/core/router/router_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regression: tapping a push after a long background could leave the app on
/// the black AppLoadingScreen forever, because the router's redirect awaited
/// refreshSession() with no timeout and the redirect Future never resolved.
///
/// Bounding that call fixed the hang but introduced a worse bug: the caller
/// treats "not refreshed" as "session gone" and clears it, so a slow network
/// would sign out perfectly valid users. The stored expiry tracks the 1h
/// ACCESS TOKEN, not the session — Supabase sessions do not expire — so a
/// refresh we could not complete must never be a logout.
///
/// These tests pin that distinction.
class _FakeUser extends Fake implements User {
  @override
  String get id => 'u1';
  @override
  String? get email => null;
  @override
  bool get isAnonymous => true;
}

void main() {
  group('an expired access token', () {
    late Directory dir;
    var signOuts = 0;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('guard_refresh_test');
      Hive.init(dir.path);
      final box = await Hive.openBox('app_settings');
      await box.put('session_expires_at', DateTime.utc(2020).toIso8601String());
      signOuts = 0;
      RouterGuard.localSignOutForTesting = () async => signOuts++;
    });

    tearDown(() async {
      RouterGuard.refreshForTesting = null;
      RouterGuard.localSignOutForTesting = null;
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('a rejected refresh signs out of Supabase locally', () async {
      RouterGuard.refreshForTesting = () async => SessionRefreshResult.failed;
      final state = await RouterGuard.debugExpiredSessionState(_FakeUser());
      expect(state.isAuthenticated, isFalse);
      expect(signOuts, 1,
          reason: 'without it currentUser stays set and the next guard run '
              'reads the user as signed in again');
      expect(Hive.box('app_settings').get('session_expires_at'), isNull);
    });

    test('an inconclusive refresh keeps the session', () async {
      RouterGuard.refreshForTesting =
          () async => SessionRefreshResult.inconclusive;
      final state = await RouterGuard.debugExpiredSessionState(_FakeUser());
      expect(state.isAuthenticated, isTrue);
      expect(state.isGuest, isTrue);
      expect(signOuts, 0);
    });

    test('a successful refresh keeps the session', () async {
      RouterGuard.refreshForTesting =
          () async => SessionRefreshResult.refreshed;
      final state = await RouterGuard.debugExpiredSessionState(_FakeUser());
      expect(state.isAuthenticated, isTrue);
      expect(signOuts, 0);
    });
  });

  group('classifyRefreshError', () {
    test('an AuthException is a real sign-out', () {
      // Supabase answered and rejected the refresh token.
      expect(
        RouterGuard.classifyRefreshError(
          const AuthException('Invalid Refresh Token: Already Used'),
        ),
        SessionRefreshResult.failed,
      );
    });

    test('a timeout is inconclusive, never a sign-out', () {
      expect(
        RouterGuard.classifyRefreshError(
          TimeoutException('refresh timed out', const Duration(seconds: 5)),
        ),
        SessionRefreshResult.inconclusive,
      );
    });

    test('a dead socket is inconclusive, never a sign-out', () {
      // The app waking from background before the radio reconnects.
      expect(
        RouterGuard.classifyRefreshError(
          const SocketException('Failed host lookup'),
        ),
        SessionRefreshResult.inconclusive,
      );
    });

    test('an unexpected error is inconclusive rather than a sign-out', () {
      // Fail safe: an error we did not anticipate must not cost the user
      // their session.
      expect(
        RouterGuard.classifyRefreshError(StateError('unexpected')),
        SessionRefreshResult.inconclusive,
      );
    });
  });

  group('SessionRefreshResult', () {
    test('failed is the only outcome that may sign a user out', () {
      // Guards the caller's contract in _getAuthenticationState: it clears the
      // session on `failed` alone. If a value is ever added here, that branch
      // has to be revisited deliberately.
      expect(SessionRefreshResult.values, [
        SessionRefreshResult.refreshed,
        SessionRefreshResult.failed,
        SessionRefreshResult.inconclusive,
      ]);
    });
  });
}
