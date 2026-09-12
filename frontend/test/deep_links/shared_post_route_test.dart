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

  test('the route lands on the community list, never inside the fellowship',
      () {
    // A shared link reaches people who are not in the fellowship. This redirect
    // is synchronous and cannot know, so it must not send anyone into the
    // fellowship screen — every request that screen makes returns 403 for a
    // non-member, which is how a shared link produced "0 members", "Something
    // went wrong" and a red server-error toast. DeepLinkService does the
    // membership check and opens the post itself when the user may see it.
    final block = RegExp(
      r'fellowship_post_deep[\s\S]{0,1600}?\),\n',
    ).stringMatch(router);

    expect(block, isNotNull, reason: 'route block not found');
    expect(block!.contains('AppRoutes.community'), true,
        reason: 'the safe landing spot is the community list');
    expect(
      block.contains(r'$fellowshipId/post/$postId'),
      false,
      reason: 'redirecting straight into the fellowship walks non-members '
          'into a screen that can only fail',
    );
  });

  test('the deep link service checks membership before opening a post', () {
    final service =
        File('lib/core/services/deep_link_service.dart').readAsStringSync();

    expect(service.contains('caller_is_member'), true,
        reason: 'membership decides whether the post can be opened at all');
    expect(service.contains('is_public'), true,
        reason: 'a public group gets an offer to join rather than a refusal');
    expect(service.contains('joinPublicFellowship'), true,
        reason: 'accepting the offer has to actually join');
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
