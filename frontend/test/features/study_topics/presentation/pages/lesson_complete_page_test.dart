import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/utils/achievement_popup_gate.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_bloc.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_event.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/study_topics_refresh_requests.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/lesson_ref.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/pages/lesson_complete_page.dart';

import '../../../../helpers/welcome_test_harness.dart';

class _MockRepo extends Mock implements LearningPathsRepository {}

class _MockHomeBloc extends MockBloc<HomeEvent, HomeState>
    implements HomeBloc {}

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

class _FakePrefs extends Fake implements LanguagePreferenceService {
  @override
  String? getLearningPathStudyModePreferenceRaw() => 'recommended';
}

LearningPathTopic _topic(int pos, String title) => LearningPathTopic(
      position: pos,
      isMilestone: false,
      topicId: 't$pos',
      title: title,
      description: '',
      category: 'c',
      xpValue: 50,
    );

final _titles = [
  'Who is Jesus Christ?',
  'One God, Three Persons',
  'Why Read the Bible?',
  'Prayer',
  'T5',
  'T6',
  'T7',
  'T8',
];

LearningPathDetail _path() => LearningPathDetail(
      id: 'p',
      slug: 's',
      title: 'NBE',
      description: '',
      iconName: '',
      color: '',
      totalXp: 0,
      estimatedDays: 0,
      discipleLevel: 'seeker',
      topicsCount: 8,
      topics: [for (var i = 0; i < 8; i++) _topic(i + 1, _titles[i])],
    );

LearningPath _listed(String id, String title) => LearningPath(
      id: id,
      slug: id,
      title: title,
      description: '',
      iconName: 'menu_book',
      color: '',
      totalXp: 0,
      estimatedDays: 14,
      discipleLevel: 'seeker',
      topicsCount: 8,
    );

void main() {
  late _MockRepo repo;
  late GoRouter router;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.getLearningPathDetails(
          pathId: any(named: 'pathId'),
          language: any(named: 'language'),
          forceRefresh: any(named: 'forceRefresh'),
        )).thenAnswer((_) async => Right(_path()));
    when(() => repo.getNextPaths(
          language: any(named: 'language'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => Right(NextPathsResult(paths: [
          _listed('p', 'NBE'), // the path just finished: never listed
          _listed('rooted', 'Rooted in Christ'),
          _listed('mark', 'Gospel of Mark'),
          _listed('john', 'Gospel of John'),
        ])));
    sl.registerSingleton<TranslationService>(FakeTranslationService());
    sl.registerSingleton<LearningPathsRepository>(repo);
    sl.registerSingleton<LanguagePreferenceService>(_FakePrefs());
  });
  tearDown(() {
    AchievementPopupGate.reset();
    return sl.reset();
  });

  Future<void> pumpPage(WidgetTester tester, int n, {ThemeData? theme}) async {
    useSurface(tester, const Size(400, 800));
    router = GoRouter(
      initialLocation: '/lesson-complete',
      routes: [
        GoRoute(
          path: '/lesson-complete',
          builder: (_, __) => LessonCompletePage(
            args: LessonCompleteArgs(
              lesson: LessonRef(
                  pathId: 'p',
                  pathTitle: 'NBE',
                  lessonNumber: n,
                  lessonTotal: 8),
              lessonTitle: _titles[n - 1],
              mode: StudyMode.quick,
              language: 'en',
            ),
          ),
        ),
        GoRoute(
            path: '/study-guide-v2', builder: (_, __) => const Text('guide')),
        GoRoute(path: '/', builder: (_, __) => const Text('home')),
        GoRoute(
          path: '/learning-path/:pathId',
          builder: (_, s) => Text('path:${s.pathParameters['pathId']}'),
        ),
        GoRoute(
            path: '/study-topics', builder: (_, __) => const Text('topics')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      theme: theme ?? AppTheme.darkTheme,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();
  }

  Map<String, String> opened() =>
      router.routeInformationProvider.value.uri.queryParameters;

  testWidgets(
      'opening refreshes Home and Topics: the push that led here never '
      'returns after Mark complete', (tester) async {
    final home = _MockHomeBloc();
    sl.registerSingleton<HomeBloc>(home);
    var topicsRefreshes = 0;
    void onRefresh() => topicsRefreshes++;
    StudyTopicsRefreshRequests.instance.addListener(onRefresh);
    addTearDown(
        () => StudyTopicsRefreshRequests.instance.removeListener(onRefresh));

    await pumpPage(tester, 1);
    verify(() => home.add(const LoadActiveLearningPath(forceRefresh: true)))
        .called(1);
    expect(topicsRefreshes, 1);
  });

  testWidgets('shows next lesson, Continue opens it immediately (no day gate)',
      (tester) async {
    await pumpPage(tester, 1);
    expect(find.text('Lesson 1 complete'), findsOneWidget);
    expect(find.text('Up next'.toUpperCase()), findsOneWidget);
    expect(find.text('Tomorrow'), findsNothing);
    expect(find.text('Continue to lesson 2'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
    await tester.tap(find.text('Continue to lesson 2'));
    await tester.pumpAndSettle();
    expect(opened()['lesson_number'], '2');
    expect(opened()['mode'], 'standard');
  });

  testWidgets('a 64px gold check in confetti and a 23pt title', (tester) async {
    await pumpPage(tester, 1);
    expect(tester.getSize(find.byKey(const Key('lesson_complete_check'))),
        const Size(64, 64));
    final title = tester.widget<Text>(find.text('Lesson 1 complete'));
    expect(title.style!.fontSize, 23);
  });

  testWidgets('next-lesson row is tappable', (tester) async {
    await pumpPage(tester, 1);
    await tester.tap(find.text('One God, Three Persons'));
    await tester.pumpAndSettle();
    expect(opened()['lesson_number'], '2');
  });

  testWidgets('Back to Home goes home', (tester) async {
    await pumpPage(tester, 1);
    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('last lesson: finished title, only Back to Home', (tester) async {
    await pumpPage(tester, 8);
    expect(find.text('You finished NBE'), findsOneWidget);
    expect(find.textContaining('Continue to lesson'), findsNothing);
    expect(find.text('Back to Home'), findsOneWidget);
  });

  testWidgets('last lesson: What next? lists three next paths, not this one',
      (tester) async {
    await pumpPage(tester, 8);
    final card = find.byKey(const Key('lesson_complete_what_next'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('What next?')),
        findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('NBE')), findsNothing);
    for (final t in ['Rooted in Christ', 'Gospel of Mark', 'Gospel of John']) {
      expect(find.text(t), findsOneWidget);
    }
    verify(() => repo.getNextPaths(language: any(named: 'language'), limit: 4))
        .called(1);

    await tester.ensureVisible(find.text('Gospel of Mark'));
    await tester.tap(find.text('Gospel of Mark'));
    await tester.pumpAndSettle();
    expect(find.text('path:mark'), findsOneWidget);
  });

  testWidgets('before the last lesson: no What next?', (tester) async {
    await pumpPage(tester, 1);
    expect(find.byKey(const Key('lesson_complete_what_next')), findsNothing);
    verifyNever(() => repo.getNextPaths(
        language: any(named: 'language'), limit: any(named: 'limit')));
  });

  testWidgets('What next? never blocks: a failed load offers Retry',
      (tester) async {
    when(() => repo.getNextPaths(
          language: any(named: 'language'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const Left(NetworkFailure()));
    await pumpPage(tester, 8);
    expect(find.byKey(const Key('next_paths_retry')), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
  });

  testWidgets(
      'guest: only the paths the server allows; none left asks for an '
      'account', (tester) async {
    final guest = _MockGuest();
    final flags = _MockFlags();
    when(() => guest.isGuest).thenReturn(true);
    when(() => flags.guestMode).thenReturn(true);
    sl.registerSingleton<GuestSessionService>(guest);
    sl.registerSingleton<RolloutFlags>(flags);
    when(() => repo.getNextPaths(
          language: any(named: 'language'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const Right(NextPathsResult(paths: [])));
    await pumpPage(tester, 8);
    final row = find.byKey(const Key('next_paths_guest_account'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('primary fill is white on dark and gold on light',
      (tester) async {
    Color? fill() => tester
        .widget<FilledButton>(find.byType(FilledButton))
        .style!
        .backgroundColor!
        .resolve({});
    await pumpPage(tester, 1);
    expect(fill(), Colors.white);
    await pumpPage(tester, 1, theme: AppTheme.lightTheme);
    expect(fill(), AppColors.brandHighlightDark);
  });

  group('achievement pop-ups', () {
    testWidgets('wait until the page is shown, then may show over it',
        (tester) async {
      var flushes = 0;
      void count() => flushes++;
      AchievementPopupGate.flushRequests.addListener(count);
      addTearDown(
          () => AchievementPopupGate.flushRequests.removeListener(count));
      expect(AchievementPopupGate.holdsAt('/lesson-complete'), isTrue);

      await pumpPage(tester, 1);
      expect(AchievementPopupGate.holdsAt('/lesson-complete'), isFalse);
      expect(flushes, greaterThan(0));
    });

    testWidgets('leaving the page holds them on the next Lesson complete',
        (tester) async {
      await pumpPage(tester, 1);
      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();
      expect(AchievementPopupGate.holdsAt('/lesson-complete'), isTrue);
    });

    testWidgets("a guest's page (sign-up block) never shows them",
        (tester) async {
      final guest = _MockGuest();
      final flags = _MockFlags();
      when(() => guest.isGuest).thenReturn(true);
      when(() => flags.guestMode).thenReturn(true);
      sl.registerSingleton<GuestSessionService>(guest);
      sl.registerSingleton<RolloutFlags>(flags);

      await pumpPage(tester, 1);
      expect(AchievementPopupGate.holdsAt('/lesson-complete'), isTrue);
    });
  });
}
