import 'package:flutter_test/flutter_test.dart';

import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';

final t0 = DateTime(2026, 10, 6);
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
}) =>
    NewForYouEligibility(firstLessonCompleted: lesson, available: available);

DateTime day(int d) => t0.add(Duration(days: d));

void main() {
  group('pickBanner', () {
    test('nothing before lesson 1', () {
      expect(pickBanner(NewForYouState.empty(), e(lesson: false), t0), isNull);
    });

    test('nothing before lesson 1 even with a banner in its week', () {
      final s = NewForYouState(
          firstShownAt: {NewForYouKind.paths: t0}, done: const {});
      expect(pickBanner(s, e(lesson: false), day(1)), isNull);
    });

    test('first banner is paths', () {
      expect(pickBanner(NewForYouState.empty(), e(), t0), NewForYouKind.paths);
    });

    test('same banner stays during its week', () {
      final s = NewForYouState(
          firstShownAt: {NewForYouKind.paths: t0}, done: const {});
      expect(pickBanner(s, e(), day(3)), NewForYouKind.paths);
      expect(pickBanner(s, e(), t0.add(const Duration(days: 6, hours: 23))),
          NewForYouKind.paths);
    });

    test('dismissed: nothing new until 7 days after it was first shown', () {
      final s = NewForYouState(
          firstShownAt: {NewForYouKind.paths: t0}, done: {NewForYouKind.paths});
      expect(pickBanner(s, e(), day(2)), isNull);
      expect(pickBanner(s, e(), day(7)), NewForYouKind.memory);
    });

    test('an ignored banner retires after its week and the next one starts',
        () {
      final s = NewForYouState(
          firstShownAt: {NewForYouKind.paths: t0}, done: const {});
      expect(pickBanner(s, e(), day(7)), NewForYouKind.memory);
      final later = NewForYouState(firstShownAt: {
        NewForYouKind.paths: t0,
        NewForYouKind.memory: day(7),
      }, done: const {});
      for (var d = 14; d < 100; d += 7) {
        expect(pickBanner(later, e(), day(d)), isNot(NewForYouKind.paths));
        expect(pickBanner(later, e(), day(d)), isNot(NewForYouKind.memory));
      }
    });

    test('at most one new banner a week', () {
      final s = NewForYouState(firstShownAt: {
        NewForYouKind.paths: t0,
        NewForYouKind.memory: day(7),
      }, done: {
        NewForYouKind.paths,
        NewForYouKind.memory,
      });
      expect(pickBanner(s, e(), day(8)), isNull);
      expect(pickBanner(s, e(), day(13)), isNull);
      expect(pickBanner(s, e(), day(14)), NewForYouKind.generate);
    });

    test('follows the enum order', () {
      final s = NewForYouState(firstShownAt: {
        NewForYouKind.paths: t0,
        NewForYouKind.memory: day(7),
        NewForYouKind.generate: day(14),
      }, done: {
        NewForYouKind.paths,
        NewForYouKind.memory,
        NewForYouKind.generate,
      });
      expect(pickBanner(s, e(), day(21)), NewForYouKind.discipler);
    });

    test('unavailable kinds are skipped (e.g. guest: no discipler/fellowships)',
        () {
      final s = NewForYouState(firstShownAt: {
        NewForYouKind.paths: t0,
        NewForYouKind.memory: day(7),
        NewForYouKind.generate: day(14),
      }, done: {
        NewForYouKind.paths,
        NewForYouKind.memory,
        NewForYouKind.generate,
      });
      expect(
          pickBanner(
              s,
              e(available: {
                NewForYouKind.paths,
                NewForYouKind.memory,
                NewForYouKind.generate,
              }),
              day(30)),
          isNull);
    });

    test('an unavailable first kind is skipped for the next one', () {
      expect(
          pickBanner(NewForYouState.empty(),
              e(available: {NewForYouKind.generate}), t0),
          NewForYouKind.generate);
    });

    test(
        'a banner in its week that became unavailable is not shown and '
        'blocks a new one until the week ends', () {
      final s = NewForYouState(
          firstShownAt: {NewForYouKind.memory: t0}, done: const {});
      final noMemory = e(available: {
        NewForYouKind.generate,
        NewForYouKind.discipler,
      });
      expect(pickBanner(s, noMemory, day(2)), isNull);
      expect(pickBanner(s, noMemory, day(7)), NewForYouKind.generate);
    });

    test('a dismissed banner never returns', () {
      final s = NewForYouState(
          firstShownAt: {NewForYouKind.paths: t0}, done: {NewForYouKind.paths});
      for (var d = 0; d < 100; d += 7) {
        expect(pickBanner(s, e(), day(d)), isNot(NewForYouKind.paths));
      }
    });

    test('nothing once every kind has been shown', () {
      final s = NewForYouState(firstShownAt: {
        for (final (i, k) in NewForYouKind.values.indexed) k: day(i * 7),
      }, done: NewForYouKind.values.toSet());
      expect(pickBanner(s, e(), day(100)), isNull);
    });
  });

  group('NewForYouState json', () {
    test('round trip', () {
      final s = NewForYouState(
          firstShownAt: {NewForYouKind.memory: t0},
          done: {NewForYouKind.paths});
      final back = NewForYouState.fromJson(s.toJson());
      expect(back.done, {NewForYouKind.paths});
      expect(back.firstShownAt, {NewForYouKind.memory: t0});
    });

    test('unknown kinds and bad dates are dropped', () {
      final s = NewForYouState.fromJson({
        'firstShownAt': {
          'paths': t0.toIso8601String(),
          'retired_kind': t0.toIso8601String(),
          'memory': 'not a date',
        },
        'done': ['generate', 'nope', 3],
      });
      expect(s.firstShownAt, {NewForYouKind.paths: t0});
      expect(s.done, {NewForYouKind.generate});
    });

    test('garbage gives the empty state', () {
      final s = NewForYouState.fromJson({'firstShownAt': 4, 'done': 'x'});
      expect(s.firstShownAt, isEmpty);
      expect(s.done, isEmpty);
    });
  });

  group('buildEligibility', () {
    test('full user: every kind', () {
      final el = buildEligibility(isGuest: false, firstLessonCompleted: true);
      expect(el.available, all);
      expect(el.firstLessonCompleted, isTrue);
    });

    test('guest: paths only', () {
      final el = buildEligibility(isGuest: true, firstLessonCompleted: true);
      expect(el.available, {NewForYouKind.paths});
    });

    test('guest with paths hidden: nothing', () {
      final el = buildEligibility(
          isGuest: true,
          firstLessonCompleted: true,
          hiddenFeatures: {NewForYouKind.paths});
      expect(el.available, isEmpty);
    });

    test('hidden and used kinds are dropped', () {
      final el = buildEligibility(
        isGuest: false,
        firstLessonCompleted: false,
        hiddenFeatures: {NewForYouKind.discipler},
        usedFeatures: {NewForYouKind.memory, NewForYouKind.fellowships},
      );
      expect(el.available, {NewForYouKind.paths, NewForYouKind.generate});
      expect(el.firstLessonCompleted, isFalse);
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
