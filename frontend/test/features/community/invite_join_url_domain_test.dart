@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The invites screen's fallback join URL used to hardcode app.disciplefy.in
/// — the bare client-side SPA, with no Open Graph preview and no app-store
/// fallback for someone who hasn't installed the app. Every other
/// invite-sharing path already used ShareLinks.fellowshipInvite, which points
/// at go.disciplefy.in, the landing page built for exactly that recipient.
/// This was the one inconsistency.
void main() {
  final source = File(
    'lib/features/community/presentation/screens/fellowship_invites_screen.dart',
  ).readAsStringSync();

  test('the fallback join URL goes through ShareLinks, not a hardcoded host',
      () {
    expect(source.contains('ShareLinks.fellowshipInvite(_token)'), true,
        reason:
            'the fallback must use the same host as every other invite link');
    expect(source.contains('https://app.disciplefy.in'), false,
        reason:
            'a hardcoded app.disciplefy.in has no preview or app-store fallback');
  });
}
