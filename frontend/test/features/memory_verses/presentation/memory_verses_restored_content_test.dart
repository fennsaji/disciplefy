import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/mastery_progress_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_champion_entry.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_mode_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/practice_result_params.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/review_statistics_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/suggested_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/memory_champions_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/memory_stats_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/memory_verses_home_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/practice_results_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/add_manual_verse_dialog.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_verse_list_item.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/practice_activity_grid.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/practice_mode_row.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/suggested_verses_sheet.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/verse_flip_card.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

import '../../../helpers/welcome_test_harness.dart';

/// Content restored after the memory verses redesign, and labels that must
/// show whole (never "…") at 320pt in English, Hindi and Malayalam.

class _MockMemoryVerseBloc extends MockBloc<MemoryVerseEvent, MemoryVerseState>
    implements MemoryVerseBloc {}

class _MockGamificationBloc
    extends MockBloc<GamificationEvent, GamificationState>
    implements GamificationBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _SeenWalkthroughs extends Fake implements WalkthroughRepository {
  @override
  Future<bool> hasSeen(WalkthroughScreen screen) async => true;

  @override
  Future<void> markSeen(WalkthroughScreen screen) async {}
}

final _today = DateTime.now();

MemoryVerseEntity _verse(
  String id,
  String reference, {
  required int dueInDays,
  MasteryLevel level = MasteryLevel.beginner,
  double easeFactor = 2.5,
  int repetitions = 2,
}) =>
    MemoryVerseEntity(
      id: id,
      verseReference: reference,
      verseText: 'I can do all things through him who strengthens me.',
      language: 'en',
      sourceType: 'manual',
      easeFactor: easeFactor,
      intervalDays: 3,
      repetitions: repetitions,
      nextReviewDate:
          DateTime(_today.year, _today.month, _today.day + dueInDays, 9),
      addedDate: DateTime(2026, 9, 2),
      totalReviews: 4,
      createdAt: DateTime(2026, 9, 2),
      masteryLevel: level,
    );

/// Every rendered [Text] with exactly [text] lays out whole: no ellipsis and
/// no lines dropped by `maxLines`.
void expectWhole(WidgetTester tester, String text) {
  final finder = find.text(text);
  expect(finder, findsWidgets, reason: '"$text" is not shown');
  for (final element in finder.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse, reason: '"$text" is cut off');
    expect(
        paragraph.overflow == TextOverflow.ellipsis && paragraph.maxLines == 1,
        isFalse,
        reason: '"$text" is single-line ellipsized');
  }
}

void main() {
  late FakeTranslationService translations;
  late _MockMemoryVerseBloc bloc;
  late _MockConnectivityBloc connectivity;
  late List<String> visited;

  String tr(String key, [Map<String, dynamic>? args]) =>
      translations.getTranslation(key, args);

  setUpAll(() {
    registerFallbackValue(const LoadMemoryStatisticsEvent());
  });

  setUp(() {
    translations = FakeTranslationService();
    bloc = _MockMemoryVerseBloc();
    connectivity = _MockConnectivityBloc();
    visited = [];
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<WalkthroughRepository>(_SeenWalkthroughs());
    sl.registerSingleton<GamificationBloc>(_MockGamificationBloc());
    sl.registerFactory<MemoryVerseBloc>(() => bloc);
    whenListen<ConnectivityState>(
      connectivity,
      const Stream<ConnectivityState>.empty(),
      initialState: ConnectivityOnline(),
    );
  });

  tearDown(() async => sl.reset());

  Widget app(Widget page, {bool dark = true}) {
    GoRoute stub(String route) => GoRoute(
          path: route,
          builder: (_, state) {
            visited.add(state.uri.toString());
            return Scaffold(body: Text('stub:$route'));
          },
        );
    final router = GoRouter(
      initialLocation: '/page',
      routes: [
        GoRoute(path: '/page', builder: (_, __) => page),
        stub('/memory-verses/champions'),
        stub('/memory-verses/stats'),
        stub('/memory-verses/practice/:id'),
        stub('/'),
      ],
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider<MemoryVerseBloc>.value(value: bloc),
        BlocProvider<ConnectivityBloc>.value(value: connectivity),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  Widget host(Widget child, {bool dark = true}) => MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(body: ListView(children: [child])),
      );

  group('Statistics heat map and mode records', () {
    final stats = {
      'total_verses': 4,
      'total_reviews': 27,
      'perfect_recalls': 9,
      'total_practice_days': 12,
      'current_streak': 4,
      'longest_streak': 9,
      'activity_data': {
        for (var i = 0; i < 20; i++)
          DateTime(_today.year, _today.month, _today.day - i * 3)
              .toIso8601String()
              .substring(0, 10): (i % 4) + 1,
      },
      'mastery_distribution': {'beginner': 1, 'master': 1},
      'practice_modes': [
        {'mode_type': 'flip_card', 'success_rate': 88, 'times_practiced': 6},
      ],
    };

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: heat map labels, legend, streaks',
          (tester) async {
        translations.language = language;
        whenListen<MemoryVerseState>(
          bloc,
          const Stream<MemoryVerseState>.empty(),
          initialState: MemoryStatisticsLoaded(statistics: stats),
        );
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(const MemoryStatsPage()));
        await tester.pumpAndSettle();

        for (final key in [
          TranslationKeys.heatMapTitle,
          TranslationKeys.heatMapSubtitle,
          TranslationKeys.heatMapMon,
          TranslationKeys.heatMapWed,
          TranslationKeys.heatMapFri,
          TranslationKeys.heatMapLess,
          TranslationKeys.heatMapMore,
          TranslationKeys.memoryStatsTotalReviews,
          TranslationKeys.memoryStatsPracticeDays,
        ]) {
          expectWhole(tester, tr(key));
        }
        expectWhole(tester, tr(TranslationKeys.heatMapDayStreak, {'count': 4}));
        expectWhole(
            tester, tr(TranslationKeys.heatMapLongestStreak, {'days': 9}));

        // Month names above the grid (at least one in 12 weeks).
        final gridTexts = find.descendant(
          of: find.byType(PracticeActivityGrid),
          matching: find.byType(Text),
        );
        expect(gridTexts.evaluate().length, greaterThanOrEqualTo(4));

        await tester.scrollUntilVisible(
          find.text('88%'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expectWhole(tester,
            tr(TranslationKeys.memoryScreensPracticesCount, {'count': 6}));
        expect(find.text('88%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Home quick links', () {
    final loaded = DueVersesLoaded(
      verses: [_verse('v1', 'Philippians 4:13', dueInDays: 0)],
      statistics: const ReviewStatisticsEntity(
        totalVerses: 1,
        dueVerses: 1,
        reviewedToday: 0,
        upcomingReviews: 0,
        masteredVerses: 0,
        fullyMasteredVerses: 0,
      ),
      hasMore: false,
    );

    for (final language in AppLanguage.values) {
      testWidgets(
          '320x640 ${language.code}: Champions and Statistics whole in the menu',
          (tester) async {
        translations.language = language;
        whenListen<MemoryVerseState>(
          bloc,
          const Stream<MemoryVerseState>.empty(),
          initialState: loaded,
        );
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(const MemoryVersesHomePage()));
        await tester.pumpAndSettle();
        expect(
            find.text(tr(TranslationKeys.memoryMenuChampions)), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expectWhole(tester, tr(TranslationKeys.memoryMenuChampions));
        expectWhole(tester, tr(TranslationKeys.memoryMenuStatistics));
        expect(tester.takeException(), isNull);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: header line fits, whole',
          (tester) async {
        translations.language = language;
        whenListen<MemoryVerseState>(
          bloc,
          Stream<MemoryVerseState>.value(const MemoryStreakLoaded(
            currentStreak: 12,
            longestStreak: 30,
            totalPracticeDays: 40,
            freezeDaysAvailable: 0,
            freezeDaysUsed: 0,
            milestones: {},
          )),
          initialState: loaded,
        );
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(const MemoryVersesHomePage()));
        await tester.pumpAndSettle();

        expect(
            find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
        // One verse in the deck: singular line.
        expectWhole(
            tester,
            tr(TranslationKeys.memoryHeaderLineOne,
                {'streak': '12', 'count': '1'}));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('links open champions and statistics', (tester) async {
      whenListen<MemoryVerseState>(
        bloc,
        const Stream<MemoryVerseState>.empty(),
        initialState: loaded,
      );
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const MemoryVersesHomePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Champions'));
      await tester.pumpAndSettle();
      expect(visited.last, '/memory-verses/champions');
    });
  });

  group('Champions rows', () {
    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: streak per row', (tester) async {
        translations.language = language;
        whenListen<MemoryVerseState>(
          bloc,
          const Stream<MemoryVerseState>.empty(),
          initialState: const MemoryChampionsLeaderboardLoaded(
            period: 'all_time',
            userStats: UserMemoryStats(
              rank: 6,
              masterVerses: 1,
              currentStreak: 4,
              longestStreak: 4,
              totalPracticeDays: 12,
            ),
            leaderboard: [
              MemoryChampionEntry(
                  userId: 'a',
                  displayName: 'Anna George',
                  rank: 1,
                  masterVerses: 14,
                  longestStreak: 20,
                  totalPracticeDays: 40),
              MemoryChampionEntry(
                  userId: 'c',
                  displayName: 'Rahul',
                  rank: 5,
                  masterVerses: 6,
                  longestStreak: 7,
                  totalPracticeDays: 12),
            ],
          ),
        );
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(const MemoryChampionsPage()));
        await tester.pumpAndSettle();

        expectWhole(
            tester, tr(TranslationKeys.heatMapDayStreak, {'count': 20}));
        expectWhole(tester, tr(TranslationKeys.heatMapDayStreak, {'count': 7}));
        expect(find.byTooltip(tr(TranslationKeys.memoryScreensTopTen)),
            findsOneWidget);
        expectWhole(tester, tr(TranslationKeys.memoryScreensStatDayStreak));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Mode row', () {
    const mode = PracticeModeEntity(
      modeType: PracticeModeType.wordBank,
      timesPracticed: 3,
      successRate: 72,
      isFavorite: false,
    );

    for (final language in AppLanguage.values) {
      testWidgets('320 ${language.code}: lock reason and record shown whole',
          (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(host(Column(
          children: [
            PracticeModeRow(
              mode: mode,
              isTierLocked: true,
              onTap: () {},
              onLockedTap: () {},
            ),
            PracticeModeRow(
              mode: mode,
              isUnlockLimitReached: true,
              onTap: () {},
              onLockedTap: () {},
            ),
            PracticeModeRow(
              mode: mode,
              isRecommended: true,
              isFirstRecommended: true,
              onTap: () {},
              onInfoTap: () {},
            ),
          ],
        )));
        expectWhole(
          tester,
          '${tr(TranslationKeys.memoryScreensModeLockedUpgrade)} · '
          '${tr(TranslationKeys.memoryScreensTapToSeePlans)}',
        );
        expectWhole(
          tester,
          '${tr(TranslationKeys.memoryScreensDailyLimitReached)} · '
          '${tr(TranslationKeys.memoryScreensChooseUnlockedModes)}',
        );
        expectWhole(tester, tr(TranslationKeys.practiceModeWordBankDesc));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Results', () {
    PracticeResultParams params({bool showedAnswer = true}) =>
        PracticeResultParams(
          verseId: 'v1',
          verseReference: 'Philippians 4:13',
          verseText: 'I can do all things through him who strengthens me.',
          practiceMode: 'word_bank',
          timeSpentSeconds: 42,
          accuracyPercentage: 60,
          hintsUsed: 0,
          showedAnswer: showedAnswer,
          qualityRating: 3,
          confidenceRating: 3,
        );

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: stars, verse, penalty, actions',
          (tester) async {
        translations.language = language;
        whenListen<MemoryVerseState>(
          bloc,
          const Stream<MemoryVerseState>.empty(),
          initialState: const MemoryVerseInitial(),
        );
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(PracticeResultsPage(params: params())));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
        expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
        expect(find.text('I can do all things through him who strengthens me.'),
            findsOneWidget);
        expectWhole(
          tester,
          '${tr(TranslationKeys.practiceResultsAnswerShown)}: '
          '${tr(TranslationKeys.practiceResultsPenaltyApplied)}',
        );
        expectWhole(tester, tr(TranslationKeys.practiceResultsAccuracy));
        // Primary action keeps its full label.
        expectWhole(tester, tr(TranslationKeys.practiceResultsDone));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Verse row and flip card details', () {
    testWidgets('reviews, interval and milestone; no difficulty',
        (tester) async {
      await tester.pumpWidget(host(Column(
        children: [
          MemoryVerseListItem(
            verse: _verse('v1', 'John 3:16', dueInDays: 4),
            onTap: () {},
          ),
          MemoryVerseListItem(
            verse: _verse('v2', 'Joshua 1:9',
                dueInDays: 4, level: MasteryLevel.expert, easeFactor: 1.8),
            onTap: () {},
          ),
        ],
      )));
      expect(find.text('Easy'), findsNothing);
      expect(find.text('Hard'), findsNothing);
      expect(find.text('2 reviews'), findsNWidgets(2));
      expect(find.text('3 days'), findsNWidgets(2));
      expect(find.text('Review Milestone'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final language in AppLanguage.values) {
      testWidgets('320 ${language.code}: row meta and tag whole',
          (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(host(MemoryVerseListItem(
          verse: _verse('v2', 'Joshua 1:9',
              dueInDays: 4, level: MasteryLevel.expert),
          onTap: () {},
        )));
        expectWhole(tester, tr(TranslationKeys.memoryReviewMilestone));
        expectWhole(
            tester, tr(TranslationKeys.flipCardReviews, {'count': '2'}));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('flip card no longer shows the ease factor', (tester) async {
      await tester.pumpWidget(host(SizedBox(
        height: 560,
        child: VerseFlipCard(
          verse: _verse('v1', 'John 3:16', dueInDays: 0),
          isFlipped: true,
          onFlip: () {},
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Ease 2.5'), findsNothing);
      expect(find.text('2 reviews'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Add verse sheet', () {
    const suggestions = SuggestedVersesLoaded(
      verses: [
        SuggestedVerseEntity(
          id: 's1',
          reference: 'John 3:16',
          localizedReference: 'John 3:16',
          verseText: 'For God so loved the world.',
          book: 'John',
          chapter: 3,
          verseStart: 16,
          category: SuggestedVerseCategory.salvation,
        ),
      ],
      categories: SuggestedVerseCategory.values,
      total: 1,
    );

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: category tag and tiles whole',
          (tester) async {
        translations.language = language;
        whenListen<MemoryVerseState>(
          bloc,
          const Stream<MemoryVerseState>.empty(),
          initialState: suggestions,
        );
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => SuggestedVersesSheet.show(
                  context,
                  language: 'en',
                  onAddFromDaily: () {},
                  onAddManually: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        )));
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Chip + tag.
        expect(
            find.text(tr(TranslationKeys.categorySalvation)), findsNWidgets(2));
        for (final key in [
          TranslationKeys.memoryScreensTileDaily,
          TranslationKeys.memoryScreensTileDailyHint,
          TranslationKeys.memoryScreensTileSuggestedHint,
          TranslationKeys.memoryScreensTileCustomHint,
          TranslationKeys.addMemoryVerseTitle,
        ]) {
          expectWhole(tester, tr(key));
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Top bars', () {
    for (final language in AppLanguage.values) {
      testWidgets('320 ${language.code}: long titles are never cut',
          (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        final title = tr(TranslationKeys.practiceSelectionTitle);
        final practiceTitle = tr(TranslationKeys.practiceModeWordScramble);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            appBar: MemoryTopBar(
              title: title,
              subtitle: 'Philippians 4:13',
              actions: [
                MemoryBarAction(
                    icon: Icons.add, tooltip: 'add', onPressed: () {}),
              ],
            ),
            body: MemoryPracticeTopBar(
              title: practiceTitle,
              subtitle:
                  'Philippians 4:13 · ${tr(TranslationKeys.difficultyMedium)}',
              elapsedSeconds: 42,
            ),
          ),
        ));
        expectWhole(tester, title);
        expectWhole(tester, practiceTitle);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Add verse dialog', () {
    ({String reference, String text, String language})? submitted;

    Widget dialogHost({bool dark = true}) =>
        BlocProvider<MemoryVerseBloc>.value(
          value: bloc,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => AddManualVerseDialog.show(
                      context,
                      onSubmit: ({
                        required String verseReference,
                        required String verseText,
                        required String language,
                      }) =>
                          submitted = (
                        reference: verseReference,
                        text: verseText,
                        language: language,
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

    setUp(() {
      submitted = null;
      whenListen<MemoryVerseState>(
        bloc,
        const Stream<MemoryVerseState>.empty(),
        initialState: const MemoryVerseInitial(),
      );
    });

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: labels above filled fields',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(dialogHost(dark: dark));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text(tr(TranslationKeys.addVerseTitle)), findsNWidgets(2));
        expect(find.text(tr(TranslationKeys.memoryScreensAddVerseSubtitle)),
            findsOneWidget);
        expect(find.text(tr(TranslationKeys.memoryScreensChooseBook)),
            findsOneWidget);
        expect(find.text(tr(TranslationKeys.addVerseChapter)), findsOneWidget);
        expect(find.text(tr(TranslationKeys.addVerseTo)), findsOneWidget);
        expect(
            find.byType(MemorySegmentedControl<VerseLanguage>), findsOneWidget);
        // Fetch stays disabled until the reference is complete.
        final fetch = tester.widget<MemoryActionPill>(find.byWidgetPredicate(
            (w) =>
                w is MemoryActionPill &&
                w.label == tr(TranslationKeys.addVerseFetch)));
        expect(fetch.onPressed, isNull);
        expect(tester.takeException(), isNull);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow, actions whole',
          (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(dialogHost());
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expectWhole(tester, tr(TranslationKeys.addVerseCancel));
        expectWhole(tester, tr(TranslationKeys.addVerseTo));
        expectWhole(tester, tr(TranslationKeys.addVerseFetch));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Add without a reference shows the required message',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(dialogHost());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final add = find.byWidgetPredicate((w) =>
          w is MemoryPrimaryPill &&
          w.label == tr(TranslationKeys.addVerseTitle));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
      expect(find.text(tr(TranslationKeys.addVerseSelectRequired)),
          findsOneWidget);
      expect(submitted, isNull);
    });

    testWidgets('pick Genesis 1:1, fetch, type and Add submits the verse',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(dialogHost());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Genesis').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<int?>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').last);
      await tester.pumpAndSettle();

      final fetch = find.byWidgetPredicate((w) =>
          w is MemoryActionPill &&
          w.label == tr(TranslationKeys.addVerseFetch));
      await tester.ensureVisible(fetch);
      await tester.tap(fetch);
      await tester.pump();
      verify(() => bloc.add(const FetchVerseTextRequested(
            book: 'Genesis',
            chapter: 1,
            verseStart: 1,
            language: 'en',
          ))).called(1);

      await tester.enterText(
          find.byType(TextField), 'In the beginning God created.');
      final add = find.byWidgetPredicate((w) =>
          w is MemoryPrimaryPill &&
          w.label == tr(TranslationKeys.addVerseTitle));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();

      expect(submitted?.reference, 'Genesis 1:1');
      expect(submitted?.text, 'In the beginning God created.');
      expect(submitted?.language, 'en');
    });
  });
}
