import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/guest_lesson_nudge.dart';
import 'package:disciplefy_bible_study/features/auth/presentation/widgets/save_progress_block.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';

import '../../../helpers/text_fit.dart';
import '../../../helpers/welcome_test_harness.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

class _MockPaths extends Mock implements LearningPathsRepository {}

class _MemoryBox extends Fake implements Box<dynamic> {
  final Map<dynamic, dynamic> stored = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      stored.containsKey(key) ? stored[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => stored[key] = value;
}

LearningPath _path(
  String id, {
  bool guestAccessible = true,
  int progress = 0,
  int lessons = 8,
}) =>
    LearningPath(
      id: id,
      slug: id,
      title: 'Path $id',
      description: '',
      iconName: '',
      color: '',
      totalXp: 0,
      estimatedDays: 0,
      discipleLevel: 'seeker',
      guestAccessible: guestAccessible,
      progressPercentage: progress,
      topicsCount: lessons,
    );

void main() {
  late FakeTranslationService translations;
  late _MockGuest guest;
  late _MockFlags flags;
  late _MockPaths paths;
  late _MemoryBox box;

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    guest = _MockGuest();
    flags = _MockFlags();
    paths = _MockPaths();
    when(() => guest.isGuest).thenReturn(true);
    when(() => flags.guestMode).thenReturn(true);
    sl.registerSingleton<GuestSessionService>(guest);
    sl.registerSingleton<RolloutFlags>(flags);
    sl.registerSingleton<LearningPathsRepository>(paths);
    box = _MemoryBox();
    GuestNudgeDismissals.debugBox = box;
  });

  tearDown(() async {
    GuestNudgeDismissals.debugBox = null;
    await sl.reset();
  });

  group('guestNudgeFor', () {
    GuestNudge pick(int n,
            {bool guest = true, bool last = false, bool firstRun = false}) =>
        guestNudgeFor(
          isGuest: guest,
          lessonNumber: n,
          isLastLesson: last,
          firstRun: firstRun,
        );

    test('a full account never gets a nudge', () {
      expect(pick(1, guest: false, firstRun: true), GuestNudge.none);
      expect(pick(3, guest: false), GuestNudge.none);
      expect(pick(8, guest: false, last: true), GuestNudge.none);
    });

    test('lesson 1 of the first run gets the sign-up block', () {
      expect(pick(1, firstRun: true), GuestNudge.signUpBlock);
      expect(pick(1), GuestNudge.none);
    });

    test('lessons 3 and 6 get the keep-progress card', () {
      expect(pick(3), GuestNudge.keepProgressCard);
      expect(pick(6), GuestNudge.keepProgressCard);
      for (final n in [2, 4, 5, 7]) {
        expect(pick(n), GuestNudge.none, reason: 'lesson $n');
      }
    });

    test('the last lesson wins over every other rule', () {
      expect(pick(6, last: true), GuestNudge.pathFinished);
      expect(pick(1, last: true, firstRun: true), GuestNudge.pathFinished);
    });
  });

  group('loadNextGuestPaths', () {
    test('up to two accessible, unfinished paths other than the current',
        () async {
      when(() => paths.getLearningPaths(
            language: any(named: 'language'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Right(LearningPathsResult(
            paths: [
              _path('current'),
              _path('locked', guestAccessible: false),
              _path('done', progress: 100),
              _path('a'),
              _path('b'),
              _path('c'),
            ],
            total: 6,
          )));
      final next = await loadNextGuestPaths(paths,
          language: 'en', currentPathId: 'current');
      expect(next.map((p) => p.id), ['a', 'b']);
    });

    test('a failure gives an empty list', () async {
      when(() => paths.getLearningPaths(
                language: any(named: 'language'),
                offset: any(named: 'offset'),
                limit: any(named: 'limit'),
              ))
          .thenAnswer((_) async => const Left(NetworkFailure(message: 'off')));
      expect(
          await loadNextGuestPaths(paths, language: 'en', currentPathId: 'x'),
          isEmpty);
    });
  });

  Widget nudge({
    required int lesson,
    bool last = false,
    bool firstRun = false,
    bool dark = false,
  }) =>
      welcomeApp(
        path: '/lesson-complete',
        dark: dark,
        screen: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: GuestLessonNudge(
              pathId: 'current',
              lessonNumber: lesson,
              isLastLesson: last,
              firstRun: firstRun,
              language: 'en',
            ),
          ),
        ),
      );

  group('SaveProgressBlock', () {
    testWidgets('lesson 1 of the first run: block with Not now',
        (tester) async {
      await tester.pumpWidget(nudge(lesson: 1, firstRun: true));
      await tester.pumpAndSettle();
      expect(find.text('Sign up to save your progress and continue'),
          findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save_progress_block')), findsNothing);
    });

    testWidgets('not a guest: nothing', (tester) async {
      when(() => guest.isGuest).thenReturn(false);
      await tester.pumpWidget(nudge(lesson: 1, firstRun: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save_progress_block')), findsNothing);
    });

    testWidgets('guest mode switched off: an existing guest still sees it',
        (tester) async {
      when(() => flags.guestMode).thenReturn(false);
      await tester.pumpWidget(nudge(lesson: 1, firstRun: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save_progress_block')), findsOneWidget);
    });

    testWidgets('linking goes Home', (tester) async {
      when(() => guest.linkGoogle())
          .thenAnswer((_) async => LinkOutcome.linked);
      await tester.pumpWidget(nudge(lesson: 1, firstRun: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.text('stub:/'), findsOneWidget);
    });

    testWidgets('email confirmation shows Check your email', (tester) async {
      useSurface(tester, const Size(400, 1000));
      when(() => guest.linkEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            fullName: any(named: 'fullName'),
          )).thenAnswer((_) async => LinkOutcome.emailConfirmationSent);
      await tester.pumpWidget(nudge(lesson: 1, firstRun: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('account_email_name')), 'Anu Mathew');
      await tester.enterText(
          find.byKey(const Key('account_email_address')), 'a@b.co');
      await tester.enterText(
          find.byKey(const Key('account_email_password')), 'secret123');
      await tester.tap(find.byKey(const Key('account_email_submit')));
      await tester.pumpAndSettle();
      expect(find.text('Check your email to confirm: a@b.co'), findsOneWidget);
    });

    testWidgets('last lesson: path-finished title and next paths',
        (tester) async {
      useSurface(tester, const Size(400, 1000));
      when(() => paths.getLearningPaths(
            language: any(named: 'language'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Right(LearningPathsResult(
            paths: [_path('current'), _path('a'), _path('b'), _path('c')],
            total: 4,
          )));
      await tester.pumpWidget(nudge(lesson: 8, last: true));
      await tester.pumpAndSettle();
      expect(
          find.text('Sign up to keep your progress and start your next path'),
          findsOneWidget);
      expect(find.text('Not now'), findsNothing);
      expect(find.text('YOUR NEXT PATHS'), findsOneWidget);
      expect(find.text('Path a'), findsOneWidget);
      expect(find.text('Path b'), findsOneWidget);
      expect(find.text('Path c'), findsNothing);
      await tester.tap(find.text('Sign up to start').first);
      await tester.pumpAndSettle();
      expect(find.text('Your next path needs an account'), findsOneWidget);
    });

    testWidgets('last lesson without next paths shows only the block',
        (tester) async {
      when(() => paths.getLearningPaths(
                language: any(named: 'language'),
                offset: any(named: 'offset'),
                limit: any(named: 'limit'),
              ))
          .thenAnswer((_) async => const Left(NetworkFailure(message: 'off')));
      await tester.pumpWidget(nudge(lesson: 8, last: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save_progress_block')), findsOneWidget);
      expect(find.text('YOUR NEXT PATHS'), findsNothing);
    });
  });

  group('KeepProgressCard', () {
    testWidgets('lesson 3 shows the card; tap opens the sheet', (tester) async {
      await tester.pumpWidget(nudge(lesson: 3));
      await tester.pumpAndSettle();
      expect(find.text('Keep these 3 days safe'), findsOneWidget);
      await tester.tap(find.byKey(const Key('keep_progress_card')));
      await tester.pumpAndSettle();
      expect(find.text('Sign up to save your progress and continue'),
          findsOneWidget);
    });

    testWidgets('dismissal hides it and is remembered', (tester) async {
      await tester.pumpWidget(nudge(lesson: 6));
      await tester.pumpAndSettle();
      expect(find.text('Keep these 6 days safe'), findsOneWidget);
      await tester.tap(find.byKey(const Key('keep_progress_dismiss')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('keep_progress_card')), findsNothing);
      expect(box.stored['guest_nudge_dismissed_6'], isTrue);

      // A later visit to the same lesson stays quiet; lesson 3 still shows.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(nudge(lesson: 6));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('keep_progress_card')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(nudge(lesson: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('keep_progress_card')), findsOneWidget);
    });

    testWidgets('lesson 4 has no nudge', (tester) async {
      await tester.pumpWidget(nudge(lesson: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('keep_progress_card')), findsNothing);
      expect(find.byKey(const Key('save_progress_block')), findsNothing);
    });
  });

  group('no cut-off text at 320px', () {
    setUpAll(loadAppFonts);
    setUp(() {
      when(() => paths.getLearningPaths(
            language: any(named: 'language'),
            offset: any(named: 'offset'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Right(LearningPathsResult(
            paths: [_path('a', lessons: 12), _path('b', lessons: 22)],
            total: 2,
          )));
    });
    for (final language in AppLanguage.values) {
      for (final dark in [false, true]) {
        final theme = dark ? 'dark' : 'light';
        testWidgets('block ${language.code} $theme', (tester) async {
          useSurface(tester, const Size(320, 1000));
          translations.language = language;
          await tester.pumpWidget(nudge(lesson: 1, firstRun: true, dark: dark));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });

        testWidgets('path finished ${language.code} $theme', (tester) async {
          useSurface(tester, const Size(320, 1000));
          translations.language = language;
          await tester.pumpWidget(nudge(lesson: 8, last: true, dark: dark));
          await tester.pumpAndSettle();
          expect(find.text('Path a'), findsOneWidget);
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });

        testWidgets('keep card ${language.code} $theme', (tester) async {
          useSurface(tester, const Size(320, 600));
          translations.language = language;
          await tester.pumpWidget(nudge(lesson: 3, dark: dark));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });
      }
    }
  });
}
