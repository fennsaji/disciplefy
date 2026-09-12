@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the deep-link paths for a shared daily verse and a shared study
/// guide.
///
/// Neither had any deep link at all before: sharing either only appended a
/// generic app-download link, so tapping it just opened a browser — never
/// the app, let alone the right screen inside it.
void main() {
  final router = File('lib/core/router/app_router.dart').readAsStringSync();
  final service =
      File('lib/core/services/deep_link_service.dart').readAsStringSync();
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final aasa =
      File('web/.well-known/apple-app-site-association').readAsStringSync();
  final routes = File('lib/core/router/app_routes.dart').readAsStringSync();

  test('a shared daily verse link has a top-level route to Home', () {
    expect(router.contains('path: AppRoutes.dailyVerseShared'), true);
    final block = RegExp(
      r'daily_verse_shared[\s\S]{0,300}?\),\n',
    ).stringMatch(router);
    expect(block, isNotNull, reason: 'route block not found');
    expect(block!.contains('AppRoutes.home'), true,
        reason: 'there is no per-verse content to open — Home is the point');
  });

  test('a shared study guide link opens the exact literal path', () {
    // GoRouter's own native App Links handling races DeepLinkService's
    // manual `_router.go(...)` call for any incoming URI. If the registered
    // route path does not exactly match the literal incoming path (segment
    // for segment), GoRouter's own routing 404s on the raw path and that
    // error lands after DeepLinkService's redirect, clobbering it. This bit
    // once already: the route was registered as `/study-guide-open/:id`
    // while the shared link and the deep-link handler both use
    // `/study-guide/:id`.
    expect(
      routes.contains(
          "static const String studyGuideOpen = '/study-guide/:guideId'"),
      true,
      reason: 'the registered route must match the literal shared-link path',
    );
    expect(service.contains("_router.go('/study-guide/\$guideId')"), true,
        reason: 'must match the literal incoming path exactly');
  });

  test('the study guide open route is keyed by guideId', () {
    // Without a key tied to guideId, opening a second shared-guide link
    // reuses the same State object — initState() (and its fetch) never
    // reruns, so the screen silently keeps showing the first guide.
    final block = RegExp(
      r'study_guide_open[\s\S]{0,600}?\),\n',
    ).stringMatch(router);
    expect(block, isNotNull, reason: 'route block not found');
    expect(block!.contains('ValueKey'), true,
        reason: 'a fresh guideId must produce a fresh State, not a reused one');
  });

  test('the deep link service validates and routes both link types', () {
    expect(service.contains("'daily-verse'"), true);
    expect(service.contains("'study-guide'"), true);
    expect(service.contains("_router.go('/daily-verse')"), true);
  });

  test('the platforms advertise the same paths', () {
    expect(manifest.contains('android:pathPrefix="/daily-verse"'), true);
    expect(manifest.contains('android:pathPrefix="/study-guide"'), true);
    expect(aasa.contains('/daily-verse'), true);
    expect(aasa.contains('/study-guide/*'), true);
  });
}
