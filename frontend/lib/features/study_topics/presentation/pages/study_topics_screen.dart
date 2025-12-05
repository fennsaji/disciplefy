import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/models/app_language.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../home/presentation/bloc/home_bloc.dart';
import '../../domain/entities/learning_path.dart';
import '../../domain/entities/topic_progress.dart';
import '../bloc/continue_learning_bloc.dart';
import '../bloc/continue_learning_event.dart';
import '../bloc/continue_learning_state.dart';
import '../bloc/learning_paths_bloc.dart';
import '../bloc/learning_paths_event.dart';
import '../widgets/continue_learning_section.dart';
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
  late ContinueLearningBloc _continueLearningBloc;
  late LearningPathsBloc _learningPathsBloc;
  late LanguagePreferenceService _languageService;
  StreamSubscription<AppLanguage>? _languageSubscription;

  @override
  void initState() {
    super.initState();
    // Create BLoCs without dispatching events yet
    _continueLearningBloc = sl<ContinueLearningBloc>();
    _learningPathsBloc = sl<LearningPathsBloc>();
    _languageService = sl<LanguagePreferenceService>();
    _loadLanguageAndInitialize();
    _setupLanguageChangeListener();
  }

  /// Listen for language preference changes from settings
  void _setupLanguageChangeListener() {
    debugPrint('[STUDY_TOPICS] Setting up language change listener');
    _languageSubscription = _languageService.languageChanges.listen(
      (AppLanguage newLanguage) {
        debugPrint(
            '[STUDY_TOPICS] Language change received: ${newLanguage.code}, current: $_currentLanguage');
        Logger.info(
          'Study Topics: Language changed to ${newLanguage.code}, refreshing content',
          tag: 'STUDY_TOPICS',
        );
        if (mounted && newLanguage.code != _currentLanguage) {
          debugPrint(
              '[STUDY_TOPICS] Refreshing content for language: ${newLanguage.code}');
          setState(() {
            _currentLanguage = newLanguage.code;
          });
          // Refresh all content with new language
          _continueLearningBloc
              .add(RefreshContinueLearning(language: newLanguage.code));
          _learningPathsBloc
              .add(RefreshLearningPaths(language: newLanguage.code));
        } else {
          debugPrint(
              '[STUDY_TOPICS] Skipping refresh - mounted: $mounted, same language: ${newLanguage.code == _currentLanguage}');
        }
      },
    );
  }

  Future<void> _loadLanguageAndInitialize() async {
    // PERFORMANCE FIX: Set languageLoaded immediately to unblock UI,
    // then update with actual language when available
    if (mounted && !_languageLoaded) {
      setState(() {
        _languageLoaded = true;
      });
    }

    final language = await _languageService.getSelectedLanguage();
    if (mounted) {
      setState(() {
        _currentLanguage = language.code;
      });
      // Always force refresh to ensure correct language content is loaded
      // This handles cases where the screen is kept alive by IndexedStack
      // but the language was changed while on another screen
      _continueLearningBloc.add(LoadContinueLearning(
        language: _currentLanguage,
        forceRefresh: true,
      ));
      _learningPathsBloc.add(LoadLearningPaths(
        language: _currentLanguage,
        forceRefresh: true,
      ));
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

  const _StudyTopicsScreenContent({
    this.topicId,
    required this.currentLanguage,
    required this.languageLoaded,
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

    // Navigate directly to study guide V2 with the topic ID
    if (mounted) {
      final encodedTopicId = Uri.encodeComponent(topicId);
      context.go(
          '/study-guide-v2?input=&type=topic&language=en&source=deepLink&topic_id=$encodedTopicId');
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
    return const StudyTopicsAppBar();
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Section 1: Continue Learning (Primary Focus)
        BlocBuilder<ContinueLearningBloc, ContinueLearningState>(
          builder: (context, state) {
            if (state is ContinueLearningLoading) {
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
                    RefreshContinueLearning(language: widget.currentLanguage)),
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

        const SizedBox(height: 24),

        // Section 2: Learning Paths (Curated Learning Journeys)
        LearningPathsSection(
          onPathTap: _navigateToLearningPath,
          onRetry: () => context
              .read<LearningPathsBloc>()
              .add(RefreshLearningPaths(language: widget.currentLanguage)),
        ),

        const SizedBox(height: 24),
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

    _isNavigating = true;

    // Use the current language from the screen's state (already loaded from LanguagePreferenceService)
    final languageCode = widget.currentLanguage;

    // Navigate directly to study guide V2
    final encodedTitle = Uri.encodeComponent(topic.title);
    final encodedDescription = Uri.encodeComponent(topic.description);
    final topicIdParam =
        topic.topicId.isNotEmpty ? '&topic_id=${topic.topicId}' : '';
    final descriptionParam =
        topic.description.isNotEmpty ? '&description=$encodedDescription' : '';
    final pathIdParam =
        topic.learningPathId != null ? '&path_id=${topic.learningPathId}' : '';

    debugPrint(
        '[CONTINUE_LEARNING] Navigating to study guide V2 for topic: ${topic.title} (ID: ${topic.topicId})');

    // Use push() and await - when user returns, refresh the data
    await context.push(
        '/study-guide-v2?input=$encodedTitle&type=topic&language=$languageCode&source=continueLearning$topicIdParam$descriptionParam$pathIdParam');

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
  const StudyTopicsAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr(TranslationKeys.studyTopicsTitle),
          style: AppFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: context.tr(TranslationKeys.leaderboardTooltip),
            onPressed: () => AppRouter.router.goToLeaderboard(),
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 15);
}
