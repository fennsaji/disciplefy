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

import '../../../../helpers/fit_matrix.dart';
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
  String? id,
  bool guestAccessible = false,
  bool featured = false,
  int? order,
  int lessons = 8,
  int days = 14,
  String title = '',
}) =>
    LearningPath(
      id: id ?? 'id-$slug',
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

  /// What the server's next-path engine answers (it already orders and
  /// filters: goal paths, featured, guest-accessible only for a guest).
  void listPaths(List<LearningPath> list, {FinishedPathRef? finished}) {
    when(() => paths.getNextPaths(
              language: any(named: 'language'),
              limit: any(named: 'limit'),
            ))
        .thenAnswer((_) async =>
            Right(NextPathsResult(paths: list, finishedPath: finished)));
  }

  void failNextPaths() {
    when(() => paths.getNextPaths(
          language: any(named: 'language'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const Left(NetworkFailure()));
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
    failNextPaths();
    await tester.pumpWidget(app(section(null)));
    await tester.pumpAndSettle();
    expect(find.text('Choose your first path'), findsOneWidget);
    expect(find.text('See all paths'), findsOneWidget);
  });

  testWidgets('chooser shows at most three of the server\'s paths, in order',
      (tester) async {
    when(() => guest.isGuest).thenReturn(true);
    listPaths([for (final s in _guestSlugs) _path(s, guestAccessible: true)]);
    await tester.pumpWidget(app(section(null)));
    await tester.pumpAndSettle();
    for (final s in _guestSlugs.take(3)) {
      expect(find.text('Path $s'), findsOneWidget);
    }
    expect(find.text('Path theology-of-suffering'), findsNothing);
    expect(
        verify(() => paths.getNextPaths(
            language: any(named: 'language'),
            limit: captureAny(named: 'limit'))).captured,
        [3]);
  });

  testWidgets('guest with no guest path left: one row opens the account sheet',
      (tester) async {
    when(() => guest.isGuest).thenReturn(true);
    listPaths(const []);
    await tester.pumpWidget(app(section(null)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account for more paths'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('no active path after finishing one: the chooser says What next?',
      (tester) async {
    listPaths(
      [_path('gospel-of-john', title: 'John'), _path('gospel-of-luke')],
      finished: const FinishedPathRef(id: 'id-mark', title: 'Mark'),
    );
    await tester.pumpWidget(app(section(null)));
    await tester.pumpAndSettle();
    expect(find.text('What next?'), findsOneWidget);
    expect(find.text('Pick a path to keep going.'), findsOneWidget);
    expect(find.text('Choose your first path'), findsNothing);
    expect(find.text('John'), findsOneWidget);
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
    // Dots show where you are: no "Lesson n of m" caption on short paths.
    expect(find.textContaining('Lesson 4 of 8'), findsNothing);
    expect(find.text('5 to go'), findsNothing);
    expect(find.byType(ChooseFirstPathCard), findsNothing);
    expect(find.byType(SaveProgressRow), findsNothing);

    final title = tester.widget<Text>(find.text('New Believer Essentials'));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.style!.fontSize, 16);

    await tester.tap(find.text('See path'));
    await tester.pumpAndSettle();
    expect(find.text('detail:p1:home'), findsOneWidget);
  });

  testWidgets('long paths: the caption sits inside the path card',
      (tester) async {
    ActivePathSummary long(int total, int done) => ActivePathSummary(
          pathId: 'p1',
          title: 'Long path',
          description: '',
          discipleLevel: 'seeker',
          lessonTotal: total,
          lessonsCompleted: done,
          next: NextLesson(
            topicId: 't',
            title: 'Next one',
            description: '',
            inputType: 'topic',
            number: done + 1,
            total: total,
          ),
        );
    await tester.pumpWidget(app(section(long(16, 3))));
    await tester.pumpAndSettle();
    final caption = find.byKey(const Key('strip_caption'));
    expect(
        find.descendant(of: find.byType(PathProgressStrip), matching: caption),
        findsOneWidget);
    expect(find.textContaining('Lesson 4 of 16'), findsOneWidget);
    // Segments: no "to go", as in the design.
    expect(find.text('13 to go'), findsNothing);

    await tester.pumpWidget(app(section(long(29, 11))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lesson 12 of 29'), findsOneWidget);
    expect(find.text('18 to go'), findsOneWidget);
  });

  testWidgets('one card holds the strip and the lesson, no Today label',
      (tester) async {
    await tester.pumpWidget(app(section(summary4of8)));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('today_path_card'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.byType(PathProgressStrip)),
        findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Start lesson 4')),
        findsOneWidget);
    expect(find.text('Today'), findsNothing);
    // The header stays above the card.
    expect(tester.getBottomLeft(find.text('New Believer Essentials')).dy,
        lessThanOrEqualTo(tester.getTopLeft(card).dy));
  });

  testWidgets('loading skeleton is as tall as the loaded section',
      (tester) async {
    await tester.pumpWidget(app(section(null, loading: true)));
    await tester.pump();
    final skeleton =
        tester.getSize(find.byKey(const Key('home_path_placeholder'))).height;
    await tester.pumpWidget(app(section(summary4of8)));
    await tester.pumpAndSettle();
    final loaded = tester.getSize(find.byType(HomePathSection)).height;
    expect((skeleton - loaded).abs(), lessThanOrEqualTo(2));
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

  testWidgets('chooser: a path page that reports a change refreshes Home',
      (tester) async {
    listPaths([_path('rooted-in-christ', featured: true, order: 1)]);
    var refreshed = 0;
    await tester.pumpWidget(app(HomePathSection(
      summary: null,
      loading: false,
      mode: StudyMode.quick,
      onProgressMayHaveChanged: () => refreshed++,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Path rooted-in-christ'));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).last).pop(true);
    await tester.pumpAndSettle();
    expect(refreshed, 1);
  });

  testWidgets('chooser: a failed list offers Retry, which loads it again',
      (tester) async {
    failNextPaths();
    await tester.pumpWidget(app(section(null)));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load paths"), findsOneWidget);
    listPaths([_path('rooted-in-christ', featured: true, order: 1)]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load paths"), findsNothing);
    expect(find.text('Path rooted-in-christ'), findsOneWidget);
  });

  testWidgets('Start lesson ignores a quick second tap', (tester) async {
    await tester.pumpWidget(app(section(summary4of8)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start lesson 4'));
    await tester.pump();
    await tester.tap(find.text('Start lesson 4'), warnIfMissed: false);
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();
    expect(find.text('Start lesson 4'), findsOneWidget);
    expect(find.textContaining('stub:lesson'), findsNothing);
  });

  testWidgets('See path has a 40px tap target', (tester) async {
    await tester.pumpWidget(app(section(summary4of8)));
    await tester.pumpAndSettle();
    final button = find.ancestor(
        of: find.text('See path'), matching: find.byType(TextButton));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(40));
  });

  testWidgets('unfinished path without a next lesson: See path in the card',
      (tester) async {
    const missingNext = ActivePathSummary(
      pathId: 'p1',
      title: 'New Believer Essentials',
      description: '',
      discipleLevel: 'seeker',
      lessonTotal: 8,
      lessonsCompleted: 3,
    );
    await tester.pumpWidget(app(section(missingNext)));
    await tester.pumpAndSettle();
    expect(find.textContaining('You finished'), findsNothing);
    await tester.tap(find.descendant(
        of: find.byType(TodayLessonCard), matching: find.text('See path')));
    await tester.pumpAndSettle();
    expect(find.text('detail:p1:home'), findsOneWidget);
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
    listPaths(const []);
    await tester.pumpWidget(app(section(finishedSummary)));
    await tester.pumpAndSettle();
    expect(find.text('Lesson 8 of 8'), findsNothing);
    await tester.tap(find.text('Choose your next path'));
    await tester.pumpAndSettle();
    expect(find.text('Your next path needs an account'), findsOneWidget);
    expect(find.text('stub:topics'), findsNothing);
  });

  testWidgets(
      'finished path: What next? lists the next paths, not the finished one',
      (tester) async {
    listPaths([
      // The finished path itself (a stale server answer) is never listed.
      _path('new-believer-essentials', id: 'p1', title: 'Finished one'),
      _path('rooted-in-christ', title: 'Rooted in Christ'),
      _path('gospel-of-mark', title: 'Mark'),
      _path('gospel-of-john', title: 'John'),
    ]);
    await tester.pumpWidget(app(section(finishedSummary)));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('home_what_next'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('What next?')),
        findsOneWidget);
    expect(find.text('Rooted in Christ'), findsOneWidget);
    expect(find.text('Finished one'), findsNothing);
    expect(find.text('John'), findsOneWidget);
    // One extra asked for, as the finished path is left out.
    verify(() => paths.getNextPaths(language: any(named: 'language'), limit: 4))
        .called(1);
    await tester.ensureVisible(find.text('Mark'));
    await tester.tap(find.text('Mark'));
    await tester.pumpAndSettle();
    expect(find.text('detail:id-gospel-of-mark:home'), findsOneWidget);
  });

  testWidgets('unfinished path: no What next?', (tester) async {
    listPaths([_path('gospel-of-mark')]);
    await tester.pumpWidget(app(section(summary4of8)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_what_next')), findsNothing);
    verifyNever(() => paths.getNextPaths(
        language: any(named: 'language'), limit: any(named: 'limit')));
  });

  testWidgets('full user finished path: Choose your next path opens Topics',
      (tester) async {
    listPaths(const []);
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

  for (final c in fitCases()) {
    final language = c.lang;
    final dark = c.dark;
    final summary = language == 'hi' ? hiSummary : mlSummary;
    testWidgets('$language ${c.width.toInt()}px fits (dark: $dark), guest',
        (tester) async {
      when(() => guest.isGuest).thenReturn(true);
      useSurface(tester, c.size(900));
      await tester
          .pumpWidget(app(section(summary), dark: dark, language: language));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectNoTruncatedText(tester,
          allow: {summary.displayTitle, summary.next!.title});
    });

    testWidgets('$language ${c.width.toInt()}px chooser fits (dark: $dark)',
        (tester) async {
      useSurface(tester, c.size(900));
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
