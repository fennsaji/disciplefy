import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_streak.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_event.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_state.dart';
import 'package:disciplefy_bible_study/features/gamification/domain/entities/achievement.dart';
import 'package:disciplefy_bible_study/features/gamification/domain/entities/user_level.dart';
import 'package:disciplefy_bible_study/features/gamification/domain/entities/user_stats.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_state.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/pages/stats_dashboard_page.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/reflection_response.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/repositories/reflections_repository.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/pages/reflection_journal_screen.dart';

import '../../helpers/welcome_test_harness.dart';
import 'text_fit.dart';

class _MockGamificationBloc
    extends MockBloc<GamificationEvent, GamificationState>
    implements GamificationBloc {}

class _MockDailyVerseBloc extends MockBloc<DailyVerseEvent, DailyVerseState>
    implements DailyVerseBloc {}

class _FakeReflections extends Fake implements ReflectionsRepository {
  final List<ReflectionSession> reflections;

  _FakeReflections(this.reflections);

  @override
  Future<ReflectionListResult> listReflections({
    int page = 1,
    int perPage = 20,
    StudyMode? studyMode,
  }) async =>
      ReflectionListResult(
        reflections: reflections,
        total: reflections.length,
        page: 1,
        perPage: 20,
        hasMore: false,
      );

  @override
  Future<ReflectionStats> getReflectionStats() async => ReflectionStats(
        totalReflections: reflections.length,
        totalTimeSpentSeconds: 1260,
        reflectionsByMode: const {},
        mostCommonLifeAreas: const ['family', 'work'],
      );
}

class _FakeAuthStateProvider extends Fake
    with ChangeNotifier
    implements AuthStateProvider {
  @override
  String get profileBasedDisplayName => 'Fenn';
  @override
  String? get profilePictureUrl => null;
}

void main() {
  late FakeTranslationService translations;

  setUp(() {
    translations = FakeTranslationService();
    sl.registerSingleton<TranslationService>(translations);
  });

  tearDown(() async => sl.reset());

  Widget app(Widget screen,
      {required bool dark, Widget Function(Widget)? wrap}) {
    final router = GoRouter(
      initialLocation: '/page',
      routes: [
        GoRoute(path: '/page', builder: (_, __) => screen),
        GoRoute(path: '/', builder: (_, __) => const Text('stub:/')),
      ],
    );
    final materialApp = MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(translations.language.code),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
    return wrap == null ? materialApp : wrap(materialApp);
  }

  group('StatsDashboardPage', () {
    late _MockGamificationBloc bloc;

    GamificationState loaded(String languageCode) => GamificationState(
          status: GamificationStatus.loaded,
          languageCode: languageCode,
          level: UserLevel.fromXp(1720, languageCode),
          stats: const UserStats(
            totalXp: 1720,
            leaderboardRank: 12,
            studyCurrentStreak: 4,
            studyLongestStreak: 9,
            verseCurrentStreak: 2,
            verseLongestStreak: 6,
            totalStudiesCompleted: 31,
            totalTimeSpentSeconds: 9000,
            totalMemoryVerses: 4,
            totalVoiceSessions: 3,
            totalSavedGuides: 7,
            totalStudyDays: 20,
          ),
          achievements: [
            for (var i = 0; i < 6; i++)
              Achievement(
                id: 'a$i',
                name: 'Achievement number $i',
                description: 'Do the thing $i times',
                icon: '🔥',
                xpReward: 50,
                category: AchievementCategory.values[i % 5],
                threshold: 10,
                isUnlocked: i < 4,
              ),
          ],
        );

    setUp(() {
      bloc = _MockGamificationBloc();
      sl.registerSingleton<AuthStateProvider>(_FakeAuthStateProvider());
    });

    Widget page(bool dark) => app(
          const StatsDashboardPage(),
          dark: dark,
          wrap: (child) =>
              BlocProvider<GamificationBloc>.value(value: bloc, child: child),
        );

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: level card, stats, badges',
          (tester) async {
        whenListen(bloc, const Stream<GamificationState>.empty(),
            initialState: loaded('en'));
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(page(dark));
        await tester.pumpAndSettle();

        final level = UserLevel.fromXp(1720, 'en');
        expect(find.text('My progress'), findsOneWidget);
        expect(
            find.text('${level.title} · Level ${level.level}'), findsOneWidget);
        expect(find.text('1,720 XP'), findsOneWidget);
        expect(find.text('4'), findsWidgets);
        expect(find.text('31'), findsOneWidget);
        expect(find.text('ACHIEVEMENTS · 4 OF 6'), findsOneWidget);
        verify(() => bloc.add(const LoadGamificationStats())).called(1);
      });
    }

    Future<Set<String>> allTexts(WidgetTester tester) async {
      final seen = <String>{};
      void collect() {
        for (final e in find.byType(Text).evaluate()) {
          final data = (e.widget as Text).data;
          if (data != null) seen.add(data);
        }
      }

      collect();
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        collect();
      }
      return seen;
    }

    testWidgets(
        'one streak: no separate study or verse streak rows, personal best '
        'is the daily streak\'s best', (tester) async {
      whenListen(bloc, const Stream<GamificationState>.empty(),
          initialState: loaded('en'));
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();

      final seen = await allTexts(tester);
      expect(seen, contains('Personal best'));
      expect(seen, contains('6 days'));
      expect(seen, isNot(contains('Study')));
      expect(seen, isNot(contains('Verse')));
      // The study-streak numbers (4 current, 9 best) are not shown as a streak.
      expect(seen, isNot(contains('9 days')));
      expect(seen, isNot(contains('4 days')));
    });

    testWidgets(
        'the live daily streak from the verse bloc drives the tile and the '
        'personal best', (tester) async {
      whenListen(bloc, const Stream<GamificationState>.empty(),
          initialState: loaded('en'));
      final verseBloc = _MockDailyVerseBloc();
      whenListen<DailyVerseState>(
          verseBloc, const Stream<DailyVerseState>.empty(),
          initialState: DailyVerseLoaded(
            verse: DailyVerseEntity(
              id: 'v',
              reference: 'John 3:16',
              referenceTranslations: const ReferenceTranslations(
                  en: 'John 3:16', hi: 'John 3:16', ml: 'John 3:16'),
              translations: const DailyVerseTranslations(
                  esv: 'For God so loved', hindi: 'x', malayalam: 'y'),
              date: DateTime(2026, 10, 6),
            ),
            currentLanguage: VerseLanguage.english,
            preferredLanguage: VerseLanguage.english,
            streak: DailyVerseStreak(
              userId: 'u',
              currentStreak: 8,
              longestStreak: 7,
              totalViews: 8,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ));
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(
        const StatsDashboardPage(),
        dark: false,
        wrap: (child) => MultiBlocProvider(providers: [
          BlocProvider<GamificationBloc>.value(value: bloc),
          BlocProvider<DailyVerseBloc>.value(value: verseBloc),
        ], child: child),
      ));
      await tester.pumpAndSettle();

      expect(find.text('8'), findsOneWidget);
      final seen = await allTexts(tester);
      // Best is never below the current run.
      expect(seen, contains('8 days'));
    });

    testWidgets('restores profile header, XP %, categories and details',
        (tester) async {
      whenListen(bloc, const Stream<GamificationState>.empty(),
          initialState: loaded('en'));
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();

      final level = UserLevel.fromXp(1720, 'en');
      // Header: name, avatar initial, level badge, total XP, rank.
      expect(find.text('Fenn'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      expect(find.text('${level.level}'), findsWidgets);
      expect(find.text('1,720 XP total'), findsOneWidget);
      expect(find.text('#12'), findsWidgets);
      // Level card percentage.
      expect(find.text('${(level.progressToNextLevel * 100).round()}%'),
          findsOneWidget);

      final seen = <String>{};
      void collect() {
        for (final e in find.byType(Text).evaluate()) {
          final data = (e.widget as Text).data;
          if (data != null) seen.add(data);
        }
      }

      collect();
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        collect();
      }
      // Category headings, descriptions, progress and XP reward.
      expect(seen, contains('📚 Study Guides'));
      expect(seen, contains('Do the thing 0 times'));
      expect(seen, contains('Do the thing 5 times'));
      // Locked achievements show "current/threshold".
      expect(seen.where((t) => RegExp(r'^\d+/10$').hasMatch(t)), isNotEmpty);
    });

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        whenListen(bloc, const Stream<GamificationState>.empty(),
            initialState: loaded(language.code));
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(page(true));
        await tester.pumpAndSettle();
        expectNoTruncatedText(tester);
        for (var i = 0; i < 10; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -400));
          await tester.pumpAndSettle();
          expectNoTruncatedText(tester);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tapping a badge opens its details', (tester) async {
      whenListen(bloc, const Stream<GamificationState>.empty(),
          initialState: loaded('en'));
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Achievement number 5'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Achievement number 5'));
      await tester.pumpAndSettle();
      // Row and sheet both show the description now.
      expect(find.text('Do the thing 5 times'), findsNWidgets(2));
      expect(find.text('Locked'), findsOneWidget);
    });
  });

  group('ReflectionJournalScreen', () {
    final now = DateTime.now();
    final reflections = [
      ReflectionSession(
        id: 'r1',
        studyGuideId: 'g1',
        studyMode: StudyMode.standard,
        timeSpentSeconds: 480,
        completedAt: now,
        createdAt: now,
        responses: const [
          ReflectionResponse(
            interactionType: ReflectionInteractionType.yesNo,
            cardIndex: 0,
            sectionTitle: 'Summary',
            value: true,
            additionalText:
                'Forgiving my brother is harder than I thought but Christ forgave me first.',
          ),
          ReflectionResponse(
            interactionType: ReflectionInteractionType.multiSelect,
            cardIndex: 1,
            sectionTitle: 'Life areas',
            value: ['family', 'work'],
          ),
        ],
      ),
      ReflectionSession(
        id: 'r2',
        studyGuideId: 'g2',
        studyMode: StudyMode.quick,
        timeSpentSeconds: 180,
        completedAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
        responses: const [
          ReflectionResponse(
            interactionType: ReflectionInteractionType.tapSelection,
            cardIndex: 0,
            sectionTitle: 'Interpretation',
            value: 'His strength, not my own willpower.',
          ),
        ],
      ),
    ];

    for (final dark in [true, false]) {
      testWidgets('${dark ? 'dark' : 'light'}: cards with excerpt and meta',
          (tester) async {
        useSurface(tester, const Size(390, 844));
        await tester.pumpWidget(app(
          ReflectionJournalScreen(repository: _FakeReflections(reflections)),
          dark: dark,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Reflection journal'), findsOneWidget);
        expect(find.text('2 reflections'), findsOneWidget);
        expect(find.text('YOUR JOURNEY'), findsOneWidget);
        // Day group headings, and the mode (with its icon) on each card.
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Yesterday'), findsOneWidget);
        expect(find.text('📖 Standard Study'), findsOneWidget);
        expect(find.text('⚡ Quick Read'), findsOneWidget);
        expect(find.text('8 min'), findsOneWidget);
        expect(find.textContaining('Forgiving my brother'), findsOneWidget);

        // Expanding shows the actions.
        await tester.tap(find.text('📖 Standard Study'));
        await tester.pumpAndSettle();
        expect(find.text('View Study'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });
    }

    testWidgets('empty state', (tester) async {
      useSurface(tester, const Size(390, 844));
      await tester.pumpWidget(app(
        ReflectionJournalScreen(repository: _FakeReflections(const [])),
        dark: true,
      ));
      await tester.pumpAndSettle();
      expect(find.text('No reflections yet'), findsOneWidget);
      expect(find.text('Start a study'), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(app(
          ReflectionJournalScreen(repository: _FakeReflections(reflections)),
          dark: false,
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(InkWell).at(0), warnIfMissed: false);
        await tester.pumpAndSettle();
        expectNoTruncatedText(tester);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expectNoTruncatedText(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
