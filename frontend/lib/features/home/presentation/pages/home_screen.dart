import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:disciplefy_bible_study/core/utils/path_icon_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import '../../../../features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/study_mode_preferences.dart';
import '../../../../core/animations/app_animations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/reader_palette.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/app_routes.dart';
import 'package:disciplefy_bible_study/core/router/guest_route_gate.dart';
import 'package:disciplefy_bible_study/core/utils/tap_guard.dart';
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
import '../../../subscription/presentation/widgets/standard_subscription_sheet.dart';
import '../../../subscription/presentation/widgets/upgrade_required_dialog.dart';
import '../../../subscription/presentation/widgets/insufficient_tokens_dialog.dart';
import '../../../study_generation/data/repositories/token_cost_repository.dart';
import '../../../subscription/presentation/services/usage_threshold_service.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../../tokens/domain/entities/token_status.dart';

import '../widgets/home_community_section.dart';
import '../widgets/home_sections.dart';
import '../widgets/home_verse_hero.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../personalization/presentation/widgets/personalization_prompt_card.dart';
import '../../../study_generation/domain/entities/study_mode.dart';
import '../../../study_generation/presentation/widgets/mode_selection_sheet.dart';
import '../../../community/domain/entities/fellowship_entity.dart';
import '../../../community/domain/entities/fellowship_meeting_entity.dart';
import '../../../community/domain/fellowship_changes.dart';
import '../../../community/domain/repositories/community_repository.dart';
import '../../../../core/error/failures.dart';
import 'package:dartz/dartz.dart' show Either;
import '../../../study_topics/domain/repositories/learning_paths_repository.dart';
import '../../../study_topics/presentation/widgets/learning_path_card.dart';
import '../../../../core/connectivity/connectivity_bloc.dart';
import '../../../onboarding/domain/first_run_flags.dart';
import '../../../walkthrough/domain/walkthrough_repository.dart';
import '../../../walkthrough/domain/walkthrough_screen.dart';
import '../../../walkthrough/presentation/showcase_keys.dart';
import '../../../walkthrough/presentation/walkthrough_tooltip.dart';
import 'package:disciplefy_bible_study/core/services/rollout_flags.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/home_today_layout.dart';
import 'package:disciplefy_bible_study/features/home/presentation/widgets/today/memory_pill_badge.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
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
              if (!ShowcaseKeys.triggerNavTabsAndCommunity()) {
                // No dock steps to show: the tour ends here.
                sl<WalkthroughRepository>().markSeen(WalkthroughScreen.home);
              }
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
  // Track if we're currently navigating to prevent multiple navigations
  /// Ignores a double tap on the verse Study and path rows. Never held
  /// across an awaited push: go_router may never complete it (Lesson
  /// complete → Back home), which would lock these taps for the session.
  final TapGuard _navGuard = TapGuard();

  // Track if we've already triggered the notification prompts this session
  bool _hasTriggeredDailyVersePrompt = false;
  bool _hasTriggeredStreakPrompt = false;
  bool _hasTriggeredStreakLostPrompt = false;

  // Usage stats bloc for soft paywall system
  late final UsageStatsBloc _usageStatsBloc;
  late final UsageThresholdService _usageThresholdService;

  /// Advances the showcase to the next step.
  ///
  /// Uses [this.context] which is [_HomeScreenContent]'s element context —
  /// a descendant of [ShowCaseWidget], so [ShowCaseWidget.of()] resolves correctly.
  VoidCallback get _onNext => () => ShowCaseWidget.of(context).next();

  /// Walkthrough targets, owned by this Home: two Homes can be mounted at
  /// once (e.g. while a page pushed over the shell goes back to Home), and
  /// shared keys would then collide.
  final GlobalKey _dailyVerseTarget = GlobalKey(debugLabel: 'homeDailyVerse');
  final GlobalKey _memoryVersesTarget =
      GlobalKey(debugLabel: 'homeMemoryVerses');

  /// The Today layout (rollout flag `home_today_layout`); off keeps the
  /// shipped Home.
  bool get _todayLayout {
    try {
      return sl.isRegistered<RolloutFlags>() &&
          sl<RolloutFlags>().homeTodayLayout;
    } catch (_) {
      return false;
    }
  }

  /// Whether the user was a guest when last checked, to load the memory
  /// deck once they create an account (a guest's Home never asks for it).
  bool _wasGuest = false;

  @override
  void initState() {
    super.initState();
    final todayLayout = _todayLayout;
    // Sync walkthrough seen state from Supabase (no-op for anonymous users)
    sl<WalkthroughRepository>().syncFromRemote();
    // The Today layout has no walkthrough targets of its own.
    if (!todayLayout) _triggerWalkthroughIfNeeded();
    _wasGuest = GuestRouteGate.currentUserIsGuest();
    sl<AuthStateProvider>().addListener(_onAuthChanged);
    _usageStatsBloc = sl<UsageStatsBloc>();
    _usageThresholdService = sl<UsageThresholdService>();
    _loadDailyVerse();
    _loadSubscriptionStatus();
    _loadUsageStats();
    // Language changes (app and study content) are handled by HomeBloc.
    final homeBloc = sl<HomeBloc>();
    // HomeBloc is a DI singleton that outlives a sign-out, so the path load
    // runs on every mount: the active path shows the cached copy for this
    // user and language at once while a fresh one (progress) is fetched.
    // Neither layout shows a "For You" topic list, so none is fetched.
    homeBloc.add(const LoadActiveLearningPath());
  }

  /// A guest who just created an account gets their memory deck (and the
  /// header's due count) without leaving Home.
  void _onAuthChanged() {
    if (!mounted) return;
    final guest = GuestRouteGate.currentUserIsGuest();
    if (_wasGuest && !guest) {
      try {
        context
            .read<MemoryVerseBloc>()
            .add(const LoadDueVerses(forceRefresh: true));
      } catch (e) {
        Logger.debug('[HOME] No memory deck to reload: $e');
      }
    }
    _wasGuest = guest;
  }

  /// Triggers the home screen walkthrough the first time the user sees this screen.
  Future<void> _triggerWalkthroughIfNeeded() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Set up the verse-loaded future FIRST so we don't miss the BLoC event
      // while the hasSeen check is awaiting. If already loaded this resolves
      // immediately; if still loading it captures the upcoming emission.
      final dailyVerseBloc = context.read<DailyVerseBloc>();
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

      // Only steps whose target is on screen: a missing target would stall
      // the tour with no tooltip to dismiss it.
      final keys = _buildWalkthroughKeys()
          .where((k) => k.currentContext != null)
          .toList();
      if (keys.isNotEmpty) {
        ShowcaseKeys.beginHomeTour(keys);
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

    // Body steps run in the home screen's own ShowCaseWidget.
    // The dock-tab steps (Generate / Discipler / Topics / Community) run in
    // the AppShell's ShowCaseWidget, triggered via ShowcaseKeys.triggerNavTabsAndCommunity().
    return [
      _dailyVerseTarget,
      if (showMemoryVerses) _memoryVersesTarget,
    ];
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

    if (!mounted || !await _homeWalkthroughDone()) return;

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

    if (!mounted || !await _homeWalkthroughDone()) return;

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

    if (!mounted || !await _homeWalkthroughDone()) return;

    await showNotificationEnablePrompt(
      context: context,
      type: NotificationPromptType.streakLost,
      languageCode: languageCode,
    );
  }

  /// Notification prompts wait for the first-run walkthrough: a bottom sheet
  /// opening over the walkthrough tooltips leaves two overlays fighting for
  /// the same tap. When the walkthrough is still due, the prompt is skipped
  /// for this session and offered on a later open.
  ///
  /// Also waits for lesson 1 on the quiet first run (see [FirstRunFlags]);
  /// existing users are never held back by that.
  Future<bool> _homeWalkthroughDone() async {
    if (!FirstRunFlags.notificationPromptsAllowed) return false;
    try {
      return await sl<WalkthroughRepository>().hasSeen(WalkthroughScreen.home);
    } catch (_) {
      return true;
    }
  }

  /// Load daily verse - called only once during initialization
  void _loadDailyVerse() {
    // Auto-load daily verse on home screen initialization
    // BLoC will handle caching and avoid redundant calls
    // The app-wide bloc from main.dart. DailyVerseBloc is a DI *factory*, so
    // sl<DailyVerseBloc>() would build a throwaway instance nobody watches.
    final bloc = context.read<DailyVerseBloc>();
    bloc.add(const LoadTodaysVerse());
  }

  /// Handle daily verse card tap to generate study guide
  Future<void> _onDailyVerseCardTap() async {
    // Prevent multiple clicks during navigation
    if (_navGuard.isLocked) {
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
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.homeVerseNotLoaded),
        tone: AppSnackTone.error,
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
    _navGuard.tryAcquire();

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
      _navGuard.release();
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
        _navGuard.release();
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
    _navGuard.dispose();
    sl<AuthStateProvider>().removeListener(_onAuthChanged);
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
        // Cached stats are only a placeholder: wait for the fresh response.
        if (state is UsageStatsLoaded && !state.isCached) {
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
            if (usageState is UsageStatsLoaded && !usageState.isCached) {
              _checkUsageThreshold(context, usageState.usageStats);
            }
          }
        },
        child: BlocListener<DailyVerseBloc, DailyVerseState>(
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
            // The rollout switches too, so the Today layout follows an
            // admin toggle once the config refreshes.
            listenable: Listenable.merge([
              sl<AuthStateProvider>(),
              if (sl.isRegistered<RolloutFlags>()) sl<RolloutFlags>(),
            ]),
            builder: (context, _) {
              final authProvider = sl<AuthStateProvider>();
              final currentUserName = authProvider.currentUserName;

              if (kDebugMode) {
                Logger.debug(
                    '👤 [HOME] User loaded via AuthStateProvider: $currentUserName');
                Logger.debug('👤 [HOME] Auth state: ${authProvider.debugInfo}');
              }

              const sectionPadding = EdgeInsets.symmetric(horizontal: 18);

              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                // The hero runs under the status bar; HomeScrollView covers
                // the status bar once the hero has scrolled away.
                body: SafeArea(
                  top: false,
                  // The page scrolls behind the floating dock; HomeScrollView
                  // pads its end by the bottom inset instead.
                  bottom: false,
                  child: HomeScrollView(
                    headerBuilder: (context, onGround) =>
                        _buildAppHeader(onGround: onGround),
                    children: _todayLayout
                        ? [
                            HomeTodayLayout(
                              hero: _buildHero(currentUserName,
                                  todayLayout: true),
                            ),
                          ]
                        : [
                            _buildHero(currentUserName),

                            // Upcoming meeting banner (today's meetings);
                            // collapses to nothing when there is none.
                            const Padding(
                              padding: sectionPadding,
                              child: _UpcomingMeetingBanner(),
                            ),

                            HomeEntrance(
                              index: 0,
                              child: Padding(
                                padding: sectionPadding,
                                child: _buildTodayTiles(),
                              ),
                            ),

                            const SizedBox(height: 26),

                            HomeEntrance(
                              index: 1,
                              child: Padding(
                                padding: sectionPadding,
                                child: _buildContinueLearning(),
                              ),
                            ),

                            const SizedBox(height: 26),

                            // What's happening in the user's fellowships, or
                            // an invitation to join one. Collapses to nothing
                            // while loading or on error.
                            const HomeEntrance(
                              index: 2,
                              child: Padding(
                                padding: sectionPadding,
                                child: HomeCommunitySection(),
                              ),
                            ),

                            SizedBox(height: isLargeScreen ? 32 : 24),
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

  /// The verse-of-the-day hero. [todayLayout]: its study action is the
  /// "Reflect on this verse" link.
  Widget _buildHero(String userName, {bool todayLayout = false}) {
    return HomeVerseHero(
      imageAsset: homeHeroImageFor(DateTime.now()),
      greeting: homeGreetingText(
        context.tr(homeGreetingKeyFor(DateTime.now().hour), {'name': userName}),
        userName,
      ),
      // The Today layout goes straight from the greeting to the verse.
      subtitle:
          todayLayout ? null : context.tr(TranslationKeys.homeContinueJourney),
      verse: _buildHeroVerse(todayLayout: todayLayout),
    );
  }

  /// The pinned header. [onGround]: it sits on the page colour (scrolled)
  /// rather than the hero photo; in light theme it then switches from white
  /// to dark so it stays readable.
  Widget _buildAppHeader({bool onGround = false}) {
    final onPhoto =
        !onGround || Theme.of(context).brightness == Brightness.dark;
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
    // width (full label); the logo image is left-aligned and shrinks only when
    // the header is genuinely tight. When the full label would squeeze the
    // logo below [_minLogoWidth] (small phone, long Hindi/Malayalam label),
    // the pill shows its icon alone, with the label as tooltip, rather than
    // a cut-off label.
    return LayoutBuilder(
      builder: (context, box) => _buildHeaderRow(
        onPhoto: onPhoto,
        showMemoryVerses: showMemoryVerses,
        compactPill: showMemoryVerses && !_memoryPillFits(box.maxWidth),
      ),
    );
  }

  static const double _minLogoWidth = 110;

  /// Room the pill needs besides its label: padding, icon and gap.
  static const double _memoryPillChrome = 8 + 18 + 6 + 12 + 2;

  /// Settings button plus the gaps around the pill.
  static const double _headerFixedWidth = 48 + 8 + 4;

  bool _memoryPillFits(double headerWidth) {
    if (!headerWidth.isFinite) return true;
    final label = TextPainter(
      text: TextSpan(
        text: context.tr(TranslationKeys.homeMemoryVerses),
        style: DefaultTextStyle.of(context)
            .style
            .merge(Theme.of(context).textTheme.labelLarge)
            .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final pill = _memoryPillChrome + label.width;
    label.dispose();
    return headerWidth - _headerFixedWidth - pill >= _minLogoWidth;
  }

  Widget _buildHeaderRow({
    required bool onPhoto,
    required bool showMemoryVerses,
    required bool compactPill,
  }) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            // The logo doubles as "back to top", like most app bars.
            onTap: HomeScrollToTop.instance.request,
            child: _buildLogoWidget(onPhoto: onPhoto),
          ),
        ),
        const SizedBox(width: 8),
        if (showMemoryVerses) ...[
          _walkthroughStep(
            showcaseKey: _memoryVersesTarget,
            title: AppLocalizations.of(context)!.walkthroughHomeMemoryTitle,
            description:
                AppLocalizations.of(context)!.walkthroughHomeMemoryDesc,
            stepNumber: 2,
            // Header element — prefer below (flips automatically if needed)
            tooltipPosition: TooltipPosition.bottom,
            child: _buildMemoryVersesIconButton(
              onPhoto: onPhoto,
              compact: compactPill,
            ),
          ),
          const SizedBox(width: 4),
        ],
        _buildSettingsButton(onPhoto: onPhoto),
      ],
    );
  }

  Widget _buildMemoryVersesIconButton({
    bool onPhoto = true,
    bool compact = false,
  }) {
    return BlocBuilder<MemoryVerseBloc, MemoryVerseState>(
      buildWhen: (_, current) => current is DueVersesLoaded,
      builder: (context, memState) {
        final isGuest = GuestRouteGate.currentUserIsGuest();
        // A guest has no deck (memory verses need an account): neutral pill
        // with a lock, never a badge.
        final dueCount = !isGuest && memState is DueVersesLoaded
            ? memState.verses.length
            : 0;
        // Today layout: a gold count, and only once a verse is saved.
        final todayLayout = _todayLayout;
        final goldCount = todayLayout
            ? memoryBadgeCount(
                savedCount: !isGuest && memState is DueVersesLoaded
                    ? memState.statistics.totalVerses
                    : 0,
                dueCount: dueCount,
              )
            : null;
        // White on the (always dark-shaded) photo; dark once the header is
        // on the light page colour.
        final pillColor = onPhoto ? Colors.white : AppColors.lightTextSecondary;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Plain OutlinedButton (not .icon) with a Flexible label so the
              // text ellipsizes when the header is tight — .icon leaves the
              // label unconstrained and it overflows instead.
              _withTooltip(
                compact ? context.tr(TranslationKeys.homeMemoryVerses) : null,
                OutlinedButton(
                  onPressed: _handleMemoryVersesTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pillColor,
                    side: BorderSide(
                      color: pillColor.withValues(alpha: 0.5),
                    ),
                    backgroundColor: pillColor.withValues(alpha: 0.12),
                    padding: compact
                        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                        : const EdgeInsets.fromLTRB(8, 6, 12, 6),
                    minimumSize: const Size(40, 36),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // A guest's lock takes the place of the icon, so the
                      // label keeps its room on a narrow phone.
                      if (isGuest)
                        const Icon(Icons.lock_outline,
                            key: Key('home_memory_pill_lock'), size: 16)
                      else
                        const Icon(Icons.psychology_outlined, size: 18),
                      if (!compact) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.tr(TranslationKeys.homeMemoryVerses),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (goldCount != null)
                Positioned(
                  top: -4,
                  right: -4,
                  child: MemoryPillBadge(count: goldCount),
                )
              else if (!todayLayout && dueCount > 0)
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

  Widget _withTooltip(String? message, Widget child) =>
      message == null ? child : Tooltip(message: message, child: child);

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
    // Memory verses need an account; Home opens the account-needed sheet.
    if (GuestRouteGate.currentUserIsGuest()) {
      context.go(GuestRouteGate.homeWithReason(AccountReasons.memoryVerses));
      return;
    }

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

  Widget _buildLogoWidget({bool onPhoto = true}) {
    // Dark-ground logo on the shaded photo; the regular one on a light page.
    final logoAsset = onPhoto
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
            AppColors.brandGold,
            AppColors.streakGlow,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.menu_book_rounded,
        color: ReaderPalette.ink,
        size: 24,
      ),
    );
  }

  Widget _buildSettingsButton({bool onPhoto = true}) {
    return IconButton(
      onPressed: () {
        context.go('/settings');
      },
      tooltip: context.tr(TranslationKeys.settingsTitle),
      icon: Icon(
        Icons.settings_outlined,
        color: onPhoto ? Colors.white : AppColors.lightTextSecondary,
        size: 24,
      ),
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
        // A refreshing state may still be the persisted balance: the
        // listener re-runs this once the fresh status arrives.
        if (tokenState is! TokenLoaded || tokenState.isRefreshing) {
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

  /// Wraps [child] as a step of the home walkthrough. The Today layout runs
  /// no walkthrough, so there it is [child] alone.
  Widget _walkthroughStep({
    required GlobalKey showcaseKey,
    required String title,
    required String description,
    required int stepNumber,
    TooltipPosition tooltipPosition = TooltipPosition.top,
    required Widget child,
  }) {
    if (_todayLayout) return child;
    return WalkthroughTooltip(
      showcaseKey: showcaseKey,
      title: title,
      description: description,
      screen: WalkthroughScreen.home,
      stepNumber: stepNumber,
      totalSteps: 6,
      onNext: _onNext,
      tooltipPosition: tooltipPosition,
      child: child,
    );
  }

  /// Verse of the day inside the hero. Hidden entirely by the
  /// bible_content_enabled kill-switch; greyed and locked like every other
  /// gated feature when the plan does not include it.
  Widget _buildHeroVerse({bool todayLayout = false}) {
    if (!sl<SystemConfigService>().isBibleContentEnabled) {
      return const SizedBox.shrink();
    }
    return _walkthroughStep(
      showcaseKey: _dailyVerseTarget,
      title: AppLocalizations.of(context)!.walkthroughHomeDailyVerseTitle,
      description: AppLocalizations.of(context)!.walkthroughHomeDailyVerseDesc,
      stepNumber: 1,
      child: LockedFeatureWrapper(
        featureKey: 'daily_verse',
        child: HomeDailyVerse(
          onStudy: _onDailyVerseCardTap,
          todayLayout: todayLayout,
        ),
      ),
    );
  }

  /// Streak and memory-review tiles. The review tile follows the same
  /// display_mode rule as the Memory Verses pill in the header.
  Widget _buildTodayTiles() {
    final tokenState = sl<TokenBloc>().state;
    final userPlan = tokenState is TokenLoaded
        ? tokenState.tokenStatus.userPlan.name
        : 'free';
    final showReview =
        !sl<SystemConfigService>().shouldHideFeature('memory_verses', userPlan);

    return BlocBuilder<DailyVerseBloc, DailyVerseState>(
      builder: (context, verseState) {
        final streakDays = verseState is DailyVerseLoaded
            ? (verseState.streak?.currentStreak ?? 0)
            : 0;
        return BlocBuilder<MemoryVerseBloc, MemoryVerseState>(
          // Keep the last count through transient states (adding, reloading)
          // rather than dropping to "all caught up" for a moment.
          buildWhen: (_, current) => current is DueVersesLoaded,
          builder: (context, memState) {
            final due =
                memState is DueVersesLoaded ? memState.verses : const [];
            return HomeTodayTiles(
              streakDays: streakDays,
              dueCount: due.length,
              nextReviewReference:
                  due.isNotEmpty ? due.first.verseReference : null,
              showReview: showReview,
              onStreakTap: () => context.push(AppRoutes.statsDashboard),
              onReviewTap: _handleMemoryVersesTap,
            );
          },
        );
      },
    );
  }

  /// "Continue learning": the user's active path as a ring row, or a row
  /// that opens the path catalogue when there is none. Replaces the old
  /// "For You" block and the separate Explore Learning Paths button.
  Widget _buildContinueLearning() {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        final homeState =
            state is HomeCombinedState ? state : const HomeCombinedState();
        final path = homeState.activeLearningPath;
        final accentIcon = ReaderPalette.of(context).accentIcon;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (homeState.showPersonalizationPrompt) ...[
              PersonalizationPromptCard(
                onGetStarted: () => _navigateToQuestionnaire(),
                onSkip: () => context
                    .read<HomeBloc>()
                    .add(const DismissPersonalizationPrompt()),
              ),
              const SizedBox(height: 20),
            ],
            HomeSectionHeader(
              title: context.tr(TranslationKeys.homeContinueLearning),
              subtitle: path != null &&
                      homeState.learningPathReason ==
                          LearningPathRecommendationReason.personalized
                  ? context.tr(TranslationKeys.homeReadyForNextStep)
                  : path != null &&
                          homeState.learningPathReason ==
                              LearningPathRecommendationReason.offlineAvailable
                      ? context.tr(TranslationKeys.homeAvailableOffline)
                      : null,
              actionLabel: context.tr(TranslationKeys.homeAllPaths),
              onAction: () => context.go(AppRoutes.studyTopics),
              trailing: homeState.isLoadingActivePath && path == null
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(context.appAccent),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            if (path != null)
              LockedFeatureWrapper(
                featureKey: 'learning_paths',
                child: HomePathRow(
                  key: const Key('home_active_path_row'),
                  title: path.displayTitle,
                  subtitle: homePathSubtitle(context, path),
                  progress: path.progressPercentage / 100,
                  accent: homePathAccent(context, path),
                  ringIcon: iconForPath(path.iconName, category: path.category),
                  onTap: () => _navigateToLearningPath(path.id),
                ),
              )
            else if (_isLearningPathsLocked())
              LockedFeatureWrapper(
                featureKey: 'learning_paths',
                child: const HomeLockedPathsCard(),
              )
            else
              HomePathRow(
                key: const Key('home_browse_paths_row'),
                title: context.tr(TranslationKeys.homeBrowsePaths),
                subtitle: context.tr(TranslationKeys.homeBrowsePathsHint),
                progress: 0,
                icon: Icons.explore_outlined,
                accent: accentIcon,
                onTap: () => context.go(AppRoutes.studyTopics),
              ),
          ],
        );
      },
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
    if (!_navGuard.tryAcquire()) return;

    Logger.debug('[HOME] Navigating to learning path: $pathId');

    // Include source=home so a directly-opened deep link still has a sensible
    // back target.
    final progressChanged =
        await context.push<bool>('/learning-path/$pathId?source=home');

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
}

// ---------------------------------------------------------------------------
// Upcoming Meeting Banner
// ---------------------------------------------------------------------------

/// Fetches all fellowships the user belongs to, collects today's upcoming
/// (or currently running) meetings across all of them, and surfaces the
/// single nearest meeting as a compact banner card.
///
/// Renders [SizedBox.shrink] when there are no meetings today.
/// Meetings for each of [fellowships], requested concurrently; results are in
/// the same order as [fellowships].
@visibleForTesting
Future<List<Either<Failure, List<FellowshipMeetingEntity>>>>
    fetchMeetingsInParallel(
  CommunityRepository repo,
  List<FellowshipEntity> fellowships,
) =>
        Future.wait(fellowships.map((f) => repo.getMeetings(f.id)));

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
    FellowshipChanges.instance.addListener(_fetchUpcomingMeeting);
  }

  @override
  void dispose() {
    FellowshipChanges.instance.removeListener(_fetchUpcomingMeeting);
    super.dispose();
  }

  Future<void> _fetchUpcomingMeeting() async {
    // Fellowships need an account: a guest has no meetings to show.
    if (GuestRouteGate.currentUserIsGuest()) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    try {
      final repo = sl<CommunityRepository>();
      // Content language, matching every other getFellowships caller — the
      // parameter picks a learning-path title translation, it does not filter
      // which fellowships are returned.
      String language = 'en';
      try {
        final resolved =
            await sl<LanguagePreferenceService>().getStudyContentLanguage();
        language = resolved.code;
      } catch (_) {
        // Keep the English default and still attempt the fetch.
      }

      final fellowshipsResult = await repo.getFellowships(language);
      // A failed lookup is not the same as belonging to no fellowship:
      // folding the error into an empty list makes today's meeting silently
      // disappear from Home as though none were scheduled.
      final fellowships = fellowshipsResult.fold<List<FellowshipEntity>?>(
        (_) => null,
        (list) => list,
      );

      if (fellowships == null || fellowships.isEmpty) {
        // Clear any meeting from a group the user has since left.
        if (mounted) {
          setState(() {
            if (fellowships != null) _upcoming = null;
            _loaded = true;
          });
        }
        return;
      }

      final now = DateTime.now();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

      ({
        FellowshipMeetingEntity meeting,
        String fellowshipName,
        String fellowshipId,
      })? closest;

      // Fetch meetings for every fellowship in parallel; keep the nearest one
      // ending after now (results are walked in list order, as before).
      final results = await fetchMeetingsInParallel(repo, fellowships);
      for (var i = 0; i < fellowships.length; i++) {
        final fellowship = fellowships[i];
        final result = results[i];
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
    final timeFormat = DateFormat('h:mm a');
    final timeLabel = start == null
        ? context.tr(TranslationKeys.homeMeetingToday)
        : isHappeningNow
            ? context.tr(TranslationKeys.homeMeetingNowEnds,
                {'time': timeFormat.format(end)})
            : context.tr(TranslationKeys.homeMeetingTodayAt,
                {'time': timeFormat.format(start)});

    final palette = ReaderPalette.of(context);
    final isOnline = meeting.meetLink.isNotEmpty;
    final accent = palette.accentIcon;
    final surface = palette.card;
    final border =
        isHappeningNow ? accent.withValues(alpha: 0.6) : palette.hairline;
    final textPrimary = palette.text;
    final textMuted = palette.muted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('home_meeting_banner'),
          onTap: () => context.push('/community/${data.fellowshipId}'),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isOnline
                        ? Icons.videocam_outlined
                        : Icons.location_on_outlined,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isHappeningNow) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                // White on the brighter red is 3.8:1.
                                color: AppColors.errorDark,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                context.tr(TranslationKeys.homeMeetingLive),
                                style: AppFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              timeLabel,
                              style: AppFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meeting.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        data.fellowshipName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.inter(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: textMuted, size: 18),
              ],
            ),
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
        // White on Red-500 is 3.8:1; on Red-800 it is 8.3:1.
        color: AppColors.errorDark,
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
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
