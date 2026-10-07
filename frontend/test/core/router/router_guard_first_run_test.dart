// The new first run (/welcome) sits behind the new_first_run flag; a guest
// counts as signed in and is kept out of the routes that need an account.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/router/router_guard.dart';
import 'package:disciplefy_bible_study/core/services/guest_marker.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';

class _MockRolloutFlags extends Mock implements RolloutFlags {}

void main() {
  late Directory tempDir;
  late _MockRolloutFlags flags;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('guard_first_run_test');
    Hive.init(tempDir.path);
    await Hive.openBox('app_settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box('app_settings').clear();
    flags = _MockRolloutFlags();
    when(() => flags.newFirstRun).thenReturn(false);
    if (sl.isRegistered<RolloutFlags>()) sl.unregister<RolloutFlags>();
    sl.registerSingleton<RolloutFlags>(flags);
  });

  tearDown(() {
    if (sl.isRegistered<RolloutFlags>()) sl.unregister<RolloutFlags>();
  });

  group('signed out', () {
    test('new user on / goes to /welcome when new_first_run is on', () {
      when(() => flags.newFirstRun).thenReturn(true);
      expect(
        RouterGuard.debugUnauthenticatedRedirect('/',
            onboardingCompleted: false),
        AppRoutes.welcome,
      );
    });

    test('flag off keeps the slides', () {
      expect(
        RouterGuard.debugUnauthenticatedRedirect('/',
            onboardingCompleted: false),
        AppRoutes.onboarding,
      );
    });

    test('returning user on / still goes to login with the flag on', () {
      when(() => flags.newFirstRun).thenReturn(true);
      expect(
        RouterGuard.debugUnauthenticatedRedirect('/',
            onboardingCompleted: true),
        AppRoutes.login,
      );
    });

    test('a deep link on a fresh install goes to /welcome and is stashed', () {
      when(() => flags.newFirstRun).thenReturn(true);
      const link = '/fellowship/abc/post/def';
      expect(
        RouterGuard.debugUnauthenticatedRedirect(link,
            onboardingCompleted: false),
        AppRoutes.welcome,
      );
      expect(Hive.box('app_settings').get('pending_deep_link_redirect'),
          Uri.encodeComponent(link));
    });

    test('/welcome and /welcome/goal are allowed (no terms gate)', () {
      when(() => flags.newFirstRun).thenReturn(true);
      expect(
        RouterGuard.debugUnauthenticatedRedirect(AppRoutes.welcome,
            onboardingCompleted: false),
        isNull,
      );
      expect(
        RouterGuard.debugUnauthenticatedRedirect(AppRoutes.welcomeGoal,
            onboardingCompleted: false),
        isNull,
      );
    });

    test('/welcome with the flag off falls back to the slides', () {
      expect(
        RouterGuard.debugUnauthenticatedRedirect(AppRoutes.welcomeGoal,
            onboardingCompleted: false),
        AppRoutes.onboarding,
      );
    });

    group('a lost guest session (was_guest)', () {
      setUp(() => Hive.box('app_settings').put(GuestMarker.key, true));

      test('/ starts a new first run, not the login screen', () {
        when(() => flags.newFirstRun).thenReturn(true);
        expect(
          RouterGuard.debugUnauthenticatedRedirect('/',
              onboardingCompleted: true),
          AppRoutes.welcome,
        );
      });

      test('a protected route also starts a new first run', () {
        when(() => flags.newFirstRun).thenReturn(true);
        expect(
          RouterGuard.debugUnauthenticatedRedirect(AppRoutes.settings,
              onboardingCompleted: true),
          AppRoutes.welcome,
        );
      });

      test('a shared link is stashed before starting the new first run', () {
        when(() => flags.newFirstRun).thenReturn(true);
        const link = '/fellowship/abc/join';
        expect(
          RouterGuard.debugUnauthenticatedRedirect(link,
              onboardingCompleted: true),
          AppRoutes.welcome,
        );
        expect(Hive.box('app_settings').get('pending_deep_link_redirect'),
            Uri.encodeComponent(link));
      });

      test('the login screen stays reachable', () {
        when(() => flags.newFirstRun).thenReturn(true);
        Hive.box('app_settings').put('terms_accepted', true);
        expect(
          RouterGuard.debugUnauthenticatedRedirect(AppRoutes.login,
              onboardingCompleted: true),
          isNull,
        );
      });

      test('flag off: the shipped behaviour (login)', () {
        expect(
          RouterGuard.debugUnauthenticatedRedirect('/',
              onboardingCompleted: true),
          AppRoutes.login,
        );
      });

      test('a full account signing in clears the marker; a guest keeps it',
          () async {
        GuestMarker.syncWithUser(isAnonymous: true);
        expect(GuestMarker.wasGuest, isTrue);
        GuestMarker.syncWithUser(isAnonymous: false);
        await Future<void>.delayed(Duration.zero);
        expect(GuestMarker.wasGuest, isFalse);
        expect(Hive.box('app_settings').containsKey(GuestMarker.key), isFalse);
      });
    });

    test('missing RolloutFlags registration reads as off', () {
      sl.unregister<RolloutFlags>();
      expect(
        RouterGuard.debugUnauthenticatedRedirect('/',
            onboardingCompleted: false),
        AppRoutes.onboarding,
      );
    });
  });

  group('signed in or guest', () {
    test('signed-in user on /welcome is sent home', () async {
      when(() => flags.newFirstRun).thenReturn(true);
      expect(
        await RouterGuard.debugAuthenticatedRedirect(AppRoutes.welcome,
            languageCompleted: true),
        AppRoutes.home,
      );
    });

    test('guest on /welcome is sent home', () async {
      when(() => flags.newFirstRun).thenReturn(true);
      expect(
        await RouterGuard.debugAuthenticatedRedirect(AppRoutes.welcome,
            languageCompleted: true, isGuest: true),
        AppRoutes.home,
      );
    });

    test(
        'a guest just created on /welcome/goal stays there (the goal screen '
        'starts lesson 1 itself)', () async {
      when(() => flags.newFirstRun).thenReturn(true);
      expect(
        await RouterGuard.debugAuthenticatedRedirect(AppRoutes.welcomeGoal,
            languageCompleted: true, isGuest: true),
        isNull,
      );
    });

    test('/welcome/goal with the flag off sends a signed-in user home',
        () async {
      expect(
        await RouterGuard.debugAuthenticatedRedirect(AppRoutes.welcomeGoal,
            languageCompleted: true),
        AppRoutes.home,
      );
    });

    test('the language gate leaves the first-run screens alone', () async {
      when(() => flags.newFirstRun).thenReturn(true);
      expect(
        await RouterGuard.debugAuthenticatedRedirect(AppRoutes.welcomeGoal,
            languageCompleted: false, isGuest: true),
        isNull,
      );
    });

    test('language gate still applies elsewhere', () async {
      expect(
        await RouterGuard.debugAuthenticatedRedirect(AppRoutes.saved,
            languageCompleted: false),
        AppRoutes.languageSelection,
      );
    });
  });

  group('guest gate', () {
    test('guest on Generate goes home with account=generate', () async {
      expect(
        await RouterGuard.debugAuthenticatedRedirect(AppRoutes.generateStudy,
            languageCompleted: true, isGuest: true),
        '/?account=generate',
      );
    });

    test('guest on a memory verse practice route → memory_verses', () async {
      expect(
        await RouterGuard.debugAuthenticatedRedirect(
            '/memory-verses/practice/cloze/v1',
            languageCompleted: true,
            isGuest: true),
        '/?account=memory_verses',
      );
    });

    test('guest on a community route → community', () async {
      expect(
        await RouterGuard.debugAuthenticatedRedirect('/community/abc/feed',
            languageCompleted: true, isGuest: true),
        '/?account=community',
      );
    });

    test('guest keeps open routes', () async {
      expect(
        await RouterGuard.debugAuthenticatedRedirect(AppRoutes.settings,
            languageCompleted: true, isGuest: true),
        isNull,
      );
      expect(
        await RouterGuard.debugAuthenticatedRedirect('/learning-path/p1',
            languageCompleted: true, isGuest: true),
        isNull,
      );
    });

    test('a full user is not gated', () async {
      expect(
        await RouterGuard.debugAuthenticatedRedirect(AppRoutes.generateStudy,
            languageCompleted: true),
        isNull,
      );
      expect(
        await RouterGuard.debugAuthenticatedRedirect(AppRoutes.memoryVerses,
            languageCompleted: true),
        isNull,
      );
    });

    test('a signed-out user on a gated route still goes to login', () {
      expect(
        RouterGuard.debugUnauthenticatedRedirect(AppRoutes.memoryVerses,
            onboardingCompleted: true),
        '${AppRoutes.login}?redirect=${Uri.encodeComponent(AppRoutes.memoryVerses)}',
      );
    });
  });
}
