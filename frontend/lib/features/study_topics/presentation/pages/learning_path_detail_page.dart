import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/constants/study_mode_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/connectivity/connectivity_bloc.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/services/auth_state_provider.dart';
import '../../../../core/utils/category_utils.dart';
import '../../../study_generation/domain/entities/study_mode.dart';
import '../../../study_generation/presentation/widgets/mode_selection_sheet.dart';
import '../../../subscription/presentation/widgets/insufficient_tokens_dialog.dart';
import '../../../study_generation/data/repositories/token_cost_repository.dart';
import '../../../study_generation/data/datasources/study_local_data_source.dart';
import '../../../tokens/presentation/bloc/token_bloc.dart';
import '../../../tokens/presentation/bloc/token_state.dart';
import '../../../user_profile/data/services/user_profile_service.dart';
import '../../../user_profile/data/models/user_profile_model.dart';
import '../../data/models/learning_path_download_model.dart';
import '../../data/services/learning_path_download_service.dart';
import '../../domain/entities/learning_path.dart';
import '../bloc/learning_paths_bloc.dart';
import '../bloc/learning_paths_event.dart';
import '../bloc/learning_paths_state.dart';
import '../../../../core/utils/logger.dart';

/// Detail page for a learning path showing topics and progress.
class LearningPathDetailPage extends StatefulWidget {
  /// The learning path ID.
  final String pathId;

  /// Optional pre-loaded path data for immediate display.
  final LearningPath? initialPath;

  /// Navigation source to determine back button behavior.
  /// 'home' = navigate back to home, 'studyTopics' = navigate to study topics
  final String? source;

  const LearningPathDetailPage({
    super.key,
    required this.pathId,
    this.initialPath,
    this.source,
  });

  @override
  State<LearningPathDetailPage> createState() => _LearningPathDetailPageState();
}

class _LearningPathDetailPageState extends State<LearningPathDetailPage> {
  String _currentLanguage = 'en';
  LearningPathDownloadModel? _downloadModel;
  StreamSubscription<LearningPathDownloadModel>? _downloadSub;

  @override
  void initState() {
    super.initState();
    _loadLanguageAndPathDetails();
    _subscribeToDownloadState();
  }

  void _subscribeToDownloadState() {
    _downloadSub = sl<LearningPathDownloadService>()
        .watchDownload(widget.pathId)
        .listen((model) {
      if (mounted) setState(() => _downloadModel = model);
    });
    // Sync current state immediately (stream only emits on change)
    final current =
        sl<LearningPathDownloadService>().getDownload(widget.pathId);
    if (current != null) setState(() => _downloadModel = current);
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  Future<void> _loadLanguageAndPathDetails() async {
    final languageService = sl<LanguagePreferenceService>();
    // Use study content language (not global app language)
    final language = await languageService.getStudyContentLanguage();
    if (mounted) {
      setState(() {
        _currentLanguage = language.code;
      });
      _loadPathDetails();
    }
  }

  void _loadPathDetails({bool forceRefresh = false}) {
    context.read<LearningPathsBloc>().add(
          LoadLearningPathDetails(
            pathId: widget.pathId,
            language: _currentLanguage,
            forceRefresh: forceRefresh,
          ),
        );
  }

  /// Navigate to topic and refresh on return
  Future<void> _navigateToTopic(
      LearningPathTopic topic, LearningPathDetail path) async {
    // Auto-enroll if not enrolled yet
    if (!path.isEnrolled) {
      Logger.debug(
          '[LEARNING_PATH_DETAIL] Auto-enrolling user in path: ${path.title}');
      context
          .read<LearningPathsBloc>()
          .add(EnrollInLearningPath(pathId: path.id));
    }

    // Get learning path study mode preference from Settings
    final authProvider = sl<AuthStateProvider>();
    final languageService = sl<LanguagePreferenceService>();
    final learningPathModePreference =
        languageService.getLearningPathStudyModePreferenceRaw();

    StudyMode? selectedMode;

    // Determine mode based on preference
    if (StudyModePreferences.isRecommended(learningPathModePreference)) {
      // Use path's recommended mode
      selectedMode =
          studyModeFromString(path.recommendedMode) ?? StudyMode.standard;
      Logger.debug(
          '[LEARNING_PATH_DETAIL] Using recommended mode: ${selectedMode.name}');
      await _navigateToTopicWithMode(topic, path, selectedMode, false);
    } else if (StudyModePreferences.isSpecificMode(learningPathModePreference,
        isLearningPath: true)) {
      // Use specific mode from settings (quick, standard, deep, lectio)
      selectedMode =
          studyModeFromString(learningPathModePreference) ?? StudyMode.standard;
      Logger.debug(
          '[LEARNING_PATH_DETAIL] Using specific mode from settings: ${selectedMode.name}');
      await _navigateToTopicWithMode(topic, path, selectedMode, false);
    } else {
      // No saved preference — check connectivity before showing the sheet.
      // When offline, skip the sheet and use the best available mode:
      //   1. General study mode preference (if saved locally)
      //   2. Path's recommended mode
      final isOffline =
          context.read<ConnectivityBloc>().state is ConnectivityOffline;
      if (isOffline) {
        final generalPref = await languageService.getStudyModePreferenceRaw();
        selectedMode = studyModeFromString(generalPref) ??
            studyModeFromString(path.recommendedMode) ??
            StudyMode.standard;
        Logger.debug(
            '[LEARNING_PATH_DETAIL] Offline – using mode without sheet: ${selectedMode.name}');
        await _navigateToTopicWithMode(topic, path, selectedMode, false);
        return;
      }

      // Online: show mode selection sheet
      Logger.debug(
          '[LEARNING_PATH_DETAIL] Showing mode selection sheet with recommended mode');

      final recommendedMode =
          studyModeFromString(path.recommendedMode) ?? StudyMode.standard;

      // Get study content language preference for token cost calculation
      // Uses study content language (not app UI language)
      final selectedLanguage =
          await sl<LanguagePreferenceService>().getStudyContentLanguage();

      final result = await ModeSelectionSheet.show(
        context: context,
        languageCode: selectedLanguage.code,
        recommendedMode: recommendedMode,
        isFromLearningPath: true,
        learningPathTitle: path.title,
      );

      if (result == null) return; // User cancelled

      selectedMode = result['mode'] as StudyMode;

      // Save "always use recommended" preference if checked
      if (result['alwaysUseRecommended'] == true) {
        final userProfileService = sl<UserProfileService>();
        await userProfileService
            .updateLearningPathStudyModePreference('recommended');
        // Persist locally so it survives cold-start offline
        await languageService
            .cacheLearningPathStudyModePreference('recommended');

        // Update cached profile
        final userId = authProvider.userId;
        if (userId != null) {
          final currentProfile = authProvider.userProfile ?? {};
          currentProfile['learning_path_study_mode'] = 'recommended';
          authProvider.cacheProfile(userId, currentProfile);
        }

        Logger.debug(
            '[LEARNING_PATH_DETAIL] Saved "always use recommended" preference');
      }

      // Save general mode preference if "remember my choice" checked
      if (result['rememberChoice'] == true) {
        await languageService.saveStudyModePreference(selectedMode);
        Logger.debug(
            '[LEARNING_PATH_DETAIL] Saved general study mode preference: ${selectedMode.name}');
      }

      await _navigateToTopicWithMode(topic, path, selectedMode, false);
    }
  }

  // -------------------------------------------------------------------------
  // Persistent "accessed topics" helpers
  // -------------------------------------------------------------------------
  static const String _accessedTopicsPrefsKey = 'lp_accessed_topic_keys';

  /// Returns a stable key for a topic used in the accessed-topics store.
  String _topicKey(LearningPathTopic topic) => topic.topicId.isNotEmpty
      ? topic.topicId
      : '${topic.title.toLowerCase()}_${topic.inputType}';

  /// Returns true if this topic was previously navigated to (persisted across sessions).
  Future<bool> _hasBeenAccessedBefore(LearningPathTopic topic) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getStringList(_accessedTopicsPrefsKey) ?? [];
      return keys.contains(_topicKey(topic));
    } catch (_) {
      return false;
    }
  }

  /// Marks this topic as accessed in SharedPreferences (fire-and-forget).
  void _markTopicAsAccessed(LearningPathTopic topic) {
    SharedPreferences.getInstance().then((prefs) {
      final keys = prefs.getStringList(_accessedTopicsPrefsKey) ?? [];
      final key = _topicKey(topic);
      if (!keys.contains(key)) {
        keys.add(key);
        // Cap at 500 entries to avoid unbounded growth
        if (keys.length > 500) keys.removeRange(0, keys.length - 500);
        prefs.setStringList(_accessedTopicsPrefsKey, keys);
      }
    }).catchError((_) {});
  }

  /// Navigate to topic with the selected study mode
  Future<void> _navigateToTopicWithMode(
    LearningPathTopic topic,
    LearningPathDetail path,
    StudyMode mode,
    bool rememberChoice,
  ) async {
    // Skip token check if: topic is completed (backend-confirmed) OR guide
    // is already in Hive cache. isInProgress is not sufficient — the guide
    // may not be cached and a new generation (costing tokens) may be needed.
    final hiveCached = topic.isCompleted ||
        await _hasCachedStudyGuide(
            topic.title, topic.inputType, _currentLanguage);

    if (hiveCached) {
      Logger.info(
          '📦 [LEARNING_PATH_DETAIL] Skipping token check for "${topic.title}" '
          '(completed=${topic.isCompleted}, hiveCached=$hiveCached)');
      // Fall through to navigation; study screen will load from cache
    } else {
      // TODO: Remove or update this when learning path token pricing is finalized.
      // Learning path recommended mode generation is free for all users (validated server-side).
      // Skip the pre-check for the recommended mode to avoid false blocking.
      final isRecommendedMode = mode ==
          (studyModeFromString(path.recommendedMode) ?? StudyMode.standard);

      if (!isRecommendedMode) {
        // Non-recommended mode: check if user has sufficient tokens
        final tokenState = context.read<TokenBloc>().state;
        if (tokenState is TokenLoaded && !tokenState.tokenStatus.isPremium) {
          final costResult = await sl<TokenCostRepository>()
              .getTokenCost(_currentLanguage, mode.value);
          final requiredCost = costResult.fold((f) => 0, (cost) => cost);
          if (requiredCost > 0 &&
              tokenState.tokenStatus.totalTokens < requiredCost &&
              mounted) {
            await InsufficientTokensDialog.show(
              context,
              tokenStatus: tokenState.tokenStatus,
              requiredTokens: requiredCost,
            );
            return;
          }
        }
      }
    }

    final languageService = sl<LanguagePreferenceService>();

    // Save user's mode preference if they chose to remember
    if (rememberChoice) {
      languageService.saveStudyModePreference(mode);
    }

    final encodedTitle = Uri.encodeComponent(topic.title);
    final encodedDescription = Uri.encodeComponent(topic.description);
    final encodedInputType = Uri.encodeComponent(topic.inputType);
    final encodedPathTitle = Uri.encodeComponent(path.title);
    final encodedPathDescription = Uri.encodeComponent(path.description);
    final topicIdParam =
        topic.topicId.isNotEmpty ? '&topic_id=${topic.topicId}' : '';
    final descriptionParam =
        topic.description.isNotEmpty ? '&description=$encodedDescription' : '';
    final pathIdParam = path.id.isNotEmpty ? '&path_id=${path.id}' : '';
    final pathTitleParam =
        path.title.isNotEmpty ? '&path_title=$encodedPathTitle' : '';
    final pathDescriptionParam = path.description.isNotEmpty
        ? '&path_description=$encodedPathDescription'
        : '';
    final discipleLevelParam = path.discipleLevel.isNotEmpty
        ? '&disciple_level=${Uri.encodeComponent(path.discipleLevel)}'
        : '';

    Logger.debug(
        '[LEARNING_PATH_DETAIL] Navigating to topic: ${topic.title} with mode: ${mode.name}, path: ${path.title}, level: ${path.discipleLevel}');

    // Use push and await the result - when user returns, refresh the data
    await context.push(
      '${AppRoutes.studyGuideV2}?input=$encodedTitle&type=$encodedInputType&language=$_currentLanguage&mode=${mode.name}&source=learningPath$topicIdParam$descriptionParam$pathIdParam$pathTitleParam$pathDescriptionParam$discipleLevelParam',
    );

    // Persist that this topic was accessed so future visits bypass the token check
    _markTopicAsAccessed(topic);

    // Refresh data when returning from the study guide - force refresh to bypass cache
    if (mounted) {
      Logger.debug(
          '[LEARNING_PATH_DETAIL] Returned from study guide, refreshing with forceRefresh: true');
      _loadPathDetails(forceRefresh: true);
    }
  }

  /// Returns true if a study guide matching [input]/[inputType]/[language]
  /// exists in the local Hive cache.
  Future<bool> _hasCachedStudyGuide(
    String input,
    String inputType,
    String language,
  ) async {
    try {
      final cached = await sl<StudyLocalDataSource>().getCachedStudyGuides();
      final normalizedInput = input.trim().toLowerCase();
      return cached.any(
        (g) =>
            g.input.trim().toLowerCase() == normalizedInput &&
            g.inputType == inputType &&
            g.language == language,
      );
    } catch (_) {
      return false;
    }
  }

  /// Handle back navigation - go to appropriate screen when can't pop
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Navigate based on source - default to home if source is 'home', otherwise study topics
      if (widget.source == 'home') {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.studyTopics);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        body: BlocConsumer<LearningPathsBloc, LearningPathsState>(
          listener: (context, state) {
            if (state is LearningPathEnrolled) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      context.tr(TranslationKeys.learningPathsEnrolledSuccess)),
                  backgroundColor: AppColors.success,
                ),
              );
              // Reload details to show updated enrollment status
              _loadPathDetails();
            }
          },
          builder: (context, state) {
            if (state is LearningPathDetailLoading) {
              return _buildLoadingState(context);
            }

            if (state is LearningPathsError) {
              return _buildErrorState(context, state);
            }

            if (state is LearningPathDetailLoaded) {
              return _buildLoadedState(context, state.pathDetail);
            }

            if (state is LearningPathEnrolling) {
              return _buildEnrollingState(context);
            }

            // Show initial path data while loading
            if (widget.initialPath != null) {
              return _buildInitialState(context, widget.initialPath!);
            }

            return _buildLoadingState(context);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, null),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),
                CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr(TranslationKeys.learningPathsLoadingDetails),
                  style: AppFonts.inter(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnrollingState(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, null),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),
                CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr(TranslationKeys.learningPathsEnrolling),
                  style: AppFonts.inter(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, LearningPathsError state) {
    final theme = Theme.of(context);
    final isOffline =
        context.read<ConnectivityBloc>().state is ConnectivityOffline;

    return CustomScrollView(
      slivers: [
        _buildAppBar(context, null),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(
                  isOffline ? Icons.wifi_off_rounded : Icons.error_outline,
                  size: 64,
                  color: isOffline
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  isOffline
                      ? "You're offline"
                      : context.tr(TranslationKeys.learningPathsFailedToLoad),
                  style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOffline
                      ? 'This learning path hasn\'t been downloaded. Download it while online to access it offline.'
                      : 'Something went wrong. Please try again.',
                  style: AppFonts.inter(
                    fontSize: 14,
                    color: isOffline
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!isOffline)
                  ElevatedButton(
                    onPressed: _loadPathDetails,
                    child: Text(context.tr(TranslationKeys.commonRetry)),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                      side: BorderSide(
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialState(BuildContext context, LearningPath path) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, path),
        SliverToBoxAdapter(
          child: _buildPathHeader(context, path),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  context.tr(TranslationKeys.learningPathsLoadingTopics),
                  style: AppFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadedState(BuildContext context, LearningPathDetail path) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, path),
        SliverToBoxAdapter(
          child: _buildPathHeader(context, path),
        ),
        if (!path.isEnrolled)
          SliverToBoxAdapter(
            child: _buildEnrollButton(context, path),
          ),
        if (path.isEnrolled)
          SliverToBoxAdapter(
            child: _buildProgressSection(context, path),
          ),
        SliverToBoxAdapter(
          child: _buildTopicsHeader(context, path),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                _buildTopicItem(context, path.topics[index], index, path),
            childCount: path.topics.length,
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 40),
        ),
      ],
    );
  }

  Widget _buildDownloadButton(LearningPathDetail path) {
    final model = _downloadModel;

    if (model == null ||
        model.status == PathDownloadStatus.failed ||
        model.status == PathDownloadStatus.paused) {
      return IconButton(
        icon: const Icon(Icons.download_outlined),
        tooltip: 'Download for offline',
        onPressed: () => _showTopicSelectionSheet(path),
      );
    }

    if (model.status == PathDownloadStatus.completed) {
      return IconButton(
        icon: Icon(Icons.check_circle, color: AppColors.success),
        tooltip: 'Available offline',
        onPressed: () => _showCompletedDownloadOptions(path),
      );
    }

    // Downloading / queued — show progress ring
    final total = model.totalCount;
    final done = model.completedCount;
    return GestureDetector(
      onTap: () => _showDownloadOptions(path),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: total > 0 ? done / total : null,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Text(
            '$done',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTopicSelectionSheet(LearningPathDetail path) async {
    final languageService = sl<LanguagePreferenceService>();
    final lang = await languageService.getStudyContentLanguage();

    // Fetch token cost per guide (0 for premium users).
    final costResult = await sl<TokenCostRepository>()
        .getTokenCost(lang.code, path.recommendedMode ?? 'standard');
    final costPerGuide = costResult.fold((_) => 0, (c) => c);

    // Pre-select topics that haven't been downloaded yet.
    final alreadyDownloaded = sl<LearningPathDownloadService>()
            .getDownload(path.id)
            ?.topics
            .where((t) => t.status == TopicDownloadStatus.done)
            .map((t) => t.topicId)
            .toSet() ??
        {};

    final selectable = path.topics
        .where((t) => !alreadyDownloaded.contains(t.topicId))
        .toList();

    if (selectable.isEmpty || !mounted) return;

    final selected = Set<String>.from(selectable.map((t) => t.topicId));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TopicSelectionSheet(
        topics: selectable,
        initialSelected: selected,
        costPerGuide: costPerGuide,
        onConfirm: (chosenTopics) async {
          final downloadTopics = chosenTopics
              .map((t) => LearningPathTopicDownload(
                    topicId: t.topicId,
                    topicTitle: t.title,
                    inputType: t.inputType,
                    description: t.description,
                    studyMode: path.recommendedMode ?? 'standard',
                    status: TopicDownloadStatus.pending,
                  ))
              .toList();

          await sl<LearningPathDownloadService>().queueAdditionalTopics(
            pathId: path.id,
            pathTitle: path.title,
            language: lang.code,
            newTopics: downloadTopics,
          );
        },
      ),
    );
  }

  void _showCompletedDownloadOptions(LearningPathDetail path) =>
      _showDownloadSheet(path);

  void _showDownloadOptions(LearningPathDetail path) =>
      _showDownloadSheet(path);

  void _showDownloadSheet(LearningPathDetail path) {
    final model = _downloadModel;
    if (model == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UnifiedDownloadSheet(
        path: path,
        initialModel: model,
        onPause: () {
          sl<LearningPathDownloadService>().pauseDownload(path.id);
          Navigator.pop(context);
        },
        onCancel: () {
          sl<LearningPathDownloadService>().cancelDownload(path.id);
          Navigator.pop(context);
        },
        onRemoveAll: () {
          sl<LearningPathDownloadService>().deleteDownload(path.id);
          Navigator.pop(context);
        },
        onDeleteTopic: (guideId) {
          sl<LearningPathDownloadService>().deleteTopic(path.id, guideId);
        },
        onRetryTopic: (topicId) {
          sl<LearningPathDownloadService>().retryTopic(path.id, topicId);
        },
        onDownloadSingle: (topic) {
          final dl = LearningPathTopicDownload(
            topicId: topic.topicId,
            topicTitle: topic.title,
            inputType: topic.inputType,
            description: topic.description,
            studyMode: path.recommendedMode ?? 'standard',
            status: TopicDownloadStatus.pending,
          );
          sl<LearningPathDownloadService>().queueSingleTopic(path.id, dl);
        },
        onDownloadMore: () {
          Navigator.pop(context);
          _showTopicSelectionSheet(path);
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, LearningPath? path) {
    final theme = Theme.of(context);
    final color =
        path != null ? _parseColor(path.color) : theme.colorScheme.primary;

    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
        onPressed: _handleBackNavigation,
      ),
      actions: path is LearningPathDetail
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildDownloadButton(path),
              ),
            ]
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: path != null
              ? Center(
                  child: Icon(
                    CategoryUtils.getIconForCategory(path.iconName),
                    size: 80,
                    color: color.withValues(alpha: 0.3),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildPathHeader(BuildContext context, LearningPath path) {
    final theme = Theme.of(context);
    final color = _parseColor(path.color);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  path.title,
                  style: AppFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getDiscipleLevelColor(path.discipleLevel)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getTranslatedDiscipleLevel(context, path.discipleLevel),
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getDiscipleLevelColor(path.discipleLevel),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            path.description,
            style: AppFonts.inter(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 20),

          // Stats row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  Icons.book_outlined,
                  '${path.topicsCount}',
                  context.tr(TranslationKeys.learningPathsTopics),
                  color,
                ),
                _buildDivider(context),
                _buildStatItem(
                  context,
                  Icons.star_outline,
                  '${path.totalXp}',
                  context.tr(TranslationKeys.learningPathsXp),
                  Colors.amber,
                ),
                _buildDivider(context),
                _buildStatItem(
                  context,
                  Icons.schedule_outlined,
                  '${path.estimatedDays}',
                  context.tr(TranslationKeys.learningPathsDays),
                  AppColors.info,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: AppFonts.inter(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 1,
      height: 40,
      color: theme.colorScheme.outline.withValues(alpha: 0.2),
    );
  }

  Widget _buildEnrollButton(BuildContext context, LearningPath path) {
    final theme = Theme.of(context);
    final color = _parseColor(path.color);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: () {
          context.read<LearningPathsBloc>().add(
                EnrollInLearningPath(pathId: path.id),
              );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_fill, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.tr(TranslationKeys.learningPathsStartPath),
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context, LearningPathDetail path) {
    final theme = Theme.of(context);
    final color = _parseColor(path.color);
    final progress = path.progressPercentage / 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr(TranslationKeys.learningPathsProgress),
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${path.topicsCompleted}/${path.topicsCount} ${context.tr(TranslationKeys.learningPathsTopics)}',
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor:
                    theme.colorScheme.outline.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(
                  path.isCompleted ? AppColors.success : color,
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr(
                    TranslationKeys.learningPathsPercentComplete,
                    {'percent': path.progressPercentage.toString()},
                  ),
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: path.isCompleted ? AppColors.success : color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (path.isCompleted)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.tr(TranslationKeys.learningPathsCompleted),
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicsHeader(BuildContext context, LearningPathDetail path) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text(
            context.tr(TranslationKeys.learningPathsTopics),
            style: AppFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${path.topics.length}',
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicItem(
    BuildContext context,
    LearningPathTopic topic,
    int index,
    LearningPathDetail path,
  ) {
    final theme = Theme.of(context);
    final color = CategoryUtils.getColorForCategory(context, topic.category);

    // Determine if topic is locked based on sequential progression
    // A topic is unlocked if:
    // - Path allows non-sequential access (all topics unlocked), OR
    // - It's completed or in-progress (can always revisit), OR
    // - It's at or before the first incomplete topic after the last completed one
    //   (i.e., all topics up to lastCompletedIndex + 1 are unlocked)
    final bool isLocked;
    if (path.allowNonSequentialAccess) {
      isLocked = false;
    } else if (topic.isCompleted || topic.isInProgress) {
      isLocked = false;
    } else {
      // Find the last completed topic index
      int lastCompletedIndex = -1;
      for (int i = path.topics.length - 1; i >= 0; i--) {
        if (path.topics[i].isCompleted) {
          lastCompletedIndex = i;
          break;
        }
      }
      // Unlock everything up to and including the next topic after last completed
      isLocked = index > lastCompletedIndex + 1;
    }

    // "Next" is the first non-completed topic that's unlocked
    final isNext = path.isEnrolled &&
        !isLocked &&
        !topic.isCompleted &&
        !path.topics.take(index).any((t) => !t.isCompleted);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GestureDetector(
        onTap: isLocked ? null : () => _navigateToTopic(topic, path),
        child: AnimatedOpacity(
          opacity: isLocked ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: topic.isCompleted
                    ? AppColors.success.withOpacity(0.4)
                    : (isNext
                        ? color.withValues(alpha: 0.5)
                        : theme.colorScheme.outline.withValues(alpha: 0.2)),
                width: isNext ? 2 : 1,
              ),
              boxShadow: isNext
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Position indicator
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: topic.isCompleted
                        ? AppColors.success
                        : (isNext
                            ? color
                            : theme.colorScheme.outline.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: topic.isCompleted
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          )
                        : (isLocked
                            ? Icon(
                                Icons.lock,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                size: 16,
                              )
                            : Text(
                                '${topic.position}',
                                style: AppFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isNext
                                      ? Colors.white
                                      : theme.colorScheme.onSurface,
                                ),
                              )),
                  ),
                ),

                const SizedBox(width: 14),

                // Topic info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              topic.title,
                              style: AppFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (topic.isMilestone)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.flag,
                                    size: 10,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    context.tr(
                                        TranslationKeys.learningPathsMilestone),
                                    style: AppFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                topic.category,
                                style: AppFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.star_outline,
                            size: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '+${topic.xpValue} XP',
                            style: AppFonts.inter(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action indicator
                if (!isLocked)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: topic.isCompleted
                        ? AppColors.success
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  Color _getDiscipleLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'seeker':
        return AppColors.info;
      case 'believer':
        return AppColors.success;
      case 'disciple':
        return AppColors.warning;
      case 'leader':
        return Theme.of(context).colorScheme.primary;
      default:
        return AppColors.lightTextSecondary;
    }
  }

  String _getTranslatedDiscipleLevel(BuildContext context, String level) {
    switch (level.toLowerCase()) {
      case 'seeker':
        return context.tr(TranslationKeys.discipleLevelSeeker);
      case 'believer':
        return context.tr(TranslationKeys.discipleLevelBeliever);
      case 'disciple':
        return context.tr(TranslationKeys.discipleLevelDisciple);
      case 'leader':
        return context.tr(TranslationKeys.discipleLevelLeader);
      default:
        return _capitalize(level);
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

// ---------------------------------------------------------------------------
// Unified download management bottom sheet (in-progress / completed / paused)
// ---------------------------------------------------------------------------

class _UnifiedDownloadSheet extends StatefulWidget {
  final LearningPathDetail path;
  final LearningPathDownloadModel initialModel;
  final VoidCallback onPause;
  final VoidCallback onCancel;
  final VoidCallback onRemoveAll;
  final void Function(String guideId) onDeleteTopic;
  final void Function(String topicId) onRetryTopic;
  final void Function(LearningPathTopic topic) onDownloadSingle;
  final VoidCallback onDownloadMore;

  const _UnifiedDownloadSheet({
    required this.path,
    required this.initialModel,
    required this.onPause,
    required this.onCancel,
    required this.onRemoveAll,
    required this.onDeleteTopic,
    required this.onRetryTopic,
    required this.onDownloadSingle,
    required this.onDownloadMore,
  });

  @override
  State<_UnifiedDownloadSheet> createState() => _UnifiedDownloadSheetState();
}

class _UnifiedDownloadSheetState extends State<_UnifiedDownloadSheet> {
  late LearningPathDownloadModel _model;
  StreamSubscription<LearningPathDownloadModel>? _sub;

  @override
  void initState() {
    super.initState();
    _model = widget.initialModel;
    _sub = sl<LearningPathDownloadService>()
        .watchDownload(widget.path.id)
        .listen((m) {
      if (mounted) setState(() => _model = m);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get _isDownloading =>
      _model.status == PathDownloadStatus.downloading ||
      _model.status == PathDownloadStatus.queued;

  bool get _isCompleted => _model.status == PathDownloadStatus.completed;

  // Map topicId → download info for quick lookup.
  Map<String, LearningPathTopicDownload> get _downloadMap =>
      {for (final t in _model.topics) t.topicId: t};

  int get _missingCount {
    final map = _downloadMap;
    return widget.path.topics
        .where((t) =>
            !map.containsKey(t.topicId) ||
            map[t.topicId]!.status != TopicDownloadStatus.done)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = _model.completedCount;
    final total = widget.path.topics.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isDownloading
                            ? 'Downloading offline guides'
                            : 'Offline guides',
                        style: AppFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isDownloading
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$done / $total',
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isDownloading
                              ? theme.colorScheme.primary
                              : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total > 0 ? done / total : 0,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isDownloading
                          ? theme.colorScheme.primary
                          : AppColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isDownloading
                      ? 'Downloading $done of $total guides…'
                      : _missingCount > 0
                          ? '$done downloaded · $_missingCount not yet downloaded'
                          : 'All $total guides available offline',
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 20),

          // ── Topic list ───────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.path.topics.length,
              itemBuilder: (_, index) {
                final topic = widget.path.topics[index];
                final dl = _downloadMap[topic.topicId];
                final isNotDownloaded =
                    dl == null || dl.status != TopicDownloadStatus.done;
                return _DownloadTopicCard(
                  topic: topic,
                  downloadInfo: dl,
                  isCompleted: _isCompleted,
                  onDelete: dl?.cachedGuideId != null
                      ? () => widget.onDeleteTopic(dl!.cachedGuideId!)
                      : null,
                  onRetry: dl?.status == TopicDownloadStatus.failed
                      ? () => widget.onRetryTopic(topic.topicId)
                      : null,
                  onDownloadSingle: isNotDownloaded &&
                          dl?.status != TopicDownloadStatus.downloading &&
                          dl?.status != TopicDownloadStatus.pending
                      ? () => widget.onDownloadSingle(topic)
                      : null,
                );
              },
            ),
          ),

          // ── Actions ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _isDownloading
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onPause,
                            icon: const Icon(Icons.pause_rounded, size: 18),
                            label: const Text('Pause'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onCancel,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                              side: BorderSide(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_missingCount > 0)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: widget.onDownloadMore,
                              icon:
                                  const Icon(Icons.download_rounded, size: 18),
                              label: Text(
                                  'Download $_missingCount more guide${_missingCount == 1 ? '' : 's'}'),
                            ),
                          ),
                        if (_missingCount > 0) const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: widget.onRemoveAll,
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18),
                            label: const Text('Remove all downloads'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                              side: BorderSide(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTopicCard extends StatelessWidget {
  final LearningPathTopic topic;
  final LearningPathTopicDownload? downloadInfo;
  final bool isCompleted;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  final VoidCallback? onDownloadSingle;

  const _DownloadTopicCard({
    required this.topic,
    required this.downloadInfo,
    required this.isCompleted,
    this.onDelete,
    this.onRetry,
    this.onDownloadSingle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dl = downloadInfo;
    final status = dl?.status;

    final isDone = status == TopicDownloadStatus.done;
    final isActivelyDownloading = status == TopicDownloadStatus.downloading;
    final isFailed = status == TopicDownloadStatus.failed;
    final isPending = status == TopicDownloadStatus.pending;
    final isNotQueued = dl == null; // topic exists on path but not in download

    // Leading indicator color + icon
    final Color indicatorBg;
    final Widget indicatorChild;

    if (isDone) {
      indicatorBg = AppColors.success;
      indicatorChild =
          const Icon(Icons.check_rounded, color: Colors.white, size: 18);
    } else if (isActivelyDownloading) {
      indicatorBg = theme.colorScheme.primary.withValues(alpha: 0.15);
      indicatorChild = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      );
    } else if (isFailed) {
      indicatorBg = theme.colorScheme.errorContainer;
      indicatorChild = Icon(Icons.error_outline_rounded,
          color: theme.colorScheme.error, size: 18);
    } else {
      // pending or not queued
      indicatorBg = theme.colorScheme.outline.withValues(alpha: 0.15);
      indicatorChild = Icon(
        isNotQueued || isCompleted
            ? Icons.download_outlined
            : Icons.schedule_rounded,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        size: 16,
      );
    }

    final Color borderColor;
    if (isDone) {
      borderColor = AppColors.success.withValues(alpha: 0.4);
    } else if (isActivelyDownloading) {
      borderColor = theme.colorScheme.primary.withValues(alpha: 0.5);
    } else if (isFailed) {
      borderColor = theme.colorScheme.error.withValues(alpha: 0.4);
    } else {
      borderColor = theme.colorScheme.outline.withValues(alpha: 0.15);
    }

    final String subtitle;
    if (isDone) {
      subtitle = 'Downloaded';
    } else if (isActivelyDownloading) {
      subtitle = 'Downloading…';
    } else if (isFailed) {
      subtitle = 'Failed — tap to retry';
    } else if (isPending) {
      subtitle = 'Waiting in queue';
    } else {
      subtitle = isCompleted ? 'Not downloaded' : 'Not in queue';
    }

    final double opacity =
        (isPending || isNotQueued) && !isCompleted ? 0.6 : 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                // Status indicator circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: indicatorBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(child: indicatorChild),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: isDone
                              ? AppColors.success
                              : isFailed
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Trailing: delete for downloaded, download button for not downloaded
                if (isDone && onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  )
                else if (onDownloadSingle != null)
                  IconButton(
                    icon: Icon(
                      Icons.download_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: onDownloadSingle,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topic selection bottom sheet
// ---------------------------------------------------------------------------

class _TopicSelectionSheet extends StatefulWidget {
  final List<LearningPathTopic> topics;
  final Set<String> initialSelected;
  final int costPerGuide;
  final Future<void> Function(List<LearningPathTopic>) onConfirm;

  const _TopicSelectionSheet({
    required this.topics,
    required this.initialSelected,
    required this.costPerGuide,
    required this.onConfirm,
  });

  @override
  State<_TopicSelectionSheet> createState() => _TopicSelectionSheetState();
}

class _TopicSelectionSheetState extends State<_TopicSelectionSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
  }

  int get _selectedCount => _selected.length;
  int get _totalCost => _selectedCount * widget.costPerGuide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select guides to download',
                        style: AppFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.costPerGuide > 0
                            ? '$_selectedCount guides · $_totalCost tokens'
                            : '$_selectedCount guides selected',
                        style: AppFonts.inter(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (_selected.length == widget.topics.length) {
                      _selected.clear();
                    } else {
                      _selected.addAll(widget.topics.map((t) => t.topicId));
                    }
                  }),
                  child: Text(
                    _selected.length == widget.topics.length
                        ? 'Deselect all'
                        : 'Select all',
                    style: AppFonts.inter(
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Topic list
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: widget.topics.length,
              itemBuilder: (_, index) {
                final topic = widget.topics[index];
                final isSelected = _selected.contains(topic.topicId);
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (_) => setState(() {
                    if (isSelected) {
                      _selected.remove(topic.topicId);
                    } else {
                      _selected.add(topic.topicId);
                    }
                  }),
                  title: Text(
                    topic.title,
                    style: AppFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: widget.costPerGuide > 0
                      ? Text(
                          '${widget.costPerGuide} tokens',
                          style: AppFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        )
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.brandPrimaryDeep;
                    }
                    return null;
                  }),
                  checkColor: Colors.white,
                );
              },
            ),
          ),
          // Download button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedCount == 0
                      ? null
                      : () {
                          final chosen = widget.topics
                              .where((t) => _selected.contains(t.topicId))
                              .toList();
                          Navigator.pop(context);
                          widget.onConfirm(chosen);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimaryDeep,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.brandPrimaryDeep.withValues(alpha: 0.4),
                  ),
                  child: Text(
                    _selectedCount == 0
                        ? 'Select at least one guide'
                        : widget.costPerGuide > 0
                            ? 'Download $_selectedCount guides ($_totalCost tokens)'
                            : 'Download $_selectedCount guides',
                    style: AppFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
