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
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
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

class _MockGamificationBloc
    extends MockBloc<GamificationEvent, GamificationState>
    implements GamificationBloc {}

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
        expect(find.text('My Progress'), findsOneWidget);
        expect(
            find.text('${level.title} · Level ${level.level}'), findsOneWidget);
        expect(find.text('1,720 XP'), findsOneWidget);
        expect(find.text('4'), findsWidgets);
        expect(find.text('31'), findsOneWidget);
        expect(find.text('ACHIEVEMENTS · 4 OF 6'), findsOneWidget);
        verify(() => bloc.add(const LoadGamificationStats())).called(1);
      });
    }

    for (final language in AppLanguage.values) {
      testWidgets('320x640 ${language.code}: no overflow', (tester) async {
        translations.language = language;
        whenListen(bloc, const Stream<GamificationState>.empty(),
            initialState: loaded(language.code));
        useSurface(tester, const Size(320, 640));
        await tester.pumpWidget(page(true));
        await tester.pumpAndSettle();
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -400));
          await tester.pumpAndSettle();
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

      await tester.tap(find.text('Achievement number 5'));
      await tester.pumpAndSettle();
      expect(find.text('Do the thing 5 times'), findsOneWidget);
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

        expect(find.text('Reflection Journal'), findsOneWidget);
        expect(find.text('2 reflections'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Yesterday'), findsOneWidget);
        expect(find.text('8 min'), findsOneWidget);
        expect(find.textContaining('Forgiving my brother'), findsOneWidget);
        expect(find.textContaining('· Standard'), findsOneWidget);

        // Expanding shows the actions.
        await tester.tap(find.text('Today'));
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
      expect(find.text('Start a Study'), findsOneWidget);
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
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
