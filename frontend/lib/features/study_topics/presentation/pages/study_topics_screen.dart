import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/study_mode_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/models/app_language.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/services/system_config_service.dart';
import '../../../../core/widgets/locked_feature_wrapper.dart';
import '../../../../core/widgets/upgrade_dialog.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/auth_state_provider.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../../home/presentation/bloc/home_bloc.dart';
import '../../../user_profile/data/services/user_profile_service.dart';
import '../../../user_profile/data/models/user_profile_model.dart';
import '../../../study_generation/domain/entities/study_mode.dart';
import '../../../subscription/domain/repositories/subscription_repository.dart';
import '../../../study_generation/presentation/widgets/mode_selection_sheet.dart';
import '../../domain/entities/learning_path.dart';
import '../../domain/entities/topic_progress.dart';
import '../bloc/continue_learning_bloc.dart';
import '../bloc/continue_learning_event.dart';
import '../bloc/continue_learning_state.dart';
import '../bloc/learning_paths_bloc.dart';
import '../bloc/learning_paths_event.dart';
import '../widgets/continue_learning_section.dart';
import '../widgets/learning_path_card.dart';
import '../widgets/learning_paths_section.dart';

/// Screen for browsing study topics with Continue Learning and Learning Paths.
///
/// Layout (top to bottom):
/// 1. Continue Learning - In-progress topics (primary focus)
/// 2. Learning Paths - Structured learning journeys
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
  late ContinueLearningBloc _continueLearningBloc;
  late LearningPathsBloc _learningPathsBloc;
  late LanguagePreferenceService _languageService;
  late SystemConfigService _systemConfigService;
  late SubscriptionRepository _subscriptionRepository;
  StreamSubscription<AppLanguage>? _languageSubscription;
  String _userPlan = 'free';
  bool _isLearningPathsFeatureEnabled = true; // Default to true until checked
  bool _isLeaderboardFeatureEnabled = true; // Default to true until checked

  @override
  void initState() {
    super.initState();
    // Create BLoCs without dispatching events yet
    _continueLearningBloc = sl<ContinueLearningBloc>();
    _learningPathsBloc = sl<LearningPathsBloc>();
    _languageService = sl<LanguagePreferenceService>();
    _systemConfigService = sl<SystemConfigService>();
    _subscriptionRepository = sl<SubscriptionRepository>();
    _loadLanguageAndInitialize();
    _setupLanguageChangeListener();
    _checkLearningPathsFeatureAccess();
  }

  /// Checks if Learning Paths and Leaderboard features are enabled based on feature flags and user's plan
  Future<void> _checkLearningPathsFeatureAccess() async {
    try {
      // Get user's current subscription plan
      final result = await _subscriptionRepository.getSubscriptionStatus();

      result.fold(
        (failure) {
          debugPrint(
              '⚠️ [STUDY_TOPICS] Failed to get subscription: ${failure.message}');
          _userPlan = 'free'; // Default to free on error
        },
        (subscription) {
          _userPlan = subscription.currentPlan;
          debugPrint('👤 [STUDY_TOPICS] User plan: $_userPlan');
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
        debugPrint(
            '🙈 [STUDY_TOPICS] Learning Paths hidden for plan $_userPlan');
      } else {
        debugPrint(
            '👀 [STUDY_TOPICS] Learning Paths visible for plan $_userPlan (may be locked)');
      }

      if (shouldHideLeaderboard) {
        debugPrint('🙈 [STUDY_TOPICS] Leaderboard hidden for plan $_userPlan');
      } else {
        debugPrint(
            '👀 [STUDY_TOPICS] Leaderboard visible for plan $_userPlan (may be locked)');
      }
    } catch (e) {
      debugPrint('❌ [STUDY_TOPICS] Error checking feature access: $e');
      // Default to enabled on error to avoid breaking existing users
      if (mounted) {
        setState(() {
          _isLearningPathsFeatureEnabled = true;
          _isLeaderboardFeatureEnabled = true;
        });
      }
    }
  }

  /// Listen for language preference changes from settings
  /// When app language changes, study content language is reset to default,
  /// so we need to refresh the content to reflect the new app language.
  void _setupLanguageChangeListener() {
    debugPrint('[STUDY_TOPICS] Setting up language change listener');

    // Cancel any existing subscription before creating a new one
    _languageSubscription?.cancel();

    // Store the subscription to ensure proper cleanup
    _languageSubscription =
        _languageService.languageChanges.listen((newLanguage) async {
      debugPrint(
          '[STUDY_TOPICS] App language changed to: ${newLanguage.displayName}');

      // When app language changes, study content language is automatically reset to default
      // Reload content with the new language
      if (mounted) {
        await _loadLanguageAndInitialize();
        debugPrint(
            '[STUDY_TOPICS] Content refreshed after app language change');
      }
    });
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

      // Check if user is authenticated (not anonymous/guest)
      // Guest users don't have continue learning data stored
      final authProvider = sl<AuthStateProvider>();
      final isGuest = authProvider.isAnonymous;

      // Only load continue learning for authenticated users
      if (!isGuest) {
        _continueLearningBloc.add(LoadContinueLearning(
          language: _currentLanguage,
          forceRefresh: true,
        ));
      }

      // Always load learning paths (available for all users)
      _learningPathsBloc.add(LoadLearningPaths(
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
    _languageSubscription?.cancel();
    _continueLearningBloc.close();
    _learningPathsBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: _continueLearningBloc,
          ),
          BlocProvider.value(
            value: _learningPathsBloc,
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

  const _StudyTopicsScreenContent({
    this.topicId,
    required this.currentLanguage,
    required this.languageLoaded,
    required this.dataLoadingStarted,
    required this.isLearningPathsFeatureEnabled,
    required this.isLeaderboardFeatureEnabled,
  });

  @override
  State<_StudyTopicsScreenContent> createState() =>
      _StudyTopicsScreenContentState();
}

class _StudyTopicsScreenContentState extends State<_StudyTopicsScreenContent> {
  // Track if we're currently navigating to prevent multiple navigations
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // Handle deep link navigation from notification
    if (widget.topicId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleTopicDeepLink(widget.topicId!);
      });
    }
  }

  /// Handle deep link to specific topic (e.g., from notification)
  void _handleTopicDeepLink(String topicId) async {
    debugPrint('[StudyTopics] Deep link detected for topic ID: $topicId');

    // Show mode selection sheet before navigating
    if (mounted) {
      final result = await ModeSelectionSheet.show(
        context: context,
        languageCode: widget.currentLanguage,
      );

      if (result != null && mounted) {
        final mode = result['mode'] as StudyMode;
        final rememberChoice = result['rememberChoice'] as bool;

        // Save user's mode preference if they chose to remember
        if (rememberChoice) {
          sl<LanguagePreferenceService>().saveStudyModePreference(mode);
        }

        final encodedTopicId = Uri.encodeComponent(topicId);
        context.go(
            '/study-guide-v2?input=&type=topic&language=${widget.currentLanguage}&mode=${mode.name}&source=deepLink&topic_id=$encodedTopicId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: () async {
          context
              .read<ContinueLearningBloc>()
              .add(RefreshContinueLearning(language: widget.currentLanguage));
          context
              .read<LearningPathsBloc>()
              .add(RefreshLearningPaths(language: widget.currentLanguage));
          // Wait for the refresh to complete
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: _buildBody(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return StudyTopicsAppBar(
      onLanguageChange: _handleStudyLanguageChange,
      showLeaderboard: widget.isLeaderboardFeatureEnabled,
    );
  }

  /// Handle study content language change and refresh content
  Future<void> _handleStudyLanguageChange() async {
    if (!mounted) return;

    final languageService = sl<LanguagePreferenceService>();
    final newLanguage = await languageService.getStudyContentLanguage();

    if (mounted) {
      // Refresh all content with new language using BLoC from context
      context
          .read<ContinueLearningBloc>()
          .add(RefreshContinueLearning(language: newLanguage.code));
      context
          .read<LearningPathsBloc>()
          .add(RefreshLearningPaths(language: newLanguage.code));
    }
  }

  Widget _buildBody(BuildContext context) {
    // Show loading state while waiting for language to load and BLoC events to be dispatched
    final showInitialLoading = !widget.dataLoadingStarted;

    // Check if user is a guest (anonymous) - don't show Continue Learning for guests
    final authProvider = sl<AuthStateProvider>();
    final isGuest = authProvider.isAnonymous;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section 1: Continue Learning (Primary Focus)
        // Hidden for guest users since we don't store their progress
        if (!isGuest)
          BlocBuilder<ContinueLearningBloc, ContinueLearningState>(
            builder: (context, state) {
              // Show loading if initial loading or BLoC is loading
              if (showInitialLoading || state is ContinueLearningLoading) {
                return ContinueLearningSection(
                  topics: const [],
                  onTopicTap: _navigateToStudyGuideFromContinueLearning,
                  isLoading: true,
                );
              } else if (state is ContinueLearningError) {
                return ContinueLearningSection(
                  topics: const [],
                  onTopicTap: _navigateToStudyGuideFromContinueLearning,
                  errorMessage: state.message,
                  onRetry: () => context.read<ContinueLearningBloc>().add(
                      RefreshContinueLearning(
                          language: widget.currentLanguage)),
                );
              } else if (state is ContinueLearningLoaded) {
                return ContinueLearningSection(
                  topics: state.topics,
                  onTopicTap: _navigateToStudyGuideFromContinueLearning,
                );
              }
              // ContinueLearningEmpty or Initial - section hides itself
              return ContinueLearningSection(
                topics: const [],
                onTopicTap: _navigateToStudyGuideFromContinueLearning,
              );
            },
          ),

        if (!isGuest) const SizedBox(height: 24),

        // Section 2: Learning Paths (Curated Learning Journeys)
        // Wrapped with LockedFeatureWrapper to support lock overlay
        LockedFeatureWrapper(
          featureKey: 'learning_paths',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show loading state if initial loading hasn't completed
              if (showInitialLoading)
                _buildLearningPathsLoadingState(context)
              else
                LearningPathsSection(
                  onPathTap: _navigateToLearningPath,
                  onRetry: () => context.read<LearningPathsBloc>().add(
                      RefreshLearningPaths(language: widget.currentLanguage)),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  /// Build loading state for Learning Paths section
  Widget _buildLearningPathsLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.route_outlined,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(TranslationKeys.learningPathsTitle),
                      style: AppFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      context.tr(TranslationKeys.learningPathsSubtitle),
                      style: AppFonts.inter(
                        fontSize: 12,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Loading skeletons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: const [
              LearningPathCardSkeleton(compact: false),
              SizedBox(height: 12),
              LearningPathCardSkeleton(compact: false),
            ],
          ),
        ),
      ],
    );
  }

  /// Navigate to study guide from Continue Learning section
  Future<void> _navigateToStudyGuideFromContinueLearning(
      InProgressTopic topic) async {
    // Prevent multiple clicks during navigation
    if (_isNavigating) {
      return;
    }

    debugPrint('🔍 [CONTINUE_LEARNING] Starting navigation...');
    debugPrint('🔍 Topic: ${topic.title}');
    debugPrint('🔍 Is from learning path: ${topic.isFromLearningPath}');
    debugPrint('🔍 Learning path name: ${topic.learningPathName}');
    debugPrint('🔍 Recommended mode raw: ${topic.recommendedMode}');

    // Parse recommended mode from topic if it's from a learning path
    StudyMode? recommendedMode;
    if (topic.recommendedMode != null) {
      recommendedMode = _parseStudyMode(topic.recommendedMode!);
      if (recommendedMode == null) {
        debugPrint(
            '⚠️ Invalid recommended mode: ${topic.recommendedMode}, defaulting to null');
      } else {
        debugPrint('✅ Parsed recommended mode: ${recommendedMode.displayName}');
      }
    }

    // Check if user has a saved study mode preference
    // For learning path topics, check learning_path_study_mode
    // For general topics, check default_study_mode
    String? savedModeRaw;

    if (topic.isFromLearningPath) {
      // Check learning path specific preference
      final authProvider = sl<AuthStateProvider>();
      savedModeRaw =
          authProvider.userProfile?['learning_path_study_mode'] as String?;
      debugPrint(
          '🔍 [CONTINUE_LEARNING] Learning path mode preference: "$savedModeRaw"');
    } else {
      // Check general preference for non-learning-path topics
      final languageService = sl<LanguagePreferenceService>();
      savedModeRaw = await languageService.getStudyModePreferenceRaw();
      debugPrint(
          '🔍 [CONTINUE_LEARNING] General mode preference: "$savedModeRaw"');
    }

    // If user selected "always use recommended" and topic has a recommended mode, use it directly
    debugPrint('🔍 Checking auto-use recommended conditions:');
    debugPrint(
        '   - savedModeRaw == "recommended": ${StudyModePreferences.isRecommended(savedModeRaw)}');
    debugPrint('   - topic.isFromLearningPath: ${topic.isFromLearningPath}');
    debugPrint('   - recommendedMode != null: ${recommendedMode != null}');

    if (StudyModePreferences.isRecommended(savedModeRaw) &&
        topic.isFromLearningPath &&
        recommendedMode != null) {
      debugPrint(
          '✅ [CONTINUE_LEARNING] Auto-using recommended mode: ${recommendedMode.displayName}');
      _isNavigating = true;
      await _navigateToStudyGuideWithMode(
          topic, recommendedMode, false); // No need to save again
      return;
    }

    // If user has a specific saved mode preference (not "ask every time" or "recommended"), use it
    if (StudyModePreferences.isSpecificMode(savedModeRaw,
        isLearningPath: topic.isFromLearningPath)) {
      final savedMode = _parseStudyMode(
          savedModeRaw!); // Safe: isSpecificMode guarantees non-null
      if (savedMode != null) {
        debugPrint(
            '✅ [CONTINUE_LEARNING] Using saved mode preference: ${savedMode.displayName}');
        _isNavigating = true;
        await _navigateToStudyGuideWithMode(
            topic, savedMode, false); // No need to save again
        return;
      }
    }

    // No saved preference or couldn't parse - show mode selection sheet
    debugPrint('📋 [CONTINUE_LEARNING] Showing mode selection sheet');
    final result = await ModeSelectionSheet.show(
      context: context,
      languageCode: widget.currentLanguage,
      recommendedMode: recommendedMode,
      isFromLearningPath: topic.isFromLearningPath,
      learningPathTitle: topic.learningPathName,
    );

    if (result != null && mounted) {
      final mode = result['mode'] as StudyMode;
      final rememberChoice = result['rememberChoice'] as bool? ?? false;
      final alwaysUseRecommended =
          result['alwaysUseRecommended'] as bool? ?? false;

      // Save preference if user checked a checkbox
      if (topic.isFromLearningPath) {
        // For learning path topics, save to learning_path_study_mode field
        if (alwaysUseRecommended) {
          final userProfileService = sl<UserProfileService>();
          final authProvider = sl<AuthStateProvider>();
          await userProfileService.updateLearningPathStudyModePreference(
              StudyModePreferences.recommended);

          // Update cache
          final userId = authProvider.userId;
          if (userId != null) {
            final currentProfile = authProvider.userProfile ?? {};
            currentProfile['learning_path_study_mode'] =
                StudyModePreferences.recommended;
            authProvider.cacheProfile(userId, currentProfile);
          }
          debugPrint(
              '[CONTINUE_LEARNING] Saved "always use recommended" to learning path preference');
        } else if (rememberChoice) {
          final userProfileService = sl<UserProfileService>();
          final authProvider = sl<AuthStateProvider>();
          await userProfileService
              .updateLearningPathStudyModePreference(mode.value);

          // Update cache
          final userId = authProvider.userId;
          if (userId != null) {
            final currentProfile = authProvider.userProfile ?? {};
            currentProfile['learning_path_study_mode'] = mode.value;
            authProvider.cacheProfile(userId, currentProfile);
          }
          debugPrint(
              '[CONTINUE_LEARNING] Saved "${mode.displayName}" to learning path preference');
        }
      } else {
        // For general topics, save to default_study_mode field
        final languageService = sl<LanguagePreferenceService>();
        if (rememberChoice) {
          await languageService.saveStudyModePreference(mode);
        } else if (alwaysUseRecommended) {
          await languageService
              .saveStudyModePreferenceRaw(StudyModePreferences.recommended);
        }
      }

      // Set navigation flag only when user actually selects a mode
      _isNavigating = true;
      await _navigateToStudyGuideWithMode(topic, mode, false);
    }
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

  /// Navigate to study guide with the selected mode
  Future<void> _navigateToStudyGuideWithMode(
    InProgressTopic topic,
    StudyMode mode,
    bool savePreference,
  ) async {
    // Save user's mode preference if they chose to remember or always use recommended
    if (savePreference) {
      sl<LanguagePreferenceService>().saveStudyModePreference(mode);
    }

    // Use the current language from the screen's state
    final languageCode = widget.currentLanguage;

    final encodedTitle = Uri.encodeComponent(topic.title);
    final encodedDescription = Uri.encodeComponent(topic.description);
    final topicIdParam =
        topic.topicId.isNotEmpty ? '&topic_id=${topic.topicId}' : '';
    final descriptionParam =
        topic.description.isNotEmpty ? '&description=$encodedDescription' : '';
    final pathIdParam =
        topic.learningPathId != null ? '&path_id=${topic.learningPathId}' : '';

    debugPrint(
        '[CONTINUE_LEARNING] Navigating to study guide V2 for topic: ${topic.title} with mode: ${mode.name}');

    // Use push() and await - when user returns, refresh the data
    await context.push(
        '/study-guide-v2?input=$encodedTitle&type=topic&language=$languageCode&mode=${mode.name}&source=continueLearning$topicIdParam$descriptionParam$pathIdParam');

    // Refresh data when returning from the study guide
    if (mounted) {
      context
          .read<ContinueLearningBloc>()
          .add(RefreshContinueLearning(language: widget.currentLanguage));
      context
          .read<LearningPathsBloc>()
          .add(RefreshLearningPaths(language: widget.currentLanguage));
      _isNavigating = false;
    }
  }

  /// Navigate to learning path detail page
  void _navigateToLearningPath(LearningPath path) {
    if (_isNavigating) return;
    _isNavigating = true;

    debugPrint(
        '[STUDY_TOPICS] Navigating to learning path: ${path.title} (ID: ${path.id})');

    // Use context.go() to properly update the browser URL
    // Include source=studyTopics so back button returns to study topics screen
    context.go('/learning-path/${path.id}?source=studyTopics');

    // Reset navigation flag after navigation completes
    Future.delayed(const Duration(milliseconds: 500), () {
      _isNavigating = false;
    });
  }
}

/// App bar widget for the Study Topics screen.
class StudyTopicsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onLanguageChange;
  final bool showLeaderboard;

  const StudyTopicsAppBar({
    super.key,
    this.onLanguageChange,
    this.showLeaderboard = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        // Move leaderboard icon to the left side - only show if feature is enabled
        leading: showLeaderboard
            ? IconButton(
                icon: const Icon(Icons.emoji_events_outlined),
                tooltip: context.tr(TranslationKeys.leaderboardTooltip),
                onPressed: () => _handleLeaderboardTap(context),
                color: Theme.of(context).colorScheme.onSurface,
              )
            : null,
        title: Text(
          context.tr(TranslationKeys.studyTopicsTitle),
          style: AppFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        // Add 3-dot menu to the right side
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: context.tr(TranslationKeys.moreOptionsTooltip),
            onSelected: (value) {
              if (value == 'language') {
                _showLanguageSelector(context, onLanguageChange);
              } else if (value == 'study_mode') {
                _showStudyModeSelector(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'language',
                child: Row(
                  children: [
                    const Icon(Icons.language),
                    const SizedBox(width: 12),
                    Text(
                        context.tr(TranslationKeys.studyTopicsContentLanguage)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'study_mode',
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome),
                    const SizedBox(width: 12),
                    Text(context.tr(TranslationKeys.studyModePreferenceTitle)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Show language selection bottom sheet for study content only
  /// This DOES NOT change the app UI language
  Future<void> _showLanguageSelector(
      BuildContext context, VoidCallback? onLanguageChange) async {
    final theme = Theme.of(context);
    final languageService = sl<LanguagePreferenceService>();
    final currentLanguage = await languageService.getStudyContentLanguage();
    final isDefault = await languageService.isStudyContentLanguageDefault();
    final appLanguage = await languageService.getSelectedLanguage();

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    context.tr(TranslationKeys.studyTopicsContentLanguage),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                        TranslationKeys.studyTopicsContentLanguageDescription),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Default option
            ListTile(
              title: Text(context
                  .tr(TranslationKeys.studyTopicsContentLanguageDefault)),
              subtitle: Text(
                '${context.tr(TranslationKeys.studyTopicsContentLanguageDefaultDescription)} (${appLanguage.displayName})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              trailing: isDefault
                  ? Icon(Icons.check, color: theme.colorScheme.primary)
                  : null,
              onTap: () async {
                // Set to default (use app language)
                await languageService.saveStudyContentLanguage(null);

                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }

                // Notify parent to refresh content
                onLanguageChange?.call();
              },
            ),
            const Divider(height: 1),
            // Specific language options
            ...AppLanguage.values.map((language) {
              final isSelected = !isDefault && language == currentLanguage;
              return ListTile(
                title: Text(language.displayName),
                trailing: isSelected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () async {
                  // Save study content language (does NOT affect app UI)
                  await languageService.saveStudyContentLanguage(language);

                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }

                  // Notify parent to refresh content
                  onLanguageChange?.call();
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Show learning path study mode preference bottom sheet
  void _showStudyModeSelector(BuildContext context) {
    // Get auth provider and check if user is anonymous
    final authProvider = sl<AuthStateProvider>();

    // Guard against anonymous users - preferences are only saved for signed-in users
    if (authProvider.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(TranslationKeys.settingsSignInToSavePreferences),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          action: SnackBarAction(
            label: context.tr(TranslationKeys.settingsSignIn),
            textColor: Theme.of(context).colorScheme.onPrimary,
            onPressed: () {
              AppRouter.router.goToLogin();
            },
          ),
        ),
      );
      return; // Exit early without showing the sheet
    }

    // Get current learning path mode preference
    final currentMode =
        authProvider.userProfile?['learning_path_study_mode'] as String?;

    // Capture parent context for snackbars after sheet closes
    final parentContext = context;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (builderContext) => Container(
        decoration: BoxDecoration(
          color: Theme.of(builderContext).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                context.tr(
                    TranslationKeys.settingsLearningPathStudyModePreference),
                style: AppFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(builderContext).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                    TranslationKeys.settingsLearningPathStudyModeDescription),
                style: AppFonts.inter(
                  fontSize: 14,
                  color: Theme.of(builderContext)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),

              // Option: Use Recommended
              _buildLearningPathModeOption(
                builderContext,
                parentContext,
                'recommended',
                context.tr(TranslationKeys.settingsUseRecommended),
                Icons.stars,
                context.tr(TranslationKeys.settingsUseRecommendedSubtitle),
                currentMode,
              ),
              const SizedBox(height: 12),

              // Option: Always Ask
              _buildLearningPathModeOption(
                builderContext,
                parentContext,
                'ask',
                context.tr(TranslationKeys.settingsAskEveryTime),
                Icons.help_outline,
                context.tr(TranslationKeys.settingsAskEveryTimeSubtitle),
                currentMode,
              ),
              const SizedBox(height: 12),

              // Divider
              Divider(
                  color: AppTheme.primaryColor.withOpacity(0.2), height: 24),

              // Specific modes (Quick, Standard, Deep, Lectio, Sermon)
              ...StudyMode.values.map((mode) => Column(
                    children: [
                      _buildLearningPathModeOption(
                        builderContext,
                        parentContext,
                        mode.value,
                        _getStudyModeTranslatedName(mode, context),
                        mode.iconData,
                        '${mode.durationText} • ${_getStudyModeTranslatedDescription(mode, context)}',
                        currentMode,
                      ),
                      const SizedBox(height: 12),
                    ],
                  )),
            ],
          ),
        ),
      ),
    );
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

  /// Build learning path mode option tile
  Widget _buildLearningPathModeOption(
    BuildContext sheetContext,
    BuildContext parentContext,
    String value,
    String label,
    IconData icon,
    String subtitle,
    String? currentMode,
  ) {
    final isSelected = value == currentMode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          // Update user profile with learning path study mode preference
          try {
            final userProfileService = sl<UserProfileService>();
            final authProvider = sl<AuthStateProvider>();

            final result = await userProfileService
                .updateLearningPathStudyModePreference(value);

            if (parentContext.mounted) {
              result.fold(
                (failure) {
                  // Close sheet on failure
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        parentContext
                            .tr(TranslationKeys.errorUpdatingPreference),
                      ),
                      backgroundColor:
                          Theme.of(parentContext).colorScheme.error,
                    ),
                  );
                },
                (profile) {
                  // Update AuthStateProvider cache with new profile
                  final userId = authProvider.userId;
                  if (userId != null) {
                    final profileMap =
                        UserProfileModel.fromEntity(profile).toJson();
                    authProvider.cacheProfile(userId, profileMap);
                  }

                  // Close sheet AFTER cache is updated
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }

                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        parentContext
                            .tr(TranslationKeys.preferenceUpdatedSuccessfully),
                      ),
                      backgroundColor:
                          Theme.of(parentContext).colorScheme.primary,
                    ),
                  );
                },
              );
            }
          } catch (e) {
            // Close sheet even on error
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }

            if (parentContext.mounted) {
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(
                  content: Text(
                    parentContext.tr(TranslationKeys.errorUpdatingPreference),
                  ),
                  backgroundColor: Theme.of(parentContext).colorScheme.error,
                ),
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.secondaryPurple.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.15)
                      : Theme.of(sheetContext)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Theme.of(sheetContext)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Theme.of(sheetContext).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppFonts.inter(
                        fontSize: 13,
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle leaderboard icon tap - check access and show upgrade dialog if needed
  void _handleLeaderboardTap(BuildContext context) {
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

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 15);
}
