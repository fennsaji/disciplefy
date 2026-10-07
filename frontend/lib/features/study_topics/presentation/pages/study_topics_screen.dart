import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/constants/study_mode_preferences.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/app_theme.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/router/app_router.dart';
import 'package:disciplefy_bible_study/core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/models/app_language.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/services/system_config_service.dart';
import 'package:disciplefy_bible_study/core/widgets/locked_feature_wrapper.dart';
import 'package:disciplefy_bible_study/core/widgets/upgrade_dialog.dart';
import 'package:disciplefy_bible_study/core/utils/logger.dart';
import 'package:disciplefy_bible_study/core/services/auth_state_provider.dart';
import 'package:disciplefy_bible_study/core/utils/reset_progress_error_localizer.dart';
import 'package:disciplefy_bible_study/core/widgets/destructive_confirm_dialog.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_bloc.dart';
import 'package:disciplefy_bible_study/features/tokens/presentation/bloc/token_state.dart';
import 'package:disciplefy_bible_study/features/home/presentation/bloc/home_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_bloc.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_event.dart';
import 'package:disciplefy_bible_study/features/gamification/presentation/bloc/gamification_state.dart';
import 'package:disciplefy_bible_study/features/user_profile/data/services/user_profile_service.dart';
import 'package:disciplefy_bible_study/features/user_profile/data/models/user_profile_model.dart';
import 'package:disciplefy_bible_study/features/study_generation/domain/entities/study_mode.dart';
import 'package:disciplefy_bible_study/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:disciplefy_bible_study/features/study_generation/presentation/widgets/mode_selection_sheet.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_repository.dart';
import 'package:disciplefy_bible_study/features/walkthrough/domain/walkthrough_screen.dart';
import 'package:disciplefy_bible_study/features/walkthrough/presentation/showcase_keys.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/continue_learning_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/continue_learning_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/continue_learning_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/study_topics_refresh_requests.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/for_you_learning_paths_section.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_path_card.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/learning_paths_section.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/widgets/topics_header_cards.dart';
import 'package:disciplefy_bible_study/core/utils/error_message_sanitizer.dart';
import 'package:disciplefy_bible_study/shared/widgets/photo_wash.dart';
import 'package:disciplefy_bible_study/shared/widgets/sheet_scroll_view.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_group.dart';
import 'package:disciplefy_bible_study/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:disciplefy_bible_study/shared/widgets/content_language_sheet.dart';

/// Screen for browsing study topics and learning paths.
///
/// Layout (top to bottom), over a photo wash:
/// 1. Header — "Study Topics" and the overflow menu
/// 2. Continue card — the path in progress and its next topic
/// 3. Study streak and Leaderboard tiles
/// 4. For you — personalised paths (fellowship → in-progress → recommended)
/// 5. Learning paths — search, level filters and category rows
class StudyTopicsScreen extends StatefulWidget {
  /// Optional topic ID from deep link (e.g., from notification)
  final String? topicId;

  const StudyTopicsScreen({super.key, this.topicId});

  @override
  State<StudyTopicsScreen> createState() => _StudyTopicsScreenState();
}

class _StudyTopicsScreenState extends State<StudyTopicsScreen> {
  String _currentLanguage = 'en';
  bool _languageLoaded = false;
  bool _dataLoadingStarted = false; // Track if BLoC events have been dispatched
  late LearningPathsBloc _learningPathsBloc;
  late ContinueLearningBloc _continueLearningBloc;
  late LanguagePreferenceService _languageService;
  late SystemConfigService _systemConfigService;
  late SubscriptionRepository _subscriptionRepository;
  StreamSubscription<AppLanguage>? _languageSubscription;
  StreamSubscription<AppLanguage>? _contentLanguageSubscription;
  String _userPlan = 'free';
  bool _isLearningPathsFeatureEnabled = true; // Default to true until checked
  bool _isLeaderboardFeatureEnabled = true; // Default to true until checked

  @override
  void initState() {
    super.initState();
    // Create BLoCs without dispatching events yet
    _learningPathsBloc = sl<LearningPathsBloc>();
    _continueLearningBloc = sl<ContinueLearningBloc>();
    _languageService = sl<LanguagePreferenceService>();
    _systemConfigService = sl<SystemConfigService>();
    _subscriptionRepository = sl<SubscriptionRepository>();
    _loadLanguageAndInitialize();
    _setupLanguageChangeListener();
    _checkLearningPathsFeatureAccess();
    _loadGamificationStats();
    StudyTopicsRefreshRequests.instance.addListener(_refreshInBackground);
  }

  /// The shell asks for this when the user switches back to this tab. The
  /// blocs keep what they show and swap in the fresh data (progress) when it
  /// lands. Skipped until the first load has been dispatched — that load
  /// already fetches fresh data.
  void _refreshInBackground() {
    if (!mounted || !_dataLoadingStarted) return;
    _learningPathsBloc
      ..add(LoadLearningPaths(language: _currentLanguage, forceRefresh: true))
      ..add(LoadPersonalizedPaths(
          language: _currentLanguage, forceRefresh: true));
    _continueLearningBloc
        .add(RefreshContinueLearning(language: _currentLanguage));
  }

  /// The streak and rank tiles read the shared [GamificationBloc]; load it
  /// if nothing else has yet.
  void _loadGamificationStats() {
    try {
      final gamification = sl<GamificationBloc>();
      if (gamification.state.status == GamificationStatus.initial) {
        gamification.add(const LoadGamificationStats());
      }
    } catch (e) {
      Logger.debug('[STUDY_TOPICS] Gamification stats unavailable: $e');
    }
  }

  /// Checks if Learning Paths and Leaderboard features are enabled based on feature flags and user's plan
  Future<void> _checkLearningPathsFeatureAccess() async {
    try {
      // Get user's current subscription plan
      final result = await _subscriptionRepository.getSubscriptionStatus();

      result.fold(
        (failure) {
          Logger.debug(
              '⚠️ [STUDY_TOPICS] Failed to get subscription: ${ErrorMessageSanitizer.sanitize(failure)}');
          _userPlan = 'free'; // Default to free on error
        },
        (subscription) {
          _userPlan = subscription.currentPlan;
          Logger.debug('👤 [STUDY_TOPICS] User plan: $_userPlan');
        },
      );

      // Check if learning_paths should be hidden (not just disabled)
      // We show features with lock overlays unless they're explicitly hidden
      final shouldHideLearningPaths =
          _systemConfigService.shouldHideFeature('learning_paths', _userPlan);

      // Check if leaderboard should be hidden (not just disabled)
      final shouldHideLeaderboard =
          _systemConfigService.shouldHideFeature('leaderboard', _userPlan);

      if (mounted) {
        setState(() {
          // Show features unless explicitly hidden
          _isLearningPathsFeatureEnabled = !shouldHideLearningPaths;
          _isLeaderboardFeatureEnabled = !shouldHideLeaderboard;
        });
      }

      if (shouldHideLearningPaths) {
        Logger.debug(
            '🙈 [STUDY_TOPICS] Learning Paths hidden for plan $_userPlan');
      } else {
        Logger.debug(
            '👀 [STUDY_TOPICS] Learning Paths visible for plan $_userPlan (may be locked)');
      }

      if (shouldHideLeaderboard) {
        Logger.debug(
            '🙈 [STUDY_TOPICS] Leaderboard hidden for plan $_userPlan');
      } else {
        Logger.debug(
            '👀 [STUDY_TOPICS] Leaderboard visible for plan $_userPlan (may be locked)');
      }
    } catch (e) {
      Logger.debug('❌ [STUDY_TOPICS] Error checking feature access: $e');
      // Default to enabled on error to avoid breaking existing users
      if (mounted) {
        setState(() {
          _isLearningPathsFeatureEnabled = true;
          _isLeaderboardFeatureEnabled = true;
        });
      }
    }
  }

  /// Listen for language changes from Settings. Content on "Default" follows
  /// the app language, so an app-language change can change the content.
  void _setupLanguageChangeListener() {
    Logger.debug('[STUDY_TOPICS] Setting up language change listener');

    // Cancel any existing subscription before creating a new one
    _languageSubscription?.cancel();

    // Store the subscription to ensure proper cleanup
    _languageSubscription =
        _languageService.languageChanges.listen((newLanguage) async {
      Logger.debug(
          '[STUDY_TOPICS] App language changed to: ${newLanguage.displayName}');

      // Re-resolve the content language; it only changes if it is on Default.
      if (mounted) {
        await _loadLanguageAndInitialize();
        Logger.debug(
            '[STUDY_TOPICS] Content refreshed after app language change');
      }
    });

    // Content language can also change from Settings while this tab stays
    // alive in the tab stack; reload so paths match the chosen language.
    _contentLanguageSubscription?.cancel();
    _contentLanguageSubscription = _languageService.studyContentLanguageChanges
        .listen((newLanguage) => _applyContentLanguage(newLanguage.code));
  }

  /// Reloads paths in [code] unless they are already in it. Both the stream
  /// above and the Topics menu's own callback land here, so one change never
  /// triggers two reloads.
  void _applyContentLanguage(String code) {
    if (!mounted || code == _currentLanguage) return;
    setState(() => _currentLanguage = code);
    _learningPathsBloc.add(RefreshLearningPaths(language: code));
    _learningPathsBloc
        .add(LoadPersonalizedPaths(language: code, forceRefresh: true));
    _continueLearningBloc
        .add(LoadContinueLearning(language: code, forceRefresh: true));
  }

  Future<void> _loadLanguageAndInitialize() async {
    // PERFORMANCE FIX: Set languageLoaded immediately to unblock UI,
    // then update with actual language when available
    if (mounted && !_languageLoaded) {
      setState(() {
        _languageLoaded = true;
      });
    }

    // Use study content language (not global app language)
    final language = await _languageService.getStudyContentLanguage();
    if (mounted) {
      setState(() {
        _currentLanguage = language.code;
      });

      // Always load learning paths (available for all users)
      _learningPathsBloc.add(LoadLearningPaths(
        language: _currentLanguage,
        forceRefresh: true,
      ));

      // Load personalized paths for the For You section (questionnaire-based)
      _learningPathsBloc.add(LoadPersonalizedPaths(
        language: _currentLanguage,
        forceRefresh: true,
      ));

      // The Continue card's current topic.
      _continueLearningBloc.add(LoadContinueLearning(
        language: _currentLanguage,
        forceRefresh: true,
      ));

      // Mark that data loading has started
      if (!_dataLoadingStarted) {
        setState(() {
          _dataLoadingStarted = true;
        });
      }
    }
  }

  @override
  void dispose() {
    StudyTopicsRefreshRequests.instance.removeListener(_refreshInBackground);
    _languageSubscription?.cancel();
    _contentLanguageSubscription?.cancel();
    _learningPathsBloc.close();
    _continueLearningBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: _learningPathsBloc,
          ),
          BlocProvider.value(
            value: _continueLearningBloc,
          ),
          BlocProvider.value(
            value: sl<HomeBloc>(),
          ),
        ],
        child: _StudyTopicsScreenContent(
          topicId: widget.topicId,
          currentLanguage: _currentLanguage,
          languageLoaded: _languageLoaded,
          dataLoadingStarted: _dataLoadingStarted,
          isLearningPathsFeatureEnabled: _isLearningPathsFeatureEnabled,
          isLeaderboardFeatureEnabled: _isLeaderboardFeatureEnabled,
          onStudyLanguageChanged: _applyContentLanguage,
        ),
      );
}

class _StudyTopicsScreenContent extends StatefulWidget {
  /// Optional topic ID from deep link (e.g., from notification)
  final String? topicId;

  /// Current app language code
  final String currentLanguage;

  /// Whether the language has been loaded
  final bool languageLoaded;

  /// Whether BLoC events have been dispatched and data loading has started
  final bool dataLoadingStarted;

  /// Whether learning paths feature is enabled for user's plan
  final bool isLearningPathsFeatureEnabled;

  /// Whether leaderboard feature is enabled for user's plan
  final bool isLeaderboardFeatureEnabled;

  /// Called when the user changes the study content language via the AppBar.
  /// Receives the new language code; the outer state updates [currentLanguage]
  /// and dispatches the BLoC refresh so all child widgets stay in sync.
  final void Function(String newLanguageCode)? onStudyLanguageChanged;

  const _StudyTopicsScreenContent({
    this.topicId,
    required this.currentLanguage,
    required this.languageLoaded,
    required this.dataLoadingStarted,
    required this.isLearningPathsFeatureEnabled,
    required this.isLeaderboardFeatureEnabled,
    this.onStudyLanguageChanged,
  });

  @override
  State<_StudyTopicsScreenContent> createState() =>
      _StudyTopicsScreenContentState();
}

class _StudyTopicsScreenContentState extends State<_StudyTopicsScreenContent> {
  /// Scenery behind the top of the tab.
  static const String _washImage = 'assets/images/hero/green_hills.webp';

  // Track if we're currently navigating to prevent multiple navigations
  bool _isNavigating = false;
  final ScrollController _scrollController = ScrollController();

  // Builder context from ShowCaseWidget — use this for ShowCaseWidget.of() calls.
  // this.context is an ancestor of ShowCaseWidget; ShowCaseWidget.of(this.context) fails.
  BuildContext? _showcaseContext;

  /// Advances the showcase to the next step.
  VoidCallback get _onNext => () => ShowCaseWidget.of(_showcaseContext!).next();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _triggerWalkthroughIfNeeded();

    // Handle deep link navigation from notification
    if (widget.topicId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleTopicDeepLink(widget.topicId!);
      });
    }
  }

  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _showcaseContext == null) return;
      final repo = sl<WalkthroughRepository>();
      if (await repo.hasSeen(WalkthroughScreen.learningPaths)) return;
      ShowCaseWidget.of(_showcaseContext!).startShowCase([
        ShowcaseKeys.topicsPathList,
        ShowcaseKeys.topicsPathCard,
      ]);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      final bloc = context.read<LearningPathsBloc>();
      final state = bloc.state;
      final isSearchActive = state is LearningPathsLoaded &&
          (state.searchQuery?.isNotEmpty ?? false);
      if (state is LearningPathsLoaded &&
          state.hasMoreCategories &&
          !state.isFetchingMoreCategories &&
          !isSearchActive) {
        bloc.add(LoadMoreCategories(language: widget.currentLanguage));
      }
    }
  }

  /// Handle deep link to specific topic (e.g., from notification)
  void _handleTopicDeepLink(String topicId) async {
    Logger.debug('[StudyTopics] Deep link detected for topic ID: $topicId');

    if (!mounted) return;

    // For topics, the recommended mode is standard
    const recommendedMode = StudyMode.standard;

    // Check saved default_study_mode preference before showing sheet
    final savedModeRaw =
        await sl<LanguagePreferenceService>().getStudyModePreferenceRaw();

    if (!mounted) return;

    final encodedTopicId = Uri.encodeComponent(topicId);

    void navigateWithMode(StudyMode mode) {
      context.go(
          '/study-guide-v2?input=&type=topic&language=${widget.currentLanguage}&mode=${mode.name}&source=deepLink&topic_id=$encodedTopicId');
    }

    if (StudyModePreferences.isRecommended(savedModeRaw)) {
      Logger.debug(
          '✅ [DEEP_LINK] Using recommended mode for topic: ${recommendedMode.name}');
      navigateWithMode(recommendedMode);
    } else if (savedModeRaw != null) {
      final savedMode = _parseStudyMode(savedModeRaw);
      if (savedMode != null) {
        Logger.debug('✅ [DEEP_LINK] Using saved study mode: ${savedMode.name}');
        navigateWithMode(savedMode);
      } else {
        // Invalid mode string — fall back to sheet
        final result = await ModeSelectionSheet.show(
          context: context,
          languageCode: widget.currentLanguage,
          recommendedMode: recommendedMode,
        );
        if (result != null && mounted) {
          final mode = result['mode'] as StudyMode;
          if (result['rememberChoice'] as bool) {
            sl<LanguagePreferenceService>().saveStudyModePreference(mode);
          }
          navigateWithMode(mode);
        }
      }
    } else {
      // No saved preference → show mode selection sheet
      Logger.debug('[StudyTopics] No saved preference - showing mode sheet');
      final result = await ModeSelectionSheet.show(
        context: context,
        languageCode: widget.currentLanguage,
        recommendedMode: recommendedMode,
      );
      if (result != null && mounted) {
        final mode = result['mode'] as StudyMode;
        if (result['rememberChoice'] as bool) {
          sl<LanguagePreferenceService>().saveStudyModePreference(mode);
        }
        navigateWithMode(mode);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return ShowCaseWidget(
      enableAutoScroll: true,
      onFinish: () =>
          sl<WalkthroughRepository>().markSeen(WalkthroughScreen.learningPaths),
      builder: (showcaseContext) {
        _showcaseContext = showcaseContext;
        return Scaffold(
          backgroundColor: palette.page,
          body: PhotoWash(
            image: _washImage,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StudyTopicsAppBar(
                    onLanguageChange: _handleStudyLanguageChange,
                    language: widget.currentLanguage,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: _buildBody(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refresh() async {
    context
        .read<LearningPathsBloc>()
        .add(RefreshLearningPaths(language: widget.currentLanguage));
    context
        .read<ContinueLearningBloc>()
        .add(RefreshContinueLearning(language: widget.currentLanguage));
    try {
      sl<GamificationBloc>()
          .add(const LoadGamificationStats(forceRefresh: true));
    } catch (e) {
      Logger.debug('[STUDY_TOPICS] Gamification refresh skipped: $e');
    }
    // Wait for the refresh to complete
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Handle study content language change and refresh content.
  ///
  /// Delegates to [widget.onStudyLanguageChanged] so the outer state can
  /// update [currentLanguage] (used by [LearningPathsSection] for "More" /
  /// search actions) and dispatch the BLoC refresh — single source of truth.
  Future<void> _handleStudyLanguageChange() async {
    if (!mounted) return;

    final languageService = sl<LanguagePreferenceService>();
    final newLanguage = await languageService.getStudyContentLanguage();

    if (mounted) {
      widget.onStudyLanguageChanged?.call(newLanguage.code);
    }
  }

  Widget _buildBody(BuildContext context) {
    // Show loading state while waiting for language to load and BLoC events to be dispatched
    final showInitialLoading = !widget.dataLoadingStarted;

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      // The floating dock overlaps the page; its height is in the bottom
      // inset, so the last card scrolls clear of it.
      padding: EdgeInsets.fromLTRB(
          0, 8, 0, 16 + MediaQuery.paddingOf(context).bottom),
      children: [
        // Continue card — the path in progress and its next topic
        _buildContinueCard(context),

        // Study streak + Leaderboard
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildStatTiles(context),
        ),

        const SizedBox(height: 28),

        // For You — personalised paths
        ForYouLearningPathsSection(
          onPathTap: _navigateToLearningPath,
          onNext: _showcaseContext != null ? _onNext : null,
        ),

        const SizedBox(height: 28),

        // Learning Paths (Curated Learning Journeys)
        LockedFeatureWrapper(
          featureKey: 'learning_paths',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showInitialLoading)
                _buildLearningPathsLoadingState(context)
              else
                LearningPathsSection(
                  language: widget.currentLanguage,
                  onPathTap: _navigateToLearningPath,
                  onCategorySeeAll: _navigateToCategory,
                  onRetry: () => context.read<LearningPathsBloc>().add(
                      RefreshLearningPaths(language: widget.currentLanguage)),
                  onNext: _showcaseContext != null ? _onNext : null,
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  /// The Continue card, or nothing when no path is in progress.
  Widget _buildContinueCard(BuildContext context) {
    return BlocBuilder<LearningPathsBloc, LearningPathsState>(
      buildWhen: (previous, current) =>
          current is LearningPathsLoaded || previous is LearningPathsLoaded,
      builder: (context, pathsState) {
        return BlocBuilder<ContinueLearningBloc, ContinueLearningState>(
          builder: (context, continueState) {
            final paths = pathsState is LearningPathsLoaded
                ? {
                    for (final p in [
                      ...pathsState.enrolledPaths,
                      ...pathsState.allPaths,
                    ])
                      p.id: p,
                  }.values.toList()
                : const <LearningPath>[];
            final data = TopicsContinueData.resolve(
              inProgressTopics: continueState is ContinueLearningLoaded
                  ? continueState.topics
                  : const [],
              paths: paths,
            );
            if (data == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: LockedFeatureWrapper(
                featureKey: 'learning_paths',
                child: TopicsContinueCard(
                  data: data,
                  onTap: () => _navigateToPathId(data.pathId),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Study streak and (when the feature is visible) Leaderboard tiles.
  Widget _buildStatTiles(BuildContext context) {
    return BlocBuilder<GamificationBloc, GamificationState>(
      bloc: sl<GamificationBloc>(),
      builder: (context, state) {
        final stats = state.stats;
        final streak = stats?.studyCurrentStreak;
        final rank = stats?.leaderboardRank;
        final streakTile = TopicsStatTile(
          key: const Key('topics_streak_tile'),
          icon: Icons.local_fire_department_outlined,
          value: streak == null
              ? null
              : context.tr(
                  streak == 1
                      ? TranslationKeys.topicsHubStreakValueOne
                      : TranslationKeys.topicsHubStreakValue,
                  {'count': streak},
                ),
          label: context.tr(TranslationKeys.topicsHubStreakLabel),
        );
        if (!widget.isLeaderboardFeatureEnabled) return streakTile;
        final leaderboardTile = TopicsStatTile(
          key: const Key('topics_leaderboard_tile'),
          icon: Icons.emoji_events_outlined,
          value: rank != null && rank > 0 ? '#$rank' : null,
          label: context.tr(TranslationKeys.topicsHubLeaderboardLabel),
          onTap: () => openLeaderboardWithAccessCheck(context),
        );
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: streakTile),
              const SizedBox(width: 10),
              Expanded(child: leaderboardTile),
            ],
          ),
        );
      },
    );
  }

  /// Build loading state for Learning Paths section
  Widget _buildLearningPathsLoadingState(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.tr(TranslationKeys.learningPathsTitle),
            style: AppFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              LearningPathCardSkeleton(),
              SizedBox(width: 12),
              LearningPathCardSkeleton(),
            ],
          ),
        ),
      ],
    );
  }

  /// Parse study mode string to StudyMode enum
  StudyMode? _parseStudyMode(String modeString) {
    switch (modeString.toLowerCase()) {
      case 'quick':
        return StudyMode.quick;
      case 'standard':
        return StudyMode.standard;
      case 'deep':
        return StudyMode.deep;
      case 'lectio':
        return StudyMode.lectio;
      case 'sermon':
        return StudyMode.sermon;
      default:
        return null;
    }
  }

  Future<void> _navigateToLearningPath(LearningPath path) {
    Logger.debug(
        '[STUDY_TOPICS] Navigating to learning path: ${path.title} (ID: ${path.id})');
    return _navigateToPathId(path.id);
  }

  /// Navigate to learning path detail page.
  ///
  /// Uses `push`, not `go`: the detail route sits on the root navigator as a
  /// sibling of the `StatefulShellRoute`, so `go` would unmatch the shell and
  /// dispose every branch navigator — wiping this screen's scroll offset,
  /// category pagination and loaded bloc state, forcing a full reload on the
  /// way back. `push` keeps the shell mounted underneath (and still updates the
  /// browser URL on web).
  Future<void> _navigateToPathId(String pathId) async {
    if (_isNavigating) return;
    _isNavigating = true;

    // Include source=studyTopics so a directly-opened deep link still has a
    // sensible back target.
    final progressChanged =
        await context.push<bool>('/learning-path/$pathId?source=studyTopics');

    _isNavigating = false;

    // Only refetch when the detail page reports progress actually changed;
    // otherwise the preserved state stands and there is no visible reload.
    if (!mounted || progressChanged != true) return;
    _reloadAfterProgressChange();
  }

  void _reloadAfterProgressChange() {
    context.read<LearningPathsBloc>()
      ..add(LoadLearningPaths(
        forceRefresh: true,
        language: widget.currentLanguage,
      ))
      ..add(LoadPersonalizedPaths(
          language: widget.currentLanguage, forceRefresh: true));
    context
        .read<ContinueLearningBloc>()
        .add(RefreshContinueLearning(language: widget.currentLanguage));
  }

  /// Opens every path of [category]. Pushed (like the detail page) and given
  /// this tab's bloc so already-loaded paths show at once and pages loaded
  /// there are kept here.
  Future<void> _navigateToCategory(String category) async {
    if (_isNavigating) return;
    _isNavigating = true;
    await context.push<void>(
      AppRoutes.learningPathCategoryLocation(category,
          language: widget.currentLanguage),
      extra: context.read<LearningPathsBloc>(),
    );
    _isNavigating = false;
    if (!mounted) return;
    // The category page refetches paths itself after progress changes;
    // keep the Continue card in step with it.
    context
        .read<ContinueLearningBloc>()
        .add(RefreshContinueLearning(language: widget.currentLanguage));
  }
}

/// Opens the leaderboard, or the upgrade sheet when the user's plan does
/// not include it.
void openLeaderboardWithAccessCheck(BuildContext context) {
  // Check if user has access to leaderboard feature
  final tokenBloc = sl<TokenBloc>();
  final tokenState = tokenBloc.state;

  String userPlan = 'free';
  if (tokenState is TokenLoaded) {
    userPlan = tokenState.tokenStatus.userPlan.name;
  }

  final systemConfigService = sl<SystemConfigService>();
  final hasAccess =
      systemConfigService.isFeatureEnabled('leaderboard', userPlan);

  if (!hasAccess) {
    // Show upgrade dialog
    final requiredPlans = systemConfigService.getRequiredPlans('leaderboard');
    final upgradePlan =
        systemConfigService.getUpgradePlan('leaderboard', userPlan);

    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpgradeDialog(
        featureKey: 'leaderboard',
        currentPlan: userPlan,
        requiredPlans: requiredPlans,
        upgradePlan: upgradePlan,
      ),
    );
    return;
  }

  // User has access - navigate to leaderboard
  AppRouter.router.goToLeaderboard();
}

/// Header of the Study Topics screen: large "Study Topics" title and the
/// overflow menu (content language, study mode, reset progress).
class StudyTopicsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onLanguageChange;

  /// The user's current study-content language code (e.g. 'en', 'hi', 'ml').
  ///
  /// Threaded in from `_StudyTopicsScreenState.currentLanguage` so the reset
  /// flow can reload the list in the language the user is actually viewing,
  /// instead of `LoadLearningPaths`'s 'en' default.
  final String language;

  const StudyTopicsAppBar({
    super.key,
    this.onLanguageChange,
    this.language = 'en',
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                context.tr(TranslationKeys.studyTopicsTitle),
                maxLines: 2,
                style: AppFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                  height: 1.2,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: palette.text),
            tooltip: context.tr(TranslationKeys.moreOptionsTooltip),
            color: palette.card,
            surfaceTintColor: Colors.transparent,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: palette.hairline),
            ),
            onSelected: (value) {
              if (value == 'language') {
                _showLanguageSelector(context, onLanguageChange);
              } else if (value == 'study_mode') {
                _showStudyModeSelector(context);
              } else if (value == 'reset_progress') {
                _handleResetProgress(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'language',
                child: Row(
                  children: [
                    Icon(Icons.language, color: palette.accentIcon),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        context.tr(TranslationKeys.studyTopicsContentLanguage),
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: palette.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'study_mode',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: palette.accentIcon),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        context.tr(TranslationKeys.studyModePreferenceTitle),
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: palette.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuDivider(color: palette.hairline),
              PopupMenuItem<String>(
                value: 'reset_progress',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, color: context.appError),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        context.tr(TranslationKeys.studyTopicsResetProgress),
                        style: AppFonts.inter(
                          fontSize: 14,
                          color: context.appError,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Confirms and then dispatches a full learning-progress reset.
  ///
  /// `LeaderboardBloc` is intentionally not refreshed here: it is only
  /// provided on the dedicated /leaderboard route. `ContinueLearningBloc` is
  /// provided by the screen (not when this bar is used on its own), so it is
  /// looked up optionally.
  /// `GamificationBloc` is a registered `LazySingleton`, so it is reached
  /// directly via `sl<GamificationBloc>()` rather than `context.read`,
  /// which also sidesteps any `BuildContext`-across-an-`await` concern.
  Future<void> _handleResetProgress(BuildContext context) async {
    final bloc = context.read<LearningPathsBloc>();
    ContinueLearningBloc? continueBloc;
    try {
      continueBloc = context.read<ContinueLearningBloc>();
    } catch (_) {
      continueBloc = null;
    }
    final successMessage = context.tr(TranslationKeys.studyTopicsResetSuccess);

    final confirmed = await DestructiveConfirmDialog.show(
      context,
      title: context.tr(TranslationKeys.studyTopicsResetProgressTitle),
      consequences: [
        context.tr(TranslationKeys.studyTopicsResetItemPaths),
        context.tr(TranslationKeys.studyTopicsResetItemTopics),
        context.tr(TranslationKeys.studyTopicsResetItemXp),
        context.tr(TranslationKeys.studyTopicsResetItemBadges),
      ],
      confirmWord: context.tr(TranslationKeys.resetProgressConfirmWord),
      confirmLabel: context.tr(TranslationKeys.studyTopicsResetProgress),
    );

    if (!confirmed) return;

    // Wait for the bloc to settle so the snackbar reflects the real outcome.
    //
    // If the user navigates away while the reset round-trip is outstanding,
    // `_StudyTopicsScreenState.dispose()` closes the bloc, ending its stream
    // with no matching state. `orElse` supplies a sentinel so this await
    // completes cleanly instead of throwing an uncaught `StateError`; the
    // `context.mounted` check below then skips the snackbar since there is
    // no widget left to report to (the reset still completes server-side).
    //
    // Narrowed to the reset-specific states (not the shared LearningPathsError,
    // which every other load/refresh on this bloc also emits): this bloc also
    // drives the app bar, both path sections, pull-to-refresh, and the
    // language-change listener, all of which can fail independently while this
    // up-to-30s round-trip is outstanding. Resolving on their unrelated
    // LearningPathsError would report the wrong outcome to this snackbar and
    // leave the real reset result unobserved.
    final completion = bloc.stream.firstWhere(
      (state) =>
          state is LearningPathsResetSuccess ||
          state is LearningPathsResetError,
      orElse: () => const LearningPathsInitial(),
    );

    bloc.add(const ResetLearningProgressRequested());

    final outcome = await completion;

    if (!context.mounted) return;

    if (outcome is LearningPathsResetSuccess) {
      showAppSnackBar(context, successMessage, tone: AppSnackTone.success);

      // Everything derived from the deleted rows must be refetched: the
      // path list (in the user's actual study-content language — passing
      // none here would silently reload in LoadLearningPaths' 'en' default),
      // the personalized "For You" paths (dropped from state on this reload
      // since the prior state is LearningPathsResetSuccess, not
      // LearningPathsLoaded — see `_onLoadLearningPaths`), and XP/rank/badges
      // (via GamificationBloc, a singleton reached directly through the
      // service locator).
      bloc.add(LoadLearningPaths(forceRefresh: true, language: language));
      bloc.add(LoadPersonalizedPaths(language: language, forceRefresh: true));
      sl<GamificationBloc>().add(const RefreshGamificationStats());
      continueBloc?.add(RefreshContinueLearning(language: language));
    } else if (outcome is LearningPathsResetError) {
      final errorMessage = localizeResetProgressError(
        context,
        code: outcome.code,
        isNetworkError: outcome.isNetworkError,
        fallbackMessage: outcome.message,
      );
      showAppSnackBar(context, errorMessage, tone: AppSnackTone.error);
    }
  }

  /// Content-language picker (study content only, not the app UI). Shared
  /// with Settings so both write the same preference the same way.
  Future<void> _showLanguageSelector(
      BuildContext context, VoidCallback? onLanguageChange) async {
    final changed = await showContentLanguageSheet(context);
    if (changed) onLanguageChange?.call();
  }

  /// Show learning path study mode preference bottom sheet
  void _showStudyModeSelector(BuildContext context) {
    final authProvider = sl<AuthStateProvider>();

    // Get current learning path mode preference
    final currentMode =
        authProvider.userProfile?['learning_path_study_mode'] as String?;

    // Capture parent context for snackbars after sheet closes
    final parentContext = context;

    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        void choose(String value) =>
            _chooseLearningPathMode(sheetContext, parentContext, value);
        final recommended =
            sheetContext.tr(TranslationKeys.settingsUseRecommended);
        final ask = sheetContext.tr(TranslationKeys.settingsAskEveryTime);
        return SettingsSheetFrame(
          title: sheetContext
              .tr(TranslationKeys.settingsLearningPathStudyModePreference),
          description: sheetContext
              .tr(TranslationKeys.settingsLearningPathStudyModeDescription),
          children: [
            SettingsSheetGroup(
              children: [
                SettingsRadioRow(
                  icon: Icons.stars_outlined,
                  title: recommended,
                  subtitle: sheetContext
                      .tr(TranslationKeys.settingsUseRecommendedSubtitle),
                  selected: currentMode == StudyModePreferences.recommended,
                  onTap: () => choose(StudyModePreferences.recommended),
                ),
                SettingsRadioRow(
                  icon: Icons.help_outline,
                  title: ask,
                  subtitle: sheetContext
                      .tr(TranslationKeys.settingsAskEveryTimeSubtitle),
                  selected:
                      currentMode == StudyModePreferences.learningPathDefault,
                  onTap: () => choose(StudyModePreferences.learningPathDefault),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SettingsSheetGroup(
              children: [
                for (final mode in StudyMode.values)
                  SettingsRadioRow(
                    icon: mode.iconData,
                    title: _getStudyModeTranslatedName(mode, sheetContext),
                    subtitle: '${mode.durationText} • '
                        '${_getStudyModeTranslatedDescription(mode, sheetContext)}',
                    selected: currentMode == mode.value,
                    onTap: () => choose(mode.value),
                  ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  /// Saves the learning-path study mode, refreshes the cached profile and
  /// closes the sheet, reporting the outcome on the page.
  Future<void> _chooseLearningPathMode(
    BuildContext sheetContext,
    BuildContext parentContext,
    String value,
  ) async {
    try {
      final userProfileService = sl<UserProfileService>();
      final authProvider = sl<AuthStateProvider>();

      final result =
          await userProfileService.updateLearningPathStudyModePreference(value);

      if (!parentContext.mounted) return;
      result.fold(
        (failure) {
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          showAppSnackBar(
            parentContext,
            parentContext.tr(TranslationKeys.errorUpdatingPreference),
            tone: AppSnackTone.error,
          );
        },
        (profile) {
          // Update AuthStateProvider cache with new profile
          final userId = authProvider.userId;
          if (userId != null) {
            final profileMap = UserProfileModel.fromEntity(profile).toJson();
            authProvider.cacheProfile(userId, profileMap);
          }

          // Close sheet AFTER cache is updated
          if (sheetContext.mounted) Navigator.of(sheetContext).pop();

          showAppSnackBar(
            parentContext,
            parentContext.tr(TranslationKeys.preferenceUpdatedSuccessfully),
            tone: AppSnackTone.success,
          );
        },
      );
    } catch (e) {
      // Close sheet even on error
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (parentContext.mounted) {
        showAppSnackBar(
          parentContext,
          parentContext.tr(TranslationKeys.errorUpdatingPreference),
          tone: AppSnackTone.error,
        );
      }
    }
  }

  /// Get translated display name for study mode enum
  String _getStudyModeTranslatedName(StudyMode mode, BuildContext context) {
    switch (mode) {
      case StudyMode.quick:
        return context.tr(TranslationKeys.studyModeQuickName);
      case StudyMode.standard:
        return context.tr(TranslationKeys.studyModeStandardName);
      case StudyMode.deep:
        return context.tr(TranslationKeys.studyModeDeepName);
      case StudyMode.lectio:
        return context.tr(TranslationKeys.studyModeLectioName);
      case StudyMode.sermon:
        return context.tr(TranslationKeys.studyModeSermonName);
    }
  }

  /// Get translated description for study mode enum
  String _getStudyModeTranslatedDescription(
      StudyMode mode, BuildContext context) {
    switch (mode) {
      case StudyMode.quick:
        return context.tr(TranslationKeys.studyModeQuickDescription);
      case StudyMode.standard:
        return context.tr(TranslationKeys.studyModeStandardDescription);
      case StudyMode.deep:
        return context.tr(TranslationKeys.studyModeDeepDescription);
      case StudyMode.lectio:
        return context.tr(TranslationKeys.studyModeLectioDescription);
      case StudyMode.sermon:
        return context.tr(TranslationKeys.studyModeSermonDescription);
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 15);
}
