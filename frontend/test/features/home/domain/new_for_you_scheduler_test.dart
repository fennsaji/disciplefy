import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';

/// The person's start: account (or guest) creation.
final start = DateTime(2026, 10, 1, 9);
const all = {
  NewForYouKind.paths,
  NewForYouKind.memory,
  NewForYouKind.generate,
  NewForYouKind.discipler,
  NewForYouKind.fellowships,
};

NewForYouEligibility e({
  bool lesson = true,
  Set<NewForYouKind> available = all,
  DateTime? startedAt,
  bool noStart = false,
}) =>
    NewForYouEligibility(
      firstLessonCompleted: lesson,
      available: available,
      startedAt: noStart ? null : (startedAt ?? start),
    );

/// Noon on local calendar day [d] after the start day.
DateTime day(int d) => DateTime(start.year, start.month, start.day + d, 12);

/// Shows the banner on [d] the way the cubit records it.
NewForYouState shown(NewForYouState s, NewForYouKind? kind, DateTime at) =>
    kind == null ? s : s.copyWith(lastShownKind: kind, lastShownAt: at);

void main() {
  group('pickBanner: first week', () {
    for (var d = 0; d <= 6; d++) {
      test('day $d after the start: nothing', () {
        expect(pickBanner(NewForYouState.empty(), e(), day(d)), isNull);
      });
    }

    test('day 6 just before midnight: still nothing', () {
      final late = DateTime(start.year, start.month, start.day + 6, 23, 59);
      expect(pickBanner(NewForYouState.empty(), e(), late), isNull);
    });

    test('day 7 (calendar days, not hours): a banner', () {
      final early = DateTime(start.year, start.month, start.day + 7, 0, 5);
      expect(pickBanner(NewForYouState.empty(), e(), early), isNotNull);
      expect(
          pickBanner(NewForYouState.empty(), e(), day(7)), NewForYouKind.paths);
      expect(pickBanner(NewForYouState.empty(), e(), day(40)), isNotNull);
    });

    test('no known start: nothing', () {
      expect(pickBanner(NewForYouState.empty(), e(noStart: true), day(30)),
          isNull);
    });

    test('nothing before lesson 1, even after the first week', () {
      expect(pickBanner(NewForYouState.empty(), e(lesson: false), day(30)),
          isNull);
    });
  });

  group('pickBanner: rotation', () {
    test('cycles through every kind, one per day, then wraps', () {
      var s = NewForYouState.empty();
      final seen = <NewForYouKind?>[];
      for (var d = 7; d < 7 + 7; d++) {
        final kind = pickBanner(s, e(), day(d));
        seen.add(kind);
        s = shown(s, kind, day(d));
      }
      expect(seen, [
        NewForYouKind.paths,
        NewForYouKind.memory,
        NewForYouKind.generate,
        NewForYouKind.discipler,
        NewForYouKind.fellowships,
        NewForYouKind.paths,
        NewForYouKind.memory,
      ]);
    });

    test('the same kind all day, across visits', () {
      final s = shown(NewForYouState.empty(), NewForYouKind.generate, day(9));
      expect(pickBanner(s, e(), day(9)), NewForYouKind.generate);
      expect(
          pickBanner(
              s, e(), DateTime(start.year, start.month, start.day + 9, 23)),
          NewForYouKind.generate);
      expect(pickBanner(s, e(), day(10)), NewForYouKind.discipler);
    });

    test('a gap of several days moves on by one kind, not by the gap', () {
      final s = shown(NewForYouState.empty(), NewForYouKind.paths, day(7));
      expect(pickBanner(s, e(), day(20)), NewForYouKind.memory);
    });

    test('unavailable kinds are skipped in the rotation', () {
      final s = shown(NewForYouState.empty(), NewForYouKind.paths, day(7));
      expect(
          pickBanner(
              s,
              e(available: {NewForYouKind.paths, NewForYouKind.fellowships}),
              day(8)),
          NewForYouKind.fellowships);
    });

    test('opened today: nothing more today, the next kind tomorrow', () {
      final s = shown(NewForYouState.empty(), NewForYouKind.paths, day(7))
          .copyWith(openedAt: day(7));
      expect(pickBanner(s, e(), day(7)), isNull);
      expect(pickBanner(s, e(), day(8)), NewForYouKind.memory);
    });

    test('opened is not retired: the kind comes round again', () {
      var s = shown(NewForYouState.empty(), NewForYouKind.paths, day(7))
          .copyWith(openedAt: day(7));
      final seen = <NewForYouKind?>[];
      for (var d = 8; d < 13; d++) {
        final kind = pickBanner(s, e(), day(d));
        seen.add(kind);
        s = shown(s, kind, day(d));
      }
      expect(seen.last, NewForYouKind.paths);
    });
  });

  group('pickBanner: retired kinds', () {
    test('a tried kind never returns', () {
      var s = NewForYouState.empty()
          .copyWith(retired: {NewForYouKind.memory, NewForYouKind.discipler});
      for (var d = 7; d < 30; d++) {
        final kind = pickBanner(s, e(), day(d));
        expect(kind, isNot(NewForYouKind.memory));
        expect(kind, isNot(NewForYouKind.discipler));
        expect(kind, isNotNull);
        s = shown(s, kind, day(d));
      }
    });

    test('a dismissed kind never returns, even if it was today\'s', () {
      final s = shown(NewForYouState.empty(), NewForYouKind.paths, day(7))
          .copyWith(retired: {NewForYouKind.paths});
      expect(pickBanner(s, e(), day(7)), NewForYouKind.memory);
      final later = shown(s, NewForYouKind.memory, day(7));
      for (var d = 8; d < 20; d++) {
        expect(pickBanner(later, e(), day(d)), isNot(NewForYouKind.paths));
      }
    });

    test('every kind tried: nothing', () {
      final s = NewForYouState.empty().copyWith(retired: all);
      expect(pickBanner(s, e(), day(30)), isNull);
    });

    test('the only kind left shows every day until it is retired', () {
      final s =
          shown(NewForYouState.empty(), NewForYouKind.fellowships, day(10))
              .copyWith(retired: all.difference({NewForYouKind.fellowships}));
      expect(pickBanner(s, e(), day(11)), NewForYouKind.fellowships);
    });
  });

  group('guest', () {
    test('only kinds a guest can use are offered', () {
      final guest = buildEligibility(
          isGuest: true, firstLessonCompleted: true, startedAt: start);
      var s = NewForYouState.empty();
      for (var d = 7; d < 20; d++) {
        final kind = pickBanner(s, guest, day(d));
        expect(kind, NewForYouKind.paths);
        s = shown(s, kind, day(d));
      }
    });

    test('a guest who dismissed paths sees nothing', () {
      final guest = buildEligibility(
          isGuest: true, firstLessonCompleted: true, startedAt: start);
      final s = NewForYouState.empty().copyWith(retired: {NewForYouKind.paths});
      expect(pickBanner(s, guest, day(10)), isNull);
    });
  });

  group('NewForYouState', () {
    test('json round trip', () {
      final s = NewForYouState(
        retired: const {NewForYouKind.paths, NewForYouKind.fellowships},
        lastShownKind: NewForYouKind.memory,
        lastShownAt: DateTime.utc(2026, 10, 9, 8),
        openedAt: DateTime.utc(2026, 10, 9, 9),
      );
      final back = NewForYouState.fromJson(s.toJson());
      expect(back.retired, s.retired);
      expect(back.lastShownKind, NewForYouKind.memory);
      expect(back.lastShownAt, s.lastShownAt);
      expect(back.openedAt, s.openedAt);
    });

    test('json uses the server keys', () {
      final json = NewForYouState(
        retired: const {NewForYouKind.paths},
        lastShownKind: NewForYouKind.memory,
        lastShownAt: DateTime.utc(2026, 10, 9),
      ).toJson();
      expect(json.keys,
          containsAll(['retired', 'last_shown_kind', 'last_shown_at']));
    });

    test('unknown kinds, bad dates and wrong types are dropped', () {
      final s = NewForYouState.fromJson({
        'retired': ['paths', 'nope', 3],
        'last_shown_kind': 'nope',
        'last_shown_at': 'not a date',
        'opened_at': 12,
      });
      expect(s.retired, {NewForYouKind.paths});
      expect(s.lastShownKind, isNull);
      expect(s.lastShownAt, isNull);
      expect(s.openedAt, isNull);
    });

    test('a last-shown kind without a date (or the reverse) is dropped', () {
      final s = NewForYouState.fromJson({'last_shown_kind': 'paths'});
      expect(s.lastShownKind, isNull);
      expect(s.lastShownAt, isNull);
    });

    group('merge (another device or the server)', () {
      final a = NewForYouState(
        retired: const {NewForYouKind.paths},
        lastShownKind: NewForYouKind.memory,
        lastShownAt: day(8),
        openedAt: day(8),
      );
      final b = NewForYouState(
        retired: const {NewForYouKind.discipler},
        lastShownKind: NewForYouKind.generate,
        lastShownAt: day(9),
        openedAt: day(7),
      );

      test('retired kinds are the union', () {
        expect(
            a.merge(b).retired, {NewForYouKind.paths, NewForYouKind.discipler});
      });

      test('the latest shown day wins, with its kind', () {
        expect(a.merge(b).lastShownKind, NewForYouKind.generate);
        expect(b.merge(a).lastShownKind, NewForYouKind.generate);
        expect(a.merge(b).lastShownAt, day(9));
      });

      test('the latest opened time wins', () {
        expect(a.merge(b).openedAt, day(8));
        expect(b.merge(a).openedAt, day(8));
      });

      test('merging with empty keeps everything', () {
        final m = NewForYouState.empty().merge(a);
        expect(m.retired, a.retired);
        expect(m.lastShownKind, a.lastShownKind);
        expect(m.openedAt, a.openedAt);
      });
    });
  });

  group('buildEligibility', () {
    test('full user: every kind, start carried through', () {
      final el = buildEligibility(
          isGuest: false, firstLessonCompleted: true, startedAt: start);
      expect(el.available, all);
      expect(el.firstLessonCompleted, isTrue);
      expect(el.startedAt, start);
    });

    test('guest: no account-only kinds (paths only)', () {
      final el = buildEligibility(isGuest: true, firstLessonCompleted: true);
      expect(el.available, {NewForYouKind.paths});
      for (final k in accountOnlyNewForYouKinds) {
        expect(el.available, isNot(contains(k)));
      }
    });

    test('guest with paths hidden: nothing', () {
      final el = buildEligibility(
          isGuest: true,
          firstLessonCompleted: true,
          hiddenFeatures: {NewForYouKind.paths});
      expect(el.available, isEmpty);
    });

    test('hidden kinds are dropped', () {
      final el = buildEligibility(
        isGuest: false,
        firstLessonCompleted: false,
        hiddenFeatures: {NewForYouKind.discipler},
      );
      expect(el.available, all.difference({NewForYouKind.discipler}));
      expect(el.firstLessonCompleted, isFalse);
    });

    test('withStartedAt replaces the start', () {
      final el = buildEligibility(isGuest: false, firstLessonCompleted: true)
          .withStartedAt(start);
      expect(el.startedAt, start);
      expect(el.available, all);
    });
  });

  group('hiddenNewForYouKinds', () {
    test('maps the feature flags to kinds', () {
      expect(hiddenNewForYouKinds((_) => false), isEmpty);
      expect(
          hiddenNewForYouKinds(
              (k) => k == 'memory_verses' || k == 'ai_discipler'),
          {NewForYouKind.memory, NewForYouKind.discipler});
      expect(hiddenNewForYouKinds((k) => k == 'learning_paths'),
          {NewForYouKind.paths});
    });

    test('generate is hidden only when every study mode is', () {
      expect(hiddenNewForYouKinds((k) => k == 'quick_read_mode'), isEmpty);
      expect(hiddenNewForYouKinds((k) => newForYouStudyModeKeys.contains(k)),
          {NewForYouKind.generate});
    });

    test('fellowships have no flag and are never hidden', () {
      expect(hiddenNewForYouKinds((_) => true),
          all.difference({NewForYouKind.fellowships}));
    });
  });
}
