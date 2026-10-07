import 'dart:convert';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/onboarding/domain/growth_goals.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_cubit.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/models/learning_path_model.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockPaths extends Mock implements LearningPathsRepository {}

class _MockFlags extends Mock implements RolloutFlags {}

class _MockLanguage extends Mock implements LanguagePreferenceService {}

class _FakeWalkthrough extends Fake implements WalkthroughRepository {
  @override
  Future<void> markSeen(WalkthroughScreen screen) async {}
}

EnrollmentResult _enrollment(String pathId) => EnrollmentResult(
      id: 'e1',
      learningPathId: pathId,
      enrolledAt: DateTime(2026),
      startedAt: DateTime(2026),
    );

LearningPathTopic _topic(int position, String id) => LearningPathTopic(
      position: position,
      isMilestone: false,
      topicId: id,
      title: 'Lesson $id',
      description: 'About $id',
      category: 'Foundations',
      xpValue: 10,
    );

LearningPathDetail _path(String id) => LearningPathDetail.forTest(
      id: id,
      title: 'New Believer Essentials',
      description: 'Start here',
      // Out of order on purpose: lesson 1 is the lowest position.
      topics: [_topic(2, 't2'), _topic(1, 't1'), _topic(3, 't3')],
    );

LearningPath _listed(String slug, String title, int lessons) => LearningPath(
      id: slug,
      slug: slug,
      title: title,
      description: '',
      iconName: '',
      color: '',
      totalXp: 0,
      estimatedDays: 0,
      discipleLevel: '',
      topicsCount: lessons,
    );

/// A path detail parsed exactly as the app parses the server's answer
/// (fixtures are real responses from the local learning-paths function).
LearningPathDetail _serverDetail(String fixture) {
  final body = jsonDecode(
    File('test/fixtures/learning_paths/$fixture.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return LearningPathDetailModel.fromJson(body['data'] as Map<String, dynamic>);
}

void main() {
  late Directory tempDir;
  late Box settings;
  late _MockGuest guest;
  late _MockPaths paths;
  late _MockFlags flags;
  late _MockLanguage language;

  setUpAll(() async {
    registerFallbackValue(AppLanguage.english);
    tempDir = await Directory.systemTemp.createTemp('first_run_cubit_test');
    Hive.init(tempDir.path);
    settings = await Hive.openBox('app_settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await settings.clear();
    guest = _MockGuest();
    paths = _MockPaths();
    flags = _MockFlags();
    language = _MockLanguage();
    when(() => flags.guestMode).thenReturn(true);
    when(() => guest.hasSession).thenReturn(false);
    when(() => guest.isGuest).thenReturn(false);
    when(() => guest.startGuest()).thenAnswer((_) async {});
    when(() => language.saveLanguagePreference(any())).thenAnswer((_) async {});
    when(() => paths.enrollInPathBySlug(any()))
        .thenAnswer((_) async => Right(_enrollment('p1')));
    when(() => paths.getLearningPathDetails(
          pathId: 'p1',
          language: any(named: 'language'),
          forceRefresh: true,
        )).thenAnswer((_) async => Right(_path('p1')));
  });

  FirstRunCubit cubit() => FirstRunCubit(
        guest: guest,
        paths: paths,
        flags: flags,
        language: language,
        settings: settings,
        walkthrough: _FakeWalkthrough(),
      );

  group('GrowthGoal', () {
    test('six goals in screen order, each on its first-run path', () {
      expect(GrowthGoal.values.map((g) => g.pathSlug).toList(), [
        'new-believer-essentials',
        'sin-repentance-and-grace',
        'growing-in-discipleship',
        'theology-of-suffering',
        'gospel-of-mark',
        'romans-gospel-unfolded',
      ]);
      expect(GrowthGoal.values.map((g) => g.labelKey).toList(), [
        'goal.new_to_faith',
        'goal.fresh_start',
        'goal.walk_with_god',
        'goal.hope_hard_times',
        'goal.read_gospel',
        'goal.understand_gospel',
      ]);
    });

    test('fromName round-trips and ignores unknown names', () {
      for (final goal in GrowthGoal.values) {
        expect(GrowthGoal.fromName(goal.name), goal);
      }
      expect(GrowthGoal.fromName('understandBible'), isNull);
      expect(GrowthGoal.fromName(null), isNull);
    });
  });

  group('startLessonOne', () {
    blocTest<FirstRunCubit, FirstRunState>(
      'guest mode: starts a guest, enrols by slug, opens lesson 1 in Quick Read',
      build: cubit,
      act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'hi'),
      expect: () => [
        isA<FirstRunStarting>(),
        isA<FirstRunReady>()
            .having((s) => Uri.parse(s.location).path, 'path',
                AppRoutes.studyGuideV2)
            .having((s) => Uri.parse(s.location).queryParameters['mode'],
                'mode', 'quick')
            .having(
                (s) => Uri.parse(s.location).queryParameters['lesson_number'],
                'n',
                '1')
            .having((s) => Uri.parse(s.location).queryParameters['topic_id'],
                'topic', 't1')
            .having((s) => Uri.parse(s.location).queryParameters['first_run'],
                'first_run', '1')
            .having((s) => Uri.parse(s.location).queryParameters['source'],
                'source', 'learningPath')
            .having((s) => Uri.parse(s.location).queryParameters['language'],
                'lang', 'hi'),
      ],
      verify: (_) {
        verifyInOrder([
          () => language.saveLanguagePreference(AppLanguage.hindi),
          () => guest.startGuest(),
          () => paths.enrollInPathBySlug('new-believer-essentials'),
          () => paths.getLearningPathDetails(
              pathId: 'p1', language: 'hi', forceRefresh: true),
        ]);
        expect(settings.get('first_run_goal'), 'newToFaith');
        expect(settings.get('terms_accepted'), isTrue);
        expect(settings.get('onboarding_completed'), isTrue);
      },
    );

    test('the goal is stored only after the path is enrolled', () async {
      final c = cubit();
      when(() => paths.enrollInPathBySlug(any())).thenAnswer((_) async {
        expect(settings.get('first_run_goal'), isNull);
        return Right(_enrollment('p1'));
      });
      await c.startLessonOne(GrowthGoal.readGospel, 'en');
      expect(settings.get('first_run_goal'), 'readGospel');
      verify(() => paths.enrollInPathBySlug('gospel-of-mark')).called(1);
      await c.close();
    });

    blocTest<FirstRunCubit, FirstRunState>(
      'signed-in user: no guest is started',
      build: () {
        when(() => guest.hasSession).thenReturn(true);
        return cubit();
      },
      act: (c) => c.startLessonOne(GrowthGoal.hopeHardTimes, 'en'),
      expect: () => [isA<FirstRunStarting>(), isA<FirstRunReady>()],
      verify: (_) {
        verifyNever(() => guest.startGuest());
        verify(() => paths.enrollInPathBySlug('theology-of-suffering'))
            .called(1);
        expect(settings.get('first_run_goal'), 'hopeHardTimes');
      },
    );

    blocTest<FirstRunCubit, FirstRunState>(
      'guest mode off and signed out: asks to log in (goal remembered)',
      build: () {
        when(() => flags.guestMode).thenReturn(false);
        return cubit();
      },
      act: (c) => c.startLessonOne(GrowthGoal.readGospel, 'en'),
      expect: () => [isA<FirstRunStarting>(), isA<FirstRunNeedsLogin>()],
      verify: (_) {
        verifyNever(() => guest.startGuest());
        verifyNever(() => paths.enrollInPathBySlug(any()));
        expect(settings.get('first_run_goal'), 'readGospel');
      },
    );

    blocTest<FirstRunCubit, FirstRunState>(
      'enrol failure shows a retry; retrying reuses the guest and opens lesson 1',
      build: () {
        var calls = 0;
        when(() => paths.enrollInPathBySlug(any())).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            return const Left(NetworkFailure(message: 'offline'));
          }
          return Right(_enrollment('p1'));
        });
        return cubit();
      },
      act: (c) async {
        await c.startLessonOne(GrowthGoal.newToFaith, 'en');
        // The first attempt created the guest.
        when(() => guest.hasSession).thenReturn(true);
        await c.startLessonOne(GrowthGoal.newToFaith, 'en');
      },
      expect: () => [
        isA<FirstRunStarting>(),
        isA<FirstRunFailed>()
            .having((s) => s.messageKey, 'key', 'first_run.error')
            .having((s) => s.accountRequired, 'accountRequired', false),
        isA<FirstRunStarting>(),
        isA<FirstRunReady>(),
      ],
      verify: (_) => verify(() => guest.startGuest()).called(1),
    );

    blocTest<FirstRunCubit, FirstRunState>(
      'a guest who already holds another path is told so, not shown an error',
      build: () {
        when(() => guest.hasSession).thenReturn(true);
        when(() => guest.isGuest).thenReturn(true);
        when(() => paths.enrollInPathBySlug(any())).thenAnswer((_) async =>
            const Left(AccountRequiredFailure(reason: 'other_path')));
        return cubit();
      },
      act: (c) => c.startLessonOne(GrowthGoal.walkWithGod, 'en'),
      expect: () => [
        isA<FirstRunStarting>(),
        isA<FirstRunFailed>()
            .having((s) => s.messageKey, 'key', 'first_run.error_has_path')
            .having((s) => s.accountRequired, 'accountRequired', true),
      ],
    );

    blocTest<FirstRunCubit, FirstRunState>(
      'guest start failure: inline error, nothing enrolled',
      build: () {
        when(() => guest.startGuest()).thenThrow(Exception('offline'));
        return cubit();
      },
      act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'en'),
      expect: () => [
        isA<FirstRunStarting>(),
        isA<FirstRunFailed>()
            .having((s) => s.messageKey, 'key', 'first_run.error'),
      ],
      verify: (_) => verifyNever(() => paths.enrollInPathBySlug(any())),
    );

    blocTest<FirstRunCubit, FirstRunState>(
      'path details failure: inline error',
      build: () {
        when(() => paths.getLearningPathDetails(
                  pathId: any(named: 'pathId'),
                  language: any(named: 'language'),
                  forceRefresh: any(named: 'forceRefresh'),
                ))
            .thenAnswer(
                (_) async => const Left(ServerFailure(message: 'boom')));
        return cubit();
      },
      act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'en'),
      expect: () => [isA<FirstRunStarting>(), isA<FirstRunFailed>()],
    );

    blocTest<FirstRunCubit, FirstRunState>(
      'a path with no lessons: inline error',
      build: () {
        when(() => paths.getLearningPathDetails(
                  pathId: any(named: 'pathId'),
                  language: any(named: 'language'),
                  forceRefresh: any(named: 'forceRefresh'),
                ))
            .thenAnswer((_) async => Right(LearningPathDetail.forTest(
                id: 'p1', title: 'Empty', description: '', topics: const [])));
        return cubit();
      },
      act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'en'),
      expect: () => [isA<FirstRunStarting>(), isA<FirstRunFailed>()],
    );

    group('with real server responses', () {
      for (final fixture in const [
        'path_detail_guest_enrolled_ml',
        'path_detail_guest_not_enrolled_ml',
        'path_detail_full_user_enrolled_en',
      ]) {
        blocTest<FirstRunCubit, FirstRunState>(
          '$fixture: opens lesson 1',
          build: () {
            final detail = _serverDetail(fixture);
            when(() => paths.getLearningPathDetails(
                  pathId: any(named: 'pathId'),
                  language: any(named: 'language'),
                  forceRefresh: any(named: 'forceRefresh'),
                )).thenAnswer((_) async => Right(detail));
            return cubit();
          },
          act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'ml'),
          expect: () => [
            isA<FirstRunStarting>(),
            isA<FirstRunReady>()
                .having(
                    (s) =>
                        Uri.parse(s.location).queryParameters['lesson_number'],
                    'n',
                    '1')
                .having(
                    (s) => Uri.parse(s.location).queryParameters['topic_id'],
                    'topic',
                    _serverDetail(fixture)
                        .topics
                        .firstWhere((t) => t.position == 0)
                        .topicId),
          ],
        );
      }
    });

    group('an unexpected error logs the failing step and its type', () {
      late List<String> logs;
      late DebugPrintCallback original;

      setUp(() {
        logs = [];
        original = debugPrint;
        debugPrint =
            (String? message, {int? wrapWidth}) => logs.add(message ?? '');
      });

      tearDown(() => debugPrint = original);

      String failureLog() =>
          logs.singleWhere((l) => l.contains('First run could not start'));

      blocTest<FirstRunCubit, FirstRunState>(
        'enrol ok, details throw a TypeError',
        build: () {
          when(() => paths.getLearningPathDetails(
                pathId: any(named: 'pathId'),
                language: any(named: 'language'),
                forceRefresh: any(named: 'forceRefresh'),
              )).thenThrow(TypeError());
          return cubit();
        },
        act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'en'),
        expect: () => [
          isA<FirstRunStarting>(),
          isA<FirstRunFailed>()
              .having((s) => s.messageKey, 'key', 'first_run.error'),
        ],
        verify: (_) {
          expect(failureLog(), contains('step=path_details'));
          expect(failureLog(), contains('TypeError'));
        },
      );

      blocTest<FirstRunCubit, FirstRunState>(
        'enrol throws',
        build: () {
          when(() => paths.enrollInPathBySlug(any())).thenThrow(StateError(''));
          return cubit();
        },
        act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'en'),
        expect: () => [isA<FirstRunStarting>(), isA<FirstRunFailed>()],
        verify: (_) {
          expect(failureLog(), contains('step=enrol'));
          expect(failureLog(), contains('StateError'));
        },
      );

      blocTest<FirstRunCubit, FirstRunState>(
        'guest start throws',
        build: () {
          when(() => guest.startGuest()).thenThrow(StateError(''));
          return cubit();
        },
        act: (c) => c.startLessonOne(GrowthGoal.newToFaith, 'en'),
        expect: () => [isA<FirstRunStarting>(), isA<FirstRunFailed>()],
        verify: (_) => expect(failureLog(), contains('step=guest')),
      );
    });

    test('a second tap while starting is ignored', () async {
      final c = cubit();
      final first = c.startLessonOne(GrowthGoal.newToFaith, 'en');
      final second = c.startLessonOne(GrowthGoal.newToFaith, 'en');
      await Future.wait([first, second]);
      verify(() => paths.enrollInPathBySlug(any())).called(1);
      await c.close();
    });
  });

  group('skip', () {
    blocTest<FirstRunCubit, FirstRunState>(
      'saves the language, clears any goal, finishes onboarding, goes home',
      build: () {
        settings.put('first_run_goal', 'readGospel');
        return cubit();
      },
      act: (c) => c.skip('ml'),
      expect: () => [isA<FirstRunSkipped>()],
      verify: (_) {
        verify(() => language.saveLanguagePreference(AppLanguage.malayalam))
            .called(1);
        verifyNever(() => guest.startGuest());
        verifyNever(() => paths.enrollInPathBySlug(any()));
        expect(settings.get('first_run_goal'), isNull);
        expect(settings.get('onboarding_completed'), isTrue);
      },
    );
  });

  group('guest helper', () {
    test('signed out with guest mode on: the guest helper', () {
      expect(cubit().showsGuestHelper, isTrue);
    });

    test('a guest: the guest helper', () {
      when(() => guest.hasSession).thenReturn(true);
      when(() => guest.isGuest).thenReturn(true);
      expect(cubit().showsGuestHelper, isTrue);
    });

    test('a full account: the plain helper', () {
      when(() => guest.hasSession).thenReturn(true);
      expect(cubit().showsGuestHelper, isFalse);
    });

    test('guest mode off: the plain helper', () {
      when(() => flags.guestMode).thenReturn(false);
      expect(cubit().showsGuestHelper, isFalse);
    });
  });

  group('loadStarterPaths', () {
    test('pages through the list until every goal path is found', () async {
      when(() => paths.getLearningPaths(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Right(LearningPathsResult(
            paths: [
              _listed('new-believer-essentials', 'New Believer Essentials', 8),
              _listed('rooted-in-christ', 'Rooted in Christ', 5),
              _listed('sin-repentance-and-grace', 'Sin and Grace', 8),
            ],
            total: 50,
            hasMore: true,
          )));
      when(() => paths.getLearningPaths(
            offset: 3,
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Right(LearningPathsResult(
            paths: [
              _listed('growing-in-discipleship', 'Growing', 12),
              _listed('theology-of-suffering', 'Suffering', 7),
              _listed('gospel-of-mark', 'Mark', 22),
              _listed('romans-gospel-unfolded', 'Romans', 16),
            ],
            total: 50,
            hasMore: true,
          )));

      final result = await cubit().loadStarterPaths('en');

      expect(result.totalPaths, 50);
      expect(result.forGoal(GrowthGoal.newToFaith)?.title,
          'New Believer Essentials');
      expect(result.forGoal(GrowthGoal.readGospel)?.lessonCount, 22);
      expect(result.forGoal(GrowthGoal.understandGospel)?.title, 'Romans');
      verifyNever(() => paths.getLearningPaths(
            offset: 7,
            limit: any(named: 'limit'),
          ));
    });

    test('a page-sized total (an old cached page) is not shown', () async {
      // Before the server sent the real count, `total` was the page length.
      when(() => paths.getLearningPaths(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Right(LearningPathsResult(
            paths: [
              for (var i = 0; i < 10; i++) _listed('other-$i', 'Other', 3),
            ],
            total: 10,
            hasMore: true,
          )));
      when(() => paths.getLearningPaths(
            offset: 10,
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Right(LearningPathsResult(
            paths: [
              for (var i = 10; i < 30; i++) _listed('other-$i', 'Other', 3),
            ],
            total: 20,
            hasMore: true,
          )));
      when(() => paths.getLearningPaths(
                offset: 30,
                limit: any(named: 'limit'),
              ))
          .thenAnswer((_) async =>
              const Right(LearningPathsResult(paths: [], total: 0)));

      final result = await cubit().loadStarterPaths('en');

      expect(result.totalPaths, isNull);
    });

    test('the real total from a later page wins over a stale first page',
        () async {
      when(() => paths.getLearningPaths(
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Right(LearningPathsResult(
            paths: [
              for (var i = 0; i < 10; i++) _listed('other-$i', 'Other', 3),
            ],
            total: 10,
            hasMore: true,
          )));
      when(() => paths.getLearningPaths(
            offset: 10,
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Right(LearningPathsResult(
            paths: [
              for (final g in GrowthGoal.values) _listed(g.pathSlug, 'P', 3),
            ],
            total: 50,
            hasMore: true,
          )));

      final result = await cubit().loadStarterPaths('en');

      expect(result.totalPaths, 50);
    });

    test('a failure keeps what was found and never throws', () async {
      when(() => paths.getLearningPaths(
                language: any(named: 'language'),
                offset: any(named: 'offset'),
                limit: any(named: 'limit'),
              ))
          .thenAnswer((_) async => const Left(NetworkFailure(message: 'off')));

      final result = await cubit().loadStarterPaths('en');

      expect(result.totalPaths, isNull);
      expect(result.forGoal(GrowthGoal.newToFaith), isNull);
    });
  });

  group('appFrame', () {
    test('reads VM and web frames, skipping package frames', () {
      expect(
          FirstRunCubit.appFrame(StackTrace.fromString(
              '#0 Iterable.reduce (dart:core/iterable.dart:1:1)\n'
              '#1 FirstRunCubit._lessonOneLocation (package:disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_cubit.dart:164:30)')),
          'features/onboarding/presentation/bloc/first_run_cubit.dart:164');
      expect(
          FirstRunCubit.appFrame(StackTrace.fromString(
              'dart-sdk/lib/core/iterable.dart 1:1  reduce\n'
              'packages/disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_cubit.dart 164:30  [_lessonOneLocation]')),
          'features/onboarding/presentation/bloc/first_run_cubit.dart:164');
      expect(FirstRunCubit.appFrame(StackTrace.fromString('')), 'unknown');
    });
  });
}
