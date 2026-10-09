import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_service.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/services/guest_path_enrollment.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/features/auth/data/services/guest_session_service.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/daily_verse/domain/entities/daily_verse_entity.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_event.dart';
import 'package:disciplefy_bible_study/features/daily_verse/presentation/bloc/daily_verse_state.dart';
import 'package:disciplefy_bible_study/features/home/domain/entities/active_path_summary.dart';
import 'package:disciplefy_bible_study/features/home/domain/utils/lesson_launch_from_summary.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_bloc.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_event.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_state.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/new_for_you_cubit.dart';
import 'package:disciplefy_bible_study/features/home/presentation/pages/home_screen.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/home_community_section.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/home_sections.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/choose_first_path_card.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/home_path_section.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/home_today_layout.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/memory_pill_badge.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/new_for_you_banner.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/save_progress_row.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/memory_verse_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/entities/review_statistics_entity.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:disciplefy_bible_study/features/onboarding/presentation/bloc/first_run_cubit.dart';
import 'package:disciplefy_bible_study/features/personalization/presentation/widgets/personalization_prompt_card.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/subscription_state.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/usage_stats_bloc.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/usage_stats_event.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/bloc/usage_stats_state.dart';
import 'package:disciplefy_bible_study/features/subscription/presentation/services/usage_threshold_service.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_event.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/user_profile/data/services/user_profile_service.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/walkthrough_tooltip.dart';

import '../../../../helpers/fit_matrix.dart';
import '../../../../helpers/text_fit.dart';
import '../../../../helpers/welcome_test_harness.dart';

class _MockHomeBloc extends MockBloc<HomeEvent, HomeState>
    implements HomeBloc {}

class _MockVerseBloc extends MockBloc<DailyVerseEvent, DailyVerseState>
    implements DailyVerseBloc {}

class _MockMemoryBloc extends MockBloc<MemoryVerseEvent, MemoryVerseState>
    implements MemoryVerseBloc {}

class _MockTokenBloc extends MockBloc<TokenEvent, TokenState>
    implements TokenBloc {}

class _MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

class _MockUsageStatsBloc extends MockBloc<UsageStatsEvent, UsageStatsState>
    implements UsageStatsBloc {}

class _MockSubscriptionBloc
    extends MockBloc<SubscriptionEvent, SubscriptionState>
    implements SubscriptionBloc {}

class _MockWalkthrough extends Mock implements WalkthroughRepository {}

class _MockThreshold extends Mock implements UsageThresholdService {}

class _MockConfig extends Mock implements SystemConfigService {}

class _MockFlags extends Mock implements RolloutFlags {}

class _MockGuest extends Mock implements GuestSessionService {}

class _MockAuth extends Mock implements AuthStateProvider {}

class _MockLanguagePrefs extends Mock implements LanguagePreferenceService {}

class _MockProfile extends Mock implements UserProfileService {}

class _MockCommunity extends Mock implements CommunityRepository {}

class _MockPaths extends Mock implements LearningPathsRepository {}

const _summary4of8 = ActivePathSummary(
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

const _summaryLesson1 = ActivePathSummary(
  pathId: 'p1',
  title: 'New Believer Essentials',
  description: 'First steps',
  discipleLevel: 'seeker',
  lessonTotal: 8,
  lessonsCompleted: 0,
  next: NextLesson(
    topicId: 't1',
    title: 'Who Is Jesus?',
    description: '',
    inputType: 'topic',
    number: 1,
    total: 8,
  ),
);

ActivePathSummary _localSummary(String language) => ActivePathSummary(
      pathId: 'p1',
      title: language == 'hi'
          ? 'नए विश्वासी की नींव और पहला कदम'
          : 'പുതിയ വിശ്വാസിയുടെ അടിസ്ഥാനങ്ങൾ',
      description: '',
      discipleLevel: '',
      lessonTotal: 16,
      lessonsCompleted: 3,
      next: NextLesson(
        topicId: 't4',
        title: language == 'hi'
            ? 'अपने उद्धार में भरोसा'
            : 'നിങ്ങളുടെ രക്ഷയിലുള്ള ഉറപ്പ്',
        description: '',
        inputType: 'topic',
        number: 4,
        total: 16,
      ),
    );

LearningPath _path({bool enrolled = true, String id = 'p1'}) => LearningPath(
      id: id,
      slug: 'new-believer-essentials',
      title: 'New Believer Essentials',
      description: '',
      iconName: 'menu_book',
      color: '',
      totalXp: 0,
      estimatedDays: 14,
      discipleLevel: 'seeker',
      isEnrolled: enrolled,
      topicsCount: 8,
    );

HomeCombinedState _home({
  ActivePathSummary? summary,
  bool enrolled = true,
  bool loading = false,
  bool personalization = false,
}) =>
    HomeCombinedState(
      activeLearningPath: summary == null && !enrolled
          ? null
          : (summary == null ? null : _path(enrolled: enrolled)),
      activePathSummary: summary,
      isLoadingActivePath: loading,
      showPersonalizationPrompt: personalization,
    );

DailyVerseLoaded _verse() {
  const ref = 'Psalm 23:1';
  const text = 'The LORD is my shepherd; I shall not want.';
  return DailyVerseLoaded(
    verse: DailyVerseEntity(
      id: 'v1',
      reference: ref,
      referenceTranslations: const ReferenceTranslations(
          en: ref, hi: 'भजन 23:1', ml: 'സങ്കീ 23:1'),
      translations: const DailyVerseTranslations(
          esv: text,
          hindi: 'यहोवा मेरा चरवाहा है',
          malayalam: 'യഹോവ എന്റെ ഇടയൻ'),
      date: DateTime(2026, 10, 7),
    ),
    currentLanguage: VerseLanguage.english,
    preferredLanguage: VerseLanguage.english,
  );
}

MemoryVerseEntity _memoryVerse(int i) => MemoryVerseEntity(
      id: 'm$i',
      verseReference: 'Philippians 4:13',
      verseText: 'I can do all things through him who strengthens me.',
      language: 'en',
      sourceType: 'manual',
      easeFactor: 2.5,
      intervalDays: 0,
      repetitions: 0,
      nextReviewDate: DateTime(2026, 10, 7),
      addedDate: DateTime(2026, 10, 2),
      totalReviews: 0,
      createdAt: DateTime(2026, 10, 2),
    );

DueVersesLoaded _deck({required int saved, required int due}) =>
    DueVersesLoaded(
      verses: [for (var i = 0; i < due; i++) _memoryVerse(i)],
      statistics: ReviewStatisticsEntity(
        totalVerses: saved,
        dueVerses: due,
        reviewedToday: 0,
        upcomingReviews: 0,
        masteredVerses: 0,
        fullyMasteredVerses: 0,
      ),
    );

void main() {
  late _MockHomeBloc homeBloc;
  late _MockVerseBloc verseBloc;
  late _MockMemoryBloc memoryBloc;
  late _MockTokenBloc tokenBloc;
  late _MockConnectivityBloc connectivity;
  late _MockFlags flags;
  late _MockGuest guest;
  late _MockAuth auth;
  late _MockLanguagePrefs languagePrefs;
  late _MockProfile profile;
  late _MockCommunity community;
  late _MockPaths paths;
  late _MockConfig config;
  late FakeTranslationService translations;
  late Directory hiveDir;

  final launchPath = Uri.parse(
          buildLessonLaunchFromSummary(_summary4of8, StudyMode.quick, 'en'))
      .path;

  setUpAll(() async {
    registerFallbackValue(const LoadActiveLearningPath());
    registerFallbackValue(const LoadDueVerses());
    registerFallbackValue(WalkthroughScreen.home);
    await loadAppFonts();
    hiveDir = await Directory.systemTemp.createTemp('home_today_test');
    Hive.init(hiveDir.path);
    await Hive.openBox('app_settings');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  setUp(() async {
    await Hive.box('app_settings').clear();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    translations = FakeTranslationService();
    homeBloc = _MockHomeBloc();
    verseBloc = _MockVerseBloc();
    memoryBloc = _MockMemoryBloc();
    tokenBloc = _MockTokenBloc();
    connectivity = _MockConnectivityBloc();
    flags = _MockFlags();
    guest = _MockGuest();
    auth = _MockAuth();
    languagePrefs = _MockLanguagePrefs();
    profile = _MockProfile();
    community = _MockCommunity();
    paths = _MockPaths();
    config = _MockConfig();
    final walkthrough = _MockWalkthrough();
    final usageStats = _MockUsageStatsBloc();
    final subscription = _MockSubscriptionBloc();

    whenListen(verseBloc, const Stream<DailyVerseState>.empty(),
        initialState: _verse());
    whenListen(tokenBloc, const Stream<TokenState>.empty(),
        initialState: const TokenInitial());
    whenListen(connectivity, const Stream<ConnectivityState>.empty(),
        initialState: ConnectivityOnline());
    whenListen(usageStats, const Stream<UsageStatsState>.empty(),
        initialState: const UsageStatsInitial());
    whenListen(subscription, const Stream<SubscriptionState>.empty(),
        initialState: const SubscriptionInitial());

    when(() => walkthrough.syncFromRemote()).thenAnswer((_) async {});
    when(() => walkthrough.hasSeen(any())).thenAnswer((_) async => true);
    when(() => walkthrough.markSeen(any())).thenAnswer((_) async {});

    when(() => config.shouldHideFeature(any(), any())).thenReturn(false);
    when(() => config.isFeatureEnabled(any(), any())).thenReturn(true);
    when(() => config.isFeatureLocked(any(), any())).thenReturn(false);
    when(() => config.hasFeatureAccess(any(), any())).thenReturn(true);
    when(() => config.isBibleContentEnabled).thenReturn(true);

    when(() => flags.homeTodayLayout).thenReturn(true);
    when(() => flags.guestMode).thenReturn(true);
    when(() => guest.isGuest).thenReturn(false);
    when(() => guest.hasSession).thenReturn(true);

    when(() => auth.currentUserName).thenReturn('Anu');
    when(() => auth.debugInfo).thenReturn('');
    when(() => auth.userId).thenReturn('u1');
    when(() => auth.userProfile).thenReturn(null);

    when(() => languagePrefs.getStudyContentLanguage())
        .thenAnswer((_) async => AppLanguage.english);
    when(() => languagePrefs.getLearningPathStudyModePreferenceRaw())
        .thenReturn('standard');
    when(() => languagePrefs.cacheLearningPathStudyModePreference(any()))
        .thenAnswer((_) async {});
    when(() => profile.updateLearningPathStudyModePreference(any())).thenAnswer(
        (_) async => const Left(AuthenticationFailure(message: 'no row')));

    when(() => community.getFellowships(any()))
        .thenAnswer((_) async => const Right(<FellowshipEntity>[]));
    when(() => paths.getLearningPaths(
              language: any(named: 'language'),
              includeEnrolled: any(named: 'includeEnrolled'),
              forceRefresh: any(named: 'forceRefresh'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              search: any(named: 'search'),
              fellowshipId: any(named: 'fellowshipId'),
            ))
        .thenAnswer(
            (_) async => const Right(LearningPathsResult(paths: [], total: 0)));

    sl.registerSingleton<TranslationService>(translations);
    sl.registerSingleton<HomeBloc>(homeBloc);
    sl.registerSingleton<TokenBloc>(tokenBloc);
    sl.registerSingleton<WalkthroughRepository>(walkthrough);
    sl.registerSingleton<UsageStatsBloc>(usageStats);
    sl.registerSingleton<UsageThresholdService>(_MockThreshold());
    sl.registerSingleton<SubscriptionBloc>(subscription);
    sl.registerSingleton<SystemConfigService>(config);
    sl.registerSingleton<RolloutFlags>(flags);
    sl.registerSingleton<GuestSessionService>(guest);
    sl.registerSingleton<AuthStateProvider>(auth);
    sl.registerSingleton<LanguagePreferenceService>(languagePrefs);
    sl.registerSingleton<UserProfileService>(profile);
    sl.registerSingleton<CommunityRepository>(community);
    sl.registerSingleton<LearningPathsRepository>(paths);
    sl.registerFactory<NewForYouCubit>(
      () => NewForYouCubit(prefs: prefs, clock: () => DateTime(2026, 10, 7)),
    );
    GuestPathEnrollment.currentUserId = () => 'u1';
  });

  tearDown(() async {
    GuestPathEnrollment.reset();
    await sl.reset();
  });

  void asGuest() {
    when(() => guest.isGuest).thenReturn(true);
    whenListen(memoryBloc, const Stream<MemoryVerseState>.empty(),
        initialState: const MemoryVerseInitial());
  }

  /// Mounts Home. The path load settles from [loading] to [state] right
  /// after the first frame, as HomeBloc does on a cold start.
  Future<void> pumpHome(
    WidgetTester tester, {
    ActivePathSummary? summary,
    HomeCombinedState? state,
    MemoryVerseState? memory,
    bool dark = false,
    String language = 'en',
    Size size = const Size(390, 1400),
    Stream<HomeState>? states,
  }) async {
    useSurface(tester, size);
    translations.language = AppLanguage.fromCode(language);
    final settled = state ?? _home(summary: summary);
    whenListen(
      homeBloc,
      states ?? Stream<HomeState>.value(settled),
      initialState: settled.copyWith(isLoadingActivePath: true),
    );
    if (memory != null || !guest.isGuest) {
      whenListen(memoryBloc, const Stream<MemoryVerseState>.empty(),
          initialState: memory ?? _deck(saved: 0, due: 0));
    }
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        // A second Home pushed over the first: both stay mounted, as during
        // a route transition back to Home.
        GoRoute(path: '/home-again', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: launchPath,
          builder: (_, s) => Scaffold(
              body: Text('stub:lesson:${s.uri.queryParameters['mode']}')),
        ),
        GoRoute(
          path: '/learning-path/:id',
          builder: (_, s) =>
              Scaffold(body: Text('stub:path:${s.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/intro/:kind',
          builder: (_, s) =>
              Scaffold(body: Text('stub:intro:${s.pathParameters['kind']}')),
        ),
        for (final stub in const [
          '/study-topics',
          '/memory-verses',
          '/settings',
        ])
          GoRoute(
            path: stub,
            builder: (_, __) => Scaffold(body: Text('stub:$stub')),
          ),
      ],
    );
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<DailyVerseBloc>.value(value: verseBloc),
        BlocProvider<MemoryVerseBloc>.value(value: memoryBloc),
        BlocProvider<TokenBloc>.value(value: tokenBloc),
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
    ));
    await tester.pumpAndSettle();
  }

  double topOf(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  group('flag on', () {
    testWidgets(
        'verse, path section, lesson card; no streak tile, no personalize, '
        'no fellowship', (tester) async {
      await pumpHome(tester,
          state: _home(summary: _summary4of8, personalization: true));
      expect(find.byType(HomeTodayLayout), findsOneWidget);
      expect(find.text('Reflect on this verse'), findsOneWidget);
      expect(find.text('Start lesson 4'), findsOneWidget);
      expect(find.byType(HomeTodayTiles), findsNothing);
      expect(find.byType(PersonalizationPromptCard), findsNothing);
      expect(find.byType(HomeCommunitySection), findsNothing);
      expect(find.byKey(const Key('home_active_path_row')), findsNothing);
      expect(find.text('Study now'), findsNothing);
      // The verse keeps copy, share and save to memory.
      expect(find.byTooltip('Copy'), findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);
      expect(find.byTooltip('Add to Memory Verses'), findsOneWidget);
      // No For You list is requested.
      verifyNever(() => homeBloc.add(any(that: isA<LoadForYouTopics>())));
      verify(() => homeBloc.add(const LoadActiveLearningPath())).called(1);
    });

    testWidgets('builds no walkthrough targets', (tester) async {
      await pumpHome(tester, summary: _summary4of8);
      expect(
          find.byType(WalkthroughTooltip, skipOffstage: false), findsNothing);
    });

    testWidgets('sections in order: hero, path, New for you, Save progress',
        (tester) async {
      asGuest();
      await pumpHome(tester, summary: _summary4of8);
      final hero = find.text('Reflect on this verse');
      final path = find.byType(HomePathSection);
      final banner = find.byType(NewForYouBanner);
      final save = find.byType(SaveProgressRow);
      expect(banner, findsOneWidget);
      expect(save, findsOneWidget);
      expect(topOf(tester, hero), lessThan(topOf(tester, path)));
      expect(topOf(tester, path), lessThan(topOf(tester, banner)));
      expect(topOf(tester, banner), lessThan(topOf(tester, save)));
      // A guest is offered paths only.
      expect(find.text('Explore more learning paths'), findsOneWidget);
    });

    testWidgets(
        'New for you is worked out again once the user id is known '
        '(not given up after a load with no user)', (tester) async {
      asGuest();
      String? uid;
      when(() => auth.userId).thenAnswer((_) => uid);
      final states = StreamController<HomeState>();
      addTearDown(states.close);
      final settled = _home(summary: _summary4of8);
      await pumpHome(tester, summary: _summary4of8, states: states.stream);
      states.add(settled);
      await tester.pumpAndSettle();
      expect(find.byType(NewForYouBanner), findsNothing);

      uid = 'u1';
      states
        ..add(settled.copyWith(isLoadingActivePath: true))
        ..add(settled);
      await tester.pumpAndSettle();
      expect(find.byType(NewForYouBanner), findsOneWidget);
    });

    testWidgets('the hero reference is plain text', (tester) async {
      await pumpHome(tester, summary: _summary4of8);
      final reference = find.textContaining('Psalm 23:1 · ');
      expect(reference, findsOneWidget);
      expect(
          find.ancestor(of: reference, matching: find.byType(GestureDetector)),
          findsNothing);
    });

    testWidgets('Start lesson 4 opens lesson 4 in the chosen mode and saves it',
        (tester) async {
      await pumpHome(tester, summary: _summary4of8);
      // Saved preference: Full guide.
      expect(find.text('Full guide · 8 min'), findsOneWidget);
      await tester.tap(find.text('Full guide · 8 min'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick read · 3 min').last);
      await tester.pumpAndSettle();
      expect(find.text('Quick read · 3 min'), findsOneWidget);
      verify(() => languagePrefs.cacheLearningPathStudyModePreference('quick'))
          .called(1);
      verify(() => profile.updateLearningPathStudyModePreference('quick'))
          .called(1);

      await tester.tap(find.text('Start lesson 4'));
      await tester.pumpAndSettle();
      expect(find.text('stub:lesson:quick'), findsOneWidget);

      // Back on Home the path is refreshed.
      clearInteractions(homeBloc);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      verify(() =>
              homeBloc.add(const LoadActiveLearningPath(forceRefresh: true)))
          .called(1);
    });

    testWidgets('a failed profile write keeps the mode on the cached profile',
        (tester) async {
      when(() => auth.userProfile)
          .thenReturn({'id': 'u1', 'learning_path_study_mode': 'standard'});
      await pumpHome(tester, summary: _summary4of8);
      await tester.tap(find.text('Full guide · 8 min'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick read · 3 min').last);
      await tester.pumpAndSettle();
      verify(() => auth.cacheProfile(
          'u1', {'id': 'u1', 'learning_path_study_mode': 'quick'})).called(1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lesson 1 after the first-run goal starts as Quick read',
        (tester) async {
      await tester.runAsync(() =>
          Hive.box('app_settings').put(FirstRunCubit.goalKey, 'know_jesus'));
      await pumpHome(tester, summary: _summaryLesson1);
      expect(find.text('Start lesson 1'), findsOneWidget);
      expect(find.text('Quick read · 3 min'), findsOneWidget);
    });

    testWidgets('a saved Quick path mode shows and opens Quick read',
        (tester) async {
      when(() => languagePrefs.getLearningPathStudyModePreferenceRaw())
          .thenReturn('quick');
      await pumpHome(tester, summary: _summary4of8);
      expect(find.text('Quick read · 3 min'), findsOneWidget);
      await tester.tap(find.text('Start lesson 4'));
      await tester.pumpAndSettle();
      expect(find.text('stub:lesson:quick'), findsOneWidget);
    });

    testWidgets('lesson 1 without a first-run goal uses the saved mode',
        (tester) async {
      await pumpHome(tester, summary: _summaryLesson1);
      expect(find.text('Full guide · 8 min'), findsOneWidget);
    });

    testWidgets('no enrolled path → Choose your first path', (tester) async {
      await pumpHome(tester, state: _home());
      expect(find.byType(ChooseFirstPathCard), findsOneWidget);
      expect(find.text('Choose your first path'), findsOneWidget);
      expect(find.textContaining('Start lesson'), findsNothing);
    });

    testWidgets('a featured path the user has not joined → chooser',
        (tester) async {
      await pumpHome(tester,
          state: _home(summary: _summary4of8, enrolled: false));
      expect(find.byType(ChooseFirstPathCard), findsOneWidget);
      expect(find.textContaining('Start lesson'), findsNothing);
    });

    testWidgets('while the path loads: skeleton, never a blank or chooser',
        (tester) async {
      useSurface(tester, const Size(390, 1400));
      whenListen(homeBloc, const Stream<HomeState>.empty(),
          initialState: _home(loading: true));
      whenListen(memoryBloc, const Stream<MemoryVerseState>.empty(),
          initialState: _deck(saved: 0, due: 0));
      await tester.pumpWidget(MultiBlocProvider(
        providers: [
          BlocProvider<DailyVerseBloc>.value(value: verseBloc),
          BlocProvider<MemoryVerseBloc>.value(value: memoryBloc),
          BlocProvider<TokenBloc>.value(value: tokenBloc),
          BlocProvider<ConnectivityBloc>.value(value: connectivity),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('home_path_placeholder')), findsOneWidget);
      expect(find.byType(ChooseFirstPathCard), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('the path call failed with nothing cached → chooser',
        (tester) async {
      // HomeBloc clears the path and stops loading on a failure.
      await pumpHome(tester, state: _home());
      expect(find.text('Choose your first path'), findsOneWidget);
    });

    testWidgets('full user: gold due count on the Memory Verses pill',
        (tester) async {
      await pumpHome(tester,
          summary: _summary4of8, memory: _deck(saved: 3, due: 2));
      expect(find.byType(MemoryPillBadge), findsOneWidget);
      expect(tester.widget<MemoryPillBadge>(find.byType(MemoryPillBadge)).count,
          2);
      expect(find.byKey(const Key('home_memory_pill_lock')), findsNothing);
    });

    testWidgets('full user: New for you reads memory and fellowships',
        (tester) async {
      await pumpHome(tester, summary: _summary4of8);
      verify(() => community.getFellowships('en')).called(1);
      // First banner is paths, under the lesson card.
      expect(find.text('Explore more learning paths'), findsOneWidget);
    });
  });

  group('guest', () {
    testWidgets('sees Save progress row, which opens the account sheet',
        (tester) async {
      asGuest();
      await pumpHome(tester, summary: _summary4of8);
      expect(find.text('Save progress to your account'), findsOneWidget);
      await tester.tap(find.text('Save progress to your account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account_continue_guest')), findsOneWidget);
    });

    testWidgets('no gated calls: no fellowship or memory loads',
        (tester) async {
      asGuest();
      await pumpHome(tester, summary: _summary4of8);
      verifyNever(() => community.getFellowships(any()));
      verifyNever(() => memoryBloc.add(any()));
      verifyNever(() => profile.updateLearningPathStudyModePreference(any()));
      // Header pill: lock, never a count.
      expect(find.byKey(const Key('home_memory_pill_lock')), findsOneWidget);
      expect(find.byType(MemoryPillBadge), findsNothing);
      // The verse's memory icon is locked too.
      expect(find.byKey(const Key('daily_verse_memory_lock')), findsOneWidget);
    });

    testWidgets('a guest can change the lesson mode (kept on the device)',
        (tester) async {
      asGuest();
      await pumpHome(tester, summary: _summary4of8);
      await tester.tap(find.text('Full guide · 8 min'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick read · 3 min').last);
      await tester.pumpAndSettle();
      verify(() => languagePrefs.cacheLearningPathStudyModePreference('quick'))
          .called(1);
      expect(find.text('Quick read · 3 min'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('two Homes mounted at once', () {
    Future<void> pushSecondHome(WidgetTester tester) async {
      GoRouter.of(tester.element(find.byType(HomeScreen))).push('/home-again');
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen, skipOffstage: false), findsNWidgets(2));
    }

    testWidgets('flag on: no duplicate keys', (tester) async {
      await pumpHome(tester, summary: _summary4of8);
      await pushSecondHome(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('flag off: no duplicate keys', (tester) async {
      when(() => flags.homeTodayLayout).thenReturn(false);
      await pumpHome(tester, summary: _summary4of8);
      expect(find.byType(WalkthroughTooltip), findsNWidgets(2));
      await pushSecondHome(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('flag off', () {
    testWidgets('old Home unchanged', (tester) async {
      when(() => flags.homeTodayLayout).thenReturn(false);
      await pumpHome(tester, summary: _summary4of8);
      expect(find.byType(HomeTodayLayout), findsNothing);
      expect(find.byType(HomeTodayTiles), findsOneWidget);
      expect(find.text('Study now'), findsOneWidget);
      expect(find.text('Reflect on this verse'), findsNothing);
      expect(find.byType(HomePathSection), findsNothing);
      // Nothing on the old Home shows "For You" topics: none are fetched.
      verifyNever(() => homeBloc.add(any(that: isA<LoadForYouTopics>())));
    });

    testWidgets('due count keeps the shipped badge', (tester) async {
      when(() => flags.homeTodayLayout).thenReturn(false);
      await pumpHome(tester,
          summary: _summary4of8, memory: _deck(saved: 3, due: 2));
      expect(find.byType(MemoryPillBadge), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('fits at 360px and 320px', () {
    for (final c in fitCases()) {
      final language = c.lang;
      testWidgets('${c.name}, guest with banner', (tester) async {
        asGuest();
        final summary = _localSummary(language);
        await pumpHome(
          tester,
          summary: summary,
          dark: c.dark,
          language: language,
          size: c.size(1600),
        );
        expect(find.byType(NewForYouBanner), findsOneWidget);
        expect(find.byType(SaveProgressRow), findsOneWidget);
        expect(tester.takeException(), isNull);
        expectNoTruncatedText(tester, allow: {
          summary.displayTitle,
          summary.next!.title,
          // The verse clamps by design; the greeting is the user's name.
          'यहोवा',
          'യഹോവ',
        });
      });
    }
  });
}
