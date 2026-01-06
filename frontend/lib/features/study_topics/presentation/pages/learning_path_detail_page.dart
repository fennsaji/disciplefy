import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/services/auth_state_provider.dart';
import '../../../../core/utils/category_utils.dart';
import '../../../study_generation/domain/entities/study_mode.dart';
import '../../../study_generation/presentation/widgets/mode_selection_sheet.dart';
import '../../../user_profile/data/services/user_profile_service.dart';
import '../../../user_profile/data/models/user_profile_model.dart';
import '../../domain/entities/learning_path.dart';
import '../bloc/learning_paths_bloc.dart';
import '../bloc/learning_paths_event.dart';
import '../bloc/learning_paths_state.dart';

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

  @override
  void initState() {
    super.initState();
    _loadLanguageAndPathDetails();
  }

  Future<void> _loadLanguageAndPathDetails() async {
    final languageService = sl<LanguagePreferenceService>();
    final language = await languageService.getSelectedLanguage();
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
      debugPrint(
          '[LEARNING_PATH_DETAIL] Auto-enrolling user in path: ${path.title}');
      context
          .read<LearningPathsBloc>()
          .add(EnrollInLearningPath(pathId: path.id));
    }

    // Get learning path study mode preference from Settings
    final authProvider = sl<AuthStateProvider>();
    final learningPathModePreference =
        authProvider.userProfile?['learning_path_study_mode'] as String?;

    StudyMode? selectedMode;

    // Determine mode based on preference
    if (learningPathModePreference == 'recommended') {
      // Use path's recommended mode
      selectedMode =
          StudyModeExtension.fromString(path.recommendedMode ?? 'standard');
      debugPrint(
          '[LEARNING_PATH_DETAIL] Using recommended mode: ${selectedMode.name}');
      await _navigateToTopicWithMode(topic, path, selectedMode, false);
    } else if (learningPathModePreference != null &&
        learningPathModePreference != 'ask') {
      // Use specific mode from settings (quick, standard, deep, lectio)
      selectedMode = StudyModeExtension.fromString(learningPathModePreference);
      debugPrint(
          '[LEARNING_PATH_DETAIL] Using specific mode from settings: ${selectedMode.name}');
      await _navigateToTopicWithMode(topic, path, selectedMode, false);
    } else {
      // learningPathModePreference == null OR 'ask' → Show mode selection sheet
      debugPrint(
          '[LEARNING_PATH_DETAIL] Showing mode selection sheet with recommended mode');

      final recommendedMode =
          StudyModeExtension.fromString(path.recommendedMode ?? 'standard');

      final result = await ModeSelectionSheet.show(
        context: context,
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

        // Update cached profile
        final userId = authProvider.userId;
        if (userId != null) {
          final currentProfile = authProvider.userProfile ?? {};
          currentProfile['learning_path_study_mode'] = 'recommended';
          authProvider.cacheProfile(userId, currentProfile);
        }

        debugPrint(
            '[LEARNING_PATH_DETAIL] Saved "always use recommended" preference');
      }

      // Save general mode preference if "remember my choice" checked
      if (result['rememberChoice'] == true) {
        final languageService = sl<LanguagePreferenceService>();
        await languageService.saveStudyModePreference(selectedMode);
        debugPrint(
            '[LEARNING_PATH_DETAIL] Saved general study mode preference: ${selectedMode.name}');
      }

      await _navigateToTopicWithMode(topic, path, selectedMode, false);
    }
  }

  /// Navigate to topic with the selected study mode
  Future<void> _navigateToTopicWithMode(
    LearningPathTopic topic,
    LearningPathDetail path,
    StudyMode mode,
    bool rememberChoice,
  ) async {
    final languageService = sl<LanguagePreferenceService>();

    // Save user's mode preference if they chose to remember
    if (rememberChoice) {
      languageService.saveStudyModePreference(mode);
    }

    final encodedTitle = Uri.encodeComponent(topic.title);
    final encodedDescription = Uri.encodeComponent(topic.description);
    final topicIdParam =
        topic.topicId.isNotEmpty ? '&topic_id=${topic.topicId}' : '';
    final descriptionParam =
        topic.description.isNotEmpty ? '&description=$encodedDescription' : '';
    final pathIdParam = path.id.isNotEmpty ? '&path_id=${path.id}' : '';

    debugPrint(
        '[LEARNING_PATH_DETAIL] Navigating to topic: ${topic.title} with mode: ${mode.name}');

    // Use push and await the result - when user returns, refresh the data
    await context.push(
      '${AppRoutes.studyGuideV2}?input=$encodedTitle&type=${topic.inputType}&language=$_currentLanguage&mode=${mode.name}&source=learningPath$topicIdParam$descriptionParam$pathIdParam',
    );

    // Refresh data when returning from the study guide - force refresh to bypass cache
    if (mounted) {
      debugPrint(
          '[LEARNING_PATH_DETAIL] Returned from study guide, refreshing with forceRefresh: true');
      _loadPathDetails(forceRefresh: true);
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
                  backgroundColor: Colors.green,
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
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr(TranslationKeys.learningPathsFailedToLoad),
                  style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  style: AppFonts.inter(
                    fontSize: 14,
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadPathDetails,
                  child: Text(context.tr(TranslationKeys.commonRetry)),
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
                  Colors.blue,
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
        ),
        Text(
          label,
          style: AppFonts.inter(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
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
            Text(
              context.tr(TranslationKeys.learningPathsStartPath),
              style: AppFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
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
                ),
                Text(
                  '${path.topicsCompleted}/${path.topicsCount} ${context.tr(TranslationKeys.learningPathsTopics)}',
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
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
                  path.isCompleted ? Colors.green : color,
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
                    color: path.isCompleted ? Colors.green : color,
                  ),
                ),
                if (path.isCompleted)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.tr(TranslationKeys.learningPathsCompleted),
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
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
    // - It's the first topic (index 0), OR
    // - It's already completed (can always revisit), OR
    // - The previous topic is completed (sequential unlock)
    final bool isLocked;
    if (path.allowNonSequentialAccess) {
      // Path allows non-sequential access = all topics unlocked
      isLocked = false;
    } else if (index == 0) {
      // First topic is always unlocked
      isLocked = false;
    } else if (topic.isCompleted) {
      // Completed topics are always accessible
      isLocked = false;
    } else if (path.topics[index - 1].isCompleted) {
      // Previous topic completed = this one is unlocked
      isLocked = false;
    } else {
      // Previous topic not completed = locked
      isLocked = true;
    }

    final isNext = path.isEnrolled &&
        !topic.isCompleted &&
        (index == 0 || (index > 0 && path.topics[index - 1].isCompleted));

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
                    ? Colors.green.withValues(alpha: 0.4)
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
                        ? Colors.green
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
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
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
                        ? Colors.green
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
      return const Color(0xFF6A4FB6);
    }
  }

  Color _getDiscipleLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'seeker':
        return Colors.blue;
      case 'believer':
        return Colors.green;
      case 'disciple':
        return Colors.orange;
      case 'leader':
        return Colors.purple;
      default:
        return Colors.grey;
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
