// Verifies that the Apple Guideline 1.2 terms gate cannot be bypassed by
// navigating directly to an auth route. /email-auth and /phone-auth are
// public routes reachable by URL or deep link, so gating only LoginScreen
// would leave registration reachable without the terms being shown.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/router/router_guard.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('guard_terms_test');
    Hive.init(tempDir.path);
    await Hive.openBox('app_settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box('app_settings').clear();
  });

  group('terms not yet accepted', () {
    test('redirects /email-auth to /login (with redirect param)', () {
      expect(
        RouterGuard.debugTermsGateRedirect(AppRoutes.emailAuth),
        '${AppRoutes.login}?redirect=${Uri.encodeComponent(AppRoutes.emailAuth)}',
      );
    });

    test('redirects /phone-auth to /login (with redirect param)', () {
      expect(
        RouterGuard.debugTermsGateRedirect(AppRoutes.phoneAuth),
        '${AppRoutes.login}?redirect=${Uri.encodeComponent(AppRoutes.phoneAuth)}',
      );
    });

    // The three exclusions below are load-bearing, not incidental.

    test('does not redirect /login (would be an infinite loop)', () {
      expect(RouterGuard.debugTermsGateRedirect(AppRoutes.login), isNull);
    });

    test('does not redirect /auth/callback (would break OAuth sign-in)', () {
      expect(
        RouterGuard.debugTermsGateRedirect(AppRoutes.authCallback),
        isNull,
      );
    });

    test('does not redirect /password-reset (would strand a reset link)', () {
      expect(
        RouterGuard.debugTermsGateRedirect(AppRoutes.passwordReset),
        isNull,
      );
    });

    test('does not redirect a non-auth public route', () {
      expect(RouterGuard.debugTermsGateRedirect(AppRoutes.pricing), isNull);
    });

    test('redirect preserves a deep-link path with its own query params', () {
      const deepLink = '/email-auth?prefill=someone%40example.com';
      expect(
        RouterGuard.debugTermsGateRedirect(deepLink),
        '${AppRoutes.login}?redirect=${Uri.encodeComponent(deepLink)}',
      );
    });
  });

  group('terms already accepted', () {
    setUp(() async {
      await Hive.box('app_settings').put('terms_accepted', true);
    });

    test('allows /email-auth through', () {
      expect(RouterGuard.debugTermsGateRedirect(AppRoutes.emailAuth), isNull);
    });

    test('allows /phone-auth through', () {
      expect(RouterGuard.debugTermsGateRedirect(AppRoutes.phoneAuth), isNull);
    });
  });
}
