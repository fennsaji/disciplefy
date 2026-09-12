import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Since Flutter 3.44, `SnackBar.persist` defaults to `action != null`
/// (`persist = persist ?? action != null` in the SDK's snack_bar.dart). A
/// persisting SnackBar never times out, and because the app has a single
/// app-level ScaffoldMessenger with a FIFO queue, the stuck one also blocks
/// every snackbar shown afterwards — from any screen — for the rest of the
/// session. It reached the emulator as an error toast that sat on screen for
/// minutes and followed the user across three routes.
void main() {
  test('the SDK still defaults an action SnackBar to persisting', () {
    // If this ever fails, Flutter changed the default back and the explicit
    // `persist: false` below is no longer load-bearing.
    final withAction = SnackBar(
      content: const Text('x'),
      action: SnackBarAction(label: 'y', onPressed: () {}),
    );
    expect(withAction.persist, isTrue);

    const withoutAction = SnackBar(content: Text('x'));
    expect(withoutAction.persist, isFalse);
  });

  test('every SnackBar with an action opts out of persisting', () {
    final lib = Directory('lib');
    final offenders = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('SnackBarAction')) continue;

      // Count the SnackBars that carry an action against the persist opt-outs
      // in the same file. Both are per-SnackBar, so the counts must match.
      final actions = 'SnackBarAction'.allMatches(source).length;
      final optOuts = 'persist: false'.allMatches(source).length;
      if (optOuts < actions) {
        offenders
            .add('${entity.path}: $actions action(s), $optOuts opt-out(s)');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'A SnackBar with an action needs `persist: false`, or it never '
          'dismisses and blocks the app-wide snackbar queue:\n'
          '${offenders.join('\n')}',
    );
  });
}
