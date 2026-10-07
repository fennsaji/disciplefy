import 'dart:math' as math;
import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
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
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/memory_champions_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/memory_stats_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/memory_verses_home_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/pages/practice_results_page.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/memory_ui/memory_ui.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/widgets/practice_mode_row.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';

import '../../../helpers/welcome_test_harness.dart';

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
  String language = 'en',
  String text =
      'I can do all things through him who strengthens me, and more words '
          'so the text wraps onto a second line.',
}) =>
    MemoryVerseEntity(
      id: id,
      verseReference: reference,
      verseText: text,
      language: language,
      sourceType: 'manual',
      easeFactor: 2.5,
      intervalDays: 3,
      repetitions: 2,
      nextReviewDate:
          DateTime(_today.year, _today.month, _today.day + dueInDays, 9),
      addedDate: DateTime(2026, 9, 2),
      totalReviews: 4,
      createdAt: DateTime(2026, 9, 2),
      masteryLevel: level,
    );

final _loaded = DueVersesLoaded(
  verses: [
    _verse('v1', 'Philippians 4:13', dueInDays: 0),
    _verse('v2', 'Joshua 1:9', dueInDays: 3, level: MasteryLevel.intermediate),
    _verse('v3', 'भजन संहिता 119:105',
        dueInDays: 1,
        level: MasteryLevel.master,
        language: 'hi',
        text:
            'तेरा वचन मेरे पाँव के लिये दीपक, और मेरे मार्ग के लिये उजियाला है।'),
  ],
  statistics: const ReviewStatisticsEntity(
    totalVerses: 3,
    dueVerses: 1,
    reviewedToday: 2,
    upcomingReviews: 2,
    masteredVerses: 1,
    fullyMasteredVerses: 1,
  ),
  hasMore: false,
);

void main() {
  late FakeTranslationService translations;
  late _MockMemoryVerseBloc bloc;
  late _MockGamificationBloc gamification;
  late _MockConnectivityBloc connectivity;
  late List<String> visited;

  setUpAll(() {
    registerFallbackValue(const LoadMemoryStatisticsEvent());
  });

  setUp(() {
    translations = FakeTranslationService();
    bloc = _MockMemoryVerseBloc();
    gamification = _MockGamificationBloc();
    connectivity = _MockConnectivityBloc();
    visited = [];
    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<WalkthroughRepository>(_SeenWalkthroughs());
    sl.registerSingleton<GamificationBloc>(gamification);
    // Stats and champions resolve their own bloc from the container.
    sl.registerFactory<MemoryVerseBloc>(() => bloc);
    whenListen<ConnectivityState>(
      connectivity,
      const Stream<ConnectivityState>.empty(),
      initialState: ConnectivityOnline(),
    );
  });

  tearDown(() async => sl.reset());

  Widget app(Widget page, {required bool dark, String path = '/page'}) {
    GoRoute stub(String route) => GoRoute(
          path: route,
          builder: (_, state) {
            visited.add(state.uri.toString());
            return Scaffold(body: Text('stub:$route'));
          },
        );
    final router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(path: path, builder: (_, __) => page),
        stub('/memory-verses/practice/:id'),
        stub('/memory-verses/review/:id'),
        stub('/memory-verses/practice/word-bank/:id'),
        stub('/pricing'),
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

  void stubHome() {
    whenListen<MemoryVerseState>(
      bloc,
      Stream<MemoryVerseState>.fromIterable(const [
        MemoryStreakLoaded(
          currentStreak: 4,
          longestStreak: 9,
          totalPracticeDays: 12,
          freezeDaysAvailable: 0,
          freezeDaysUsed: 0,
          milestones: {},
        ),
        DailyGoalLoaded(
          targetReviews: 5,
          completedReviews: 2,
          targetNewVerses: 1,
          addedNewVerses: 0,
          goalAchieved: false,
          bonusXpAwarded: 0,
        ),
      ]),
      initialState: _loaded,
    );
  }

  group('Memory verses home', () {
    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: summary, sections and rows',
          (tester) async {
        stubHome();
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(const MemoryVersesHomePage(), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('Memory Verses'), findsWidgets);
        expect(find.text('1 due today'), findsOneWidget);
        // Streak and verse count on one line.
        expect(find.text('4-day streak · 3 verses'), findsOneWidget);
        expect(find.text('2 of 5'), findsOneWidget);
        expect(find.textContaining('(1)'), findsOneWidget);
        expect(find.text('COMING UP'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Philippians 4:13'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('Philippians 4:13'), findsOneWidget);
        expect(find.text('Due'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Tomorrow'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('In 3 days'), findsOneWidget);
        expect(find.text('Tomorrow'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        stubHome();
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(const MemoryVersesHomePage(), dark: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('language chip reloads the deck in that language',
        (tester) async {
      stubHome();
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const MemoryVersesHomePage(), dark: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text(VerseLanguage.hindi.displayName));
      await tester.pump();

      verify(() => bloc.add(const LoadDueVerses(language: 'hi'))).called(1);
    });

    testWidgets('tapping a verse opens its practice mode picker',
        (tester) async {
      stubHome();
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const MemoryVersesHomePage(), dark: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Joshua 1:9'));
      await tester.pumpAndSettle();

      expect(visited, contains('/memory-verses/practice/v2'));
    });

    testWidgets('add opens the add-verse sheet and loads suggestions',
        (tester) async {
      stubHome();
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const MemoryVersesHomePage(), dark: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add verse'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Daily verse'), findsOneWidget);
      expect(find.text('Suggested'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      verify(() => bloc.add(any(that: isA<LoadSuggestedVersesEvent>())))
          .called(1);
    });
  });

  group('Add verse sheet', () {
    for (final language in AppLanguage.values) {
      for (final dark in [true, false]) {
        testWidgets(
            '320x640 ${language.code} ${dark ? 'dark' : 'light'}: '
            'tiles and chips fit', (tester) async {
          translations.language = language;
          stubHome();
          useSurface(tester, const Size(320, 640));
          await tester
              .pumpWidget(app(const MemoryVersesHomePage(), dark: dark));
          await tester.pumpAndSettle();

          await tester.tap(find.byIcon(Icons.add));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
          expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Practice results', () {
    PracticeResultParams params() => const PracticeResultParams(
          verseId: 'v1',
          verseReference: 'Philippians 4:13',
          verseText: 'I can do all things through him who strengthens me.',
          practiceMode: 'word_bank',
          timeSpentSeconds: 42,
          accuracyPercentage: 92,
          hintsUsed: 1,
          showedAnswer: false,
          qualityRating: 4,
          confidenceRating: 4,
          blankComparisons: [
            BlankComparison(
              expected: 'I',
              userInput: 'I',
              isCorrect: true,
              matchType: MatchType.correct,
              score: 1,
            ),
            BlankComparison(
              expected: 'him',
              userInput: 'Him',
              isCorrect: false,
            ),
            BlankComparison(
              expected: 'strengthens',
              userInput: '(missing)',
              isCorrect: false,
            ),
          ],
        );

    void stubSubmitted() {
      whenListen<MemoryVerseState>(
        bloc,
        Stream<MemoryVerseState>.value(PracticeSessionSubmitted(
          verse: _verse('v1', 'Philippians 4:13', dueInDays: 6),
          message: 'ok',
          xpEarned: 10,
        )),
        initialState: const MemoryVerseInitial(),
      );
    }

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: ring, tiles, answer diff',
          (tester) async {
        stubSubmitted();
        useSurface(tester, const Size(390, 844));
        await tester
            .pumpWidget(app(PracticeResultsPage(params: params()), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('92%'), findsOneWidget);
        expect(find.text('Good recall'), findsOneWidget);
        expect(find.text('Next review in 6 days'), findsOneWidget);
        expect(find.text('0:42'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('practice_results_answer')))
              .textSpan!
              .toPlainText(),
          'I Him',
        );
        expect(find.textContaining('Missed:'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        stubSubmitted();
        useSurface(tester, const Size(320, 640));
        await tester
            .pumpWidget(app(PracticeResultsPage(params: params()), dark: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('accuracy ring is a progress arc from 12 o\'clock',
        (tester) async {
      stubSubmitted();
      useSurface(tester, const Size(390, 844));
      await tester
          .pumpWidget(app(PracticeResultsPage(params: params()), dark: true));
      await tester.pumpAndSettle();

      final arc = find.byKey(const Key('practice_results_accuracy_arc'));
      final painter =
          tester.widget<CustomPaint>(arc).painter! as AccuracyArcPainter;
      expect(painter.progress, closeTo(0.92, 0.0001));
      // Full track, then the 92% arc starting at the top.
      expect(
        tester.renderObject(arc),
        paints
          ..arc(startAngle: 0, sweepAngle: 2 * math.pi)
          ..arc(
            startAngle: -math.pi / 2,
            sweepAngle: 2 * math.pi * 0.92,
            strokeCap: StrokeCap.round,
          ),
      );
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
    });

    testWidgets('accuracy arc sweeps once and then stops', (tester) async {
      stubSubmitted();
      useSurface(tester, const Size(390, 844));
      await tester
          .pumpWidget(app(PracticeResultsPage(params: params()), dark: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final arc = find.byKey(const Key('practice_results_accuracy_arc'));
      double progress() =>
          (tester.widget<CustomPaint>(arc).painter! as AccuracyArcPainter)
              .progress;
      expect(progress(), lessThan(0.92));
      await tester.pumpAndSettle();
      expect(progress(), closeTo(0.92, 0.0001));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('next review ignores a previous session\'s stale result',
        (tester) async {
      // The bloc is shared, so it can still hold the last session's result
      // when this page opens; only the answer to this submission counts.
      whenListen<MemoryVerseState>(
        bloc,
        const Stream<MemoryVerseState>.empty(),
        initialState: PracticeSessionSubmitted(
          verse: _verse('v1', 'Philippians 4:13', dueInDays: 9),
          message: 'old',
          xpEarned: 5,
        ),
      );
      useSurface(tester, const Size(390, 844));
      await tester
          .pumpWidget(app(PracticeResultsPage(params: params()), dark: true));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('practice_results_next_review')), findsNothing);
    });

    testWidgets('next review stays after later bloc states', (tester) async {
      whenListen<MemoryVerseState>(
        bloc,
        Stream<MemoryVerseState>.fromIterable([
          PracticeSessionSubmitted(
            verse: _verse('v1', 'Philippians 4:13', dueInDays: 1),
            message: 'ok',
            xpEarned: 10,
          ),
          _loaded,
        ]),
        initialState: const MemoryVerseInitial(),
      );
      useSurface(tester, const Size(390, 844));
      await tester
          .pumpWidget(app(PracticeResultsPage(params: params()), dark: true));
      await tester.pumpAndSettle();
      expect(find.text('Next review tomorrow'), findsOneWidget);
    });

    testWidgets('phrase answers read as one single-spaced sentence',
        (tester) async {
      stubSubmitted();
      useSurface(tester, const Size(390, 844));
      const phrases = [
        'Trust in the LORD ',
        ' with all  thine heart;',
        'and lean not\nunto',
        'thine own understanding.',
      ];
      await tester.pumpWidget(app(
        PracticeResultsPage(
          params: PracticeResultParams(
            verseId: 'v1',
            verseReference: 'Proverbs 3:5',
            verseText: 'Trust in the LORD with all thine heart; and lean not '
                'unto thine own understanding.',
            practiceMode: 'word_scramble',
            timeSpentSeconds: 23,
            accuracyPercentage: 100,
            hintsUsed: 0,
            showedAnswer: false,
            qualityRating: 5,
            confidenceRating: 5,
            blankComparisons: [
              for (final p in phrases)
                BlankComparison(expected: p, userInput: p, isCorrect: true),
            ],
          ),
        ),
        dark: true,
      ));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const Key('practice_results_answer')))
            .textSpan!
            .toPlainText(),
        'Trust in the LORD with all thine heart; and lean not unto thine '
        'own understanding.',
      );
    });

    testWidgets('submits the session once and Done returns to the picker',
        (tester) async {
      stubSubmitted();
      useSurface(tester, const Size(390, 844));
      await tester
          .pumpWidget(app(PracticeResultsPage(params: params()), dark: true));
      await tester.pumpAndSettle();

      verify(() => bloc.add(any(that: isA<SubmitPracticeSessionEvent>())))
          .called(1);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(visited.last, '/memory-verses/practice/v1?lastMode=word_bank');
    });

    testWidgets('Practice again reopens the same mode', (tester) async {
      stubSubmitted();
      useSurface(tester, const Size(390, 844));
      await tester
          .pumpWidget(app(PracticeResultsPage(params: params()), dark: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Practice Again'));
      await tester.pumpAndSettle();
      expect(visited.last, '/memory-verses/practice/word-bank/v1');
    });
  });

  group('Statistics', () {
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
      'mastery_distribution': {
        'beginner': 1,
        'intermediate': 1,
        'advanced': 1,
        'expert': 0,
        'master': 1,
      },
      'practice_modes': [
        {'mode_type': 'flip_card', 'success_rate': 88, 'times_practiced': 6},
        {'mode_type': 'type_it_out', 'success_rate': 61, 'times_practiced': 2},
      ],
    };

    void stubStats() {
      whenListen<MemoryVerseState>(
        bloc,
        const Stream<MemoryVerseState>.empty(),
        initialState: MemoryStatisticsLoaded(statistics: stats),
      );
    }

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: tiles, activity, mastery',
          (tester) async {
        stubStats();
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(const MemoryStatsPage(), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('27'), findsOneWidget);
        expect(find.text('Total Reviews'), findsOneWidget);
        expect(find.text('Practice Activity'), findsOneWidget);
        expect(find.text('88%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        stubStats();
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(const MemoryStatsPage(), dark: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('loads statistics on open', (tester) async {
      stubStats();
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const MemoryStatsPage(), dark: true));
      await tester.pumpAndSettle();
      verify(() => bloc.add(const LoadMemoryStatisticsEvent())).called(1);
    });
  });

  group('Champions', () {
    const leaderboard = MemoryChampionsLeaderboardLoaded(
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
            userId: 'b',
            displayName: 'Joel Mathew',
            rank: 2,
            masterVerses: 11,
            longestStreak: 9,
            totalPracticeDays: 30),
        MemoryChampionEntry(
            userId: 'c',
            displayName: 'Rahul Varghese with a very long display name',
            rank: 4,
            masterVerses: 6,
            longestStreak: 5,
            totalPracticeDays: 12),
      ],
    );

    void stubChampions() {
      whenListen<MemoryVerseState>(
        bloc,
        const Stream<MemoryVerseState>.empty(),
        initialState: leaderboard,
      );
    }

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: rank card and rows',
          (tester) async {
        stubChampions();
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(const MemoryChampionsPage(), dark: dark));
        await tester.pumpAndSettle();

        expect(find.text('#6'), findsOneWidget);
        expect(find.text('YOUR RANK'), findsOneWidget);
        expect(find.text('14 mastered'), findsOneWidget);
        expect(find.text('Anna George'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        stubChampions();
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(const MemoryChampionsPage(), dark: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('opens on all time and switching period reloads',
        (tester) async {
      stubChampions();
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(const MemoryChampionsPage(), dark: true));
      await tester.pumpAndSettle();

      verify(() => bloc.add(
              const LoadMemoryChampionsLeaderboardEvent(period: 'all_time')))
          .called(1);

      await tester.tap(find.text('Weekly'));
      await tester.pump();
      verify(() => bloc
              .add(const LoadMemoryChampionsLeaderboardEvent(period: 'weekly')))
          .called(1);
    });
  });

  group('Practice mode row', () {
    const mode = PracticeModeEntity(
      modeType: PracticeModeType.wordBank,
      timesPracticed: 3,
      successRate: 72,
      isFavorite: false,
    );

    Widget host(Widget child, {bool dark = true}) => MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(body: ListView(children: [child])),
        );

    testWidgets('available row opens the mode', (tester) async {
      var opened = 0;
      await tester.pumpWidget(host(PracticeModeRow(
        mode: mode,
        isRecommended: true,
        onTap: () => opened++,
      )));
      await tester.tap(find.text('Word Bank'));
      expect(opened, 1);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('locked row routes taps to the lock handler', (tester) async {
      var opened = 0;
      var locked = 0;
      await tester.pumpWidget(host(
        PracticeModeRow(
          mode: mode,
          isTierLocked: true,
          onTap: () => opened++,
          onLockedTap: () => locked++,
        ),
        dark: false,
      ));
      await tester.tap(find.text('Word Bank'));
      expect(opened, 0);
      expect(locked, 1);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      testWidgets('320 wide ${language.code}: no overflow', (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(host(PracticeModeRow(
          mode: mode,
          isRecommended: true,
          isFirstRecommended: true,
          onTap: () {},
          onInfoTap: () {},
        )));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Shared practice widgets', () {
    Widget scaffoldHost({required bool dark, required VoidCallback onCheck}) =>
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: MemoryPracticeScaffold(
            title: 'Fill in the Blanks',
            subtitle: 'Philippians 4:13 · Medium',
            elapsedSeconds: 42,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MemoryAnswerCard(
                  label: 'Your answer',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      MemoryTokenChip(
                          label: 'I', state: MemoryTokenState.selected),
                      MemoryTokenChip(
                          label: 'പ്രവർത്തിക്കുന്നവൻ',
                          state: MemoryTokenState.correct),
                      MemoryTokenChip(
                          label: 'him', state: MemoryTokenState.wrong),
                      MemoryTokenChip(
                          label: '',
                          state: MemoryTokenState.placeholder,
                          minWidth: 70),
                    ],
                  ),
                ),
                const MemoryDropZone(label: 'Drop here'),
                const MemoryStepIndicator(
                    steps: ['Read', 'Speak', 'Results'], currentIndex: 1),
              ],
            ),
            bottomBar: MemoryActionBar(
              secondary: [
                MemoryActionPill(
                    label: 'दिखाएँ उत्तर',
                    icon: Icons.visibility_outlined,
                    onPressed: () {}),
                MemoryActionPill(
                    label: 'സൂചന ഉപയോഗിക്കുക',
                    icon: Icons.lightbulb_outline,
                    onPressed: () {}),
              ],
              primary: MemoryPrimaryPill(
                label: 'Check',
                icon: Icons.check,
                onPressed: onCheck,
              ),
            ),
          ),
        );

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'} 320x640: no overflow',
          (tester) async {
        useSurface(tester, const Size(320, 640));
        var checks = 0;
        await tester
            .pumpWidget(scaffoldHost(dark: dark, onCheck: () => checks++));
        expect(tester.takeException(), isNull);
        expect(find.text('0:42'), findsOneWidget);
        // Narrow screen: secondary pills collapse to icon-only circles.
        expect(find.text('दिखाएँ उत्तर'), findsNothing);
        await tester.tap(find.text('Check'));
        expect(checks, 1);
      });
    }

    testWidgets('390 wide: secondary pills show labels that fit whole',
        (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MemoryActionBar(
            secondary: [
              MemoryActionPill(
                  label: 'Hint',
                  icon: Icons.lightbulb_outline,
                  onPressed: () {}),
            ],
            primary: MemoryPrimaryPill(label: 'Check', onPressed: () {}),
          ),
        ),
      ));
      expect(find.text('Hint'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('segmented control reports the tapped value', (tester) async {
      String? picked;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MemorySegmentedControl<String>(
            segments: const [
              MemorySegment(value: 'easy', label: 'Easy'),
              MemorySegment(value: 'hard', label: 'Hard'),
            ],
            selected: 'easy',
            onChanged: (v) => picked = v,
          ),
        ),
      ));
      await tester.tap(find.text('Hard'));
      expect(picked, 'hard');
    });
  });
}
