@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the deep-link path for a shared fellowship post.
///
/// Shared links, the Android intent filters and the Apple site association all
/// use `/fellowship/<id>/post/<id>`, but the screen lives under
/// `/community/<id>/post/<id>` inside the navigation shell. The router had no
/// top-level entry for the first form, so every shared post opened the app on
/// "Something went wrong" — the app launched, then dropped the link.
void main() {
  final router = File('lib/core/router/app_router.dart').readAsStringSync();

  test('a shared post path has a top-level route', () {
    expect(
      router.contains("path: '/fellowship/:fellowshipId/post/:postId'"),
      true,
      reason: 'without this the deep link falls through to the error page',
    );
  });

  test('it redirects into the community screen rather than a second copy', () {
    final redirectsToCommunity = RegExp(
      r'fellowship_post_deep[\s\S]{0,400}AppRoutes\.community',
    ).hasMatch(router);

    expect(redirectsToCommunity, true,
        reason: 'one screen serves both paths; a duplicate would drift');
  });

  test('the platforms advertise the same path', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final aasa =
        File('web/.well-known/apple-app-site-association').readAsStringSync();

    expect(manifest.contains('android:pathPrefix="/fellowship"'), true);
    expect(aasa.contains('/fellowship/*/post/*'), true);
  });
}
