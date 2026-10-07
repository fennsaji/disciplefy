import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/new_for_you_cubit.dart';

final t0 = DateTime(2026, 10, 6);
const all = {
  NewForYouKind.paths,
  NewForYouKind.memory,
  NewForYouKind.generate,
  NewForYouKind.discipler,
  NewForYouKind.fellowships,
};

NewForYouEligibility e({bool lesson = true}) =>
    NewForYouEligibility(firstLessonCompleted: lesson, available: all);

void main() {
  late SharedPreferences prefs;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = t0;
  });

  NewForYouCubit build() => NewForYouCubit(prefs: prefs, clock: () => now);

  NewForYouState stored(String userId) {
    final raw = prefs.getString(NewForYouCubit.keyFor(userId));
    return NewForYouState.fromJson(jsonDecode(raw!) as Map<String, dynamic>);
  }

  test('key is per user', () {
    expect(NewForYouCubit.keyFor('u1'), 'new_for_you_v1_u1');
  });

  blocTest<NewForYouCubit, NewForYouKind?>(
    'dismissals are per user',
    build: build,
    act: (c) async {
      await c.load('u1', e());
      await c.dismiss();
      await c.load('u2', e());
    },
    expect: () => [NewForYouKind.paths, null, NewForYouKind.paths],
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'load records firstShownAt once and saves',
    build: build,
    act: (c) async {
      await c.load('u1', e());
      now = t0.add(const Duration(days: 3));
      await c.load('u1', e());
    },
    expect: () => [NewForYouKind.paths],
    verify: (_) {
      final s = stored('u1');
      expect(s.firstShownAt, {NewForYouKind.paths: t0});
      expect(s.done, isEmpty);
    },
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'nothing before lesson 1, and nothing is recorded',
    build: build,
    act: (c) => c.load('u1', e(lesson: false)),
    expect: () => <NewForYouKind?>[],
    verify: (_) {
      final raw = prefs.getString(NewForYouCubit.keyFor('u1'));
      if (raw != null) {
        expect(stored('u1').firstShownAt, isEmpty);
      }
    },
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'dismiss persists: the banner does not come back, the next waits a week',
    build: build,
    act: (c) async {
      await c.load('u1', e());
      await c.dismiss();
      now = t0.add(const Duration(days: 3));
      await c.load('u1', e());
      now = t0.add(const Duration(days: 7));
      await c.load('u1', e());
    },
    expect: () => [NewForYouKind.paths, null, NewForYouKind.memory],
    verify: (_) {
      final s = stored('u1');
      expect(s.done, {NewForYouKind.paths});
      expect(s.firstShownAt[NewForYouKind.memory],
          t0.add(const Duration(days: 7)));
    },
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'opened marks the kind done',
    build: build,
    act: (c) async {
      await c.load('u1', e());
      await c.opened();
    },
    expect: () => [NewForYouKind.paths, null],
    verify: (_) => expect(stored('u1').done, {NewForYouKind.paths}),
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'a new cubit reads what an earlier one saved',
    build: build,
    setUp: () async {
      final first = NewForYouCubit(prefs: prefs, clock: () => t0);
      await first.load('u1', e());
      await first.dismiss();
      await first.close();
    },
    act: (c) => c.load('u1', e()),
    expect: () => <NewForYouKind?>[],
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'dismiss with no banner does nothing',
    build: build,
    act: (c) => c.dismiss(),
    expect: () => <NewForYouKind?>[],
    verify: (_) => expect(prefs.getKeys(), isEmpty),
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'a corrupt stored value is treated as empty',
    build: build,
    setUp: () => prefs.setString(NewForYouCubit.keyFor('u1'), '{not json'),
    act: (c) => c.load('u1', e()),
    expect: () => [NewForYouKind.paths],
  );
}
