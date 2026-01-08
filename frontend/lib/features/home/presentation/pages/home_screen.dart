import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/animations/app_animations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_utils.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/auth_state_provider.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/widgets/auth_protected_screen.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../domain/entities/recommended_guide_topic.dart';
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
import '../../../subscription/presentation/widgets/standard_subscription_banner.dart';
import '../../../subscription/presentation/widgets/standard_subscription_sheet.dart';
import '../../../subscription/presentation/widgets/upgrade_required_dialog.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../../tokens/domain/entities/token_status.dart';

import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../personalization/presentation/widgets/personalization_prompt_card.dart';
import '../../../study_generation/domain/entities/study_mode.dart';
import '../../../study_generation/presentation/widgets/mode_selection_sheet.dart';
import '../../../study_topics/domain/repositories/learning_paths_repository.dart';
import '../../../study_topics/presentation/widgets/learning_path_card.dart';

/// Home screen displaying daily verse, navigation options, and study recommendations.
///
/// Features app logo, verse of the day, main navigation, and predefined study topics
/// following the UX specifications and brand guidelines.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: sl<HomeBloc>(),
        child: const _HomeScreenContent(),
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

  @override
  void initState() {
    super.initState();
    _loadDailyVerse();
    _loadSubscriptionStatus();
    // Fire initial topics load once; HomeBloc is a singleton via DI
    final homeBloc = sl<HomeBloc>();
    final current = homeBloc.state;
    if (current is! HomeCombinedState || current.topics.isEmpty) {
      // Use LoadForYouTopics for authenticated users (bloc handles fallback)
      homeBloc.add(const LoadForYouTopics());
    }
    // Load active learning path for the For You section
    if (current is! HomeCombinedState || current.activeLearningPath == null) {
      homeBloc.add(const LoadActiveLearningPath());
    }
  }

  /// Load subscription status for Standard plan banner
  void _loadSubscriptionStatus() {
    final subscriptionBloc = sl<SubscriptionBloc>();
    subscriptionBloc.add(LoadSubscriptionStatus());
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
  /// - After 3+ day streak: Show streak reminder prompt
  /// - After 7+ day streak: Show streak milestone prompt
  Future<void> _showStreakNotificationPrompt(
      String languageCode, int currentStreak) async {
    if (_hasTriggeredStreakPrompt) return;

    // Only show streak prompts for meaningful streaks
    if (currentStreak < 3) return;

    _hasTriggeredStreakPrompt = true;

    // Delay to show after daily verse prompt (if shown)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Show streak reminder prompt at 3+ days
    // Show milestone prompt at 7+ days (includes streak lost notifications)
    final promptType = currentStreak >= 7
        ? NotificationPromptType.streakMilestone
        : NotificationPromptType.streakReminder;

    await showNotificationEnablePrompt(
      context: context,
      type: promptType,
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

      if (savedModeRaw == 'recommended') {
        // ✅ FIX: "Use Recommended" - automatically select Deep Dive for scripture without showing sheet
        debugPrint('✅ [HOME] Using recommended mode for scripture: Deep Dive');
        _navigateToDailyVerseStudy(currentState, StudyMode.deep, false);
      } else if (savedModeRaw != null) {
        // User has a specific saved preference - use it directly without showing sheet
        final savedMode = studyModeFromString(savedModeRaw);
        debugPrint('✅ [HOME] Using saved study mode: ${savedMode.name}');
        _navigateToDailyVerseStudy(currentState, savedMode, false);
      } else {
        // No saved preference (null) - show mode selection sheet with Deep Dive as recommended for scripture
        debugPrint(
            '🔍 [HOME] No saved preference - showing mode selection sheet with Deep Dive recommended');
        const recommendedMode = StudyMode.deep; // Scripture → Deep Dive

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
          _navigateToDailyVerseStudy(
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
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Navigate to daily verse study guide with selected mode
  void _navigateToDailyVerseStudy(
    DailyVerseState currentState,
    StudyMode mode,
    bool rememberChoice, {
    StudyMode? recommendedMode,
  }) {
    _isNavigating = true;

    // Save user's mode preference if they chose to remember
    if (rememberChoice) {
      // ✅ FIX: If user selected the recommended mode, save "recommended" instead of specific mode
      if (recommendedMode != null && mode == recommendedMode) {
        debugPrint(
            '✅ [HOME] Saving preference as "recommended" (selected mode matches recommended)');
        sl<LanguagePreferenceService>()
            .saveStudyModePreferenceRaw('recommended');
      } else {
        debugPrint('✅ [HOME] Saving preference as specific mode: ${mode.name}');
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

    final encodedReference = Uri.encodeComponent(verseReference);

    debugPrint(
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
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLargeScreen = screenHeight > 700;

    return BlocListener<DailyVerseBloc, DailyVerseState>(
      bloc: sl<DailyVerseBloc>(),
      listener: (context, state) {
        // Trigger notification prompts when daily verse loads successfully
        if (state is DailyVerseLoaded) {
          final languageCode = _getLanguageCode(state.currentLanguage);
          _showDailyVerseNotificationPrompt(languageCode);

          // Also check for streak and show streak notification prompt
          final streak = state.streak;
          if (streak != null && streak.currentStreak > 0) {
            _showStreakNotificationPrompt(languageCode, streak.currentStreak);
          }
        }
      },
      child: ListenableBuilder(
        listenable: sl<AuthStateProvider>(),
        builder: (context, _) {
          final authProvider = sl<AuthStateProvider>();
          final currentUserName = authProvider.currentUserName;

          if (kDebugMode) {
            print(
                '👤 [HOME] User loaded via AuthStateProvider: $currentUserName');
            print('👤 [HOME] Auth state: ${authProvider.debugInfo}');
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

                          SizedBox(height: isLargeScreen ? 32 : 24),

                          // Welcome Message
                          _buildWelcomeMessage(currentUserName),

                          SizedBox(height: isLargeScreen ? 16 : 12),

                          // Email Verification Banner (shown for unverified email users)
                          BlocProvider.value(
                            value: sl<AuthBloc>(),
                            child: const EmailVerificationBanner(),
                          ),

                          // Standard Subscription Banner (shown when trial ending/ended)
                          BlocBuilder<SubscriptionBloc, SubscriptionState>(
                            bloc: sl<SubscriptionBloc>(),
                            builder: (context, state) {
                              if (state is UserSubscriptionStatusLoaded &&
                                  state.subscriptionStatus
                                      .shouldShowSubscriptionBanner) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                      top: isLargeScreen ? 16 : 12),
                                  child: StandardSubscriptionBannerCompact(
                                    status: state.subscriptionStatus,
                                    onSubscribe: () =>
                                        _showStandardSubscriptionSheet(context),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                          SizedBox(height: isLargeScreen ? 16 : 12),

                          // Daily Verse Card with click functionality
                          DailyVerseCard(
                            margin: EdgeInsets.zero,
                            onTap: _onDailyVerseCardTap,
                          ),

                          SizedBox(height: isLargeScreen ? 24 : 20),

                          // Generate Study Guide Button
                          _buildGenerateStudyButton(),

                          SizedBox(height: isLargeScreen ? 32 : 24),

                          // Resume Last Study (conditional)
                          if (_hasResumeableStudy) ...[
                            _buildResumeStudyBanner(),
                            SizedBox(height: isLargeScreen ? 32 : 24),
                          ],

                          // Recommended Study Topics
                          _buildRecommendedTopics(),

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
    );
  }

  Widget _buildAppHeader() {
    return Row(
      children: [
        _buildLogoWidget(),
        const Spacer(),
        _buildMemoryVersesIconButton(),
        _buildSettingsButton(),
      ],
    );
  }

  Widget _buildMemoryVersesIconButton() {
    return IconButton(
      onPressed: () => _handleMemoryVersesTap(),
      icon: const Icon(
        Icons.psychology_outlined,
        color: AppTheme.onSurfaceVariant,
        size: 24,
      ),
      tooltip: context.tr(TranslationKeys.homeMemoryVerses),
    );
  }

  /// Handles tap on Memory Verses button - checks plan and shows upgrade dialog for free users
  void _handleMemoryVersesTap() {
    // Get user plan from TokenBloc (more reliable as it's loaded early)
    final tokenBloc = sl<TokenBloc>();
    final tokenState = tokenBloc.state;

    UserPlan? userPlan;
    if (tokenState is TokenLoaded) {
      userPlan = tokenState.tokenStatus.userPlan;
    }

    // Only allow Standard or Premium users
    final bool hasAccess =
        userPlan == UserPlan.standard || userPlan == UserPlan.premium;

    if (!hasAccess) {
      UpgradeRequiredDialog.show(
        context,
        featureName: 'Memory Verses',
        featureIcon: Icons.psychology_outlined,
        featureDescription:
            'Memorize Bible verses using proven spaced repetition techniques. Track your progress and strengthen your faith through scripture memorization.',
      );
      return;
    }

    // User is on Standard or Premium plan - proceed to Memory Verses
    context.go('/memory-verses');
  }

  Widget _buildLogoWidget() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDarkMode
        ? 'assets/images/app_logo_dark.png'
        : 'assets/images/app_logo.png';

    return Image.asset(
      logoAsset,
      width: 180,
      height: 40,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => _buildLogoFallback(),
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
      icon: const Icon(
        Icons.settings_outlined,
        color: AppTheme.onSurfaceVariant,
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

  Widget _buildGenerateStudyButton() {
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
          onTap: () => context.go('/generate-study'),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 24,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(
                context.tr(TranslationKeys.homeGenerateStudyGuide),
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
                      color: AppTheme.textPrimary,
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

        // Determine section title based on personalization state
        final sectionTitle = homeState.isPersonalized
            ? context.tr(TranslationKeys.homeForYou)
            : context.tr(TranslationKeys.homeExploreTopics);

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
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                      backgroundColor: isDark
                          ? AppTheme.primaryColor.withOpacity(0.15)
                          : const Color(0xFFF3F0FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      context.tr(TranslationKeys.homeViewAll),
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Show Learning Path card if available (for all user types)
            if (homeState.activeLearningPath != null)
              LearningPathCard(
                path: homeState.activeLearningPath!,
                compact: false,
                onTap: () =>
                    _navigateToLearningPath(homeState.activeLearningPath!.id),
              )
            // Fallback to topics grid only if no learning path is available
            else if (homeState.topicsError != null)
              _buildTopicsErrorWidget(homeState.topicsError!)
            else if (homeState.isLoadingTopics || homeState.isLoadingActivePath)
              _buildTopicsLoadingWidget()
            else if (homeState.topics.isEmpty)
              _buildNoTopicsWidget()
            else
              _buildTopicsGrid(homeState.topics),
          ],
        );
      },
    );
  }

  /// Show Standard subscription bottom sheet
  void _showStandardSubscriptionSheet(BuildContext context) {
    final subscriptionBloc = sl<SubscriptionBloc>();
    final state = subscriptionBloc.state;

    if (state is! UserSubscriptionStatusLoaded) {
      // If status not loaded yet, show a loading snackbar
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
      isLoading: state.isLoading,
      authorizationUrl: state.authorizationUrl,
      errorMessage: state.errorMessage,
      onCreateSubscription: () {
        subscriptionBloc.add(CreateStandardSubscription());
      },
      onClose: () {
        Navigator.of(context).pop();
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

  /// Navigate to learning path detail and refresh on return
  void _navigateToLearningPath(String pathId) {
    if (_isNavigating) return;
    _isNavigating = true;

    debugPrint('[HOME] Navigating to learning path: $pathId');

    // Use context.go() to properly update the browser URL
    // Include source=home so back button returns to home screen
    context.go('/learning-path/$pathId?source=home');

    // Reset navigation flag after navigation completes
    Future.delayed(const Duration(milliseconds: 500), () {
      _isNavigating = false;
    });
  }

  Widget _buildTopicsErrorWidget(String error) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppTheme.accentColor,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(TranslationKeys.homeFailedToLoadTopics),
              style: AppFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(TranslationKeys.homeSomethingWentWrong),
              style: AppFonts.inter(
                fontSize: 14,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context
                  .read<HomeBloc>()
                  .add(const RefreshRecommendedTopics()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(context.tr(TranslationKeys.homeTryAgain)),
            ),
          ],
        ),
      );

  Widget _buildTopicsLoadingWidget() =>
      const LearningPathCardSkeleton(compact: false);

  Widget _buildLoadingTopicCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Match the real card
          children: [
            // Header row skeleton
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 20,
                  width: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Title skeleton
            Container(
              height: 14,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            const SizedBox(height: 6),

            // Description skeleton
            Container(
              height: 11,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            const SizedBox(height: 4),

            Container(
              height: 11,
              width: MediaQuery.of(context).size.width * 0.6,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            const SizedBox(height: 12),

            // Footer skeleton
            Row(
              children: [
                Container(
                  height: 10,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 10,
                  width: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildNoTopicsWidget() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.topic_outlined,
              color: AppTheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(TranslationKeys.homeNoTopicsAvailable),
              style: AppFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(TranslationKeys.homeCheckConnection),
              style: AppFonts.inter(
                fontSize: 14,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildTopicsGrid(List<RecommendedGuideTopic> topics) {
    // Use column-based layout with IntrinsicHeight for uniform row heights
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate optimal card width (accounting for spacing)
        const double spacing = 16.0;

        // Group topics into pairs for rows
        final List<List<RecommendedGuideTopic>> rows = [];
        for (int i = 0; i < topics.length; i += 2) {
          rows.add(topics.skip(i).take(2).toList());
        }

        return Column(
          children: rows.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final rowTopics = entry.value;

            return Padding(
              padding: EdgeInsets.only(
                bottom: rowTopics != rows.last ? spacing : 0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // First topic in the row with stagger animation
                    Expanded(
                      child: FadeInWidget(
                        delay: AppAnimations.getStaggerDelay(rowIndex * 2),
                        slideOffset: const Offset(0, 0.1),
                        child: _RecommendedGuideTopicCard(
                          topic: rowTopics[0],
                          onTap: () => _navigateToStudyGuide(rowTopics[0]),
                        ),
                      ),
                    ),
                    // Second topic if available, otherwise spacer
                    if (rowTopics.length > 1) ...[
                      const SizedBox(width: spacing),
                      Expanded(
                        child: FadeInWidget(
                          delay:
                              AppAnimations.getStaggerDelay(rowIndex * 2 + 1),
                          slideOffset: const Offset(0, 0.1),
                          child: _RecommendedGuideTopicCard(
                            topic: rowTopics[1],
                            onTap: () => _navigateToStudyGuide(rowTopics[1]),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: spacing),
                      const Expanded(child: SizedBox()), // Empty space
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _navigateToStudyGuide(RecommendedGuideTopic topic) async {
    // Prevent multiple clicks during navigation
    if (_isNavigating) {
      return;
    }

    // Get current language preference for token cost calculation
    final selectedLanguage =
        await sl<LanguagePreferenceService>().getSelectedLanguage();

    // Show mode selection sheet before navigating
    final result = await ModeSelectionSheet.show(
      context: context,
      languageCode: selectedLanguage.code,
    );
    if (result != null && mounted) {
      _navigateToStudyGuideWithMode(
        topic,
        result['mode'] as StudyMode,
        result['rememberChoice'] as bool,
      );
    }
  }

  /// Navigate to study guide with selected mode
  void _navigateToStudyGuideWithMode(
    RecommendedGuideTopic topic,
    StudyMode mode,
    bool rememberChoice,
  ) {
    _isNavigating = true;

    // Save user's mode preference if they chose to remember
    if (rememberChoice) {
      sl<LanguagePreferenceService>().saveStudyModePreference(mode);
    }

    // Get the current language from Daily Verse state
    final dailyVerseBloc = context.read<DailyVerseBloc>();
    final currentState = dailyVerseBloc.state;

    VerseLanguage selectedLanguage =
        VerseLanguage.english; // Default to English
    if (currentState is DailyVerseLoaded) {
      selectedLanguage = currentState.currentLanguage;
    } else if (currentState is DailyVerseOffline) {
      selectedLanguage = currentState.currentLanguage;
    }

    final languageCode = _getLanguageCode(selectedLanguage);
    final encodedTitle = Uri.encodeComponent(topic.title);
    final encodedDescription = Uri.encodeComponent(topic.description);
    final topicIdParam = topic.id.isNotEmpty ? '&topic_id=${topic.id}' : '';
    final descriptionParam =
        topic.description.isNotEmpty ? '&description=$encodedDescription' : '';

    debugPrint(
        '🔍 [HOME] Navigating to study guide V2 for topic: ${topic.title} with mode: ${mode.name}');

    // Navigate directly to study guide V2 - it will handle generation
    context.go(
        '/study-guide-v2?input=$encodedTitle&type=topic&language=$languageCode&mode=${mode.name}&source=home$topicIdParam$descriptionParam');

    // Reset navigation flag after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    });
  }
}

/// Recommended guide topic card widget for API-based topics.
class _RecommendedGuideTopicCard extends StatefulWidget {
  final RecommendedGuideTopic topic;
  final VoidCallback onTap;

  const _RecommendedGuideTopicCard({
    required this.topic,
    required this.onTap,
  });

  @override
  State<_RecommendedGuideTopicCard> createState() =>
      _RecommendedGuideTopicCardState();
}

class _RecommendedGuideTopicCardState extends State<_RecommendedGuideTopicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.defaultCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final iconData = CategoryUtils.getIconForTopic(widget.topic);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Semantics(
          button: true,
          enabled: true,
          label: widget.topic.title,
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(
                minHeight: 160,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row with icon
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          iconData,
                          color: isDark
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF6B7280),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.topic.category,
                            style: AppFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white.withOpacity(0.7)
                                  : const Color(0xFF6B7280),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Title
                  Text(
                    widget.topic.title,
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withOpacity(0.9)
                          : const Color(0xFF1F2937),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Description
                  Expanded(
                    child: Text(
                      widget.topic.description,
                      style: AppFonts.inter(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                      maxLines: widget.topic.isFromLearningPath ? 3 : 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Learning path badge (if from a learning path)
                  if (widget.topic.isFromLearningPath) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.15)
                            : Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.route_outlined,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.topic.learningPathName ?? '',
                              style: AppFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget
                              .topic.formattedPositionInPath.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              widget.topic.formattedPositionInPath,
                              style: AppFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white.withOpacity(0.5)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
