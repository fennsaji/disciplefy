import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:disciplefy_bible_study/core/constants/app_fonts.dart';
import 'package:disciplefy_bible_study/core/di/injection_container.dart';
import 'package:disciplefy_bible_study/core/extensions/translation_extension.dart';
import 'package:disciplefy_bible_study/core/i18n/translation_keys.dart';
import 'package:disciplefy_bible_study/core/localization/app_localizations.dart';
import 'package:disciplefy_bible_study/core/services/language_preference_service.dart';
import 'package:disciplefy_bible_study/core/theme/app_colors.dart';
import 'package:disciplefy_bible_study/core/theme/reader_palette.dart';
import 'package:disciplefy_bible_study/core/utils/category_utils.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_member_entity.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_members/fellowship_members_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_study/fellowship_study_state.dart';
import 'package:disciplefy_bible_study/features/community/presentation/screens/fellowship_guide_detail_screen.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_confirm_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_text_field.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_card_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_paths_cache_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/disciple_level.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/shared/widgets/gold_marks.dart';

/// Lessons tab for a fellowship.
///
/// Shows the currently active learning path with individual guide cards
/// (each topic in the path rendered as a lesson card), and allows the
/// mentor to assign or change the fellowship's study path.
class FellowshipLessonsTabScreen extends StatefulWidget {
  final String fellowshipId;
  final String? languageOverride;

  const FellowshipLessonsTabScreen({
    required this.fellowshipId,
    this.languageOverride,
    super.key,
  });

  @override
  State<FellowshipLessonsTabScreen> createState() =>
      _FellowshipLessonsTabScreenState();
}

class _FellowshipLessonsTabScreenState
    extends State<FellowshipLessonsTabScreen> {
  String _contentLanguage = 'en';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadPathDetails();
    }
  }

  /// Fetches the user's content language (always fresh) and loads path details.
  /// Using [pathId] override is for when a new path is assigned and we already
  /// know the ID, e.g. from the [BlocListener] callback.
  Future<void> _loadPathDetails({String? pathId}) async {
    final String langCode;
    if (widget.languageOverride != null) {
      langCode = widget.languageOverride!;
    } else {
      final lang =
          await sl<LanguagePreferenceService>().getStudyContentLanguage();
      langCode = lang.code;
    }
    if (!mounted) return;
    setState(() => _contentLanguage = langCode);
    final id = pathId ??
        context.read<FellowshipStudyBloc>().state.currentLearningPathId;
    if (id != null) {
      context.read<LearningPathsBloc>().add(
            LoadLearningPathDetails(pathId: id, language: langCode),
          );
    }
  }

  @override
  void didUpdateWidget(FellowshipLessonsTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.languageOverride != widget.languageOverride) {
      _loadPathDetails();
    }
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
          _loadPathDetails(pathId: state.currentLearningPathId!);
        }
      },
      child: BlocConsumer<FellowshipStudyBloc, FellowshipStudyState>(
        listenWhen: (prev, curr) =>
            prev.setStatus != curr.setStatus ||
            prev.advanceStatus != curr.advanceStatus ||
            prev.resetStatus != curr.resetStatus,
        listener: (context, state) {
          final l10n = AppLocalizations.of(context)!;
          if (state.setStatus == FellowshipStudySetStatus.success) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(l10n.lessonsPathAssignedSuccess),
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
                  content: Text(state.setError ??
                      context
                          .tr(TranslationKeys.communityFellowshipAssignFailed)),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
          } else if (state.advanceStatus ==
              FellowshipStudyAdvanceStatus.success) {
            if (state.studyCompleted && state.isMentor) {
              _showPathCompletedDialog(context, state);
            } else {
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
            }
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
                  content: Text(state.advanceError ??
                      context.tr(
                          TranslationKeys.communityFellowshipAdvanceFailed)),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
          } else if (state.resetStatus == FellowshipStudyResetStatus.success) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(l10n.lessonsProgressResetSuccess),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            context.read<FellowshipMembersBloc>().add(
                  FellowshipMembersLoadRequested(
                      fellowshipId: widget.fellowshipId),
                );
          } else if (state.resetStatus == FellowshipStudyResetStatus.failure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.resetError ??
                      context
                          .tr(TranslationKeys.communityFellowshipResetFailed)),
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

  Future<void> _showAdvanceConfirm(
      BuildContext context, AppLocalizations l10n) async {
    final studyBloc = context.read<FellowshipStudyBloc>();
    final state = studyBloc.state;
    final isLastGuide = state.currentGuideIndex != null &&
        state.totalGuides != null &&
        state.currentGuideIndex! >= state.totalGuides! - 1;
    final title =
        isLastGuide ? l10n.lessonsFinishPath : l10n.lessonsAdvanceGuide;
    final confirmed = await showCommunityConfirmDialog(
      context,
      icon: isLastGuide ? Icons.flag_outlined : Icons.arrow_forward_rounded,
      title: title,
      body: l10n.lessonsAdvanceConfirm,
      confirmLabel: title,
      cancelLabel: l10n.cancel,
    );
    if (confirmed) studyBloc.add(const FellowshipStudyAdvanceRequested());
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
      // Above the floating tab dock, which would otherwise cover the
      // bottom of the list.
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider<LearningPathsBloc>(
        create: (_) => sl<LearningPathsBloc>()
          ..add(LoadFlatLearningPaths(
            language: _contentLanguage,
            fellowshipId: widget.fellowshipId,
          )),
        child: _PathPickerSheet(
          fellowshipId: widget.fellowshipId,
          studyBloc: studyBloc,
          language: _contentLanguage,
        ),
      ),
    );
  }

  void _showPathCompletedDialog(
      BuildContext context, FellowshipStudyState state) {
    final l10n = AppLocalizations.of(context)!;
    final pathsState = context.read<LearningPathsBloc>().state;
    final pathTitle = pathsState is LearningPathDetailLoaded
        ? pathsState.pathDetail.title
        : state.currentPathTitle ?? '';
    final palette = ReaderPalette.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.hairline),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.gold
                    .withValues(alpha: palette.isDark ? 0.16 : 0.12),
                shape: BoxShape.circle,
              ),
              // Finishing a path together is the biggest achievement moment
              // in Community — gold, like every other earned mark.
              child: Icon(Icons.emoji_events_rounded,
                  size: 32, color: palette.gold),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.lessonsPathComplete,
              style: AppFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: palette.text,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.lessonsPathCompleteBody(pathTitle),
              style: AppFonts.inter(
                fontSize: 14,
                color: palette.muted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: palette.muted,
              minimumSize: const Size(44, 44),
            ),
            child: Text(l10n.lessonsLater, textAlign: TextAlign.center),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showPathPicker(context, state);
            },
            style: FilledButton.styleFrom(
              backgroundColor: palette.ctaFill,
              foregroundColor: palette.ctaInk,
              minimumSize: const Size(44, 44),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: Text(
              l10n.lessonsChooseNextPath,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FellowshipLessonsTopBar — back arrow, the learning path's title and its
// category / level, plus the page's actions (the ⋮ menu).
// ---------------------------------------------------------------------------

/// Top bar for the fellowship lessons page.
///
/// Shows the active learning path's title (falling back to the fellowship
/// study title, then to the generic "Lessons") with a muted subtitle naming
/// the path's category and discipleship level. The title and subtitle wrap
/// instead of truncating, so the bar grows with them: place it in a [Column]
/// above the page body rather than in `Scaffold.appBar`.
class FellowshipLessonsTopBar extends StatelessWidget {
  final List<Widget> actions;
  final VoidCallback? onBack;

  const FellowshipLessonsTopBar({
    this.actions = const [],
    this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<FellowshipStudyBloc, FellowshipStudyState>(
      buildWhen: (prev, curr) =>
          prev.currentLearningPathId != curr.currentLearningPathId ||
          prev.currentPathTitle != curr.currentPathTitle,
      builder: (context, study) =>
          BlocBuilder<LearningPathsBloc, LearningPathsState>(
        builder: (context, paths) {
          final hasStudy = study.currentLearningPathId != null;
          final detail = hasStudy && paths is LearningPathDetailLoaded
              ? paths.pathDetail
              : null;

          String title = l10n.lessonsTitle;
          final studyTitle = study.currentPathTitle?.trim();
          if (detail != null && detail.title.trim().isNotEmpty) {
            title = detail.title.trim();
          } else if (hasStudy && studyTitle != null && studyTitle.isNotEmpty) {
            title = studyTitle;
          }

          final subtitle =
              detail == null ? null : _pathSubtitle(context, detail);

          return Material(
            color: palette.page,
            child: SafeArea(
              bottom: false,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        icon: Icon(Icons.arrow_back,
                            color: palette.text, size: 24),
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: AppFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: palette.text,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: AppFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: palette.gold,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ...actions,
                      SizedBox(width: actions.isEmpty ? 16 : 4),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// "Category · Level" for the path, or null when neither is known.
  static String? _pathSubtitle(BuildContext context, LearningPathDetail path) {
    final parts = <String>[];
    var category = path.category.trim();
    if (category.isEmpty) {
      // Path details carry no category of their own; use the lessons' one
      // when they all share it.
      final lessonCategories = path.topics
          .map((t) => t.category.trim())
          .where((c) => c.isNotEmpty)
          .toSet();
      if (lessonCategories.length == 1) category = lessonCategories.first;
    }
    if (category.isNotEmpty) parts.add(category);
    final level = path.discipleLevel.trim();
    if (level.isNotEmpty) {
      final key = discipleLevelLabelKey(level);
      parts.add(key == null ? level : context.tr(key));
    }
    return parts.isEmpty ? null : parts.join(' · ');
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
    // Watch FellowshipFeedBloc too so discussion counts appear once the
    // (async) topic-count request completes.
    return BlocBuilder<FellowshipFeedBloc, FellowshipFeedState>(
      buildWhen: (prev, curr) => prev.topicPostCounts != curr.topicPostCounts,
      builder: (context, feedState) =>
          BlocBuilder<LearningPathsBloc, LearningPathsState>(
        builder: (context, pathsState) {
          final detail = pathsState is LearningPathDetailLoaded
              ? pathsState.pathDetail
              : null;
          // After the group finishes, every lesson counts as passed.
          final currentGuideIndex = state.studyCompleted
              ? (state.totalGuides ?? 0) + 1
              : (state.currentGuideIndex ?? 0);
          final lessonContext = _LessonOpenContext(
            fellowshipId: fellowshipId,
            pathId: detail?.id ?? state.currentLearningPathId ?? '',
            pathTitle: detail?.title ?? state.currentPathTitle ?? '',
            pathDescription: detail?.description ?? '',
            pathDiscipleLevel: detail?.discipleLevel ?? '',
            contentLanguage: contentLanguage,
            isMentor: isMentor,
          );
          final now = (detail == null || detail.topics.isEmpty)
              ? null
              : _findNowTopic(
                  detail.topics,
                  currentGuideIndex,
                  detail.allowNonSequentialAccess,
                );

          return CustomScrollView(
            slivers: [
              // ── Summary: current lesson + group progress ──────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _LessonsSummaryCard(
                    state: state,
                    detail: detail,
                    now: now,
                    isMentor: isMentor,
                    isAdvancing: isAdvancing,
                    onAdvanceTap: onAdvanceTap,
                    onOpenNow: now == null
                        ? null
                        : () => _openLesson(context, now.topic, lessonContext),
                  ),
                ),
              ),

              // ── Member progress overview (mentor only) ────────────────
              if (isMentor)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _MemberProgressSection(
                      l10n: l10n,
                      fellowshipGuideIndex: state.studyCompleted
                          ? state.totalGuides
                          : state.currentGuideIndex,
                      fellowshipTotalGuides: state.totalGuides,
                    ),
                  ),
                ),

              // ── The lesson path ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _LessonPath(
                    pathsState: pathsState,
                    topicPostCounts: feedState.topicPostCounts,
                    currentGuideIndex: currentGuideIndex,
                    nowPosition: now?.position,
                    lessonContext: lessonContext,
                    studyPathId: state.currentLearningPathId,
                  ),
                ),
              ),

              // ── Assign / change path button (mentor only) ─────────────
              if (isMentor)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: _AssignPathButton(
                      isLoading:
                          state.setStatus == FellowshipStudySetStatus.loading,
                      hasStudy: true,
                      onTap: onPathPickerTap,
                    ),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
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
// _findNowTopic — finds the fellowship's "Now" guide: the first accessible,
// not-yet-done topic. Shared by the summary card and the lesson path so both
// agree on which topic is "now".
// ---------------------------------------------------------------------------

class _NowTopic {
  final int position;
  final LearningPathTopic topic;
  const _NowTopic(this.position, this.topic);
}

_NowTopic? _findNowTopic(
  List<LearningPathTopic> topics,
  int currentGuideIndex,
  bool allowNonSequentialAccess,
) {
  for (int i = 0; i < topics.length; i++) {
    final t = topics[i];
    final done = t.isCompleted || t.position < currentGuideIndex;
    if (done) continue;
    final accessible = allowNonSequentialAccess ||
        i == 0 ||
        t.isCompleted ||
        (i > 0 && topics[i - 1].isCompleted) ||
        t.position <= currentGuideIndex;
    if (accessible) return _NowTopic(t.position, t);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Opening a lesson — shared by the summary card and every lesson row.
// ---------------------------------------------------------------------------

class _LessonOpenContext {
  final String fellowshipId;
  final String pathId;
  final String pathTitle;
  final String pathDescription;
  final String pathDiscipleLevel;
  final String contentLanguage;
  final bool isMentor;

  const _LessonOpenContext({
    required this.fellowshipId,
    required this.pathId,
    required this.pathTitle,
    required this.pathDescription,
    required this.pathDiscipleLevel,
    required this.contentLanguage,
    required this.isMentor,
  });
}

/// Opens [topic]'s guide detail, then refreshes path, study, member and feed
/// state on return so completions and auto-advances show straight away.
Future<void> _openLesson(
  BuildContext context,
  LearningPathTopic topic,
  _LessonOpenContext c,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FellowshipGuideDetailScreen(
        fellowshipId: c.fellowshipId,
        topic: topic,
        pathTitle: c.pathTitle,
        pathDescription: c.pathDescription,
        pathDiscipleLevel: c.pathDiscipleLevel,
        contentLanguage: c.contentLanguage,
        isMentor: c.isMentor,
      ),
    ),
  );
  if (!context.mounted) return;
  // Refresh path details so newly completed topics are reflected (same
  // pattern as LearningPathDetailPage._navigateToTopic).
  context.read<LearningPathsBloc>().add(
        LoadLearningPathDetails(
          pathId: c.pathId,
          language: c.contentLanguage,
          forceRefresh: true,
        ),
      );
  // The backend may have auto-advanced current_guide_index while the member
  // was inside the guide detail screen.
  context.read<FellowshipStudyBloc>().add(
        const FellowshipStudyRefreshRequested(),
      );
  context.read<FellowshipMembersBloc>().add(
        FellowshipMembersLoadRequested(fellowshipId: c.fellowshipId),
      );
  // Study-note posts created in the guide detail screen appear in the feed.
  context.read<FellowshipFeedBloc>().add(
        FellowshipFeedLoadRequested(fellowshipId: c.fellowshipId),
      );
}

// ---------------------------------------------------------------------------
// _LessonsSummaryCard — "Studying together": the current lesson, the group's
// progress, XP earned, and (for mentors) the advance button. Tapping it opens
// the current lesson.
// ---------------------------------------------------------------------------

class _LessonsSummaryCard extends StatelessWidget {
  final FellowshipStudyState state;
  final LearningPathDetail? detail;
  final _NowTopic? now;
  final bool isMentor;
  final bool isAdvancing;
  final VoidCallback onAdvanceTap;
  final VoidCallback? onOpenNow;

  const _LessonsSummaryCard({
    required this.state,
    required this.detail,
    required this.now,
    required this.isMentor,
    required this.isAdvancing,
    required this.onAdvanceTap,
    required this.onOpenNow,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);

    int? total = state.totalGuides;
    if ((total == null || total <= 0) &&
        detail != null &&
        detail!.topics.isNotEmpty) {
      total = detail!.topics.length;
    }
    final hasTotal = total != null && total > 0;
    final guideIndex = state.currentGuideIndex ?? 0;
    // Lessons the group has finished: everything before its current one.
    final groupDone = state.studyCompleted
        ? (total ?? 0)
        : (hasTotal ? guideIndex.clamp(0, total) : guideIndex);

    // The lesson this member is on, or the group's position while the
    // lessons are still loading.
    final int lessonNumber = now != null ? now!.position + 1 : guideIndex + 1;
    final String lessonOf = hasTotal
        ? context.tr(TranslationKeys.communitySharedLessonOf,
            {'number': lessonNumber, 'total': total})
        : context.tr(
            TranslationKeys.communitySharedLesson, {'number': lessonNumber});
    final allDone = state.studyCompleted || (detail != null && now == null);

    final xpEarned = detail == null
        ? 0
        : detail!.topics
            .where((t) => t.isCompleted)
            .fold<int>(0, (sum, t) => sum + t.xpValue);

    final groupProgress =
        context.tr(TranslationKeys.communityFellowshipGroupProgress);

    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CommunitySectionLabel(
                  context
                      .tr(TranslationKeys.communityFellowshipStudyingTogether),
                  fontSize: 10.5,
                ),
              ),
              if (!allDone) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    lessonOf,
                    textAlign: TextAlign.end,
                    style: AppFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: palette.accentIcon,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (allDone || now != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (allDone) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.emoji_events_rounded,
                        size: 20, color: palette.gold),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    allDone ? l10n.lessonsCompleted : now!.topic.title,
                    style: AppFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (hasTotal) ...[
            const SizedBox(height: 10),
            _GoldProgressBar(
              value: (groupDone / total).clamp(0.0, 1.0).toDouble(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  hasTotal
                      ? '$groupProgress · ${context.tr(TranslationKeys.communityLessonsGroupDone, {
                              'done': groupDone,
                              'total': total,
                            })}'
                      : groupProgress,
                  style: AppFonts.inter(fontSize: 13, color: palette.muted),
                ),
              ),
              if (xpEarned > 0) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    context.tr(TranslationKeys.communityLessonsXpEarned,
                        {'xp': xpEarned}),
                    textAlign: TextAlign.end,
                    style: AppFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.gold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Advance guide button (mentor only, study not complete).
          if (isMentor && !state.studyCompleted) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: palette.hairline),
            const SizedBox(height: 14),
            _AdvanceGuideButton(
              isLoading: isAdvancing,
              label: (state.currentGuideIndex != null &&
                      state.totalGuides != null &&
                      state.currentGuideIndex! >= state.totalGuides! - 1)
                  ? l10n.lessonsFinishPath
                  : l10n.lessonsAdvanceGuide,
              onTap: onAdvanceTap,
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: allDone ? null : onOpenNow,
          splashColor: palette.accentIcon.withValues(alpha: 0.10),
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: body,
        ),
      ),
    );
  }
}

/// 6px gold progress bar on a faint track.
class _GoldProgressBar extends StatelessWidget {
  final double value;

  const _GoldProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: palette.raised)),
            FractionallySizedBox(
              widthFactor: value,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.gold,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LessonPath — every lesson as a vertical path. Grouped under gold category
// labels when the lessons span several categories; otherwise one group.
// ---------------------------------------------------------------------------

class _LessonPath extends StatelessWidget {
  final LearningPathsState pathsState;
  final Map<String, int> topicPostCounts;
  final int currentGuideIndex;
  final int? nowPosition;
  final _LessonOpenContext lessonContext;
  final String? studyPathId;

  const _LessonPath({
    required this.pathsState,
    required this.topicPostCounts,
    required this.currentGuideIndex,
    required this.nowPosition,
    required this.lessonContext,
    required this.studyPathId,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final state = pathsState;

    if (state is LearningPathDetailLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(color: palette.accentIcon),
        ),
      );
    }

    if (state is LearningPathsError && studyPathId != null) {
      return _LessonsLoadError(
        onRetry: () => context.read<LearningPathsBloc>().add(
              LoadLearningPathDetails(
                pathId: studyPathId!,
                language: lessonContext.contentLanguage,
                forceRefresh: true,
              ),
            ),
      );
    }

    if (state is! LearningPathDetailLoaded) return const SizedBox.shrink();
    final pathDetail = state.pathDetail;
    final topics = pathDetail.topics;
    if (topics.isEmpty) return const SizedBox.shrink();

    // Request topic counts lazily (the bloc keeps them once loaded).
    if (topicPostCounts.isEmpty) {
      context.read<FellowshipFeedBloc>().add(FellowshipTopicCountsRequested(
          fellowshipId: lessonContext.fellowshipId));
    }

    // Row states, in path order.
    final rows = <_LessonRowData>[];
    for (int i = 0; i < topics.length; i++) {
      final topic = topics[i];
      // A guide is done if personally completed OR the fellowship has
      // advanced past it. isDone drives unlock/accessibility; personal vs.
      // group-past lets the row tell "you completed this" from "the group
      // moved on without you".
      final isDone = topic.isCompleted || topic.position < currentGuideIndex;
      final isGroupPast =
          !topic.isCompleted && topic.position < currentGuideIndex;

      // Unlock logic mirrors LearningPathDetailPage._buildTopicItem:
      // first guide, completed guides, the guide after a personally
      // completed one, and anything the fellowship has reached.
      final bool isAccessible = pathDetail.allowNonSequentialAccess ||
          i == 0 ||
          topic.isCompleted ||
          topics[i - 1].isCompleted ||
          topic.position <= currentGuideIndex;

      final isCurrent = !isDone && isAccessible;
      final _LessonStatus status;
      if (topic.isCompleted) {
        status = _LessonStatus.done;
      } else if (isGroupPast) {
        status = _LessonStatus.groupPast;
      } else if (isCurrent && topic.position == nowPosition) {
        status = _LessonStatus.now;
      } else if (isCurrent) {
        status = _LessonStatus.open;
      } else {
        status = _LessonStatus.locked;
      }
      rows.add(_LessonRowData(
        topic: topic,
        status: status,
        discussionCount: topicPostCounts[topic.topicId] ?? 0,
      ));
    }

    // Consecutive runs of the same category.
    final groups = <List<_LessonRowData>>[];
    for (final row in rows) {
      if (groups.isEmpty ||
          groups.last.first.topic.category.trim() !=
              row.topic.category.trim()) {
        groups.add([row]);
      } else {
        groups.last.add(row);
      }
    }
    final categories =
        rows.map((r) => r.topic.category.trim()).where((c) => c.isNotEmpty);
    final multiCategory = categories.toSet().length > 1;

    Widget pathRows(List<_LessonRowData> group) => Column(
          children: [
            for (int i = 0; i < group.length; i++)
              _LessonRow(
                data: group[i],
                isLast: i == group.length - 1,
                onTap: group[i].status == _LessonStatus.locked
                    ? null
                    : () => _openLesson(context, group[i].topic, lessonContext),
              ),
          ],
        );

    // One category: the top bar names it (see FellowshipLessonsTopBar), so
    // the rows follow the summary card without a heading of their own.
    if (!multiCategory) return pathRows(rows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int g = 0; g < groups.length; g++) ...[
          if (g > 0) const SizedBox(height: 28),
          CommunitySectionLabel(groups[g].first.topic.category.trim().isEmpty
              ? l10n.lessonsAllLessons
              : groups[g].first.topic.category.trim()),
          const SizedBox(height: 14),
          pathRows(groups[g]),
        ],
      ],
    );
  }
}

/// Where a lesson sits on the path for the viewing member.
enum _LessonStatus {
  /// Personally completed.
  done,

  /// Not completed, but the group has moved past it.
  groupPast,

  /// The fellowship's current lesson for this member.
  now,

  /// Open (non-sequential paths, or reached) but not the current one.
  open,

  /// Not yet reachable.
  locked,
}

class _LessonRowData {
  final LearningPathTopic topic;
  final _LessonStatus status;
  final int discussionCount;

  const _LessonRowData({
    required this.topic,
    required this.status,
    required this.discussionCount,
  });
}

// ---------------------------------------------------------------------------
// _LessonRow — a 36px rail (status marker + connector to the next row), then
// the title, chevron and meta. The current lesson's body sits in a card.
// ---------------------------------------------------------------------------

class _LessonRow extends StatelessWidget {
  final _LessonRowData data;
  final bool isLast;
  final VoidCallback? onTap;

  static const double _rail = 36;
  static const double _gap = 28;

  const _LessonRow({
    required this.data,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final topic = data.topic;
    final status = data.status;
    final isLocked = status == _LessonStatus.locked;
    final isDone = status == _LessonStatus.done;
    final isNow = status == _LessonStatus.now;
    final successInk =
        palette.isDark ? AppColors.successLighter : AppColors.successDark;

    final titleRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            topic.title,
            style: AppFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDone ? palette.muted : palette.text,
              height: 1.35,
            ),
          ),
        ),
        if (!isLocked) ...[
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 22, color: palette.dim),
        ],
      ],
    );

    // Tags and meta wrap onto another line rather than truncating in Hindi
    // and Malayalam.
    final meta = Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (isNow)
          _LessonTag.now(
              context, context.tr(TranslationKeys.communityFellowshipNow)),
        if (isDone)
          Text(
            context.tr(TranslationKeys.communityLessonsStatusDone),
            style: AppFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: successInk,
            ),
          ),
        if (topic.isMilestone)
          _LessonTag.milestone(
              context, context.tr(TranslationKeys.learningPathsMilestone)),
        if (status == _LessonStatus.groupPast)
          _LessonTag(
            label: l10n.lessonsGroupMovedOn,
            fill: palette.raised,
            ink: palette.muted,
          ),
        Text(
          '+${topic.xpValue} XP',
          style: AppFonts.inter(fontSize: 12.5, color: palette.muted),
        ),
        if (data.discussionCount > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_rounded,
                  size: 13, color: palette.accentIcon),
              const SizedBox(width: 4),
              Text(
                '${data.discussionCount}',
                style: AppFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: palette.accentIcon,
                ),
              ),
            ],
          ),
      ],
    );

    final bodyColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [titleRow, const SizedBox(height: 6), meta],
    );

    final Widget body = isNow
        ? Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.accentIcon.withValues(alpha: 0.4),
              ),
            ),
            child: bodyColumn,
          )
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: bodyColumn,
          );

    final connectorColor =
        isDone ? AppColors.success.withValues(alpha: 0.45) : palette.hairline;

    final content = Stack(
      children: [
        if (!isLast)
          Positioned(
            left: _rail / 2 - 1,
            width: 2,
            top: _rail,
            bottom: 0,
            child: ColoredBox(color: connectorColor),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : _gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LessonStatusMarker(
                status: status,
                number: topic.position + 1,
                size: _rail,
              ),
              const SizedBox(width: 12),
              Expanded(child: body),
            ],
          ),
        ),
      ],
    );

    return Opacity(
      opacity: isLocked ? 0.55 : 1.0,
      // Ink splash on tap only: no hover, focus or pressed fill that lingers
      // on the row after returning from the lesson.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: palette.accentIcon.withValues(alpha: 0.10),
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: content,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LessonStatusMarker — the circle on the path rail
// ---------------------------------------------------------------------------

class _LessonStatusMarker extends StatelessWidget {
  final _LessonStatus status;
  final int number;
  final double size;

  const _LessonStatusMarker({
    required this.status,
    required this.number,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final successInk =
        palette.isDark ? AppColors.successLighter : AppColors.successDark;

    Widget numberText(Color color) => Text(
          '$number',
          style: AppFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        );

    final Color fill;
    final Border? border;
    final Widget child;
    final String semanticsLabel;
    switch (status) {
      case _LessonStatus.done:
        fill = AppColors.success.withValues(alpha: 0.15);
        border = Border.all(color: successInk, width: 1.5);
        child = Icon(Icons.check_rounded, color: successInk, size: 20);
        semanticsLabel = context.tr(TranslationKeys.communityLessonsStatusDone);
      case _LessonStatus.groupPast:
        fill = Colors.transparent;
        border = Border.all(color: palette.outline, width: 1.5);
        child = Icon(Icons.check_rounded, color: palette.muted, size: 18);
        semanticsLabel = AppLocalizations.of(context)!.lessonsGroupMovedOn;
      case _LessonStatus.now:
        fill = AppColors.brandPrimary
            .withValues(alpha: palette.isDark ? 0.20 : 0.10);
        border = Border.all(color: palette.accentIcon, width: 1.5);
        child = numberText(palette.accentIcon);
        semanticsLabel = context.tr(TranslationKeys.communityFellowshipNow);
      case _LessonStatus.open:
        fill = palette.raised;
        border = null;
        child = numberText(palette.muted);
        semanticsLabel =
            context.tr(TranslationKeys.communityLessonsStatusUpcoming);
      case _LessonStatus.locked:
        fill = palette.raised;
        border = null;
        child = Icon(Icons.lock_rounded, color: palette.dim, size: 15);
        semanticsLabel =
            context.tr(TranslationKeys.communityLessonsStatusLocked);
    }

    return Semantics(
      label: semanticsLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: border,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LessonTag — the small pill used for Now, Milestone and Group moved on
// ---------------------------------------------------------------------------

class _LessonTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color fill;
  final Color ink;
  final double fontSize;
  final FontWeight fontWeight;

  const _LessonTag({
    required this.label,
    required this.fill,
    required this.ink,
    this.icon,
    this.fontSize = 11.5,
    this.fontWeight = FontWeight.w600,
  });

  /// Solid indigo "▶ Now" tag marking the current lesson.
  factory _LessonTag.now(BuildContext context, String label) => _LessonTag(
        label: label,
        icon: Icons.play_arrow_outlined,
        fill: AppColors.brandPrimary,
        ink: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      );

  /// Gold-tinted flag tag for milestone lessons.
  factory _LessonTag.milestone(BuildContext context, String label) {
    final palette = ReaderPalette.of(context);
    return _LessonTag(
      label: label,
      icon: Icons.flag_rounded,
      fill: palette.gold.withValues(alpha: palette.isDark ? 0.16 : 0.12),
      ink: palette.gold,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: ink),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              style: AppFonts.inter(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LessonsLoadError — the lessons failed to load; retry
// ---------------------------------------------------------------------------

class _LessonsLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LessonsLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 36, color: palette.dim),
          const SizedBox(height: 12),
          Text(
            context.tr(TranslationKeys.communitySharedLoadErrorBody),
            textAlign: TextAlign.center,
            style: AppFonts.inter(
              fontSize: 14,
              color: palette.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          CommunityRaisedPill(
            icon: Icons.refresh_rounded,
            label: context.tr(TranslationKeys.commonRetry),
            onPressed: onRetry,
          ),
        ],
      ),
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
    final palette = ReaderPalette.of(context);
    final message =
        isMentor ? l10n.lessonsNoPathMentor : l10n.lessonsNoPathMember;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 56, color: palette.dim),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppFonts.inter(
                fontSize: 15,
                color: palette.muted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
    final palette = ReaderPalette.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.accentIcon,
          side: BorderSide(color: palette.accentIcon, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: const StadiumBorder(),
        ),
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: palette.accentIcon,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.arrow_forward_rounded, size: 20),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: AppFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
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
    return Center(
      child: CommunityCtaPill(
        icon: Icons.add_circle_outline_rounded,
        label: label,
        loading: isLoading,
        onPressed: onTap,
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
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        context.read<LearningPathsBloc>().add(
              LoadFlatLearningPaths(language: widget.language),
            );
      } else {
        context.read<LearningPathsBloc>().add(
              SearchLearningPaths(query: trimmed, language: widget.language),
            );
      }
    });
  }

  /// The paths in discipleship order: seeker, follower, disciple, leader, and
  /// within a level the curated display order (New Believer Essentials first).
  ///
  /// The listing arrives ordered for the mentor personally — their own
  /// in-progress and enrolled paths, then featured ones — which put a path the
  /// mentor had started ahead of where a group should begin. A group picks from
  /// the curriculum as designed, so the personal order is only the tiebreak.
  List<LearningPath> _byDiscipleLevel(List<LearningPath> paths) {
    final sorted = [...paths];
    sorted.sort((a, b) {
      final byLevel = discipleLevelRank(a.discipleLevel)
          .compareTo(discipleLevelRank(b.discipleLevel));
      if (byLevel != 0) return byLevel;
      // Paths without an order (older cached data) go after ordered ones.
      final byOrder =
          (a.displayOrder ?? 1 << 30).compareTo(b.displayOrder ?? 1 << 30);
      if (byOrder != 0) return byOrder;
      return paths.indexOf(a).compareTo(paths.indexOf(b));
    });
    return sorted;
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
    final palette = ReaderPalette.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, sheetController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: palette.hairline)),
          ),
          child: Column(
            children: [
              // ── Handle ─────────────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Title ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  l10n.lessonsPickPathTitle,
                  style: AppFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
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
                    style: AppFonts.inter(fontSize: 15, color: palette.text),
                    decoration: communityInputDecoration(
                      context,
                      pill: true,
                      hintText: l10n.searchPathsHint,
                      prefixIcon: Icon(Icons.search, color: palette.muted),
                      suffixIcon: hasText
                          ? IconButton(
                              tooltip: MaterialLocalizations.of(context)
                                  .deleteButtonTooltip,
                              icon: Icon(Icons.close,
                                  size: 18, color: palette.muted),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('', ctx);
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              Divider(height: 1, color: palette.hairline),

              // ── Path list ──────────────────────────────────────────────
              Expanded(
                child: BlocBuilder<LearningPathsBloc, LearningPathsState>(
                  builder: (context, state) {
                    if (state is LearningPathsLoading ||
                        state is LearningPathsInitial) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: palette.accentIcon,
                        ),
                      );
                    }

                    if (state is LearningPathsError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            state.message,
                            style: AppFonts.inter(
                              fontSize: 14,
                              color: palette.muted,
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
                              color: palette.accentIcon,
                            ),
                          );
                        }
                        // This is the sheet's normal listing too, not only an
                        // actual search: LoadFlatLearningPaths emits every path
                        // as `searchResults` with an empty query, so `categories`
                        // — and therefore `allPaths` — is always empty here.
                        final results =
                            _byDiscipleLevel(state.searchResults ?? []);
                        if (results.isEmpty) {
                          return _PathPickerEmpty(
                              message: l10n.searchNoResults);
                        }
                        return ListView.builder(
                          controller: sheetController,
                          padding: EdgeInsets.fromLTRB(16, 8, 16,
                              24 + MediaQuery.paddingOf(context).bottom),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final path = results[index];
                            final previous = index == 0
                                ? null
                                : results[index - 1].discipleLevel;
                            final startsLevel = index == 0 ||
                                discipleLevelRank(previous) !=
                                    discipleLevelRank(path.discipleLevel);

                            return _PathPickerItem(
                              levelHeading:
                                  startsLevel ? path.discipleLevel : null,
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
                        );
                      }

                      // ── Normal mode (category listing + pagination) ──────
                      // Ordered by the discipleship progression rather than the
                      // personalised category order the listing arrives in.
                      // Flattening the categories dropped their headings, so the
                      // picker showed seeker, follower, disciple, seeker... with
                      // nothing on screen explaining the grouping — it read as
                      // random. The whole list arrives in one request here
                      // (LoadFlatLearningPaths, limit 100), so sorting it is
                      // stable; nothing reshuffles as the sheet scrolls.
                      final allPaths = _byDiscipleLevel(state.allPaths);

                      if (allPaths.isEmpty && !state.hasMoreCategories) {
                        return _PathPickerEmpty(
                          message: context
                              .tr(TranslationKeys.communityFellowshipNoPaths),
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
                          padding: EdgeInsets.fromLTRB(16, 8, 16,
                              24 + MediaQuery.paddingOf(context).bottom),
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
                                            color: palette.accentIcon,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              );
                            }

                            final path = allPaths[index];
                            // Heading at each level change, so the progression
                            // the list is sorted by is visible rather than implied.
                            final previous = index == 0
                                ? null
                                : allPaths[index - 1].discipleLevel;
                            final startsLevel = index == 0 ||
                                discipleLevelRank(previous) !=
                                    discipleLevelRank(path.discipleLevel);

                            return _PathPickerItem(
                              levelHeading:
                                  startsLevel ? path.discipleLevel : null,
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
                size: 48, color: ReaderPalette.of(context).dim),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                fontSize: 14,
                color: ReaderPalette.of(context).muted,
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

  /// Level name to head this row with, set on the first path of each level.
  final String? levelHeading;

  const _PathPickerItem({
    required this.path,
    required this.onTap,
    this.levelHeading,
  });

  @override
  Widget build(BuildContext context) {
    final heading = levelHeading;
    if (heading != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10, left: 4),
            child: CommunitySectionLabel(_levelLabel(context, heading)),
          ),
          _buildCard(context),
        ],
      );
    }
    return _buildCard(context);
  }

  /// The level's name in the reader's language, falling back to whatever the
  /// row holds when it is a level this build does not know.
  String _levelLabel(BuildContext context, String level) {
    final key = discipleLevelLabelKey(level);
    return key == null ? level : context.tr(key);
  }

  Widget _buildCard(BuildContext context) {
    final palette = ReaderPalette.of(context);
    final successInk =
        palette.isDark ? AppColors.successLighter : AppColors.successDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: palette.isDark ? palette.raised : palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary
                        .withValues(alpha: palette.isDark ? 0.24 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: palette.accentIcon,
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
                        style: AppFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                          height: 1.3,
                        ),
                      ),
                      if (path.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          path.description,
                          style: AppFonts.inter(
                            fontSize: 13,
                            color: palette.muted,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${path.topicsCount} ${context.tr(TranslationKeys.learningPathsTopics)}'
                            ' · ${_levelLabel(context, path.discipleLevel)}',
                            style: AppFonts.inter(
                              fontSize: 12.5,
                              color: palette.dim,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (path.fellowshipCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.success.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                context
                                    .tr(TranslationKeys.learningPathsCompleted),
                                style: AppFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: successInk,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: palette.dim,
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
  final int? fellowshipGuideIndex;
  final int? fellowshipTotalGuides;

  const _MemberProgressSection({
    required this.l10n,
    this.fellowshipGuideIndex,
    this.fellowshipTotalGuides,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LearningPathsBloc, LearningPathsState>(
      builder: (context, pathsState) {
        final int? totalTopics = pathsState is LearningPathDetailLoaded
            ? pathsState.pathDetail.topics.length
            : fellowshipTotalGuides;

        // The topic at the fellowship's own position — not _findNowTopic,
        // which factors in the *viewing* member's personal completion and can
        // return a different (or no) lesson than the "X/Y" count just above
        // it. Looking up by position keeps this chip always in agreement with
        // that count.
        LearningPathTopic? currentTopic;
        if (pathsState is LearningPathDetailLoaded &&
            fellowshipGuideIndex != null) {
          for (final t in pathsState.pathDetail.topics) {
            if (t.position == fellowshipGuideIndex) {
              currentTopic = t;
              break;
            }
          }
        }

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

            final fellowshipProgress = (fellowshipGuideIndex != null &&
                    totalTopics != null &&
                    totalTopics > 0)
                ? (fellowshipGuideIndex! / totalTopics).clamp(0.0, 1.0)
                : null;

            final palette = ReaderPalette.of(context);
            return Container(
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: palette.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary.withValues(
                                alpha: palette.isDark ? 0.24 : 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.people_alt_outlined,
                            size: 18,
                            color: palette.accentIcon,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Title and badge stack: side by side they overflow
                        // in Hindi and Malayalam at 320pt.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.lessonsMemberProgress,
                                style: AppFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: palette.text,
                                  height: 1.3,
                                ),
                              ),
                              if (totalTopics != null) ...[
                                const SizedBox(height: 6),
                                _CompletionBadge(
                                  completed: completedCount,
                                  total: totalCount,
                                  l10n: l10n,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Fellowship progress bar ───────────────────────────
                  if (fellowshipProgress != null) ...[
                    Divider(height: 1, color: palette.hairline),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.groups_outlined,
                                size: 16,
                                color: palette.muted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.fellowshipProgress,
                                  style: AppFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: palette.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${fellowshipGuideIndex!}/${totalTopics!}',
                                style: AppFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: palette.gold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          CommunityProgressBar(
                            value: fellowshipProgress.toDouble(),
                          ),
                          if (currentTopic != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: palette.raised,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.menu_book_rounded,
                                      size: 15,
                                      color: palette.gold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        style: AppFonts.inter(
                                          fontSize: 13,
                                          color: palette.muted,
                                          height: 1.4,
                                        ),
                                        children: [
                                          TextSpan(
                                              text:
                                                  '${l10n.lessonsCurrentLesson}: '),
                                          TextSpan(
                                            text: currentTopic.title,
                                            style: AppFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: palette.text,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  Divider(height: 1, color: palette.hairline),

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
    final palette = ReaderPalette.of(context);
    final allDone = completed == total && total > 0;
    final bg =
        allDone ? AppColors.success.withValues(alpha: 0.14) : palette.raised;
    final fg = allDone
        ? (palette.isDark ? AppColors.successLighter : AppColors.successDark)
        : palette.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$completed/$total ${l10n.lessonsMembersCompleted}',
        style: AppFonts.inter(
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
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final completed = member.topicsCompleted ?? 0;
    final total = totalTopics ?? 0;
    final progress =
        total > 0 ? (completed / total).clamp(0.0, 1.0).toDouble() : 0.0;
    final isDone = total > 0 && completed >= total;
    final isMentorMember = member.role == 'mentor';
    final successInk =
        palette.isDark ? AppColors.successLighter : AppColors.successDark;

    Widget avatar = MemberAvatar(
      displayName: member.displayName,
      avatarUrl: member.avatarUrl,
      radius: 18,
    );
    if (isDone) {
      // Green ring when completed
      avatar = Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.success, width: 2),
        ),
        child: avatar,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),

          // Name + progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      member.displayName,
                      style: AppFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    if (isMentorMember)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.gold
                              .withValues(alpha: palette.isDark ? 0.18 : 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l10n.mentorLabel,
                          style: AppFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: palette.gold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                isDone
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: 1,
                          minHeight: 4,
                          backgroundColor: palette.raised,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.success),
                        ),
                      )
                    : CommunityProgressBar(value: progress),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Fraction or checkmark
          if (isDone)
            Icon(Icons.check_circle_rounded, color: successInk, size: 20)
          else if (totalTopics != null)
            Text(
              '$completed/$total',
              style: AppFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
            ),
        ],
      ),
    );
  }
}
