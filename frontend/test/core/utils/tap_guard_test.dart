import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/core/utils/tap_guard.dart';

void main() {
  testWidgets('ignores a second tap inside the window, accepts one after it',
      (tester) async {
    final guard = TapGuard();
    addTearDown(guard.dispose);
    expect(guard.tryAcquire(), isTrue);
    expect(guard.tryAcquire(), isFalse);
    await tester.pump(const Duration(milliseconds: 999));
    expect(guard.tryAcquire(), isFalse);
    await tester.pump(const Duration(milliseconds: 2));
    expect(guard.tryAcquire(), isTrue);
    guard.release();
  });

  testWidgets('never stays locked: the action need not complete',
      (tester) async {
    final guard = TapGuard();
    addTearDown(guard.dispose);
    guard.tryAcquire();
    // The awaited push never completes; the window ends on its own.
    await tester.pump(const Duration(minutes: 5));
    expect(guard.isLocked, isFalse);
    expect(guard.tryAcquire(), isTrue);
    guard.release();
  });

  test('release ends the window early', () {
    final guard = TapGuard();
    guard.tryAcquire();
    guard.release();
    expect(guard.tryAcquire(), isTrue);
    guard.dispose();
  });
}
