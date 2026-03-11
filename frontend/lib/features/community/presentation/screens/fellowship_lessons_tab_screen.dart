import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:async';

import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_utils.dart';
import '../../../../features/study_topics/data/services/learning_paths_cache_service.dart';
import '../../../../features/study_topics/domain/entities/learning_path.dart';
import '../../../../features/study_topics/domain/repositories/learning_paths_repository.dart';
import '../../../../features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import '../../../../features/study_topics/presentation/bloc/learning_paths_event.dart';
import '../../../../features/study_topics/presentation/bloc/learning_paths_state.dart';
import '../../domain/entities/fellowship_member_entity.dart';
import '../bloc/fellowship_feed/fellowship_feed_bloc.dart';
import '../bloc/fellowship_feed/fellowship_feed_event.dart';
import '../bloc/fellowship_feed/fellowship_feed_state.dart';
import '../bloc/fellowship_members/fellowship_members_bloc.dart';
import '../bloc/fellowship_members/fellowship_members_event.dart';
import '../bloc/fellowship_members/fellowship_members_state.dart';
import 'fellowship_guide_detail_screen.dart';
import '../bloc/fellowship_study/fellowship_study_bloc.dart';
import '../bloc/fellowship_study/fellowship_study_event.dart';
import '../bloc/fellowship_study/fellowship_study_state.dart';

/// Lessons tab for a fellowship.
///
/// Shows the currently active learning path with individual guide cards
/// (each topic in the path rendered as a lesson card), and allows the
/// mentor to assign or change the fellowship's study path.
class FellowshipLessonsTabScreen extends StatefulWidget {
  final String fellowshipId;

  const FellowshipLessonsTabScreen({
    required this.fellowshipId,
    super.key,
  });

  @override
  State<FellowshipLessonsTabScreen> createState() =>
      _FellowshipLessonsTabScreenState();
}

class _FellowshipLessonsTabScreenState
    extends State<FellowshipLessonsTabScreen> {
  /// The user's study content language, fetched once on first load.
  String _contentLanguage = 'en';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadLanguageAndDetails();
    }
  }

  /// Fetches the user's content language, then triggers the initial
  /// [LoadLearningPathDetails] with the correct language code.
  Future<void> _loadLanguageAndDetails() async {
    final lang =
        await sl<LanguagePreferenceService>().getStudyContentLanguage();
    if (!mounted) return;
    _contentLanguage = lang.code;
    final pathId =
        context.read<FellowshipStudyBloc>().state.currentLearningPathId;
    if (pathId != null) {
      context.read<LearningPathsBloc>().add(
            LoadLearningPathDetails(pathId: pathId, language: _contentLanguage),
          );
    }
  }

  /// Reloads path details when the mentor assigns a new learning path.
  void _reloadPathDetails(String pathId) {
    context.read<LearningPathsBloc>().add(
          LoadLearningPathDetails(pathId: pathId, language: _contentLanguage),
        );
  }

  @override
  Widget build(BuildContext context) {
    // Reload path details whenever the active learning path ID changes
    // (e.g. after the mentor assigns a new path).
    return BlocListener<FellowshipStudyBloc, FellowshipStudyState>(
      listenWhen: (prev, curr) =>
          prev.currentLearningPathId != curr.currentLearningPathId,
      listener: (context, state) {
        if (state.currentLearningPathId != null) {
          _reloadPathDetails(state.currentLearningPathId!);
        }
      },
      child: BlocConsumer<FellowshipStudyBloc, FellowshipStudyState>(
        listenWhen: (prev, curr) =>
            prev.setStatus != curr.setStatus ||
            prev.advanceStatus != curr.advanceStatus,
        listener: (context, state) {
          final l10n = AppLocalizations.of(context)!;
          if (state.setStatus == FellowshipStudySetStatus.success) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: const Text('Learning path assigned successfully!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
          } else if (state.setStatus == FellowshipStudySetStatus.failure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content:
                      Text(state.setError ?? 'Failed to assign learning path.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
          } else if (state.advanceStatus ==
              FellowshipStudyAdvanceStatus.success) {
            final msg = state.studyCompleted
                ? l10n.lessonsCompleted
                : '${l10n.lessonsGuideProgress} ${(state.currentGuideIndex ?? 0) + 1} ${l10n.lessonsOf} ${state.totalGuides ?? '?'}';
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            // Refresh member list so topicsCompleted counts stay current.
            context.read<FellowshipMembersBloc>().add(
                  FellowshipMembersLoadRequested(
                      fellowshipId: widget.fellowshipId),
                );
          } else if (state.advanceStatus ==
              FellowshipStudyAdvanceStatus.failure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content:
                      Text(state.advanceError ?? 'Failed to advance guide.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
          }
        },
        builder: (context, state) {
          final l10n = AppLocalizations.of(context)!;
          final hasStudy = state.currentLearningPathId != null;
          final isLoading = state.setStatus == FellowshipStudySetStatus.loading;
          final isAdvancing =
              state.advanceStatus == FellowshipStudyAdvanceStatus.loading;

          final membersState = context.watch<FellowshipMembersBloc>().state;
          final isMentor =
              membersState.status == FellowshipMembersStatus.success
                  ? membersState.isMentor
                  : state.isMentor;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Scrollable content ─────────────────────────────────────
              Expanded(
                child: hasStudy
                    ? _StudyContent(
                        state: state,
                        isMentor: isMentor,
                        isAdvancing: isAdvancing,
                        l10n: l10n,
                        fellowshipId: widget.fellowshipId,
                        contentLanguage: _contentLanguage,
                        onAdvanceTap: () => _showAdvanceConfirm(context, l10n),
                        onPathPickerTap: () => _showPathPicker(context, state),
                      )
                    : _NoStudyContent(
                        isMentor: isMentor,
                        isLoading: isLoading,
                        onPathPickerTap: () => _showPathPicker(context, state),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAdvanceConfirm(BuildContext context, AppLocalizations l10n) {
    final studyBloc = context.read<FellowshipStudyBloc>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n.lessonsAdvanceGuide,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        content: Text(
          l10n.lessonsAdvanceConfirm,
          style: TextStyle(
            fontFamily: 'Inter',
            color: context.appTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              studyBloc.add(const FellowshipStudyAdvanceRequested());
            },
            child: Text(
              l10n.lessonsAdvanceGuide,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPathPicker(
      BuildContext context, FellowshipStudyState state) async {
    final studyBloc = context.read<FellowshipStudyBloc>();
    // Clear both in-memory and Hive caches so the picker always fetches
    // fresh data from the server, regardless of the 24-hour cache window.
    sl<LearningPathsRepository>().clearCache();
    await sl<LearningPathsCacheService>().clearCache();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider<LearningPathsBloc>(
        create: (_) => sl<LearningPathsBloc>()
          ..add(LoadLearningPaths(
            language: _contentLanguage,
            forceRefresh: true,
          )),
        child: _PathPickerSheet(
          fellowshipId: widget.fellowshipId,
          studyBloc: studyBloc,
          language: _contentLanguage,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StudyContent — scrollable content when a learning path is assigned
// ---------------------------------------------------------------------------

class _StudyContent extends StatelessWidget {
  final FellowshipStudyState state;
  final bool isMentor;
  final bool isAdvancing;
  final AppLocalizations l10n;
  final String fellowshipId;
  final String contentLanguage;
  final VoidCallback onAdvanceTap;
  final VoidCallback onPathPickerTap;

  const _StudyContent({
    required this.state,
    required this.isMentor,
    required this.isAdvancing,
    required this.l10n,
    required this.fellowshipId,
    required this.contentLanguage,
    required this.onAdvanceTap,
    required this.onPathPickerTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Current study header ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _CurrentStudyCard(state: state),
          ),
        ),

        // ── Advance guide button (mentor only, study not complete) ───────
        if (isMentor && !state.studyCompleted)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _AdvanceGuideButton(
                isLoading: isAdvancing,
                label: l10n.lessonsAdvanceGuide,
                onTap: onAdvanceTap,
              ),
            ),
          ),

        // ── Member progress overview (mentor only) ───────────────────────
        if (isMentor)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _MemberProgressSection(l10n: l10n),
            ),
          ),

        // ── Guide list ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text(
              l10n.lessonsTitle,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: BlocBuilder<LearningPathsBloc, LearningPathsState>(
              builder: (ctx, pathsState) {
                final pathDescription = pathsState is LearningPathDetailLoaded
                    ? pathsState.pathDetail.description
                    : '';
                final pathDiscipleLevel = pathsState is LearningPathDetailLoaded
                    ? pathsState.pathDetail.discipleLevel
                    : '';
                return _GuideList(
                  currentGuideIndex: state.currentGuideIndex ?? 0,
                  fellowshipId: fellowshipId,
                  pathTitle: state.currentPathTitle ?? '',
                  pathDescription: pathDescription,
                  pathDiscipleLevel: pathDiscipleLevel,
                  contentLanguage: contentLanguage,
                  isMentor: isMentor,
                );
              },
            ),
          ),
        ),

        // ── Assign / change path button (mentor only) ────────────────────
        if (isMentor)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: _AssignPathButton(
                isLoading: state.setStatus == FellowshipStudySetStatus.loading,
                hasStudy: true,
                onTap: onPathPickerTap,
              ),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _NoStudyContent — centered empty state when no path is assigned
// ---------------------------------------------------------------------------

class _NoStudyContent extends StatelessWidget {
  final bool isMentor;
  final bool isLoading;
  final VoidCallback onPathPickerTap;

  const _NoStudyContent({
    required this.isMentor,
    required this.isLoading,
    required this.onPathPickerTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        children: [
          Expanded(
            child: Center(child: _EmptyStudyState(isMentor: isMentor)),
          ),
          if (isMentor) ...[
            const SizedBox(height: 16),
            _AssignPathButton(
              isLoading: isLoading,
              hasStudy: false,
              onTap: onPathPickerTap,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GuideList — renders topics from LearningPathsBloc as guide cards
// ---------------------------------------------------------------------------

class _GuideList extends StatelessWidget {
  final int currentGuideIndex;
  final String fellowshipId;
  final String pathTitle;
  final bool isMentor;
  final String pathDescription;
  final String pathDiscipleLevel;
  final String contentLanguage;

  const _GuideList({
    required this.currentGuideIndex,
    required this.fellowshipId,
    required this.pathTitle,
    required this.isMentor,
    required this.pathDescription,
    required this.pathDiscipleLevel,
    required this.contentLanguage,
  });

  @override
  Widget build(BuildContext context) {
    // Also watch FellowshipFeedBloc so the list rebuilds when topicPostCounts
    // arrives (the API call is async and completes after the first render).
    return BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
        buildWhen: (prev, curr) => prev.topicPostCounts != curr.topicPostCounts,
        builder: (context, _) =>
            BlocBuilder<LearningPathsBloc, LearningPathsState>(
              builder: (context, state) {
                if (state is LearningPathDetailLoading) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  );
                }

                if (state is LearningPathDetailLoaded) {
                  final topics = state.pathDetail.topics;
                  if (topics.isEmpty) return const SizedBox.shrink();

                  final pathDetail = state.pathDetail;

                  // Request topic counts lazily (fires once; bloc deduplicates via
                  // equatable — subsequent calls with the same fellowshipId are no-ops
                  // if the state is already populated).
                  final feedBloc = context.read<FellowshipFeedBloc>();
                  if (feedBloc.state.topicPostCounts.isEmpty) {
                    feedBloc.add(FellowshipTopicCountsRequested(
                        fellowshipId: fellowshipId));
                  }
                  final topicPostCounts = feedBloc.state.topicPostCounts;

                  // Find the position of the first accessible non-done topic — that is
                  // the fellowship's "Now" guide (shown with the Now badge).
                  int? nowPosition;
                  for (int i = 0; i < topics.length; i++) {
                    final t = topics[i];
                    final done =
                        t.isCompleted || t.position < currentGuideIndex;
                    if (done) continue;
                    final accessible = pathDetail.allowNonSequentialAccess ||
                        i == 0 ||
                        t.isCompleted ||
                        (i > 0 && topics[i - 1].isCompleted) ||
                        t.position <= currentGuideIndex;
                    if (accessible) {
                      nowPosition = t.position;
                      break;
                    }
                  }

                  return Column(
                    children: List.generate(topics.length, (i) {
                      final topic = topics[i];

                      // A guide is done if personally completed OR the fellowship
                      // has advanced past it.
                      final isDone = topic.isCompleted ||
                          topic.position < currentGuideIndex;

                      // Unlock logic mirrors LearningPathDetailPage._buildTopicItem:
                      // - always unlock first guide
                      // - always unlock completed guides
                      // - unlock if previous topic is personally completed (sequential)
                      // - unlock if fellowship has advanced to/past this guide
                      final bool isAccessible;
                      if (pathDetail.allowNonSequentialAccess) {
                        isAccessible = true;
                      } else if (i == 0) {
                        isAccessible = true;
                      } else if (topic.isCompleted) {
                        isAccessible = true;
                      } else if (pathDetail.topics[i - 1].isCompleted) {
                        isAccessible = true;
                      } else if (topic.position <= currentGuideIndex) {
                        isAccessible = true;
                      } else {
                        isAccessible = false;
                      }

                      final isCurrent = !isDone && isAccessible;
                      final isNow = isCurrent && topic.position == nowPosition;
                      final discussionCount =
                          topicPostCounts[topic.topicId] ?? 0;

                      return _GuideCard(
                        topic: topic,
                        isCurrent: isCurrent,
                        isNow: isNow,
                        isDone: isDone,
                        discussionCount: discussionCount,
                        pathId: state.pathDetail.id,
                        fellowshipId: fellowshipId,
                        pathTitle: pathTitle,
                        pathDescription: pathDescription,
                        pathDiscipleLevel: pathDiscipleLevel,
                        contentLanguage: contentLanguage,
                        isMentor: isMentor,
                      );
                    }),
                  );
                }

                return const SizedBox.shrink();
              },
            ));
  }
}

// ---------------------------------------------------------------------------
// _GuideCard — matches the visual style of LearningPathDetailPage topic cards
// ---------------------------------------------------------------------------

class _GuideCard extends StatelessWidget {
  final LearningPathTopic topic;
  final bool isCurrent;
  final bool isNow;
  final bool isDone;
  final int discussionCount;
  final String pathId;
  final String fellowshipId;
  final String pathTitle;
  final String pathDescription;
  final String pathDiscipleLevel;
  final String contentLanguage;
  final bool isMentor;

  const _GuideCard({
    required this.topic,
    required this.isCurrent,
    required this.isNow,
    required this.isDone,
    required this.discussionCount,
    required this.pathId,
    required this.fellowshipId,
    required this.pathTitle,
    required this.pathDescription,
    required this.pathDiscipleLevel,
    required this.contentLanguage,
    required this.isMentor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = !isCurrent && !isDone;
    final categoryColor =
        CategoryUtils.getColorForCategory(context, topic.category);

    // Position badge
    final Widget badge = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDone
            ? AppColors.success
            : isNow
                ? context.appInteractive.withAlpha(30)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
        border: isNow
            ? Border.all(color: context.appInteractive, width: 1.5)
            : null,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : isLocked
                ? Icon(
                    Icons.lock,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 16,
                  )
                : Text(
                    '${topic.position}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isNow
                          ? context.appInteractive
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: isLocked
            ? null
            : () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FellowshipGuideDetailScreen(
                      fellowshipId: fellowshipId,
                      topic: topic,
                      pathTitle: pathTitle,
                      pathDescription: pathDescription,
                      pathDiscipleLevel: pathDiscipleLevel,
                      contentLanguage: contentLanguage,
                      isMentor: isMentor,
                    ),
                  ),
                );
                // Refresh path details after returning so newly completed
                // topics are reflected in the guide list (same pattern as
                // LearningPathDetailPage._navigateToTopic).
                if (context.mounted) {
                  context.read<LearningPathsBloc>().add(
                        LoadLearningPathDetails(
                          pathId: pathId,
                          language: contentLanguage,
                          forceRefresh: true,
                        ),
                      );
                  // Refresh fellowship study state — the backend may have
                  // auto-advanced current_guide_index while the member was
                  // inside the guide detail screen.
                  context.read<FellowshipStudyBloc>().add(
                        const FellowshipStudyRefreshRequested(),
                      );
                  context.read<FellowshipMembersBloc>().add(
                        FellowshipMembersLoadRequested(
                          fellowshipId: fellowshipId,
                        ),
                      );
                  // Refresh feed so any study_note posts created in the
                  // guide detail screen appear in Recent Activity / Feed.
                  context.read<FellowshipFeedBloc>().add(
                        FellowshipFeedLoadRequested(
                          fellowshipId: fellowshipId,
                        ),
                      );
                }
              },
        child: AnimatedOpacity(
          opacity: isLocked ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDone
                    ? AppColors.success.withOpacity(0.4)
                    : isNow
                        ? context.appInteractive.withValues(alpha: 0.4)
                        : theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                badge,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with optional milestone badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              topic.title,
                              style: TextStyle(
                                fontFamily: 'Inter',
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
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.flag,
                                      size: 10, color: Colors.amber),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Milestone',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.amber.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isNow)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.appInteractive,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Now',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Category chip + XP row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                topic.category,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: categoryColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+${topic.xpValue} XP',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          if (discussionCount > 0) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chat_bubble_rounded,
                              size: 11,
                              color: context.appInteractive,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$discussionCount',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.appInteractive,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow for unlocked topics
                if (!isLocked)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: isDone
                          ? AppColors.success
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
// _CurrentStudyCard
// ---------------------------------------------------------------------------

class _CurrentStudyCard extends StatelessWidget {
  final FellowshipStudyState state;

  const _CurrentStudyCard({required this.state});

  static Color _parseColor(String? hex, BuildContext context) {
    if (hex == null) return Theme.of(context).colorScheme.primary;
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<LearningPathsBloc, LearningPathsState>(
      builder: (ctx, pathsState) {
        // Use localized title + color from loaded path details when available.
        String displayTitle = state.currentPathTitle ?? 'Learning path active';
        Color pathColor = Theme.of(context).colorScheme.primary;

        if (pathsState is LearningPathDetailLoaded) {
          if (pathsState.pathDetail.title.isNotEmpty) {
            displayTitle = pathsState.pathDetail.title;
          }
          pathColor = _parseColor(pathsState.pathDetail.color, context);
        }

        // In dark mode use a lighter tint so it's visible on dark backgrounds.
        final accentColor =
            isDark ? Color.lerp(pathColor, Colors.white, 0.35)! : pathColor;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                pathColor.withOpacity(isDark ? 0.18 : 0.10),
                pathColor.withOpacity(isDark ? 0.08 : 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: pathColor.withOpacity(isDark ? 0.35 : 0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: pathColor.withOpacity(isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.lessonsCurrentStudy,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayTitle,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyStudyState
// ---------------------------------------------------------------------------

class _EmptyStudyState extends StatelessWidget {
  final bool isMentor;

  const _EmptyStudyState({required this.isMentor});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message =
        isMentor ? l10n.lessonsNoPathMentor : l10n.lessonsNoPathMember;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: context.appTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: context.appTextSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AdvanceGuideButton
// ---------------------------------------------------------------------------

class _AdvanceGuideButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback onTap;

  const _AdvanceGuideButton({
    required this.isLoading,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandColor = isDark
        ? AppColors.brandPrimaryLight
        : Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: brandColor,
          side: BorderSide(color: brandColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: brandColor,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.arrow_forward_rounded, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AssignPathButton
// ---------------------------------------------------------------------------

class _AssignPathButton extends StatelessWidget {
  final bool isLoading;
  final bool hasStudy;
  final VoidCallback onTap;

  const _AssignPathButton({
    required this.isLoading,
    required this.hasStudy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = hasStudy ? l10n.lessonsChangePath : l10n.lessonsAssignPath;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          gradient: isLoading ? null : AppTheme.primaryGradient,
          color: isLoading ? context.appBorder : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PathPickerSheet — bottom sheet for selecting a learning path
// Supports search filtering + scroll-triggered pagination.
// ---------------------------------------------------------------------------

class _PathPickerSheet extends StatefulWidget {
  final String fellowshipId;
  final FellowshipStudyBloc studyBloc;
  final String language;

  const _PathPickerSheet({
    required this.fellowshipId,
    required this.studyBloc,
    this.language = 'en',
  });

  @override
  State<_PathPickerSheet> createState() => _PathPickerSheetState();
}

class _PathPickerSheetState extends State<_PathPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Dispatches [SearchLearningPaths] after a 400 ms debounce.
  void _onSearchChanged(String value, BuildContext context) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<LearningPathsBloc>().add(
            SearchLearningPaths(
              query: value.trim(),
              language: widget.language,
            ),
          );
    });
  }

  void _maybeLoadMore(BuildContext context, ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return;
    }
    final metrics = notification.metrics;
    if (metrics.pixels < metrics.maxScrollExtent - 160) {
      return;
    }

    final bloc = context.read<LearningPathsBloc>();
    final state = bloc.state;
    // Only load more categories when not in search mode
    if (state is LearningPathsLoaded &&
        state.searchQuery == null &&
        state.hasMoreCategories &&
        !state.isFetchingMoreCategories) {
      bloc.add(LoadMoreCategories(language: widget.language));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, sheetController) {
        return Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle ─────────────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Title ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  l10n.lessonsPickPathTitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),

              // ── Search field ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Builder(builder: (ctx) {
                  final hasText = _searchController.text.isNotEmpty;
                  return TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      _onSearchChanged(v, ctx);
                      setState(() {}); // refresh suffix icon
                    },
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: context.appTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.searchPathsHint,
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: context.appTextTertiary,
                      ),
                      prefixIcon:
                          Icon(Icons.search, color: context.appTextTertiary),
                      suffixIcon: hasText
                          ? IconButton(
                              icon: Icon(Icons.close,
                                  size: 18, color: context.appTextTertiary),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('', ctx);
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: context.appInputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              Divider(height: 1, color: context.appDivider),

              // ── Path list ──────────────────────────────────────────────
              Expanded(
                child: BlocBuilder<LearningPathsBloc, LearningPathsState>(
                  builder: (context, state) {
                    if (state is LearningPathsLoading ||
                        state is LearningPathsInitial) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary),
                        ),
                      );
                    }

                    if (state is LearningPathsError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            state.message,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: context.appTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    if (state is LearningPathsEmpty) {
                      return _PathPickerEmpty(message: l10n.searchNoResults);
                    }

                    if (state is LearningPathsLoaded) {
                      // ── Search mode ──────────────────────────────────────
                      if (state.searchQuery != null) {
                        if (state.isSearching) {
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary),
                            ),
                          );
                        }
                        final results = state.searchResults ?? [];
                        if (results.isEmpty) {
                          return _PathPickerEmpty(
                              message: l10n.searchNoResults);
                        }
                        return ListView.builder(
                          controller: sheetController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: results.length,
                          itemBuilder: (context, index) => _PathPickerItem(
                            path: results[index],
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.studyBloc.add(
                                FellowshipStudySetRequested(
                                  fellowshipId: widget.fellowshipId,
                                  learningPathId: results[index].id,
                                  learningPathTitle: results[index].title,
                                ),
                              );
                            },
                          ),
                        );
                      }

                      // ── Normal mode (category listing + pagination) ──────
                      final allPaths = state.allPaths;

                      if (allPaths.isEmpty && !state.hasMoreCategories) {
                        return _PathPickerEmpty(
                          message: 'No learning paths available.',
                        );
                      }

                      // +1 slot for the load-more footer
                      final hasFooter = state.hasMoreCategories ||
                          state.isFetchingMoreCategories;
                      final itemCount = allPaths.length + (hasFooter ? 1 : 0);

                      return NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          _maybeLoadMore(context, n);
                          return false;
                        },
                        child: ListView.builder(
                          controller: sheetController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            // Footer spinner
                            if (index == allPaths.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: state.isFetchingMoreCategories
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              );
                            }

                            final path = allPaths[index];
                            return _PathPickerItem(
                              path: path,
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.studyBloc.add(
                                  FellowshipStudySetRequested(
                                    fellowshipId: widget.fellowshipId,
                                    learningPathId: path.id,
                                    learningPathTitle: path.title,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _PathPickerEmpty — shared empty / no-results state
// ---------------------------------------------------------------------------

class _PathPickerEmpty extends StatelessWidget {
  final String message;
  const _PathPickerEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: context.appTextTertiary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PathPickerItem
// ---------------------------------------------------------------------------

class _PathPickerItem extends StatelessWidget {
  final LearningPath path;
  final VoidCallback onTap;

  const _PathPickerItem({required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path.title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (path.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          path.description,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${path.topicsCount} topics · ${path.discipleLevel}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.appTextTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: context.appTextTertiary,
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
// _MemberProgressSection — mentor-only overview of all member progress
// ---------------------------------------------------------------------------

class _MemberProgressSection extends StatelessWidget {
  final AppLocalizations l10n;

  const _MemberProgressSection({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LearningPathsBloc, LearningPathsState>(
      builder: (context, pathsState) {
        final int? totalTopics = pathsState is LearningPathDetailLoaded
            ? pathsState.pathDetail.topics.length
            : null;

        return BlocBuilder<FellowshipMembersBloc, FellowshipMembersState>(
          buildWhen: (prev, curr) =>
              prev.members != curr.members || prev.status != curr.status,
          builder: (context, membersState) {
            final members = membersState.members;
            if (members.isEmpty) return const SizedBox.shrink();

            final completedCount = totalTopics != null
                ? members
                    .where((m) =>
                        m.topicsCompleted != null &&
                        m.topicsCompleted! >= totalTopics)
                    .length
                : 0;
            final totalCount = members.length;

            return Container(
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.appBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: context.appPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.people_alt_outlined,
                            size: 16,
                            color: context.appPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.lessonsMemberProgress,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (totalTopics != null)
                          _CompletionBadge(
                            completed: completedCount,
                            total: totalCount,
                            l10n: l10n,
                          ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: context.appDivider),

                  // ── Member rows ──────────────────────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: members
                          .map((m) => _MemberProgressRow(
                                member: m,
                                totalTopics: totalTopics,
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Completion badge chip ────────────────────────────────────────────────────

class _CompletionBadge extends StatelessWidget {
  final int completed;
  final int total;
  final AppLocalizations l10n;

  const _CompletionBadge(
      {required this.completed, required this.total, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final allDone = completed == total && total > 0;
    final bg = allDone ? AppColors.successLight : context.appSurfaceVariant;
    final fg = allDone ? AppColors.successDark : context.appTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$completed/$total ${l10n.lessonsMembersCompleted}',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ── Per-member progress row ──────────────────────────────────────────────────

class _MemberProgressRow extends StatelessWidget {
  final FellowshipMemberEntity member;
  final int? totalTopics;

  const _MemberProgressRow({required this.member, required this.totalTopics});

  @override
  Widget build(BuildContext context) {
    final completed = member.topicsCompleted ?? 0;
    final total = totalTopics ?? 0;
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final isDone = total > 0 && completed >= total;
    final initials = _memberInitials(member.displayName);
    final isMentorMember = member.role == 'mentor';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          // Avatar
          _ProgressAvatar(
            avatarUrl: member.avatarUrl,
            initials: initials,
            isDone: isDone,
          ),
          const SizedBox(width: 10),

          // Name + progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMentorMember) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Mentor',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: context.appSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDone ? AppColors.success : context.appInteractive,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Fraction or checkmark
          if (isDone)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 18)
          else if (totalTopics != null)
            Text(
              '$completed/$total',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appTextTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Progress avatar (small, with optional done ring) ────────────────────────

class _ProgressAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final bool isDone;

  const _ProgressAvatar(
      {required this.avatarUrl, required this.initials, required this.isDone});

  @override
  Widget build(BuildContext context) {
    final primary = context.appPrimary;
    const radius = 18.0;

    // Capture initials fallback BEFORE reassigning avatar — the errorBuilder
    // closure must reference this stable widget, not the ClipOval that wraps
    // Image.network (which would cause an infinite error-rebuild loop).
    final initialsAvatar = CircleAvatar(
      radius: radius,
      backgroundColor: context.appSurfaceVariant,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: primary,
        ),
      ),
    );

    Widget avatar = initialsAvatar;

    if (avatarUrl != null) {
      avatar = ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Image.network(
            avatarUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => initialsAvatar,
          ),
        ),
      );
    }

    if (!isDone) return avatar;

    // Green ring when completed
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.success, width: 2),
      ),
      child: avatar,
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String _memberInitials(String displayName) {
  final parts = displayName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
