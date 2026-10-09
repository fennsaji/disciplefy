import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/services/activation_analytics.dart';
import 'package:disciplefy_bible_study/features/home/data/services/new_for_you_remote_impl.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_remote.dart';
import 'package:disciplefy_bible_study/features/home/domain/new_for_you/new_for_you_scheduler.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/new_for_you_cubit.dart';

import '../../../../helpers/mock_activation_analytics.dart';

/// Account created a month before [t0]: past the first week.
final created = DateTime(2026, 9, 6, 9);
final t0 = DateTime(2026, 10, 6, 12);
const all = {
  NewForYouKind.paths,
  NewForYouKind.memory,
  NewForYouKind.generate,
  NewForYouKind.discipler,
  NewForYouKind.fellowships,
};

NewForYouEligibility e({bool lesson = true}) =>
    NewForYouEligibility(firstLessonCompleted: lesson, available: all);

/// A server that merges like `sync_new_for_you`, per user.
class FakeRemote implements NewForYouRemote {
  final Map<String, NewForYouState> rows = {};
  final Map<String, Set<NewForYouKind>> tried = {};
  DateTime? startedAt;
  String user = 'u1';
  bool fail = false;
  int calls = 0;

  @override
  Future<NewForYouSync> sync(NewForYouState local) async {
    calls++;
    if (fail) throw Exception('offline');
    final merged = (rows[user] ?? NewForYouState.empty())
        .merge(local)
        .merge(NewForYouState(retired: tried[user] ?? const {}));
    rows[user] = merged;
    return NewForYouSync(state: merged, startedAt: startedAt);
  }
}

void main() {
  late SharedPreferences prefs;
  late DateTime now;
  late FakeRemote remote;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = t0;
    remote = FakeRemote()..startedAt = created;
  });

  NewForYouCubit build({NewForYouRemote? r, DateTime? accountCreated}) =>
      NewForYouCubit(
        prefs: prefs,
        remote: r ?? remote,
        clock: () => now,
        accountCreatedAt: () => accountCreated,
      );

  NewForYouState stored(String userId) {
    final raw = prefs.getString(NewForYouCubit.keyFor(userId));
    return NewForYouState.fromJson(jsonDecode(raw!) as Map<String, dynamic>);
  }

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('key is per user', () {
    expect(NewForYouCubit.keyFor('u1'), 'new_for_you_v2_u1');
  });

  group('first week (start date from the server)', () {
    blocTest<NewForYouCubit, NewForYouKind?>(
      'an account created 3 days ago sees nothing',
      build: build,
      setUp: () => remote.startedAt = t0.subtract(const Duration(days: 3)),
      act: (c) => c.load('u1', e()),
      expect: () => <NewForYouKind?>[],
    );

    blocTest<NewForYouCubit, NewForYouKind?>(
      'the server start wins over the device one',
      build: () => build(accountCreated: created),
      setUp: () => remote.startedAt = t0.subtract(const Duration(days: 2)),
      act: (c) => c.load('u1', e()),
      expect: () => <NewForYouKind?>[],
    );

    blocTest<NewForYouCubit, NewForYouKind?>(
      'offline: the session account creation time is used',
      build: () => build(accountCreated: created),
      setUp: () => remote.fail = true,
      act: (c) => c.load('u1', e()),
      expect: () => [NewForYouKind.paths],
    );

    blocTest<NewForYouCubit, NewForYouKind?>(
      'no start known anywhere: nothing',
      build: build,
      setUp: () => remote.fail = true,
      act: (c) => c.load('u1', e()),
      expect: () => <NewForYouKind?>[],
    );
  });

  blocTest<NewForYouCubit, NewForYouKind?>(
    'rotates one kind per day and records it on the device and server',
    build: build,
    act: (c) async {
      await c.load('u1', e());
      now = t0.add(const Duration(hours: 3));
      await c.load('u1', e());
      now = t0.add(const Duration(days: 1));
      await c.load('u1', e());
      await flush();
    },
    expect: () => [NewForYouKind.paths, NewForYouKind.memory],
    verify: (_) {
      expect(stored('u1').lastShownKind, NewForYouKind.memory);
      expect(remote.rows['u1']!.lastShownKind, NewForYouKind.memory);
    },
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'a kind tried (per the server) is never shown',
    build: build,
    setUp: () => remote.tried['u1'] = {NewForYouKind.paths},
    act: (c) => c.load('u1', e()),
    expect: () => [NewForYouKind.memory],
    verify: (_) => expect(stored('u1').retired, contains(NewForYouKind.paths)),
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'everything tried: nothing',
    build: build,
    setUp: () => remote.tried['u1'] = all,
    act: (c) => c.load('u1', e()),
    expect: () => <NewForYouKind?>[],
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'dismiss retires the kind, here and on the server, and today moves on '
    'only on the next visit',
    build: build,
    act: (c) async {
      await c.load('u1', e());
      await c.dismiss();
      await flush();
      now = t0.add(const Duration(days: 1));
      await c.load('u1', e());
      for (var d = 2; d < 12; d++) {
        now = t0.add(Duration(days: d));
        await c.load('u1', e());
        expect(c.state, isNot(NewForYouKind.paths));
      }
    },
    expect: () => [
      NewForYouKind.paths,
      null,
      NewForYouKind.memory,
      NewForYouKind.generate,
      NewForYouKind.discipler,
      NewForYouKind.fellowships,
      NewForYouKind.memory,
      NewForYouKind.generate,
      NewForYouKind.discipler,
      NewForYouKind.fellowships,
      NewForYouKind.memory,
      NewForYouKind.generate,
      NewForYouKind.discipler,
    ],
    verify: (_) {
      expect(stored('u1').retired, {NewForYouKind.paths});
      expect(remote.rows['u1']!.retired, {NewForYouKind.paths});
    },
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'opened: nothing more today, not retired, next kind tomorrow',
    build: build,
    act: (c) async {
      await c.load('u1', e());
      await c.opened();
      now = t0.add(const Duration(hours: 2));
      await c.load('u1', e());
      now = t0.add(const Duration(days: 1));
      await c.load('u1', e());
    },
    expect: () => [NewForYouKind.paths, null, NewForYouKind.memory],
    verify: (_) => expect(stored('u1').retired, isEmpty),
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'per user: another account on the device starts fresh',
    build: build,
    act: (c) async {
      await c.load('u1', e());
      await c.dismiss();
      await flush();
      remote.user = 'u2';
      await c.load('u2', e());
    },
    expect: () => [NewForYouKind.paths, null, NewForYouKind.paths],
    verify: (_) {
      expect(stored('u1').retired, {NewForYouKind.paths});
      expect(stored('u2').retired, isEmpty);
    },
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'across devices: a kind dismissed elsewhere stays retired',
    build: build,
    setUp: () => remote.rows['u1'] = const NewForYouState(
        retired: {NewForYouKind.paths, NewForYouKind.memory}),
    act: (c) => c.load('u1', e()),
    expect: () => [NewForYouKind.generate],
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'offline: the device copy still keeps a dismissed kind away',
    build: () => build(accountCreated: created),
    setUp: () async {
      final first = build();
      await first.load('u1', e());
      await first.dismiss();
      await first.close();
      remote.fail = true;
    },
    act: (c) => c.load('u1', e()),
    expect: () => [NewForYouKind.memory],
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'nothing before lesson 1, and nothing is recorded as shown',
    build: build,
    act: (c) => c.load('u1', e(lesson: false)),
    expect: () => <NewForYouKind?>[],
    verify: (_) => expect(stored('u1').lastShownKind, isNull),
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'dismiss with no banner does nothing',
    build: build,
    act: (c) => c.dismiss(),
    expect: () => <NewForYouKind?>[],
    verify: (_) {
      expect(prefs.getKeys(), isEmpty);
      expect(remote.calls, 0);
    },
  );

  blocTest<NewForYouCubit, NewForYouKind?>(
    'a corrupt stored value is treated as empty',
    build: build,
    setUp: () => prefs.setString(NewForYouCubit.keyFor('u1'), '{not json'),
    act: (c) => c.load('u1', e()),
    expect: () => [NewForYouKind.paths],
  );

  group('parseNewForYouSync', () {
    test('reads the function result', () {
      final sync = parseNewForYouSync({
        'retired': ['paths', 'discipler'],
        'last_shown_kind': 'memory',
        'last_shown_at': '2026-10-08T06:00:00Z',
        'opened_at': null,
        'started_at': '2026-09-01T10:00:00Z',
      });
      expect(
          sync.state.retired, {NewForYouKind.paths, NewForYouKind.discipler});
      expect(sync.state.lastShownKind, NewForYouKind.memory);
      expect(sync.startedAt, DateTime.utc(2026, 9, 1, 10));
    });

    test('garbage gives an empty state and no start', () {
      final sync = parseNewForYouSync('nope');
      expect(sync.state.retired, isEmpty);
      expect(sync.startedAt, isNull);
    });
  });

  group('activation analytics', () {
    late MockActivationAnalytics analytics;

    setUp(() => analytics = registerMockAnalytics());
    tearDown(() async => sl.reset());

    test('an impression is sent once per kind per day', () async {
      final c = build();
      await c.load('u1', e());
      await c.load('u1', e());
      // A new launch the same day remembers it.
      await build().load('u1', e());
      verify(() => analytics.track(NuxEvent.nfyImpression, {'kind': 'paths'}))
          .called(1);
    });

    test('no banner, no impression', () async {
      await build().load('u1', e(lesson: false));
      verifyNever(() => analytics.track(any(), any()));
    });

    test('tap and dismiss carry the kind', () async {
      final c = build();
      await c.load('u1', e());
      await c.opened();
      verify(() => analytics.track(NuxEvent.nfyTap, {'kind': 'paths'}))
          .called(1);

      remote.user = 'u2';
      final d = build();
      await d.load('u2', e());
      await d.dismiss();
      verify(() => analytics.track(NuxEvent.nfyDismiss, {'kind': 'paths'}))
          .called(1);
    });

    test('tap with no banner sends nothing', () async {
      await build().opened();
      verifyNever(() => analytics.track(any(), any()));
    });
  });
}
