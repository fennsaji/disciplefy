import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/guest_path_enrollment.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_state.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/today_lesson_card.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/for_you_learning_paths_section.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/guest_path_lock.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_paths_section.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/topics_current_path_card.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/topics_header_cards.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/topics_layout.dart';

import '../../../../helpers/fit_matrix.dart';
import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

class _MockLearningPathsBloc
    extends MockBloc<LearningPathsEvent, LearningPathsState>
    implements LearningPathsBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _MockGuest extends Mock implements GuestSessionService {}

class _MockFlags extends Mock implements RolloutFlags {}

const summary4of8 = ActivePathSummary(
  pathId: 'nbe',
  title: 'New Believer Essentials',
  description: '',
  discipleLevel: 'seeker',
  lessonTotal: 8,
  lessonsCompleted: 3,
  next: NextLesson(
    topicId: 't4',
    title: 'Confidence in Your Salvation',
    description: '',
    inputType: 'topic',
    number: 4,
    total: 8,
  ),
  milestoneNumbers: [4, 7],
);

LearningPath _path(
  String id,
  String title, {
  String category = 'Foundations',
  bool guestAccessible = false,
  bool enrolled = false,
}) =>
    LearningPath(
      id: id,
      slug: id,
      title: title,
      description: '',
      iconName: 'park',
      color: '#10B981',
      totalXp: 250,
      estimatedDays: 21,
      discipleLevel: 'seeker',
      topicsCount: 5,
      category: category,
      guestAccessible: guestAccessible,
      isEnrolled: enrolled,
      progressPercentage: enrolled ? 40 : 0,
    );

LearningPathCategory cat(String name, int count) => LearningPathCategory(
      name: name,
      paths: [
        for (var i = 0; i < count; i++)
          _path('${name.toLowerCase()}$i', '$name path $i', category: name),
      ],
      totalInCategory: count,
      nextPathOffset: count,
    );

const finishedSummary = ActivePathSummary(
  pathId: 'nbe',
  title: 'New Believer Essentials',
  description: '',
  discipleLevel: 'seeker',
  lessonTotal: 8,
  lessonsCompleted: 8,
  milestoneNumbers: [4, 7],
);

void main() {
  late FakeTranslationService translations;
  late _MockLearningPathsBloc bloc;
  late _MockConnectivityBloc connectivity;

  setUpAll(loadAppFonts);

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
    bloc = _MockLearningPathsBloc();
    connectivity = _MockConnectivityBloc();
    when(() => connectivity.state).thenReturn(ConnectivityOnline());
  });

  tearDown(() async {
    GuestPathEnrollment.reset();
    await bloc.close();
    await connectivity.close();
    await sl.reset();
  });

  Future<void> pumpTopics(
    WidgetTester tester, {
    required ActivePathSummary? summary,
    required List<LearningPathCategory> categories,
    bool dark = true,
    AppLanguage lang = AppLanguage.english,
    Size size = const Size(390, 1400),
    void Function(String)? onTap,
    void Function(LearningPath)? onPathTap,
    VoidCallback? onNearEnd,
    ValueChanged<StudyMode>? onModeChanged,
    double textScale = 1,
    double dockInset = 0,
  }) async {
    translations.language = lang;
    useSurface(tester, size);
    whenListen(bloc, const Stream<LearningPathsState>.empty(),
        initialState: LearningPathsLoaded(categories: categories));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          // The floating dock's height, as the shell's extendBody adds it.
          padding: EdgeInsets.only(bottom: dockInset),
        ),
        child: child!,
      ),
      locale: Locale(lang.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<LearningPathsBloc>.value(value: bloc),
          BlocProvider<ConnectivityBloc>.value(value: connectivity),
        ],
        child: Scaffold(
          body: Builder(
            builder: (context) => TopicsLayout(
              onNearEnd: onNearEnd,
              currentPath: TopicsCurrentPathCard(
                summary: summary,
                onModeChanged: onModeChanged ?? (_) {},
                onContinue: () => onTap?.call('continue'),
                onSeePath: () => onTap?.call('see_path'),
                onBrowse: () => onTap?.call('browse'),
                onChooseNextPath: () => onTap?.call('choose_next'),
              ),
              statTiles: TopicsStatRow(
                streak: 13,
                rank: 5,
                onLeaderboardTap: () => onTap?.call('leaderboard'),
              ),
              paths: LearningPathsSection(
                compact: true,
                onPathTap: onPathTap ?? (_) {},
                onCategorySeeAll: (c) => onTap?.call('see_all:$c'),
              ),
              onBrowseAll: () => onTap?.call('browse_all'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Topics: current path, lesson card, streak + Leaderboard tiles, '
      'categories with See all, Browse all paths; no For you, no level chips',
      (tester) async {
    await pumpTopics(tester,
        summary: summary4of8,
        categories: [cat('Foundations', 2), cat('Gospels', 1)]);
    expect(find.text('New Believer Essentials'), findsWidgets);
    // Home's lesson card: eyebrow, mode chip, lesson title, Start lesson N.
    expect(find.byType(TodayLessonCard), findsOneWidget);
    expect(find.text('Confidence in Your Salvation'), findsOneWidget);
    expect(find.text('Start lesson 4'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('See all'), findsNWidgets(2));
    expect(find.text('Browse all paths'), findsOneWidget);
    expect(find.byKey(const Key('topics_streak_tile')), findsOneWidget);
    expect(find.byKey(const Key('topics_leaderboard_tile')), findsOneWidget);
    expect(find.byType(ForYouLearningPathsSection), findsNothing);
    expect(find.byKey(const Key('learning_paths_chip_seeker')), findsNothing);
    expect(find.byKey(const Key('learning_paths_chip_all')), findsNothing);
    expect(find.text('Seeker'), findsNothing);
    expect(find.textContaining('XP'), findsNothing);
    // No XP or level on the card or the tiles.
    for (final scope in [
      find.byType(TopicsCurrentPathCard),
      find.byType(TopicsStatRow),
    ]) {
      expect(find.descendant(of: scope, matching: find.textContaining('XP')),
          findsNothing);
      expect(
          find.descendant(of: scope, matching: find.textContaining('Seeker')),
          findsNothing);
    }
  });

  testWidgets('buttons call back: Continue, See path, See all, Browse',
      (tester) async {
    final taps = <String>[];
    await pumpTopics(tester,
        summary: summary4of8,
        categories: [cat('Foundations', 2)],
        onTap: taps.add);
    await tester.tap(find.text('Start lesson 4'));
    await tester.tap(find.text('See path'));
    await tester.tap(find.text('See all'));
    await tester.ensureVisible(find.text('Browse all paths'));
    await tester.tap(find.text('Browse all paths'));
    expect(taps, ['continue', 'see_path', 'see_all:Foundations', 'browse_all']);
  });

  testWidgets('no enrolled path shows Start a path, categories still load',
      (tester) async {
    final taps = <String>[];
    await pumpTopics(tester,
        summary: null, categories: [cat('Foundations', 2)], onTap: taps.add);
    expect(find.text('Start a path'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.byKey(const Key('strip_today')), findsNothing);
    expect(find.text('Foundations path 0'), findsOneWidget);
    await tester.tap(find.text('Start a path'));
    expect(taps, ['browse']);
  });

  testWidgets(
      'categories: no heading or search on Topics (search is on All paths), '
      'at most two rows each, See all for the rest', (tester) async {
    await pumpTopics(tester,
        summary: summary4of8,
        categories: [cat('Foundations', 5), cat('Gospels', 1)]);
    expect(find.byKey(const Key('learning_paths_search_field')), findsNothing);
    expect(find.text('Learning Paths'), findsNothing);
    expect(find.text('Foundations path 0'), findsOneWidget);
    expect(find.text('Foundations path 1'), findsOneWidget);
    expect(find.text('Foundations path 2'), findsNothing);
    expect(find.text('Gospels path 0'), findsOneWidget);
    expect(find.byKey(const Key('learning_paths_see_all_Foundations')),
        findsOneWidget);
  });

  testWidgets('lesson card mode chip reports the picked mode', (tester) async {
    final modes = <StudyMode>[];
    await pumpTopics(tester,
        summary: summary4of8,
        categories: [cat('Foundations', 1)],
        onModeChanged: modes.add);
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Quick').last);
    await tester.pumpAndSettle();
    expect(modes, [StudyMode.quick]);
  });

  testWidgets('a finished path offers Choose your next path', (tester) async {
    final taps = <String>[];
    await pumpTopics(tester,
        summary: finishedSummary,
        categories: [cat('Foundations', 1)],
        onTap: taps.add);
    expect(find.text('Start lesson 4'), findsNothing);
    await tester.tap(find.text('Choose your next path'));
    expect(taps, ['choose_next']);
  });

  group('scrolling', () {
    List<LearningPathCategory> many() =>
        [for (var i = 0; i < 8; i++) cat('Category$i', 2)];

    ScrollPosition position(WidgetTester tester) => tester
        .state<ScrollableState>(find
            .descendant(
                of: find.byType(TopicsLayout),
                matching: find.byType(Scrollable))
            .first)
        .position;

    testWidgets('a drag and a fling scroll the tab at 390x844', (tester) async {
      await pumpTopics(tester,
          summary: summary4of8, categories: many(), size: const Size(390, 844));
      final pos = position(tester);
      expect(pos.maxScrollExtent, greaterThan(400));
      expect(pos.pixels, 0);

      // A drag that starts on a path row (an InkWell) still scrolls.
      await tester.drag(find.text('Category0 path 1'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(pos.pixels, greaterThan(250));

      final before = pos.pixels;
      await tester.fling(
          find.byType(TopicsLayout), const Offset(0, -400), 2000);
      await tester.pumpAndSettle();
      expect(pos.pixels, greaterThan(before));
    });

    testWidgets('the last button scrolls clear of the floating dock',
        (tester) async {
      const dock = 96.0;
      await pumpTopics(tester,
          summary: summary4of8,
          categories: many(),
          size: const Size(390, 844),
          dockInset: dock);
      final pos = position(tester);
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pumpAndSettle();
      final browse = tester.getRect(find.byType(BrowseAllPathsButton));
      expect(browse.bottom, lessThanOrEqualTo(844 - dock));
    });

    testWidgets('near the end asks for more categories, not before',
        (tester) async {
      var calls = 0;
      await pumpTopics(tester,
          summary: summary4of8,
          categories: many(),
          size: const Size(390, 844),
          onNearEnd: () => calls++);
      expect(calls, 0);
      await tester.drag(find.byType(TopicsLayout), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(calls, 0);
      final pos = position(tester);
      await tester.drag(find.byType(TopicsLayout),
          Offset(0, -(pos.maxScrollExtent - pos.pixels)));
      await tester.pumpAndSettle();
      expect(calls, greaterThan(0));
    });

    testWidgets('a first page shorter than the screen still asks for more',
        (tester) async {
      var calls = 0;
      await pumpTopics(tester,
          summary: null,
          categories: [cat('Foundations', 1)],
          onNearEnd: () => calls++);
      expect(calls, greaterThan(0));
    });
  });

  group('topicsPathSummary', () {
    final enrolled = _path('nbe', 'New Believer Essentials', enrolled: true);
    final featured = _path('nbe', 'New Believer Essentials');

    test("uses Home's enrolled path", () {
      final home = HomeCombinedState(
          activeLearningPath: enrolled, activePathSummary: summary4of8);
      expect(topicsPathSummary(home, null), summary4of8);
      expect(topicsCurrentPath(home, null), enrolled);
    });

    test("a featured recommendation on Home is not the user's path", () {
      final home = HomeCombinedState(
          activeLearningPath: featured, activePathSummary: summary4of8);
      expect(topicsPathSummary(home, null), isNull);
    });

    test('falls back to the recommended-path call when Home has none', () {
      const home = HomeCombinedState();
      final result = RecommendedPathResult(
        path: enrolled,
        reason: LearningPathRecommendationReason.active,
        summary: summary4of8,
      );
      expect(topicsPathSummary(home, result), summary4of8);
      expect(
          topicsPathSummary(
              home,
              RecommendedPathResult(
                  path: featured,
                  reason: LearningPathRecommendationReason.featured,
                  summary: summary4of8)),
          isNull);
    });
  });

  group('guest', () {
    late _MockGuest guest;

    setUp(() {
      guest = _MockGuest();
      final flags = _MockFlags();
      when(() => guest.isGuest).thenReturn(true);
      when(() => flags.guestMode).thenReturn(true);
      sl.registerSingleton<GuestSessionService>(guest);
      sl.registerSingleton<RolloutFlags>(flags);
      GuestPathEnrollment.currentUserId = () => 'guest-1';
    });

    testWidgets(
        'category rows keep the guest locks: own path open, others locked '
        'and open the account sheet', (tester) async {
      GuestPathEnrollment.record('mine');
      final opened = <String>[];
      final mine =
          _path('mine', 'My path', guestAccessible: true, enrolled: true);
      final second = _path('second', 'Second path', guestAccessible: true);
      final closed = _path('closed', 'Closed path');
      late BuildContext ctx;
      await pumpTopics(
        tester,
        summary: summary4of8,
        categories: [
          // Topics shows two rows per category.
          LearningPathCategory(
            name: 'Foundations',
            paths: [mine, second],
            totalInCategory: 2,
          ),
          LearningPathCategory(
            name: 'Gospels',
            paths: [closed],
            totalInCategory: 1,
          ),
        ],
        onPathTap: (p) => guestPathGate(ctx, p, () async => opened.add(p.id)),
      );
      ctx = tester.element(find.byType(TopicsLayout));

      expect(find.byKey(const Key('guest_path_lock_mine')), findsNothing);
      expect(find.byKey(const Key('guest_path_lock_second')), findsOneWidget);
      expect(find.byKey(const Key('guest_path_lock_closed')), findsOneWidget);

      await tester.tap(find.text('My path'));
      await tester.pumpAndSettle();
      expect(opened, ['mine']);

      await tester.tap(find.text('Second path'));
      await tester.pumpAndSettle();
      expect(opened, ['mine']);
      expect(find.text('Your next path needs an account'), findsOneWidget);
    });
  });

  for (final width in fitWidths) {
    for (final lang in AppLanguage.values) {
      for (final dark in [true, false]) {
        final name = '${lang.code} ${dark ? 'dark' : 'light'}';
        testWidgets('fits ${width.toInt()} wide ($name)', (tester) async {
          await pumpTopics(
            tester,
            summary: summary4of8,
            categories: [cat('Foundations', 2), cat('Gospels', 1)],
            dark: dark,
            lang: lang,
            size: Size(width, 1400),
          );
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });

        testWidgets('fits ${width.toInt()} wide at 1.3x text ($name)',
            (tester) async {
          await pumpTopics(
            tester,
            summary: summary4of8,
            categories: [cat('Foundations', 2), cat('Gospels', 1)],
            dark: dark,
            lang: lang,
            size: Size(width, 1800),
            textScale: 1.3,
          );
          expect(tester.takeException(), isNull);
          // The lesson title may wrap to its two lines; nothing else is cut.
          expectNoTruncatedText(tester);
        });

        testWidgets('Start a path fits ${width.toInt()} wide ($name)',
            (tester) async {
          await pumpTopics(
            tester,
            summary: null,
            categories: [cat('Foundations', 1)],
            dark: dark,
            lang: lang,
            size: Size(width, 900),
          );
          expect(tester.takeException(), isNull);
          expectNoTruncatedText(tester);
        });
      }
    }
  }
}
