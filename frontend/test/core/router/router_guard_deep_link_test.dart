// A shared post link opened on a fresh install must survive the onboarding +
// login detour. The guard sends an unauthenticated new user to onboarding;
// unless the intended path is stashed first, the link is lost and the user
// lands on home after signing in.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/router/router_guard.dart';

void main() {
  late Directory tempDir;
  const sharedPost = '/fellowship/abc-123/post/def-456';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('guard_deep_link_test');
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

  test('fresh install: onboarding redirect stashes the shared link', () {
    expect(RouterGuard.debugUnauthenticatedRedirect(sharedPost),
        AppRoutes.onboarding);
    expect(
      Hive.box('app_settings').get('pending_deep_link_redirect'),
      Uri.encodeComponent(sharedPost),
    );
  });

  test('language selection re-stashes the link the login screen consumed', () {
    // LoginScreen deletes the key the moment auth succeeds, then go()s to the
    // shared post — where the guard sends a brand new account to language
    // selection. Without re-stashing, the link dies at that hop.
    expect(RouterGuard.debugLanguageSelectionRedirect(sharedPost),
        AppRoutes.languageSelection);
    expect(
      Hive.box('app_settings').get('pending_deep_link_redirect'),
      Uri.encodeComponent(sharedPost),
    );
  });

  test('language selection does not stash its own route', () {
    expect(
      RouterGuard.debugLanguageSelectionRedirect(AppRoutes.languageSelection),
      isNull,
    );
    expect(Hive.box('app_settings').get('pending_deep_link_redirect'), isNull);
  });

  test('login is left for the stashed link, not home, once auth lands', () {
    // The login screen navigates to the shared post the instant the session
    // arrives; the guard evaluates /login in the same frame. Returning home
    // here would race that navigation and win.
    Hive.box('app_settings')
        .put('pending_deep_link_redirect', Uri.encodeComponent(sharedPost));

    expect(RouterGuard.debugAuthRouteRedirect(AppRoutes.login), sharedPost);
    // Consumed, so a later visit to home does not bounce the user again.
    expect(Hive.box('app_settings').get('pending_deep_link_redirect'), isNull);
  });

  test('login falls back to home when nothing is stashed', () {
    expect(RouterGuard.debugAuthRouteRedirect(AppRoutes.login), AppRoutes.home);
  });
}
