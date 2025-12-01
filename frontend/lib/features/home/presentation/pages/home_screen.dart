import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_utils.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/auth_state_provider.dart';
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

import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../personalization/presentation/widgets/personalization_prompt_card.dart';
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
  void _onDailyVerseCardTap() {
    // Prevent multiple clicks during navigation
    if (_isNavigating) {
      return;
    }

    // Get the current DailyVerseBloc state
    final dailyVerseBloc = context.read<DailyVerseBloc>();
    final currentState = dailyVerseBloc.state;

    if (currentState is DailyVerseLoaded) {
      _isNavigating = true;

      final verseReference = currentState.verse.reference;
      final languageCode = _getLanguageCode(currentState.currentLanguage);
      final encodedReference = Uri.encodeComponent(verseReference);

      debugPrint(
          '🔍 [HOME] Navigating to study guide V2 for daily verse: $verseReference');

      // Navigate directly to study guide V2 - it will handle generation
      context.go(
          '/study-guide-v2?input=$encodedReference&type=scripture&language=$languageCode&source=home');

      // Reset navigation flag after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isNavigating = false;
          });
        }
      });
    } else if (currentState is DailyVerseOffline) {
      _isNavigating = true;

      final verseReference = currentState.verse.reference;
      final languageCode = _getLanguageCode(currentState.currentLanguage);
      final encodedReference = Uri.encodeComponent(verseReference);

      debugPrint(
          '🔍 [HOME] Navigating to study guide V2 for daily verse (offline): $verseReference');

      // Navigate directly to study guide V2 - it will handle generation
      context.go(
          '/study-guide-v2?input=$encodedReference&type=scripture&language=$languageCode&source=home');

      // Reset navigation flag after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isNavigating = false;
          });
        }
      });
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

                          SizedBox(height: isLargeScreen ? 32 : 24),

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
      onPressed: () => context.go('/memory-verses'),
      icon: const Icon(
        Icons.psychology_outlined,
        color: AppTheme.onSurfaceVariant,
        size: 24,
      ),
      tooltip: context.tr(TranslationKeys.homeMemoryVerses),
    );
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
        final double cardWidth = (constraints.maxWidth - spacing) / 2;

        // Group topics into pairs for rows
        final List<List<RecommendedGuideTopic>> rows = [];
        for (int i = 0; i < topics.length; i += 2) {
          rows.add(topics.skip(i).take(2).toList());
        }

        return Column(
          children: rows
              .map((rowTopics) => Padding(
                    padding: EdgeInsets.only(
                      bottom: rowTopics != rows.last ? spacing : 0,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // First topic in the row
                          Expanded(
                            child: _RecommendedGuideTopicCard(
                              topic: rowTopics[0],
                              onTap: () => _navigateToStudyGuide(rowTopics[0]),
                            ),
                          ),
                          // Second topic if available, otherwise spacer
                          if (rowTopics.length > 1) ...[
                            const SizedBox(width: spacing),
                            Expanded(
                              child: _RecommendedGuideTopicCard(
                                topic: rowTopics[1],
                                onTap: () =>
                                    _navigateToStudyGuide(rowTopics[1]),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: spacing),
                            const Expanded(child: SizedBox()), // Empty space
                          ],
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  void _navigateToStudyGuide(RecommendedGuideTopic topic) {
    // Prevent multiple clicks during navigation
    if (_isNavigating) {
      return;
    }

    _isNavigating = true;

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
        '🔍 [HOME] Navigating to study guide V2 for topic: ${topic.title} (ID: ${topic.id})');

    // Navigate directly to study guide V2 - it will handle generation
    context.go(
        '/study-guide-v2?input=$encodedTitle&type=topic&language=$languageCode&source=home$topicIdParam$descriptionParam');

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
class _RecommendedGuideTopicCard extends StatelessWidget {
  final RecommendedGuideTopic topic;
  final VoidCallback onTap;

  const _RecommendedGuideTopicCard({
    required this.topic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = CategoryUtils.getIconForTopic(topic);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      enabled: true,
      label: topic.title,
      child: Container(
        decoration: BoxDecoration(
          color:
              isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
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
                            topic.category,
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
                    topic.title,
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
                      topic.description,
                      style: AppFonts.inter(
                        fontSize: 13,
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : const Color(0xFF6B7280),
                        height: 1.5,
                      ),
                      maxLines: topic.isFromLearningPath ? 3 : 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Learning path badge (if from a learning path)
                  if (topic.isFromLearningPath) ...[
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
                              topic.learningPathName ?? '',
                              style: AppFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (topic.formattedPositionInPath.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              topic.formattedPositionInPath,
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
