import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/gamification/presentation/utils/unlock_dates.dart';

/// Converts an instant to India Standard Time (+5:30) wall-clock values,
/// so the tests do not depend on the machine's time zone.
DateTime _toIst(DateTime d) =>
    d.toUtc().add(const Duration(hours: 5, minutes: 30));

String _label(DateTime unlockedAt, DateTime now) => relativeUnlockLabel(
      unlockedAt,
      now: now,
      today: 'Today',
      yesterday: 'Yesterday',
      daysAgo: 'days ago',
      toLocal: _toIst,
    );

void main() {
  // Server timestamp "2026-10-06T19:36:06+00:00" — 01:06 on Oct 7 in IST.
  final unlockedAt = DateTime.tryParse('2026-10-06T19:36:06+00:00')!;

  group('relativeUnlockLabel', () {
    test('late-UTC-day unlock is Today for a user ahead of UTC', () {
      expect(unlockedAt.isUtc, isTrue);
      expect(_label(unlockedAt, DateTime(2026, 10, 7, 1, 10)), 'Today');
    });

    test('next local day says Yesterday', () {
      expect(_label(unlockedAt, DateTime(2026, 10, 8, 0, 5)), 'Yesterday');
    });

    test('two local days later says 2 days ago', () {
      expect(_label(unlockedAt, DateTime(2026, 10, 9, 23, 59)), '2 days ago');
    });

    test('a week or more falls back to the local date', () {
      expect(_label(unlockedAt, DateTime(2026, 10, 20)), '7/10/2026');
    });

    test('default conversion uses the device local time', () {
      final local = unlockedAt.toLocal();
      final now = DateTime(local.year, local.month, local.day, 23, 59);
      expect(
        relativeUnlockLabel(unlockedAt,
            now: now, today: 'T', yesterday: 'Y', daysAgo: 'd'),
        'T',
      );
    });
  });

  group('formatUnlockDate', () {
    test('formats the local calendar date', () {
      expect(formatUnlockDate(unlockedAt, toLocal: _toIst), 'Oct 7, 2026');
    });
  });
}
