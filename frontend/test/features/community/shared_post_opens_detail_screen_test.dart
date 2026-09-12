@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A shared post link used to push the full feed and dispatch
/// `FellowshipCommentsOpenRequested` with nothing on screen reacting to it —
/// the event only sets bloc state that the comment sheet's tap handlers read
/// when the sheet is opened directly alongside it. Dispatched on its own,
/// nothing happened: no scroll to the post, no comments sheet, nothing.
///
/// The fix pushes a real detail screen showing the post and its full comment
/// thread, instead of relying on a bloc event nobody was listening for.
void main() {
  final homeScreen = File(
    'lib/features/community/presentation/screens/fellowship_home_screen.dart',
  ).readAsStringSync();
  final detailScreen = File(
    'lib/features/community/presentation/screens/fellowship_post_detail_screen.dart',
  ).readAsStringSync();

  test('the deep-linked post pushes the detail screen, not the bare feed', () {
    final block = RegExp(
      r'_handleFeedStateChange[\s\S]{0,700}?\n  }',
    ).stringMatch(homeScreen);
    expect(block, isNotNull, reason: 'handler not found');
    expect(block!.contains('FellowshipPostDetailScreen'), true,
        reason: 'a shared post link must open a screen that shows the post');
    expect(block.contains('_FellowshipFullFeedPage'), false,
        reason: 'the bare feed does not scroll to or highlight the post');
  });

  test('the detail screen renders the post itself, not just comments', () {
    expect(detailScreen.contains('FellowshipPostCard'), true,
        reason: 'the reader came to read this post, not just its comments');
    expect(detailScreen.contains('FellowshipCommentsBody'), true,
        reason: 'the whole thread must be visible, not opened as a sheet');
  });

  test('opening the thread no longer depends on an unheard bloc event', () {
    // The body itself sets its target when it builds; the caller does not
    // need to also fire FellowshipCommentsOpenRequested to make that happen.
    expect(detailScreen.contains('FellowshipCommentsOpenRequested'), true,
        reason: 'the comment thread still needs its target post set');
  });
}
