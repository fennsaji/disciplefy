import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
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
import '../../../../core/utils/path_icon_utils.dart';
import '../../../../core/theme/reader_palette.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/photo_wash.dart';
import '../../../../shared/widgets/popup.dart'
    show
        PopupEyebrow,
        PopupIconCircle,
        PopupPrimaryButton,
        PopupTone,
        kPopupRadius;
import '../../../settings/presentation/widgets/settings_group.dart'
    show
        SettingsButton,
        SettingsButtonKind,
        SettingsButtonRow,
        SettingsTone,
        SettingsToneColors;
import '../../../../core/utils/share_links.dart';
import '../../../study_generation/domain/entities/study_mode.dart';
import '../../../study_generation/presentation/widgets/mode_selection_sheet.dart';
import '../../../study_generation/presentation/widgets/study_mode_labels.dart';
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
import '../widgets/learning_path_detail_parts.dart';

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

  /// Whether anything happened on this page that changed server-side progress
  /// (enrollment, or a topic study session). Returned as the pop result so the
  /// caller can refetch its own path list only when the data is actually stale
  /// — an ordinary look-and-go-back leaves the caller's state untouched.
  bool _progressChanged = false;

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
      _progressChanged = true;
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

    // A study session may have completed a topic, so the caller's cached path
    // progress is now stale.
    _progressChanged = true;

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
      // Pop result tells the caller whether its path progress needs refetching.
      context.pop(_progressChanged);
    } else {
      // No stack below (deep link / shared URL opened this page directly), so
      // there is no caller state to preserve — fall back to a full navigation.
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
        backgroundColor: ReaderPalette.of(context).page,
        body: PhotoWash.forKey(
          photoKey: widget.pathId,
          child: SafeArea(
            bottom: false,
            child: BlocConsumer<LearningPathsBloc, LearningPathsState>(
              listener: (context, state) {
                if (state is LearningPathEnrolled) {
                  showAppSnackBar(
                    context,
                    context.tr(TranslationKeys.learningPathsEnrolledSuccess),
                    tone: AppSnackTone.success,
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
        ),
      ),
    );
  }

  Widget _buildTopBar([LearningPathDetail? path]) {
    return PathDetailTopBar(
      onBack: _handleBackNavigation,
      actions: path == null
          ? const []
          : [
              _buildShareButton(path),
              _buildDownloadButton(path),
            ],
    );
  }

  Widget _spinner() => SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: ReaderPalette.of(context).gold,
        ),
      );

  Widget _buildLoadingState(BuildContext context) {
    return ListView(
      children: [
        _buildTopBar(),
        PathDetailStatusView(
          leading: _spinner(),
          title: context.tr(TranslationKeys.learningPathsLoadingDetails),
        ),
      ],
    );
  }

  Widget _buildEnrollingState(BuildContext context) {
    return ListView(
      children: [
        _buildTopBar(),
        PathDetailStatusView(
          leading: _spinner(),
          title: context.tr(TranslationKeys.learningPathsEnrolling),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, LearningPathsError state) {
    final palette = ReaderPalette.of(context);
    final isOffline =
        context.read<ConnectivityBloc>().state is ConnectivityOffline;

    return ListView(
      children: [
        _buildTopBar(),
        PathDetailStatusView(
          leading: PopupIconCircle(
            icon: isOffline ? Icons.wifi_off_rounded : Icons.error_outline,
            tone: isOffline ? PopupTone.indigo : PopupTone.gold,
            size: 64,
          ),
          title: isOffline
              ? context.tr(TranslationKeys.learningPathsOfflineTitle)
              : context.tr(TranslationKeys.learningPathsFailedToLoad),
          message: isOffline
              ? context.tr(TranslationKeys.downloadsNotDownloadedOffline)
              : context.tr(TranslationKeys.studyTopicsSomethingWentWrong),
          action: !isOffline
              ? FilledButton(
                  onPressed: _loadPathDetails,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.ctaFill,
                    foregroundColor: palette.ctaInk,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(context.tr(TranslationKeys.commonRetry)),
                )
              : OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(context.tr(TranslationKeys.downloadsGoBack)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.muted,
                    side: BorderSide(color: palette.outline),
                    shape: const StadiumBorder(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildInitialState(BuildContext context, LearningPath path) {
    return ListView(
      children: [
        _buildTopBar(),
        _buildPathHeader(context, path),
        PathDetailStatusView(
          leading: _spinner(),
          title: context.tr(TranslationKeys.learningPathsLoadingTopics),
        ),
      ],
    );
  }

  Widget _buildLoadedState(BuildContext context, LearningPathDetail path) {
    final cta = _primaryAction(context, path);
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildTopBar(path)),
              SliverToBoxAdapter(child: _buildPathHeader(context, path)),
              if (path.isEnrolled)
                SliverToBoxAdapter(
                  child: PathDetailProgress(
                    completed: path.topicsCompleted,
                    total: path.topicsCount,
                    percent: path.progressPercentage,
                    isCompleted: path.isCompleted,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildTopicItem(context, path.topics[index], index, path),
                  childCount: path.topics.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
        if (cta != null)
          PathDetailCtaBar(
            label: cta.label,
            icon: cta.icon,
            onPressed: cta.onPressed,
          ),
      ],
    );
  }

  /// The bottom pill: enroll when not enrolled, otherwise open the next
  /// topic, or review from the start once the path is complete.
  ({String label, IconData icon, VoidCallback onPressed})? _primaryAction(
    BuildContext context,
    LearningPathDetail path,
  ) {
    if (!path.isEnrolled) {
      return (
        label: context.tr(TranslationKeys.learningPathsStartPath),
        icon: Icons.play_arrow_outlined,
        onPressed: () => _enroll(path),
      );
    }
    if (path.topics.isEmpty) return null;

    final next = path.nextTopic;
    if (next == null) {
      final first = path.topics.first;
      return (
        label:
            '${context.tr(TranslationKeys.learningPathsReview)} · ${first.title}',
        icon: Icons.replay_rounded,
        onPressed: () => _navigateToTopic(first, path),
      );
    }
    final started = path.topics.any((t) => t.isCompleted || t.isInProgress);
    final verb = context.tr(started
        ? TranslationKeys.learningPathsContinue
        : TranslationKeys.learningPathsStartPath);
    return (
      label: '$verb · ${next.title}',
      icon: Icons.play_arrow_outlined,
      onPressed: () => _navigateToTopic(next, path),
    );
  }

  void _enroll(LearningPath path) {
    context
        .read<LearningPathsBloc>()
        .add(EnrollInLearningPath(pathId: path.id));
    _progressChanged = true;
  }

  Widget _buildShareButton(LearningPathDetail path) {
    return IconButton(
      icon: Icon(Icons.share_outlined, color: ReaderPalette.of(context).text),
      tooltip: context.tr(TranslationKeys.downloadsSharePath),
      onPressed: () => _sharePath(path),
    );
  }

  /// Shares a public link to this learning path.
  ///
  /// The link points at the public web app rather than the local origin, so it
  /// works for whoever receives it. Recipients who are not signed in are routed
  /// to login and returned here afterwards by the router guard.
  Future<void> _sharePath(LearningPathDetail path) async {
    final message = ShareLinks.learningPathMessage(path.title, path.id);
    try {
      await Share.share(message, subject: path.title);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.downloadsShareFailed),
        tone: AppSnackTone.error,
      );
    }
  }

  Widget _buildDownloadButton(LearningPathDetail path) {
    final model = _downloadModel;
    final palette = ReaderPalette.of(context);

    if (model == null ||
        model.status == PathDownloadStatus.failed ||
        model.status == PathDownloadStatus.paused) {
      return IconButton(
        icon: Icon(Icons.download_outlined, color: palette.text),
        tooltip: context.tr(TranslationKeys.downloadsDownloadForOffline),
        onPressed: () => _showTopicSelectionSheet(path),
      );
    }

    if (model.status == PathDownloadStatus.completed) {
      return IconButton(
        icon: Icon(Icons.check_circle, color: context.appSuccess),
        tooltip: context.tr(TranslationKeys.downloadsAvailableOffline),
        onPressed: () => _showCompletedDownloadOptions(path),
      );
    }

    // Downloading / queued — show progress ring
    final total = model.totalCount;
    final done = model.completedCount;
    return IconButton(
      tooltip: context.tr(TranslationKeys.downloadsStatusDownloading),
      onPressed: () => _showDownloadOptions(path),
      icon: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              value: total > 0 ? done / total : null,
              strokeWidth: 2.5,
              backgroundColor: palette.outline,
              valueColor: AlwaysStoppedAnimation<Color>(palette.gold),
            ),
          ),
          Text(
            '$done',
            style: AppFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.text,
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
    //
    // A failed lookup must not fold into 0: the sheet renders "N guides
    // selected" with no price for a zero cost, which is exactly what a
    // premium/free download looks like. Folding a network error into that
    // told the user a bulk download was free and then charged them for it.
    // Abort instead and let them retry.
    final costResult = await sl<TokenCostRepository>()
        .getTokenCost(lang.code, path.recommendedMode ?? 'standard');
    final costPerGuide = costResult.fold<int?>((_) => null, (c) => c);
    if (costPerGuide == null) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        context.tr(TranslationKeys.studyTopicsSomethingWentWrong),
        tone: AppSnackTone.error,
      );
      return;
    }

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
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TopicSelectionSheet(
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
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

  Widget _buildPathHeader(BuildContext context, LearningPath path) {
    // A cached detail saved before the category was stored has none; the
    // path passed in from the list still knows it.
    final category = path.category.isNotEmpty
        ? path.category
        : (widget.initialPath?.category ?? '');
    return PathDetailHeader(
      levelLabel: _getTranslatedDiscipleLevel(context, path.discipleLevel),
      category: category,
      title: path.title,
      description: path.description,
      topicsCount: path.topicsCount,
      totalXp: path.totalXp,
      estimatedDays: path.estimatedDays,
      icon: iconForPath(path.iconName, category: category),
    );
  }

  Widget _buildTopicItem(
    BuildContext context,
    LearningPathTopic topic,
    int index,
    LearningPathDetail path,
  ) {
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

    final PathTopicStatus status;
    if (topic.isCompleted) {
      status = PathTopicStatus.completed;
    } else if (isLocked) {
      status = PathTopicStatus.locked;
    } else if (isNext) {
      status = PathTopicStatus.current;
    } else {
      status = PathTopicStatus.upcoming;
    }

    return PathTopicRow(
      // `position` is 0-based in the database and is used as a cursor
      // (fellowship_study.current_guide_index), so only the label is shifted.
      number: topic.position + 1,
      title: topic.title,
      category: topic.category,
      xp: topic.xpValue,
      isMilestone: topic.isMilestone,
      status: status,
      upNextLine: isNext ? _upNextLine(context, path) : null,
      onTap: isLocked ? null : () => _navigateToTopic(topic, path),
    );
  }

  /// "Next Topic · Standard · 8 min" — the mode the topic will open in:
  /// the mode fixed in Settings, else the path's recommended mode.
  String _upNextLine(BuildContext context, LearningPathDetail path) {
    final pref =
        sl<LanguagePreferenceService>().getLearningPathStudyModePreferenceRaw();
    final mode =
        (StudyModePreferences.isSpecificMode(pref, isLearningPath: true)
                ? studyModeFromString(pref)
                : null) ??
            studyModeFromString(path.recommendedMode) ??
            StudyMode.standard;
    return [
      context.tr(TranslationKeys.learningPathsNextTopic),
      mode.localizedShortName(context),
      mode.localizedDuration(context),
    ].join(' · ');
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
      case 'follower':
        return context.tr(TranslationKeys.discipleLevelFollower);
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
    final palette = ReaderPalette.of(context);
    final green = SettingsToneColors.of(context, SettingsTone.green);
    final done = _model.completedCount;
    final total = widget.path.topics.length;
    // Indigo while downloading, green once settled.
    final Color progressInk =
        _isDownloading ? palette.accentIcon : green.foreground;
    final Color progressFill = _isDownloading
        ? AppColors.brandPrimary.withValues(alpha: palette.isDark ? 0.24 : 0.1)
        : green.fill;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => DecoratedBox(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(kPopupRadius)),
          border: Border(top: BorderSide(color: palette.hairline)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header + topic list: scroll together so tall hi/ml copy
            // never squeezes the pinned actions. ──────────────────────
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: EdgeInsets.zero,
                itemCount: widget.path.topics.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PopupEyebrow(
                                widget.path.title,
                                textAlign: TextAlign.start,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _isDownloading
                                          ? context.tr(TranslationKeys
                                              .downloadsDownloadingOfflineGuides)
                                          : context.tr(TranslationKeys
                                              .downloadsOfflineGuides),
                                      style: AppFonts.poppins(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600,
                                        color: palette.text,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: progressFill,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$done / $total',
                                      style: AppFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: progressInk,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: total > 0 ? done / total : 0,
                                  minHeight: 6,
                                  backgroundColor: palette.raised,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _isDownloading
                                        ? palette.gold
                                        : green.foreground,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isDownloading
                                    ? context.tr(
                                        TranslationKeys
                                            .downloadsDownloadingProgress,
                                        {'done': done, 'total': total})
                                    : _missingCount > 0
                                        ? context.tr(
                                            TranslationKeys
                                                .downloadsPartlyDownloaded,
                                            {
                                                'done': done,
                                                'missing': _missingCount
                                              })
                                        : context.tr(
                                            TranslationKeys
                                                .downloadsAllAvailableOffline,
                                            {'total': total}),
                                style: AppFonts.inter(
                                    fontSize: 12, color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                            height: 24, thickness: 1, color: palette.hairline),
                      ],
                    );
                  }
                  final index = i - 1;
                  final topic = widget.path.topics[index];
                  final dl = _downloadMap[topic.topicId];
                  final isNotDownloaded =
                      dl == null || dl.status != TopicDownloadStatus.done;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _DownloadTopicCard(
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
                    ),
                  );
                },
              ),
            ),

            // ── Actions ───────────────────────────────────────────────────
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _isDownloading
                    ? SettingsButtonRow(
                        buttons: [
                          SettingsButton(
                            key: const Key('download_sheet_pause'),
                            label: context.tr(TranslationKeys.downloadsPause),
                            icon: Icons.pause_rounded,
                            kind: SettingsButtonKind.neutral,
                            onPressed: widget.onPause,
                          ),
                          SettingsButton(
                            key: const Key('download_sheet_cancel'),
                            label: context.tr(TranslationKeys.commonCancel),
                            icon: Icons.close_rounded,
                            kind: SettingsButtonKind.destructive,
                            onPressed: widget.onCancel,
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_missingCount > 0) ...[
                            PopupPrimaryButton(
                              key: const Key('download_sheet_download_more'),
                              icon: Icons.download_rounded,
                              label: _missingCount == 1
                                  ? context.tr(
                                      TranslationKeys.downloadsDownloadOneMore)
                                  : context.tr(
                                      TranslationKeys.downloadsDownloadMore,
                                      {'count': _missingCount}),
                              onPressed: widget.onDownloadMore,
                            ),
                            const SizedBox(height: 10),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: SettingsButton(
                              key: const Key('download_sheet_remove_all'),
                              label: context
                                  .tr(TranslationKeys.downloadsRemoveAll),
                              icon: Icons.delete_outline_rounded,
                              kind: SettingsButtonKind.destructive,
                              onPressed: widget.onRemoveAll,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
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
    final palette = ReaderPalette.of(context);
    final green = SettingsToneColors.of(context, SettingsTone.green);
    final red = SettingsToneColors.of(context, SettingsTone.red);
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
      indicatorBg = green.fill;
      indicatorChild =
          Icon(Icons.check_rounded, color: green.foreground, size: 18);
    } else if (isActivelyDownloading) {
      indicatorBg =
          AppColors.brandPrimary.withValues(alpha: palette.isDark ? 0.24 : 0.1);
      indicatorChild = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(palette.accentIcon),
        ),
      );
    } else if (isFailed) {
      indicatorBg = red.fill;
      indicatorChild =
          Icon(Icons.error_outline_rounded, color: red.foreground, size: 18);
    } else {
      // pending or not queued
      indicatorBg = palette.raised;
      indicatorChild = Icon(
        isNotQueued || isCompleted
            ? Icons.download_outlined
            : Icons.schedule_rounded,
        color: palette.dim,
        size: 16,
      );
    }

    final Color borderColor;
    if (isActivelyDownloading) {
      borderColor = palette.accentIcon.withValues(alpha: 0.5);
    } else if (isFailed) {
      borderColor = red.foreground.withValues(alpha: 0.4);
    } else {
      borderColor = palette.hairline;
    }

    final String subtitle;
    if (isDone) {
      subtitle = context.tr(TranslationKeys.downloadsStatusDownloaded);
    } else if (isActivelyDownloading) {
      subtitle = context.tr(TranslationKeys.downloadsStatusDownloading);
    } else if (isFailed) {
      subtitle = context.tr(TranslationKeys.downloadsStatusFailed);
    } else if (isPending) {
      subtitle = context.tr(TranslationKeys.downloadsStatusWaiting);
    } else {
      subtitle = isCompleted
          ? context.tr(TranslationKeys.downloadsStatusNotDownloaded)
          : context.tr(TranslationKeys.downloadsStatusNotQueued);
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
              color: palette.raised,
              borderRadius: BorderRadius.circular(16),
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
                    shape: BoxShape.circle,
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
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: isDone
                              ? green.foreground
                              : isFailed
                                  ? red.foreground
                                  : palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Trailing: delete for downloaded, download button for not downloaded
                if (isDone && onDelete != null)
                  IconButton(
                    tooltip: context.tr(TranslationKeys.commonDelete),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: palette.dim,
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
                    tooltip:
                        context.tr(TranslationKeys.downloadsDownloadForOffline),
                    icon: Icon(
                      Icons.download_rounded,
                      size: 20,
                      color: palette.accentIcon,
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

/// Picks which not-yet-downloaded topics of a path to download.
///
/// Show it with a transparent sheet background.
@visibleForTesting
class TopicSelectionSheet extends StatefulWidget {
  final List<LearningPathTopic> topics;
  final Set<String> initialSelected;
  final int costPerGuide;
  final Future<void> Function(List<LearningPathTopic>) onConfirm;

  const TopicSelectionSheet({
    super.key,
    required this.topics,
    required this.initialSelected,
    required this.costPerGuide,
    required this.onConfirm,
  });

  @override
  State<TopicSelectionSheet> createState() => _TopicSelectionSheetState();
}

class _TopicSelectionSheetState extends State<TopicSelectionSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
  }

  int get _selectedCount => _selected.length;
  int get _totalCost => _selectedCount * widget.costPerGuide;
  bool get _allSelected => _selected.length == widget.topics.length;

  void _toggle(String topicId) => setState(() {
        if (!_selected.remove(topicId)) _selected.add(topicId);
      });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      // A Material (not a decorated box) so the checkbox rows' ink shows.
      builder: (_, controller) => Material(
        color: palette.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(kPopupRadius)),
          side: BorderSide(color: palette.hairline),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(TranslationKeys.downloadsSelectGuides),
                          style: AppFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.costPerGuide > 0
                              ? context.tr(
                                  TranslationKeys.downloadsGuidesWithCost,
                                  {'count': _selectedCount, 'cost': _totalCost})
                              : context.tr(
                                  TranslationKeys.downloadsGuidesSelected,
                                  {'count': _selectedCount}),
                          style: AppFonts.inter(
                            fontSize: 13,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      if (_allSelected) {
                        _selected.clear();
                      } else {
                        _selected.addAll(widget.topics.map((t) => t.topicId));
                      }
                    }),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.accentIcon,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      _allSelected
                          ? context.tr(TranslationKeys.downloadsDeselectAll)
                          : context.tr(TranslationKeys.downloadsSelectAll),
                      style: AppFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.accentIcon,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: palette.hairline),
            // Topic list
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: widget.topics.length,
                itemBuilder: (_, index) {
                  final topic = widget.topics[index];
                  final isSelected = _selected.contains(topic.topicId);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => _toggle(topic.topicId),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(
                      topic.title,
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: palette.text,
                      ),
                    ),
                    subtitle: widget.costPerGuide > 0
                        ? Text(
                            context.tr(TranslationKeys.studyUiTokensPerGuide,
                                {'count': widget.costPerGuide}),
                            style: AppFonts.inter(
                              fontSize: 12,
                              color: palette.muted,
                            ),
                          )
                        : null,
                    controlAffinity: ListTileControlAffinity.leading,
                    side: BorderSide(color: palette.dim, width: 1.5),
                    shape: const RoundedRectangleBorder(),
                    checkboxShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return ReaderPalette.selectedFill;
                      }
                      return Colors.transparent;
                    }),
                    checkColor: Colors.white,
                  );
                },
              ),
            ),
            // Download button
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
              child: PopupPrimaryButton(
                onPressed: _selectedCount == 0
                    ? null
                    : () {
                        final chosen = widget.topics
                            .where((t) => _selected.contains(t.topicId))
                            .toList();
                        Navigator.pop(context);
                        widget.onConfirm(chosen);
                      },
                label: _selectedCount == 0
                    ? context.tr(TranslationKeys.downloadsSelectAtLeastOne)
                    : widget.costPerGuide > 0
                        ? context.tr(
                            TranslationKeys.downloadsDownloadCountWithCost,
                            {'count': _selectedCount, 'cost': _totalCost})
                        : context.tr(TranslationKeys.downloadsDownloadCount,
                            {'count': _selectedCount}),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
