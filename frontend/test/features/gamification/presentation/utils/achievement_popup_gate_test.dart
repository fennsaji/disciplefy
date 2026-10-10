import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/gamification/presentation/utils/achievement_popup_gate.dart';

void main() {
  tearDown(AchievementPopupGate.reset);

  test('holds on every study guide route', () {
    for (final route in [
      '/study-guide',
      '/study-guide/abc',
      '/study-guide-v2',
      '/study-guide-v2?input=John%203&source=learningPath',
    ]) {
      expect(AchievementPopupGate.holdsAt(route), isTrue, reason: route);
    }
  });

  test('shows elsewhere', () {
    for (final route in ['/', '/study-topics', '/paths', '/study-guides']) {
      expect(AchievementPopupGate.holdsAt(route), isFalse, reason: route);
    }
  });

  test('Lesson complete holds until released, and again after', () {
    expect(AchievementPopupGate.holdsAt('/lesson-complete'), isTrue);
    AchievementPopupGate.release();
    expect(AchievementPopupGate.holdsAt('/lesson-complete'), isFalse);
    AchievementPopupGate.endRelease();
    expect(AchievementPopupGate.holdsAt('/lesson-complete'), isTrue);
  });

  test('release asks for the queue to be shown', () {
    var flushes = 0;
    void count() => flushes++;
    AchievementPopupGate.flushRequests.addListener(count);
    addTearDown(() => AchievementPopupGate.flushRequests.removeListener(count));
    AchievementPopupGate.release();
    expect(flushes, 1);
  });

  test('shows one at a time, only with something queued', () {
    expect(
        AchievementPopupGate.shouldShow(
            location: '/', hasPending: true, alreadyShowing: false),
        isTrue);
    expect(
        AchievementPopupGate.shouldShow(
            location: '/', hasPending: true, alreadyShowing: true),
        isFalse);
    expect(
        AchievementPopupGate.shouldShow(
            location: '/', hasPending: false, alreadyShowing: false),
        isFalse);
    expect(
        AchievementPopupGate.shouldShow(
            location: '/study-guide-v2',
            hasPending: true,
            alreadyShowing: false),
        isFalse);
  });

  group('suppressedFor (no pop-ups for guests or new accounts)', () {
    final now = DateTime(2026, 10, 10, 12);
    test('a guest never sees one', () {
      expect(
          AchievementPopupGate.suppressedFor(
              isGuest: true,
              accountCreatedAt: now.subtract(const Duration(days: 90)),
              now: now),
          isTrue);
    });
    test('an account under 7 days old does not', () {
      expect(
          AchievementPopupGate.suppressedFor(
              isGuest: false,
              accountCreatedAt: now.subtract(const Duration(days: 6)),
              now: now),
          isTrue);
    });
    test('an account of unknown age does not', () {
      expect(
          AchievementPopupGate.suppressedFor(
              isGuest: false, accountCreatedAt: null, now: now),
          isTrue);
    });
    test('an account 7 days or older does', () {
      expect(
          AchievementPopupGate.suppressedFor(
              isGuest: false,
              accountCreatedAt: now.subtract(const Duration(days: 7)),
              now: now),
          isFalse);
    });
  });
}
