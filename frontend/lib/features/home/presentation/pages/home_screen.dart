import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import '../../../../features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/study_mode_preferences.dart';
import '../../../../core/animations/app_animations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/auth_state_provider.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/models/app_language.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../../../core/widgets/locked_feature_wrapper.dart';
import '../../../../core/widgets/upgrade_dialog.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_bloc.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_event.dart';
import '../../../daily_verse/presentation/bloc/daily_verse_state.dart';
import '../../../daily_verse/presentation/widgets/daily_verse_card.dart';
import '../../../daily_verse/domain/entities/daily_verse_entity.dart';
import '../../../notifications/presentation/widgets/notification_enable_prompt.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/widgets/email_verification_banner.dart';
import '../../../subscription/presentation/bloc/subscription_bloc.dart';
import '../../../subscription/presentation/bloc/subscription_event.dart';
import '../../../subscription/presentation/bloc/subscription_state.dart';
import '../../../subscription/presentation/bloc/usage_stats_bloc.dart';
import '../../../subscription/presentation/bloc/usage_stats_event.dart';
import '../../../subscription/presentation/bloc/usage_stats_state.dart';
import '../../../subscription/presentation/widgets/standard_subscription_banner.dart';
import '../../../subscription/presentation/widgets/standard_subscription_sheet.dart';
import '../../../subscription/presentation/widgets/upgrade_required_dialog.dart';
import '../../../subscription/presentation/widgets/insufficient_tokens_dialog.dart';
import '../../../study_generation/data/repositories/token_cost_repository.dart';
import '../../../subscription/presentation/services/usage_threshold_service.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../../tokens/domain/entities/token_status.dart';

import '../widgets/home_community_section.dart';
import '../widgets/usage_meter_widget.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../personalization/presentation/widgets/personalization_prompt_card.dart';
import '../../../study_generation/domain/entities/study_mode.dart';
import '../../../study_generation/presentation/widgets/mode_selection_sheet.dart';
import '../../../community/domain/entities/fellowship_entity.dart';
import '../../../community/domain/entities/fellowship_meeting_entity.dart';
import '../../../community/domain/repositories/community_repository.dart';
import '../../../study_topics/domain/repositories/learning_paths_repository.dart';
import '../../../study_topics/presentation/widgets/learning_path_card.dart';
import '../../../../core/connectivity/connectivity_bloc.dart';
import '../../../walkthrough/domain/walkthrough_repository.dart';
import '../../../walkthrough/domain/walkthrough_screen.dart';
import '../../../walkthrough/presentation/showcase_keys.dart';
import '../../../walkthrough/presentation/walkthrough_tooltip.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:showcaseview/showcaseview.dart';

/// Home screen displaying daily verse, navigation options, and study recommendations.
///
/// Features app logo, verse of the day, main navigation, and predefined study topics
/// following the UX specifications and brand guidelines.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: sl<HomeBloc>(),
        child: ShowCaseWidget(
          onFinish: () {
            // After home body steps finish, highlight Generate → Topics → Community
            // nav tabs using the AppShell's ShowCaseWidget.
            // markSeen is called once the full AppShell sequence completes (see AppShell).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ShowcaseKeys.triggerNavTabsAndCommunity();
            });
          },
          builder: (context) => const _HomeScreenContent(),
        ),
      );
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> {
  final bool _hasResumeableStudy = false;

  // Track if we're currently navigating to prevent multiple navigations
  bool _isNavigating = false;

  // Track if we've already triggered the notification prompts this session
  bool _hasTriggeredDailyVersePrompt = false;
  bool _hasTriggeredStreakPrompt = false;
  bool _hasTriggeredStreakLostPrompt = false;

  // Stream subscriptions for language changes (to be cancelled in dispose)
  StreamSubscription<AppLanguage>? _languageSubscription;
  StreamSubscription<AppLanguage>? _studyContentLanguageSubscription;

  // Usage stats bloc for soft paywall system
  late final UsageStatsBloc _usageStatsBloc;
  late final UsageThresholdService _usageThresholdService;

  /// Advances the showcase to the next step.
  ///
  /// Uses [this.context] which is [_HomeScreenContent]'s element context —
  /// a descendant of [ShowCaseWidget], so [ShowCaseWidget.of()] resolves correctly.
  VoidCallback get _onNext => () => ShowCaseWidget.of(context).next();

  @override
  void initState() {
    super.initState();
    // Sync walkthrough seen state from Supabase (no-op for anonymous users)
    sl<WalkthroughRepository>().syncFromRemote();
    _triggerWalkthroughIfNeeded();
    _usageStatsBloc = sl<UsageStatsBloc>();
    _usageThresholdService = sl<UsageThresholdService>();
    _loadDailyVerse();
    _loadSubscriptionStatus();
    _loadUsageStats();
    _setupLanguageChangeListener();
    // Fire initial topics load once; HomeBloc is a singleton via DI
    final homeBloc = sl<HomeBloc>();
    final current = homeBloc.state;
    if (current is! HomeCombinedState || current.topics.isEmpty) {
      // Use LoadForYouTopics for authenticated users (bloc handles fallback)
      homeBloc.add(const LoadForYouTopics());
    }
    // Load active learning path for the For You section
    // Also re-fetch if the current path is completed (100%) so the next path is shown
    if (current is! HomeCombinedState ||
        current.activeLearningPath == null ||
        (current.activeLearningPath?.isCompleted ?? false)) {
      homeBloc.add(LoadActiveLearningPath(
        forceRefresh: current is HomeCombinedState &&
            (current.activeLearningPath?.isCompleted ?? false),
      ));
    }
  }

  /// Triggers the home screen walkthrough the first time the user sees this screen.
  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Set up the verse-loaded future FIRST so we don't miss the BLoC event
      // while the hasSeen check is awaiting. If already loaded this resolves
      // immediately; if still loading it captures the upcoming emission.
      final dailyVerseBloc = sl<DailyVerseBloc>();
      final Future<DailyVerseState> verseFuture;
      if (dailyVerseBloc.state is DailyVerseLoading ||
          dailyVerseBloc.state is DailyVerseInitial) {
        verseFuture = dailyVerseBloc.stream
            .firstWhere(
                (s) => s is! DailyVerseLoading && s is! DailyVerseInitial)
            .timeout(const Duration(seconds: 5),
                onTimeout: () => dailyVerseBloc.state);
      } else {
        verseFuture = Future.value(dailyVerseBloc.state);
      }

      final repo = sl<WalkthroughRepository>();
      if (await repo.hasSeen(WalkthroughScreen.home)) return;

      // Await the verse future — already resolved if verse loaded during hasSeen.
      await verseFuture;

      if (!mounted) return;
      // One extra frame so Flutter rebuilds the card at its final size
      // before showcaseview calculates the overlay rectangle.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      final keys = _buildWalkthroughKeys();
      if (keys.isNotEmpty) {
        ShowCaseWidget.of(context).startShowCase(keys);
      }
    });
  }

  /// Builds the ordered list of showcase keys for the home walkthrough.
  List<GlobalKey> _buildWalkthroughKeys() {
    final tokenBloc = sl<TokenBloc>();
    final tokenState = tokenBloc.state;
    String userPlan = 'free';
    if (tokenState is TokenLoaded) {
      userPlan = tokenState.tokenStatus.userPlan.name;
    }
    final systemConfigService = sl<SystemConfigService>();
    final showMemoryVerses =
        !systemConfigService.shouldHideFeature('memory_verses', userPlan);

    // Steps 1-2 run in the home screen's own ShowCaseWidget.
    // Steps 3-5 (Generate / Topics / Community nav tabs) run in the AppShell's
    // ShowCaseWidget, triggered via ShowcaseKeys.triggerNavTabsAndCommunity().
    return [
      ShowcaseKeys.homeDailyVerse,
      if (showMemoryVerses) ShowcaseKeys.homeMemoryVerses,
    ];
  }

  /// Listen for app language and study content language preference changes
  /// When app language changes, study content language is reset to default,
  /// so we need to refresh the "For You" content to reflect the new app language.
  /// When study content language changes (from Study Topics screen), we also refresh.
  void _setupLanguageChangeListener() {
    final languageService = sl<LanguagePreferenceService>();

    // Cancel any existing subscriptions before creating new ones
    _languageSubscription?.cancel();
    _studyContentLanguageSubscription?.cancel();

    // Listen to app language changes (UI language)
    _languageSubscription =
        languageService.languageChanges.listen((newLanguage) {
      Logger.debug(
          '[HOME] App language changed to: ${newLanguage.displayName}');

      // When app language changes, study content language is automatically reset to default
      // Refresh the "For You" topics with the new language
      if (mounted) {
        final homeBloc = sl<HomeBloc>();
        homeBloc.add(const LoadForYouTopics(forceRefresh: true));
        homeBloc.add(const LoadActiveLearningPath(forceRefresh: true));

        Logger.debug(
            '[HOME] "For You" content refreshed after app language change');
      }
    });

    // Listen to study content language changes (study guides language)
    _studyContentLanguageSubscription =
        languageService.studyContentLanguageChanges.listen((newLanguage) {
      Logger.debug(
          '[HOME] Study content language changed to: ${newLanguage.displayName}');

      // Refresh the "For You" topics with the new study content language
      if (mounted) {
        final homeBloc = sl<HomeBloc>();
        homeBloc.add(const LoadForYouTopics(forceRefresh: true));
        homeBloc.add(const LoadActiveLearningPath(forceRefresh: true));

        Logger.debug(
            '[HOME] "For You" content refreshed after study content language change');
      }
    });
  }

  /// Load subscription status for Standard plan banner
  void _loadSubscriptionStatus() {
    final subscriptionBloc = sl<SubscriptionBloc>();
    subscriptionBloc.add(LoadSubscriptionStatus());
  }

  /// Fetch usage statistics for soft paywall system
  void _loadUsageStats() {
    _usageStatsBloc.add(const FetchUsageStats());
  }

  /// Shows the Daily Verse notification prompt if not already shown
  Future<void> _showDailyVerseNotificationPrompt(String languageCode) async {
    if (_hasTriggeredDailyVersePrompt) return;
    _hasTriggeredDailyVersePrompt = true;

    // Small delay to let the UI settle after verse loads
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    await showNotificationEnablePrompt(
      context: context,
      type: NotificationPromptType.dailyVerse,
      languageCode: languageCode,
    );
  }

  /// Shows streak notification prompts based on streak milestone
  /// - streak == 0: Show streak lost / reset motivation prompt
  /// - streak 3+: Show streak reminder prompt
  /// - streak 7+: Show streak milestone prompt
  Future<void> _showStreakNotificationPrompt(
      String languageCode, int currentStreak) async {
    if (currentStreak == 0) {
      await _showStreakLostNotificationPrompt(languageCode);
      return;
    }

    // Mark that this user has had a streak — gates the streak lost prompt
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('had_streak_before', true);

    if (_hasTriggeredStreakPrompt) return;
    if (currentStreak < 3) return;

    _hasTriggeredStreakPrompt = true;

    // Delay to show after daily verse prompt (if shown)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final promptType = currentStreak >= 7
        ? NotificationPromptType.streakMilestone
        : NotificationPromptType.streakReminder;

    await showNotificationEnablePrompt(
      context: context,
      type: promptType,
      languageCode: languageCode,
    );
  }

  /// Shows streak reset motivation prompt when user's streak has reset to 0.
  /// Only shown if the user has previously had a streak — avoids confusing
  /// brand new users who have never built a streak.
  Future<void> _showStreakLostNotificationPrompt(String languageCode) async {
    if (_hasTriggeredStreakLostPrompt) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('had_streak_before') != true) return;

    _hasTriggeredStreakLostPrompt = true;

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    await showNotificationEnablePrompt(
      context: context,
      type: NotificationPromptType.streakLost,
      languageCode: languageCode,
    );
  }

  /// Load daily verse - called only once during initialization
  void _loadDailyVerse() {
    // Auto-load daily verse on home screen initialization
    // BLoC will handle caching and avoid redundant calls
    final bloc = sl<DailyVerseBloc>();
    // Always trigger load - the BLoC will handle daily caching logic
    bloc.add(const LoadTodaysVerse());
  }

  /// Handle daily verse card tap to generate study guide
  Future<void> _onDailyVerseCardTap() async {
    // Prevent multiple clicks during navigation
    if (_isNavigating) {
      return;
    }

    // Get the current DailyVerseBloc state
    final dailyVerseBloc = context.read<DailyVerseBloc>();
    final currentState = dailyVerseBloc.state;

    if (currentState is DailyVerseLoaded || currentState is DailyVerseOffline) {
      // Check if user has a saved study mode preference (raw string value)
      final savedModeRaw =
          await sl<LanguagePreferenceService>().getStudyModePreferenceRaw();

      if (StudyModePreferences.isRecommended(savedModeRaw)) {
        // "Use Recommended" - automatically select Standard for scripture without showing sheet
        Logger.debug('✅ [HOME] Using recommended mode for scripture: Standard');
        await _navigateToDailyVerseStudy(
            currentState, StudyMode.standard, false);
      } else if (savedModeRaw != null) {
        // User has a specific saved preference - use it directly without showing sheet
        final savedMode = studyModeFromString(savedModeRaw);
        if (savedMode != null) {
          Logger.debug('✅ [HOME] Using saved study mode: ${savedMode.name}');
          await _navigateToDailyVerseStudy(currentState, savedMode, false);
        } else {
          // Invalid mode string - fallback to mode selection sheet
          Logger.debug(
              '⚠️ [HOME] Invalid study mode string: $savedModeRaw - showing mode selection sheet');
          const recommendedMode = StudyMode.standard;
          final String languageCode;
          if (currentState is DailyVerseLoaded) {
            languageCode = currentState.currentLanguage.code;
          } else if (currentState is DailyVerseOffline) {
            languageCode = currentState.currentLanguage.code;
          } else {
            languageCode = 'en';
          }
          final result = await ModeSelectionSheet.show(
            context: context,
            languageCode: languageCode,
            recommendedMode: recommendedMode,
          );
          if (result != null && mounted) {
            await _navigateToDailyVerseStudy(
              currentState,
              result['mode'] as StudyMode,
              result['rememberChoice'] as bool,
              recommendedMode: recommendedMode,
            );
          }
        }
      } else {
        // No saved preference (null) - show mode selection sheet with Standard as recommended for scripture
        Logger.debug(
            '🔍 [HOME] No saved preference - showing mode selection sheet with Standard recommended');
        const recommendedMode = StudyMode.standard; // Scripture → Standard

        // Type-safe extraction of languageCode from state
        final String languageCode;
        if (currentState is DailyVerseLoaded) {
          languageCode = currentState.currentLanguage.code;
        } else if (currentState is DailyVerseOffline) {
          languageCode = currentState.currentLanguage.code;
        } else {
          // Fallback (should never happen due to outer if check)
          languageCode = 'en';
        }

        final result = await ModeSelectionSheet.show(
          context: context,
          languageCode: languageCode,
          recommendedMode: recommendedMode,
        );
        if (result != null && mounted) {
          await _navigateToDailyVerseStudy(
            currentState,
            result['mode'] as StudyMode,
            result['rememberChoice'] as bool,
            recommendedMode:
                recommendedMode, // Pass recommended mode for preference logic
          );
        }
      }
    } else {
      // Show error if verse is not loaded
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(TranslationKeys.homeVerseNotLoaded)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Navigate to daily verse study guide with selected mode
  Future<void> _navigateToDailyVerseStudy(
    DailyVerseState currentState,
    StudyMode mode,
    bool rememberChoice, {
    StudyMode? recommendedMode,
  }) async {
    _isNavigating = true;

    // Save user's mode preference if they chose to remember
    if (rememberChoice) {
      // ✅ FIX: If user selected the recommended mode, save "recommended" instead of specific mode
      if (recommendedMode != null && mode == recommendedMode) {
        Logger.debug(
            '✅ [HOME] Saving preference as "recommended" (selected mode matches recommended)');
        sl<LanguagePreferenceService>()
            .saveStudyModePreferenceRaw('recommended');
      } else {
        Logger.debug(
            '✅ [HOME] Saving preference as specific mode: ${mode.name}');
        sl<LanguagePreferenceService>().saveStudyModePreference(mode);
      }
    }

    String verseReference;
    String languageCode;

    if (currentState is DailyVerseLoaded) {
      verseReference = currentState.verse.reference;
      languageCode = _getLanguageCode(currentState.currentLanguage);
    } else if (currentState is DailyVerseOffline) {
      verseReference = currentState.verse.reference;
      languageCode = _getLanguageCode(currentState.currentLanguage);
    } else {
      _isNavigating = false;
      return;
    }

    // Check if user has sufficient tokens for this mode
    final tokenState = context.read<TokenBloc>().state;
    if (tokenState is TokenLoaded && !tokenState.tokenStatus.isPremium) {
      final costResult = await sl<TokenCostRepository>()
          .getTokenCost(languageCode, mode.value);
      final requiredCost = costResult.fold((f) => 0, (cost) => cost);
      if (requiredCost > 0 &&
          tokenState.tokenStatus.totalTokens < requiredCost &&
          mounted) {
        setState(() => _isNavigating = false);
        await InsufficientTokensDialog.show(
          context,
          tokenStatus: tokenState.tokenStatus,
          requiredTokens: requiredCost,
        );
        return;
      }
    }

    final encodedReference = Uri.encodeComponent(verseReference);

    Logger.debug(
        '🔍 [HOME] Navigating to study guide V2 for daily verse: $verseReference with mode: ${mode.name}');

    // Navigate directly to study guide V2 - it will handle generation
    context.go(
        '/study-guide-v2?input=$encodedReference&type=scripture&language=$languageCode&mode=${mode.name}&source=home');

    // Reset navigation flag after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    });
  }

  /// Convert VerseLanguage enum to language code string
  String _getLanguageCode(VerseLanguage language) {
    switch (language) {
      case VerseLanguage.english:
        return 'en';
      case VerseLanguage.hindi:
        return 'hi';
      case VerseLanguage.malayalam:
        return 'ml';
    }
  }

  @override
  void dispose() {
    _languageSubscription?.cancel();
    _studyContentLanguageSubscription?.cancel();
    _usageStatsBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    return BlocListener<UsageStatsBloc, UsageStatsState>(
      bloc: _usageStatsBloc,
      listener: (context, state) {
        // Check and show soft paywall when usage stats load or update
        if (state is UsageStatsLoaded) {
          _checkUsageThreshold(context, state.usageStats);
        }
      },
      child: BlocListener<TokenBloc, TokenState>(
        listener: (context, state) {
          // Re-run usage threshold check once token data is available.
          // Handles the race condition where UsageStatsLoaded fires before
          // TokenLoaded — the first check is skipped, this retries it.
          if (state is TokenLoaded) {
            final usageState = _usageStatsBloc.state;
            if (usageState is UsageStatsLoaded) {
              _checkUsageThreshold(context, usageState.usageStats);
            }
          }
        },
        child: BlocListener<DailyVerseBloc, DailyVerseState>(
          bloc: sl<DailyVerseBloc>(),
          listener: (context, state) {
            // Trigger notification prompts when daily verse loads successfully
            if (state is DailyVerseLoaded) {
              final languageCode = _getLanguageCode(state.currentLanguage);
              _showDailyVerseNotificationPrompt(languageCode);

              // Also check for streak and show streak notification prompt
              final streak = state.streak;
              if (streak != null) {
                _showStreakNotificationPrompt(
                    languageCode, streak.currentStreak);
              }
            }
          },
          child: ListenableBuilder(
            listenable: sl<AuthStateProvider>(),
            builder: (context, _) {
              final authProvider = sl<AuthStateProvider>();
              final currentUserName = authProvider.currentUserName;

              if (kDebugMode) {
                Logger.debug(
                    '👤 [HOME] User loaded via AuthStateProvider: $currentUserName');
                Logger.debug('👤 [HOME] Auth state: ${authProvider.debugInfo}');
              }

              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: SafeArea(
                  child: Column(
                    children: [
                      // Main content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: isLargeScreen ? 32 : 24),

                              // App Header with Logo
                              _buildAppHeader(),

                              // Gold hairline. The mark above it is the only
                              // gold on most screens; resting it on a gold rule
                              // ties it to the gold used for streaks, XP and
                              // the selected tab instead of leaving it a lone
                              // accent in an otherwise indigo UI.
                              Padding(
                                padding: EdgeInsets.only(
                                    top: isLargeScreen ? 14 : 10),
                                child: Container(
                                  height: 1,
                                  color: context.appGoldMark
                                      .withValues(alpha: 0.38),
                                ),
                              ),

                              SizedBox(height: isLargeScreen ? 18 : 14),

                              // Welcome Message
                              _buildWelcomeMessage(currentUserName),

                              SizedBox(height: isLargeScreen ? 16 : 12),

                              // Upcoming meeting banner (today's meetings)
                              const _UpcomingMeetingBanner(),

                              SizedBox(height: isLargeScreen ? 16 : 12),

                              // Daily Verse Card with click functionality and lock support
                              WalkthroughTooltip(
                                showcaseKey: ShowcaseKeys.homeDailyVerse,
                                title: AppLocalizations.of(context)!
                                    .walkthroughHomeDailyVerseTitle,
                                description: AppLocalizations.of(context)!
                                    .walkthroughHomeDailyVerseDesc,
                                screen: WalkthroughScreen.home,
                                stepNumber: 1,
                                totalSteps: 5,
                                onNext: _onNext,
                                child: LockedFeatureWrapper(
                                  featureKey: 'daily_verse',
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      DailyVerseCard(
                                        margin: EdgeInsets.zero,
                                        onTap: _onDailyVerseCardTap,
                                      ),
                                      SizedBox(height: isLargeScreen ? 24 : 20),
                                    ],
                                  ),
                                ),
                              ),

                              // Explore Learning Paths Button
                              _buildExploreLearningPathsButton(),
                              SizedBox(height: isLargeScreen ? 32 : 24),

                              // Resume Last Study (conditional)
                              if (_hasResumeableStudy) ...[
                                _buildResumeStudyBanner(),
                                SizedBox(height: isLargeScreen ? 32 : 24),
                              ],

                              // Recommended Study Topics
                              _buildRecommendedTopics(),

                              SizedBox(height: isLargeScreen ? 32 : 24),

                              // Closing note: what's happening in the user's
                              // fellowships, or an invitation to join one.
                              // Collapses to nothing while loading or on error.
                              const HomeCommunitySection(),

                              SizedBox(height: isLargeScreen ? 32 : 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).withHomeProtection();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    // Check if memory_verses feature should be visible (respects display_mode)
    final tokenBloc = sl<TokenBloc>();
    final tokenState = tokenBloc.state;
    String userPlan = 'free';
    if (tokenState is TokenLoaded) {
      userPlan = tokenState.tokenStatus.userPlan.name;
    }

    final systemConfigService = sl<SystemConfigService>();
    final showMemoryVerses =
        !systemConfigService.shouldHideFeature('memory_verses', userPlan);

    // The logo is Expanded so it fills all slack on the left, pushing the Memory
    // Verses pill + Settings to the right edge. The pill keeps its intrinsic
    // width (full label, capped at 140 inside the button); the logo image is
    // left-aligned and shrinks only when the header is genuinely tight.
    return Row(
      children: [
        Expanded(child: _buildLogoWidget()),
        const SizedBox(width: 8),
        if (showMemoryVerses) ...[
          WalkthroughTooltip(
            showcaseKey: ShowcaseKeys.homeMemoryVerses,
            title: AppLocalizations.of(context)!.walkthroughHomeMemoryTitle,
            description:
                AppLocalizations.of(context)!.walkthroughHomeMemoryDesc,
            screen: WalkthroughScreen.home,
            stepNumber: 2,
            totalSteps: 5,
            onNext: _onNext,
            // Header element — not enough space above; show below
            tooltipPosition: TooltipPosition.bottom,
            child: _buildMemoryVersesIconButton(),
          ),
          const SizedBox(width: 4),
        ],
        _buildSettingsButton(),
      ],
    );
  }

  Widget _buildMemoryVersesIconButton() {
    return BlocBuilder<MemoryVerseBloc, MemoryVerseState>(
      builder: (context, memState) {
        final dueCount =
            memState is DueVersesLoaded ? memState.verses.length : 0;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        // Neutral, not brand indigo: the gold wordmark owns this row, so the
        // two utility controls beside it (this pill and the settings gear)
        // stay white on dark and near-black on light.
        final pillColor = isDark ? Colors.white : AppColors.lightTextSecondary;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Plain OutlinedButton (not .icon) with a Flexible label so the
              // text ellipsizes when the header is tight — .icon leaves the
              // label unconstrained and it overflows instead.
              OutlinedButton(
                onPressed: _handleMemoryVersesTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: pillColor,
                  side: BorderSide(
                    color: pillColor.withValues(alpha: 0.5),
                  ),
                  backgroundColor: pillColor.withValues(alpha: 0.12),
                  padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.psychology_outlined, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        context.tr(TranslationKeys.homeMemoryVerses),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (dueCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: _DueBadge(count: dueCount),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Checks if Generate Study Guide button should be hidden
  /// Returns true if ALL study modes AND Talk to Discipler are disabled
  bool _shouldHideGenerateButton() {
    final tokenBloc = sl<TokenBloc>();
    final tokenState = tokenBloc.state;

    String userPlan = 'free';
    if (tokenState is TokenLoaded) {
      userPlan = tokenState.tokenStatus.userPlan.name;
    }

    final systemConfigService = sl<SystemConfigService>();

    // Check all study modes
    final studyModes = [
      'quick_read_mode',
      'standard_study_mode',
      'deep_dive_mode',
      'lectio_divina_mode',
      'sermon_outline_mode',
    ];

    // Check if ALL study modes should be hidden (respects display_mode)
    final allStudyModesDisabled = studyModes.every(
      (mode) => systemConfigService.shouldHideFeature(mode, userPlan),
    );

    // Check if Talk to Discipler should be hidden (respects display_mode)
    final aiDisciplerDisabled =
        systemConfigService.shouldHideFeature('ai_discipler', userPlan);

    // Hide if both ALL study modes should be hidden AND Talk to Discipler should be hidden
    return allStudyModesDisabled && aiDisciplerDisabled;
  }

  /// Handles tap on Memory Verses button - checks feature flag and shows upgrade dialog if disabled
  void _handleMemoryVersesTap() {
    // Check if user has access to Memory Verses feature
    final tokenBloc = sl<TokenBloc>();
    final tokenState = tokenBloc.state;

    String userPlan = 'free';
    if (tokenState is TokenLoaded) {
      userPlan = tokenState.tokenStatus.userPlan.name;
    }

    final systemConfigService = sl<SystemConfigService>();
    final hasAccess =
        systemConfigService.isFeatureEnabled('memory_verses', userPlan);

    if (!hasAccess) {
      // Show upgrade dialog
      final requiredPlans =
          systemConfigService.getRequiredPlans('memory_verses');
      final upgradePlan =
          systemConfigService.getUpgradePlan('memory_verses', userPlan);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => UpgradeDialog(
          featureKey: 'memory_verses',
          currentPlan: userPlan,
          requiredPlans: requiredPlans,
          upgradePlan: upgradePlan,
        ),
      );
      return;
    }

    // User has access - navigate to Memory Verses
    context.go('/memory-verses');
  }

  Widget _buildLogoWidget() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDarkMode
        ? 'assets/images/app_logo_dark.png'
        : 'assets/images/app_logo.png';

    // No fixed width — BoxFit.contain scales within the Flexible parent so the
    // logo shrinks on narrow screens; maxWidth caps it on wide screens. Left-
    // aligned so it hugs the leading edge as it scales.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230, maxHeight: 52),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Image.asset(
          logoAsset,
          height: 52,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildLogoFallback(),
        ),
      ),
    );
  }

  Widget _buildLogoFallback() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.menu_book_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildSettingsButton() {
    return IconButton(
      onPressed: () {
        context.go('/settings');
      },
      icon: Icon(
        Icons.settings_outlined,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppColors.lightTextSecondary,
        size: 24,
      ),
    );
  }

  Widget _buildWelcomeMessage(String userName) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(TranslationKeys.homeWelcomeBack, {'name': userName}),
            style: AppFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(TranslationKeys.homeContinueJourney),
            style: AppFonts.inter(
              fontSize: 16,
              color:
                  Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ],
      );

  /// Build usage meter widget (shows token usage for free users)
  Widget _buildUsageMeter() {
    return BlocBuilder<UsageStatsBloc, UsageStatsState>(
      bloc: _usageStatsBloc,
      builder: (context, state) {
        // Only show for loaded state
        if (state is! UsageStatsLoaded) {
          return const SizedBox.shrink();
        }

        final usageStats = state.usageStats;

        // Only show usage meter for free users
        final isFree = usageStats.currentPlan == 'free';
        if (!isFree) {
          return const SizedBox.shrink();
        }

        // For free plan, show daily token usage
        final tokensUsed = usageStats.tokensUsed;
        final tokensTotal = usageStats.tokensTotal;

        return UsageMeterWidget(
          tokensUsed: tokensUsed,
          tokensTotal: tokensTotal,
          onUpgrade: () => context.go('/pricing'),
        );
      },
    );
  }

  /// Check usage threshold and show soft paywall if needed
  void _checkUsageThreshold(BuildContext context, dynamic usageStats) {
    // Use post-frame callback to avoid showing dialog during build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      String userPlan = 'free';
      int purchasedTokens = 0;
      try {
        final tokenState = context.read<TokenBloc>().state;
        if (tokenState is! TokenLoaded) {
          // TokenBloc not loaded yet — skip now; the BlocListener on TokenBloc
          // will re-trigger this check once the state is available.
          return;
        }
        userPlan = tokenState.tokenStatus.userPlan.name;
        purchasedTokens = tokenState.tokenStatus.purchasedTokens;
      } catch (_) {}

      // Pass currentDate so the service handles daily resets internally.
      // The service is a singleton and persists across widget rebuilds,
      // preventing the dialog from re-firing just because the widget was recreated.
      // Pass purchasedTokens so the dialog is suppressed when the user has
      // purchased tokens available (daily limit exhausted ≠ truly out of tokens).
      final showed = await _usageThresholdService.checkAndShowThreshold(
        context: context,
        tokensUsed: usageStats.tokensUsed,
        tokensTotal: usageStats.tokensTotal,
        streakDays: usageStats.streakDays,
        userPlan: userPlan,
        currentDate: usageStats.monthYear as String,
        purchasedTokens: purchasedTokens,
      );

      if (showed) {
        Logger.info(
          'Soft paywall shown at ${usageStats.percentage}% usage',
          tag: 'HOME_USAGE_THRESHOLD',
        );
      }
    });
  }

  Widget _buildExploreLearningPathsButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(AppRoutes.studyTopics),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.explore_rounded,
                size: 24,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(
                context.tr(TranslationKeys.homeExploreLearningPaths),
                style: AppFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeStudyBanner() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.bookmark,
              color: AppTheme.accentColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(TranslationKeys.homeResumeLastStudy),
                    style: AppFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(TranslationKeys.homeContinueStudying,
                        {'topic': 'Faith in Trials'}),
                    style: AppFonts.inter(
                      fontSize: 14,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.accentColor,
              size: 16,
            ),
          ],
        ),
      );

  Widget _buildRecommendedTopics() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        final homeState =
            state is HomeCombinedState ? state : const HomeCombinedState();

        final sectionTitle = context.tr(TranslationKeys.homeForYou);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personalization prompt card (shown when needed)
            if (homeState.showPersonalizationPrompt) ...[
              PersonalizationPromptCard(
                onGetStarted: () => _navigateToQuestionnaire(),
                onSkip: () => context
                    .read<HomeBloc>()
                    .add(const DismissPersonalizationPrompt()),
              ),
              const SizedBox(height: 24),
            ],

            // Section header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionTitle,
                        style: AppFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withOpacity(0.9)
                              : const Color(0xFF1F2937),
                        ),
                      ),
                      if (homeState.isPersonalized) ...[
                        const SizedBox(height: 4),
                        Text(
                          context.tr(TranslationKeys.homeForYouSubtitle),
                          style: AppFonts.inter(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white.withOpacity(0.6)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (homeState.isLoadingTopics || homeState.isLoadingActivePath)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(context.appBrandAccent),
                    ),
                  )
                else if (homeState.activeLearningPath != null ||
                    homeState.topics.isNotEmpty)
                  TextButton(
                    onPressed: () => context.go('/study-topics'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      context.tr(TranslationKeys.homeViewAll),
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Show Learning Path card if available with lock support
            if (homeState.activeLearningPath != null) ...[
              // "You're ready for..." label when proactively recommending a new path
              if (homeState.learningPathReason ==
                  LearningPathRecommendationReason.personalized) ...[
                Text(
                  "You're ready for your next step",
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.brandPrimaryLight.withOpacity(0.85)
                        : context.appBrandAccent,
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (homeState.learningPathReason ==
                  LearningPathRecommendationReason.offlineAvailable) ...[
                Row(
                  children: [
                    Icon(
                      Icons.download_done_rounded,
                      size: 13,
                      color: isDark
                          ? AppColors.brandPrimaryLight.withOpacity(0.85)
                          : context.appBrandAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Available offline',
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.brandPrimaryLight.withOpacity(0.85)
                            : context.appBrandAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              LockedFeatureWrapper(
                featureKey: 'learning_paths',
                child: LearningPathCard(
                  path: homeState.activeLearningPath!,
                  compact: false,
                  onTap: () =>
                      _navigateToLearningPath(homeState.activeLearningPath!.id),
                ),
              ),
            ]
            // Check if learning_paths is locked even when no data
            else if (_isLearningPathsLocked())
              LockedFeatureWrapper(
                featureKey: 'learning_paths',
                child: _buildPlaceholderLearningPathCard(),
              ),
            // No active learning path and nothing locked: the "Explore
            // Learning Paths" button above is the only call to action here.
            // This used to fall back to a grid of unrelated cross-category
            // topics (e.g. "Marriage and Faith" next to "Being the Light in
            // Your Community") with no connection to each other or to the
            // user — it read as generic filler rather than a personalized
            // recommendation, which is exactly what this section promises.
          ],
        );
      },
    );
  }

  /// Show Standard subscription bottom sheet
  void _showStandardSubscriptionSheet(BuildContext context) {
    final state = sl<SubscriptionBloc>().state;

    if (state is! UserSubscriptionStatusLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading subscription status...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    StandardSubscriptionSheet.show(
      context,
      status: state.subscriptionStatus,
    );
  }

  /// Navigate to the personalization questionnaire
  void _navigateToQuestionnaire() {
    context.push('/personalization-questionnaire').then((_) {
      // Ensure widget is still mounted before dispatching events
      if (!mounted) return;
      // Clear LearningPaths repository cache so Study Topics screen gets fresh data
      sl<LearningPathsRepository>().clearCache();
      // Refresh all personalization-dependent data after questionnaire completion
      sl<HomeBloc>().add(const LoadForYouTopics(forceRefresh: true));
      sl<HomeBloc>().add(const LoadActiveLearningPath(forceRefresh: true));
    });
  }

  /// Navigate to learning path detail and refresh on return.
  ///
  /// Uses `push`, not `go`: the detail route is a sibling of the
  /// `StatefulShellRoute` on the root navigator, so `go` unmatches the shell and
  /// disposes every branch navigator — this screen would be rebuilt from
  /// scratch on the way back. `push` keeps it mounted (URL still updates on
  /// web), and the pop result says whether a refresh is actually needed.
  Future<void> _navigateToLearningPath(String pathId) async {
    if (_isNavigating) return;
    _isNavigating = true;

    Logger.debug('[HOME] Navigating to learning path: $pathId');

    // Include source=home so a directly-opened deep link still has a sensible
    // back target.
    final progressChanged =
        await context.push<bool>('/learning-path/$pathId?source=home');

    _isNavigating = false;

    if (!mounted || progressChanged != true) return;
    sl<HomeBloc>().add(const LoadActiveLearningPath(forceRefresh: true));
  }

  bool _isLearningPathsLocked() {
    final tokenBloc = sl<TokenBloc>();
    final tokenState = tokenBloc.state;

    String userPlan = 'free';
    if (tokenState is TokenLoaded) {
      userPlan = tokenState.tokenStatus.userPlan.name;
    }

    final systemConfigService = sl<SystemConfigService>();
    return systemConfigService.isFeatureLocked('learning_paths', userPlan);
  }

  /// Build a placeholder learning path card to show with lock overlay
  Widget _buildPlaceholderLearningPathCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.appBrandAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.route_outlined,
                  color: context.appBrandAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(TranslationKeys.learningPathsTitle),
                      style: AppFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(TranslationKeys.learningPathsSubtitle),
                      style: AppFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Unlock structured learning journeys designed to deepen your faith and biblical understanding.',
            style: AppFonts.inter(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Upcoming Meeting Banner
// ---------------------------------------------------------------------------

/// Fetches all fellowships the user belongs to, collects today's upcoming
/// (or currently running) meetings across all of them, and surfaces the
/// single nearest meeting as a compact banner card.
///
/// Renders [SizedBox.shrink] when there are no meetings today.
class _UpcomingMeetingBanner extends StatefulWidget {
  const _UpcomingMeetingBanner();

  @override
  State<_UpcomingMeetingBanner> createState() => _UpcomingMeetingBannerState();
}

class _UpcomingMeetingBannerState extends State<_UpcomingMeetingBanner> {
  // Paired data: the nearest upcoming/ongoing meeting + its fellowship name + id.
  ({
    FellowshipMeetingEntity meeting,
    String fellowshipName,
    String fellowshipId,
  })? _upcoming;

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchUpcomingMeeting();
  }

  Future<void> _fetchUpcomingMeeting() async {
    try {
      final repo = sl<CommunityRepository>();
      final fellowshipsResult = await repo.getFellowships('en');
      final fellowships = fellowshipsResult.fold(
        (_) => <FellowshipEntity>[],
        (list) => list,
      );

      if (fellowships.isEmpty) {
        if (mounted) setState(() => _loaded = true);
        return;
      }

      final now = DateTime.now();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

      ({
        FellowshipMeetingEntity meeting,
        String fellowshipName,
        String fellowshipId,
      })? closest;

      // Fetch meetings for each fellowship; keep the nearest one ending after now.
      for (final fellowship in fellowships) {
        final result = await repo.getMeetings(fellowship.id);
        result.fold(
          (_) {},
          (meetings) {
            for (final m in meetings) {
              final start = DateTime.tryParse(m.startsAt)?.toLocal();
              final end = DateTime.tryParse(m.endsAt)?.toLocal();
              if (start == null || end == null) continue;
              // Only show meetings that: start today AND haven't ended yet.
              if (start.isBefore(endOfToday) && end.isAfter(now)) {
                final currentStart =
                    DateTime.tryParse(closest?.meeting.startsAt ?? '')
                        ?.toLocal();
                if (closest == null ||
                    currentStart == null ||
                    start.isBefore(currentStart)) {
                  closest = (
                    meeting: m,
                    fellowshipName: fellowship.name,
                    fellowshipId: fellowship.id,
                  );
                }
              }
            }
          },
        );
      }

      if (mounted) {
        setState(() {
          _upcoming = closest;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _upcoming == null) return const SizedBox.shrink();

    final data = _upcoming!;
    final meeting = data.meeting;
    final start = DateTime.tryParse(meeting.startsAt)?.toLocal();
    final end = DateTime.tryParse(meeting.endsAt)?.toLocal();
    final now = DateTime.now();

    final isHappeningNow =
        start != null && end != null && now.isAfter(start) && now.isBefore(end);
    final timeLabel = start == null
        ? ''
        : isHappeningNow
            ? 'Now · ends ${DateFormat('h:mm a').format(end)}'
            : DateFormat('h:mm a').format(start);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = meeting.meetLink.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => context.push('/community/${data.fellowshipId}'),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.brandPrimary.withValues(alpha: 0.12)
                : AppColors.brandPrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.brandPrimary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isOnline ? Icons.videocam_rounded : Icons.location_on_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),

              const SizedBox(width: 12),

              // Text content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (isHappeningNow) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            'Today',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meeting.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data.fellowshipName} · $timeLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Chevron
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: context.appTextTertiary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueBadge extends StatelessWidget {
  final int count;
  const _DueBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count >= 100 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
