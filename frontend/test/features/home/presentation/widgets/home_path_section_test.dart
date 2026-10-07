import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/guest_path_enrollment.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/home/domain/utils/first_path_choices.dart';
import 'package:disciplefy_bible_study/features/home/domain/utils/lesson_launch_from_summary.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/choose_first_path_card.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/home_path_section.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/path_progress_strip.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/save_progress_row.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/today_lesson_card.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';

import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

class _MockPaths extends Mock implements LearningPathsRepository {}

const _guestSlugs = [
  'new-believer-essentials',
  'sin-repentance-and-grace',
  'growing-in-discipleship',
  'theology-of-suffering',
  'gospel-of-mark',
  'romans-gospel-unfolded',
];

LearningPath _path(
  String slug, {
  bool guestAccessible = false,
  bool featured = false,
  int? order,
  int lessons = 8,
  int days = 14,
  String title = '',
}) =>
    LearningPath(
      id: 'id-$slug',
      slug: slug,
      title: title.isEmpty ? 'Path $slug' : title,
      description: '',
      iconName: 'menu_book',
      color: '',
      totalXp: 0,
      estimatedDays: days,
      discipleLevel: 'seeker',
      guestAccessible: guestAccessible,
      isFeatured: featured,
      displayOrder: order,
      topicsCount: lessons,
    );

const summary4of8 = ActivePathSummary(
  pathId: 'p1',
  title: 'New Believer Essentials',
  description: 'First steps',
  discipleLevel: 'seeker',
  lessonTotal: 8,
  lessonsCompleted: 3,
  next: NextLesson(
    topicId: 't4',
    title: 'Confidence in Your Salvation',
    description: 'Assurance',
    inputType: 'topic',
    number: 4,
    total: 8,
  ),
);

const finishedSummary = ActivePathSummary(
  pathId: 'p1',
  title: 'New Believer Essentials',
  description: 'First steps',
  discipleLevel: 'seeker',
  lessonTotal: 8,
  lessonsCompleted: 8,
);

const mlSummary = ActivePathSummary(
  pathId: 'p1',
  title: 'പുതിയ വിശ്വാസിയുടെ അടിസ്ഥാനങ്ങൾ',
  description: '',
  discipleLevel: '',
  lessonTotal: 16,
  lessonsCompleted: 3,
  next: NextLesson(
    topicId: 't4',
    title: 'നിങ്ങളുടെ രക്ഷയിലുള്ള ഉറപ്പ്',
    description: '',
    inputType: 'topic',
    number: 4,
    total: 16,
  ),
);

const hiSummary = ActivePathSummary(
  pathId: 'p1',
  title: 'नए विश्वासी की नींव और पहला कदम',
  description: '',
  discipleLevel: '',
  lessonTotal: 16,
  lessonsCompleted: 3,
  next: NextLesson(
    topicId: 't4',
    title: 'अपने उद्धार में भरोसा',
    description: '',
    inputType: 'topic',
    number: 4,
    total: 16,
  ),
);

void main() {
  late _MockGuest guest;
  late _MockFlags flags;
  late _MockPaths paths;
  late FakeTranslationService translations;

  setUpAll(() async {
    await loadAppFonts();
  });

  setUp(() {
    translations = FakeTranslationService();
    guest = _MockGuest();
    flags = _MockFlags();
    paths = _MockPaths();
    when(() => guest.isGuest).thenReturn(false);
    when(() => guest.hasSession).thenReturn(true);
    when(() => flags.guestMode).thenReturn(true);
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<GuestSessionService>(guest);
    sl.registerSingleton<RolloutFlags>(flags);
    sl.registerSingleton<LearningPathsRepository>(paths);
    GuestPathEnrollment.currentUserId = () => 'u1';
  });

  tearDown(() async {
    GuestPathEnrollment.reset();
    await sl.reset();
  });

  void listPaths(List<LearningPath> list) {
    when(() => paths.getLearningPaths(
              language: any(named: 'language'),
              includeEnrolled: any(named: 'includeEnrolled'),
              forceRefresh: any(named: 'forceRefresh'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              search: any(named: 'search'),
              fellowshipId: any(named: 'fellowshipId'),
            ))
        .thenAnswer((_) async =>
            Right(LearningPathsResult(paths: list, total: list.length)));
  }

  final launchPath = Uri.parse(
          buildLessonLaunchFromSummary(summary4of8, StudyMode.quick, 'en'))
      .path;

  Widget app(
    Widget section, {
    bool dark = false,
    String? language,
  }) {
    if (language != null) {
      translations.language = AppLanguage.fromCode(language);
    }
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: section,
            ),
          ),
        ),
        GoRoute(
          path: '/learning-path/:pathId',
          builder: (_, s) => Scaffold(
              body: Text(
                  'detail:${s.pathParameters['pathId']}:${s.uri.queryParameters['source']}')),
        ),
        GoRoute(
          path: '/study-topics',
          builder: (_, __) => const Scaffold(body: Text('stub:topics')),
        ),
        if (launchPath != '/')
          GoRoute(
            path: launchPath,
            builder: (_, s) => Scaffold(
                body: Text('stub:lesson:${s.uri.queryParameters['mode']}')),
          ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }

  Widget section(ActivePathSummary? summary, {bool loading = false}) =>
      HomePathSection(
        summary: summary,
        loading: loading,
        mode: StudyMode.quick,
        onModeChanged: (_) {},
      );

  group('selectFirstPaths', () {
    final all = [
      _path('rooted-in-christ', featured: true, order: 2),
      _path('understanding-the-bible', featured: true, order: 1),
      for (final s in _guestSlugs.reversed) _path(s, guestAccessible: true),
      _path('the-local-church', featured: true, order: 3),
      _path('baptism', order: 0),
    ];

    test('guest: only the six guest paths, in the goal order', () {
      expect(selectFirstPaths(all, guest: true).map((p) => p.slug),
          _guestSlugs.take(3));
    });

    test('guest: the first-run goal path comes first', () {
      expect(
          selectFirstPaths(all, guest: true, goalSlug: 'gospel-of-mark')
              .map((p) => p.slug),
          [
            'gospel-of-mark',
            'new-believer-essentials',
            'sin-repentance-and-grace',
          ]);
    });

    test('guest: never a path that is not guest-accessible', () {
      final listed = [
        _path('rooted-in-christ', featured: true, order: 1),
        _path('new-believer-essentials'), // no longer guest-accessible
        _path('gospel-of-mark', guestAccessible: true),
      ];
      expect(selectFirstPaths(listed, guest: true).map((p) => p.slug),
          ['gospel-of-mark']);
    });

    test('signed in: goal path first, then featured by display order', () {
      expect(
          selectFirstPaths(all, guest: false, goalSlug: 'theology-of-suffering')
              .map((p) => p.slug),
          [
            'theology-of-suffering',
            'understanding-the-bible',
            'rooted-in-christ',
          ]);
      expect(selectFirstPaths(all, guest: false).map((p) => p.slug), [
        'understanding-the-bible',
        'rooted-in-christ',
        'the-local-church',
      ]);
    });
  });

  testWidgets(
      'no enrolled path → Choose your first path, never the lesson card',
      (tester) async {
    listPaths([
      _path('understanding-the-bible', featured: true, order: 1),
      _path('rooted-in-christ', featured: true, order: 2, lessons: 5, days: 21),
    ]);
    await tester.pumpWidget(app(section(null)));
    await tester.pumpAndSettle();
    expect(find.byType(ChooseFirstPathCard), findsOneWidget);
    expect(find.text('Choose your first path'), findsOneWidget);
    expect(
        find.text('One short lesson a day. Switch any time.'), findsOneWidget);
    expect(find.byType(TodayLessonCard), findsNothing);
    expect(find.textContaining('Start lesson'), findsNothing);
    expect(find.text('5 lessons · 21 days'), findsOneWidget);

    await tester.tap(find.text('Path rooted-in-christ'));
    await tester.pumpAndSettle();
    expect(find.text('detail:id-rooted-in-christ:home'), findsOneWidget);
  });

  testWidgets('See all paths opens Topics', (tester) async {
    listPaths([_path('understanding-the-bible', featured: true, order: 1)]);
    await tester.pumpWidget(app(section(null)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See all paths'));
    await tester.pumpAndSettle();
    expect(find.text('stub:topics'), findsOneWidget);
  });

  testWidgets('a failed path list still offers See all paths', (tester) async {
    when(() => paths.getLearningPaths(
          language: any(named: 'language'),
          includeEnrolled: any(named: 'includeEnrolled'),
          forceRefresh: any(named: 'forceRefresh'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          search: any(named: 'search'),
          fellowshipId: any(named: 'fellowshipId'),
        )).thenAnswer((_) async => const Left(NetworkFailure()));
    await tester.pumpWidget(app(section(null)));
    await tester.pumpAndSettle();
    expect(find.text('Choose your first path'), findsOneWidget);
    expect(find.text('See all paths'), findsOneWidget);
  });

  testWidgets('guest chooser lists only guest paths, at most three',
      (tester) async {
    when(() => guest.isGuest).thenReturn(true);
    listPaths([
      _path('rooted-in-christ', featured: true, order: 1),
      for (final s in _guestSlugs) _path(s, guestAccessible: true),
    ]);
    await tester.pumpWidget(app(section(null)));
    await tester.pumpAndSettle();
    expect(find.text('Path rooted-in-christ'), findsNothing);
    for (final s in _guestSlugs.take(3)) {
      expect(find.text('Path $s'), findsOneWidget);
    }
    expect(find.text('Path theology-of-suffering'), findsNothing);
  });

  testWidgets('guest tapping a locked path gets the account sheet',
      (tester) async {
    when(() => guest.isGuest).thenReturn(true);
    // Enrolled elsewhere already: every other path is locked (second_path).
    GuestPathEnrollment.record('id-other');
    listPaths([_path('gospel-of-mark', guestAccessible: true)]);
    await tester.pumpWidget(app(section(null)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guest_path_lock_id-gospel-of-mark')),
        findsOneWidget);
    await tester.tap(find.text('Path gospel-of-mark'));
    await tester.pumpAndSettle();
    expect(find.text('Your next path needs an account'), findsOneWidget);
    expect(find.textContaining('detail:'), findsNothing);
  });

  testWidgets('loading without a summary shows neither chooser nor card',
      (tester) async {
    listPaths(const []);
    await tester.pumpWidget(app(section(null, loading: true)));
    await tester.pump();
    expect(find.byType(ChooseFirstPathCard), findsNothing);
    expect(find.byType(TodayLessonCard), findsNothing);
  });

  testWidgets('summary → header, strip, card; See path opens detail',
      (tester) async {
    await tester.pumpWidget(app(section(summary4of8)));
    await tester.pumpAndSettle();
    expect(find.text('New Believer Essentials'), findsOneWidget);
    expect(find.text('See path'), findsOneWidget);
    expect(find.byType(PathProgressStrip), findsOneWidget);
    expect(find.byType(TodayLessonCard), findsOneWidget);
    expect(find.text('Lesson 4 of 8'), findsOneWidget);
    expect(find.text('5 to go'), findsOneWidget);
    expect(find.byType(ChooseFirstPathCard), findsNothing);
    expect(find.byType(SaveProgressRow), findsNothing);

    final title = tester.widget<Text>(find.text('New Believer Essentials'));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.style!.fontSize, 15);

    await tester.tap(find.text('See path'));
    await tester.pumpAndSettle();
    expect(find.text('detail:p1:home'), findsOneWidget);
  });

  testWidgets('the strip opens the path too', (tester) async {
    await tester.pumpWidget(app(section(summary4of8)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PathProgressStrip));
    await tester.pumpAndSettle();
    expect(find.text('detail:p1:home'), findsOneWidget);
  });

  testWidgets('Start lesson opens the next lesson in the chosen mode',
      (tester) async {
    await tester.pumpWidget(app(section(summary4of8)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start lesson 4'));
    await tester.pumpAndSettle();
    expect(find.text('stub:lesson:quick'), findsOneWidget);
  });

  testWidgets('guest: the section leaves the Save progress row to Home',
      (tester) async {
    // Home's Today layout puts the row after the New for you banner.
    when(() => guest.isGuest).thenReturn(true);
    await tester.pumpWidget(app(section(summary4of8)));
    await tester.pumpAndSettle();
    expect(find.byType(SaveProgressRow), findsNothing);
  });

  testWidgets('back from a lesson asks Home to refresh the path',
      (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(app(HomePathSection(
      summary: summary4of8,
      loading: false,
      mode: StudyMode.quick,
      onModeChanged: (_) {},
      onProgressMayHaveChanged: () => refreshed++,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start lesson 4'));
    await tester.pumpAndSettle();
    expect(refreshed, 0);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(refreshed, 1);
  });

  testWidgets('loading skeleton has the section shape and a label',
      (tester) async {
    await tester.pumpWidget(app(section(null, loading: true)));
    await tester.pump();
    expect(find.byKey(const Key('home_path_placeholder')), findsOneWidget);
    expect(find.bySemanticsLabel('Loading your path'), findsOneWidget);
  });

  testWidgets('guest finished path: Choose your next path opens account sheet',
      (tester) async {
    when(() => guest.isGuest).thenReturn(true);
    await tester.pumpWidget(app(section(finishedSummary)));
    await tester.pumpAndSettle();
    expect(find.text('Lesson 8 of 8'), findsNothing);
    await tester.tap(find.text('Choose your next path'));
    await tester.pumpAndSettle();
    expect(find.text('Your next path needs an account'), findsOneWidget);
    expect(find.text('stub:topics'), findsNothing);
  });

  testWidgets('full user finished path: Choose your next path opens Topics',
      (tester) async {
    await tester.pumpWidget(app(section(finishedSummary)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose your next path'));
    await tester.pumpAndSettle();
    expect(find.text('stub:topics'), findsOneWidget);
  });

  testWidgets('ml 360px header fits', (tester) async {
    useSurface(tester, const Size(360, 800));
    await tester.pumpWidget(app(section(mlSummary), language: 'ml'));
    await tester.pumpAndSettle();
    expect(find.text('പാത'), findsOneWidget);
    expectNoTruncatedText(tester,
        allow: {mlSummary.displayTitle, mlSummary.next!.title});
  });

  for (final language in ['hi', 'ml']) {
    for (final dark in [false, true]) {
      final summary = language == 'hi' ? hiSummary : mlSummary;
      testWidgets('$language 320px fits (dark: $dark), guest', (tester) async {
        when(() => guest.isGuest).thenReturn(true);
        useSurface(tester, const Size(320, 900));
        await tester
            .pumpWidget(app(section(summary), dark: dark, language: language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester,
            allow: {summary.displayTitle, summary.next!.title});
      });

      testWidgets('$language 320px chooser fits (dark: $dark)', (tester) async {
        useSurface(tester, const Size(320, 900));
        listPaths([
          _path('a',
              featured: true,
              order: 1,
              lessons: 12,
              days: 21,
              title: language == 'hi'
                  ? 'बाइबल को समझना और उसका अध्ययन'
                  : 'ബൈബിൾ മനസ്സിലാക്കുകയും പഠിക്കുകയും'),
          _path('b', featured: true, order: 2),
        ]);
        await tester
            .pumpWidget(app(section(null), dark: dark, language: language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester, allow: {
          'बाइबल को समझना',
          'ബൈബിൾ മനസ്സിലാക്കുകയും',
        });
      });
    }
  }
}
