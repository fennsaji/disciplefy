import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:disciplefy_bible_study/core/services/api_auth_helper.dart';

import 'api_auth_helper_test.mocks.dart';

/// Concurrent requests with an expiring token must wait on one shared session
/// refresh instead of each starting their own.
void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late Completer<AuthResponse> refresh;
  late int refreshCalls;

  int epochSeconds(Duration fromNow) =>
      DateTime.now().add(fromNow).millisecondsSinceEpoch ~/ 1000;

  MockSession sessionExpiringIn(Duration fromNow) {
    final session = MockSession();
    when(session.accessToken).thenReturn('access-token');
    when(session.expiresAt).thenReturn(epochSeconds(fromNow));
    final user = MockUser();
    when(user.id).thenReturn('user-id');
    when(session.user).thenReturn(user);
    return session;
  }

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    when(client.auth).thenReturn(auth);

    refresh = Completer<AuthResponse>();
    refreshCalls = 0;
    when(auth.refreshSession()).thenAnswer((_) {
      refreshCalls++;
      return refresh.future;
    });

    ApiAuthHelper.clientOverride = client;
  });

  tearDown(() => ApiAuthHelper.clientOverride = null);

  test('concurrent validations share one refresh', () async {
    // Expires within the 5-minute window, so a refresh is due.
    var current = sessionExpiringIn(const Duration(minutes: 1));
    when(auth.currentSession).thenAnswer((_) => current);

    final validations = List.generate(
      5,
      (_) => ApiAuthHelper.validateTokenForRequest(
        retryDelay: Duration.zero,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final refreshed = sessionExpiringIn(const Duration(hours: 1));
    current = refreshed;
    refresh.complete(AuthResponse(session: refreshed));
    await Future.wait(validations);

    expect(refreshCalls, 1);
  });

  test('a later validation starts a new refresh once the first is done',
      () async {
    final expiring = sessionExpiringIn(const Duration(minutes: 1));
    when(auth.currentSession).thenReturn(expiring);
    final refreshed = sessionExpiringIn(const Duration(hours: 1));
    refresh.complete(AuthResponse(session: refreshed));

    // currentSession keeps reporting the expiring token, so each sequential
    // validation needs a refresh of its own.
    await ApiAuthHelper.validateTokenForRequest(retryDelay: Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await ApiAuthHelper.validateTokenForRequest(retryDelay: Duration.zero);

    expect(refreshCalls, 2, reason: 'the shared slot is released');
  });
}
