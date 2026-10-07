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
  }) async {
    translations.language = lang;
    useSurface(tester, size);
    whenListen(bloc, const Stream<LearningPathsState>.empty(),
        initialState: LearningPathsLoaded(categories: categories));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
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
              currentPath: TopicsCurrentPathCard(
                summary: summary,
                onContinue: () => onTap?.call('continue'),
                onSeePath: () => onTap?.call('see_path'),
                onBrowse: () => onTap?.call('browse'),
              ),
              statTiles: TopicsStatRow(
                streak: 13,
                rank: 5,
                onLeaderboardTap: () => onTap?.call('leaderboard'),
              ),
              paths: LearningPathsSection(
                showFilters: false,
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
      'Topics: current path, Continue, streak + Leaderboard tiles, categories '
      'with See all, Browse all paths; no For you, no level chips',
      (tester) async {
    await pumpTopics(tester,
        summary: summary4of8,
        categories: [cat('Foundations', 2), cat('Gospels', 1)]);
    expect(find.text('New Believer Essentials'), findsWidgets);
    expect(find.text('Continue'), findsOneWidget);
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
    await tester.tap(find.text('Continue'));
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
          LearningPathCategory(
            name: 'Foundations',
            paths: [mine, second, closed],
            totalInCategory: 3,
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
