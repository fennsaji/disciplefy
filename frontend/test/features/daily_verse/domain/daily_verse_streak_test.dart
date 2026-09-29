import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_streak.dart';
import 'package:flutter_test/flutter_test.dart';

DailyVerseStreak _streak(DateTime? lastViewedAt) => DailyVerseStreak(
      userId: 'u1',
      currentStreak: 3,
      longestStreak: 3,
      lastViewedAt: lastViewedAt,
      totalViews: 3,
      createdAt: DateTime.utc(2026, 9),
      updatedAt: DateTime.utc(2026, 9),
    );

/// The database hands back `last_viewed_at` in UTC. Day comparisons must use
/// the user's local calendar, or a view made while the UTC date differs from
/// the local one (00:00–05:30 in India) counts toward the wrong day.
void main() {
  test('a view a moment ago, returned as UTC, counts as today', () {
    final s = _streak(DateTime.now().toUtc());
    expect(s.hasViewedToday, isTrue);
    expect(s.canContinueStreak, isFalse);
    expect(s.shouldResetStreak, isFalse);
  });

  test('a view yesterday, returned as UTC, continues the streak', () {
    final s = _streak(DateTime.now().subtract(const Duration(days: 1)).toUtc());
    expect(s.hasViewedToday, isFalse);
    expect(s.canContinueStreak, isTrue);
  });

  test('a view two days ago resets the streak', () {
    final s = _streak(DateTime.now().subtract(const Duration(days: 2)).toUtc());
    expect(s.shouldResetStreak, isTrue);
  });

  test('local midnight edge: first minute of today in UTC form', () {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day, 0, 1);
    expect(_streak(startOfToday.toUtc()).hasViewedToday, isTrue);
  });

  test('no view yet', () {
    final s = _streak(null);
    expect(s.hasViewedToday, isFalse);
    expect(s.canContinueStreak, isFalse);
    expect(s.shouldResetStreak, isFalse);
  });
}
