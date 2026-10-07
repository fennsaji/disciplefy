import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import 'package:disciplefy_bible_study/features/community/domain/utils/fellowship_lesson_language.dart';
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
import 'package:disciplefy_bible_study/features/community/presentation/utils/group_study_progress.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_buttons.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_confirm_dialog.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_text_field.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/community_top_bars.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_card_parts.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/fellowship_path_picker_sheet.dart';
import 'package:disciplefy_bible_study/features/community/presentation/widgets/member_avatar.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_paths_cache_service.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/disciple_level.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/entities/learning_path.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:disciplefy_bible_study/shared/widgets/gold_marks.dart';
import 'package:disciplefy_bible_study/shared/widgets/app_snackbar.dart';

/// Lessons tab for a fellowship.
///
/// Shows the currently active learning path with individual guide cards
/// (each topic in the path rendered as a lesson card), and allows the
/// mentor to assign or change the fellowship's study path.
class FellowshipLessonsTabScreen extends StatefulWidget {
  final String fellowshipId;
  final String? languageOverride;

  /// Looks up the group's language when neither [languageOverride] nor the
  /// study state has it. Defaults to a Supabase query; replaceable in tests.
  @visibleForTesting
  final Future<String?> Function(String fellowshipId)? fellowshipLanguageLoader;

  const FellowshipLessonsTabScreen({
    required this.fellowshipId,
    this.languageOverride,
    this.fellowshipLanguageLoader,
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

  static Future<String?> _fetchFellowshipLanguage(String fellowshipId) async {
    final row = await Supabase.instance.client
        .from('fellowships')
        .select('language')
        .eq('id', fellowshipId)
        .maybeSingle();
    return row?['language'] as String?;
  }

  /// Bumped on every [_loadPathDetails] call so a slower, older call (e.g.
  /// still awaiting the member's study language) can't overwrite the result
  /// of a newer one that already used the group's language.
  int _loadRequest = 0;

  /// Resolves the lesson language and loads path details. [pathId] is used
  /// when a new path was just assigned and its ID is already known, e.g. from
  /// the [BlocListener] callback.
  Future<void> _loadPathDetails({String? pathId}) async {
    final request = ++_loadRequest;
    final override = widget.languageOverride;
    final String langCode;
    if (override != null) {
      langCode = override;
    } else {
      langCode = await resolveFellowshipLessonLanguage(
        prefs: sl<SharedPreferences>(),
        fellowshipId: widget.fellowshipId,
        fellowshipLanguage:
            context.read<FellowshipStudyBloc>().state.fellowshipLanguage,
        fetchFellowshipLanguage: () => (widget.fellowshipLanguageLoader ??
            _fetchFellowshipLanguage)(widget.fellowshipId),
        userStudyLanguage: () async =>
            (await sl<LanguagePreferenceService>().getStudyContentLanguage())
                .code,
      );
    }
    if (!mounted || request != _loadRequest) return;
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
            showAppSnackBar(context, l10n.lessonsPathAssignedSuccess,
                tone: AppSnackTone.success);
            // Member progress is counted on the group's path: reload it for
            // the new one.
            context.read<FellowshipMembersBloc>().add(
                  FellowshipMembersLoadRequested(
                      fellowshipId: widget.fellowshipId),
                );
          } else if (state.setStatus == FellowshipStudySetStatus.failure) {
            showAppSnackBar(
                context,
                state.setError ??
                    context.tr(TranslationKeys.communityFellowshipAssignFailed),
                tone: AppSnackTone.error);
          } else if (state.advanceStatus ==
              FellowshipStudyAdvanceStatus.success) {
            if (state.studyCompleted && state.isMentor) {
              _showPathCompletedDialog(context, state);
            } else {
              final msg = state.studyCompleted
                  ? l10n.lessonsCompleted
                  : '${l10n.lessonsGuideProgress} ${(state.currentGuideIndex ?? 0) + 1} ${l10n.lessonsOf} ${state.totalGuides ?? '?'}';
              showAppSnackBar(context, msg, tone: AppSnackTone.success);
            }
            // Refresh member list so topicsCompleted counts stay current.
            context.read<FellowshipMembersBloc>().add(
                  FellowshipMembersLoadRequested(
                      fellowshipId: widget.fellowshipId),
                );
          } else if (state.advanceStatus ==
              FellowshipStudyAdvanceStatus.failure) {
            showAppSnackBar(
                context,
                state.advanceError ??
                    context
                        .tr(TranslationKeys.communityFellowshipAdvanceFailed),
                tone: AppSnackTone.error);
          } else if (state.resetStatus == FellowshipStudyResetStatus.success) {
            showAppSnackBar(context, l10n.lessonsProgressResetSuccess,
                tone: AppSnackTone.success);
            context.read<FellowshipMembersBloc>().add(
                  FellowshipMembersLoadRequested(
                      fellowshipId: widget.fellowshipId),
                );
          } else if (state.resetStatus == FellowshipStudyResetStatus.failure) {
            showAppSnackBar(
                context,
                state.resetError ??
                    context.tr(TranslationKeys.communityFellowshipResetFailed),
                tone: AppSnackTone.error);
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
        child: FellowshipPathPickerSheet(
          fellowshipId: widget.fellowshipId,
          fellowshipName: studyBloc.state.fellowshipName,
          currentPathId: studyBloc.state.currentLearningPathId,
          language: _contentLanguage,
          onPathSelected: (path) => studyBloc.add(
            FellowshipStudySetRequested(
              fellowshipId: widget.fellowshipId,
              learningPathId: path.id,
              learningPathTitle: path.title,
            ),
          ),
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
          // The lesson the group is on (none once it has finished the path).
          final LearningPathTopic? groupTopic =
              (detail == null || state.studyCompleted)
                  ? null
                  : detail.topics
                      .where((t) => t.position == currentGuideIndex)
                      .firstOrNull;
          // A member who has finished every lesson alone still sees the
          // group's lesson on the card — the path is not "completed" for the
          // group until it finishes it together.
          final cardNow = now ??
              (groupTopic == null
                  ? null
                  : _NowTopic(groupTopic.position, groupTopic));

          // Clear the floating tab dock (its height is in the bottom padding).
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          return CustomScrollView(
            slivers: [
              // ── Summary: current lesson + group progress ──────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _LessonsSummaryCard(
                    state: state,
                    detail: detail,
                    now: cardNow,
                    groupTopic: groupTopic,
                    isMentor: isMentor,
                    isAdvancing: isAdvancing,
                    onAdvanceTap: onAdvanceTap,
                    onOpenNow: cardNow == null
                        ? null
                        : () =>
                            _openLesson(context, cardNow.topic, lessonContext),
                  ),
                ),
              ),

              // ── Change path button (mentor only) ──────────────────────
              if (isMentor)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _AssignPathButton(
                      isLoading:
                          state.setStatus == FellowshipStudySetStatus.loading,
                      hasStudy: true,
                      finished: state.studyCompleted,
                      onTap: onPathPickerTap,
                    ),
                  ),
                ),

              // ── Member progress overview (mentor only) ────────────────
              if (isMentor)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
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
                    groupPosition: groupTopic?.position,
                    lessonContext: lessonContext,
                    studyPathId: state.currentLearningPathId,
                  ),
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 32 + bottomInset)),
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
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, 24 + MediaQuery.paddingOf(context).bottom),
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

  /// The lesson the group is on; null once the group has finished.
  final LearningPathTopic? groupTopic;
  final bool isMentor;
  final bool isAdvancing;
  final VoidCallback onAdvanceTap;
  final VoidCallback? onOpenNow;

  const _LessonsSummaryCard({
    required this.state,
    required this.detail,
    required this.now,
    required this.groupTopic,
    required this.isMentor,
    required this.isAdvancing,
    required this.onAdvanceTap,
    required this.onOpenNow,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);

    // The loaded lessons are authoritative when they are the group's path;
    // the study's stored count is the fallback while they load.
    int? total = state.totalGuides;
    if (detail != null &&
        detail!.topics.isNotEmpty &&
        (total == null ||
            total <= 0 ||
            detail!.id == state.currentLearningPathId)) {
      total = detail!.topics.length;
    }
    final hasTotal = total != null && total > 0;
    final guideIndex = state.currentGuideIndex ?? 0;
    // Lessons the group has finished: everything before its current one.
    final progress = GroupStudyProgress.of(
      currentGuideIndex: guideIndex,
      totalGuides: total,
      completed: state.studyCompleted,
    );

    // The lesson this member is on, or the group's position while the
    // lessons are still loading.
    final int lessonNumber = now != null ? now!.position + 1 : guideIndex + 1;
    final String lessonOf = hasTotal
        ? context.tr(TranslationKeys.communitySharedLessonOf,
            {'number': lessonNumber, 'total': total})
        : context.tr(
            TranslationKeys.communitySharedLesson, {'number': lessonNumber});
    // A path with no lessons (all retired) has nothing to finish.
    final allDone = state.studyCompleted ||
        (detail != null && detail!.topics.isNotEmpty && now == null);

    final xpEarned = detail == null
        ? 0
        : detail!.topics
            .where((t) => t.isCompleted)
            .fold<int>(0, (sum, t) => sum + t.xpValue);

    final groupProgress =
        context.tr(TranslationKeys.communityFellowshipGroupProgress);
    final isLastGuide = state.currentGuideIndex != null &&
        hasTotal &&
        state.currentGuideIndex! >= total - 1;

    // The group's own lesson, next to its progress — only when it differs
    // from the lesson the header already shows (a member ahead of the group).
    final String? groupLesson = !hasTotal
        ? null
        : state.studyCompleted
            ? progress.finishedLabel(context)
            : groupTopic == null || groupTopic!.position == now?.position
                ? null
                : '${context.tr(TranslationKeys.communitySharedLessonOf, {
                        'number': groupTopic!.position + 1,
                        'total': total,
                      })} · ${groupTopic!.title}';

    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: CommunitySectionLabel(
                  context
                      .tr(TranslationKeys.communityFellowshipStudyingTogether),
                  fontSize: 10.5,
                ),
              ),
              if (!allDone) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
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
          if (progress.fraction != null) ...[
            const SizedBox(height: 10),
            _GoldProgressBar(value: progress.fraction!),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  progress.hasTotal
                      ? '$groupProgress · ${progress.doneLabel(context)}'
                      : groupProgress,
                  style: AppFonts.inter(fontSize: 13, color: palette.muted),
                ),
              ),
              if (xpEarned > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
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
          if (groupLesson != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    state.studyCompleted
                        ? Icons.check_circle_rounded
                        : Icons.groups_rounded,
                    size: 16,
                    color: palette.accentIcon,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    groupLesson,
                    style: AppFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
          // Advance guide button (mentor only, study not complete).
          if (isMentor && !state.studyCompleted) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: palette.hairline),
            const SizedBox(height: 14),
            _AdvanceGuideButton(
              isLoading: isAdvancing,
              label: isLastGuide
                  ? l10n.lessonsFinishPath
                  : l10n.lessonsAdvanceGuide,
              onTap: onAdvanceTap,
            ),
            // Where advancing takes the group (not shown when it finishes).
            if (!isLastGuide && state.currentGuideIndex != null) ...[
              const SizedBox(height: 8),
              Text(
                context.tr(TranslationKeys.communityLessonsAdvanceHint,
                    {'number': state.currentGuideIndex! + 2}),
                textAlign: TextAlign.center,
                style: AppFonts.inter(
                  fontSize: 12,
                  color: palette.muted,
                  height: 1.35,
                ),
              ),
            ],
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

  /// Position of the lesson the group is on; null once it finished the path.
  final int? groupPosition;
  final _LessonOpenContext lessonContext;
  final String? studyPathId;

  const _LessonPath({
    required this.pathsState,
    required this.topicPostCounts,
    required this.currentGuideIndex,
    required this.nowPosition,
    required this.groupPosition,
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
        isGroupLesson: topic.position == groupPosition,
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

  /// The lesson the whole group is currently on — marked whatever the
  /// viewer's own status is, so a member who has finished it still sees it.
  final bool isGroupLesson;

  const _LessonRowData({
    required this.topic,
    required this.status,
    required this.discussionCount,
    this.isGroupLesson = false,
  });
}

// ---------------------------------------------------------------------------
// _LessonRow — a 36px rail (status marker + connector to the next row), then
// the title, chevron and meta. The current lesson's body sits in a card.
// ---------------------------------------------------------------------------

class _LessonRow extends StatefulWidget {
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
  State<_LessonRow> createState() => _LessonRowState();
}

class _LessonRowState extends State<_LessonRow> {
  @override
  void initState() {
    super.initState();
    if (widget.data.isGroupLesson) _revealOnce();
  }

  @override
  void didUpdateWidget(covariant _LessonRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.isGroupLesson && !oldWidget.data.isGroupLesson) {
      _revealOnce();
    }
  }

  /// Scrolls just enough to bring the group's lesson on screen (no-op when
  /// it is already visible).
  void _revealOnce() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isLast = widget.isLast;
    final onTap = widget.onTap;
    const rail = _LessonRow._rail;
    const gap = _LessonRow._gap;
    final palette = ReaderPalette.of(context);
    final l10n = AppLocalizations.of(context)!;
    final topic = data.topic;
    final status = data.status;
    final isLocked = status == _LessonStatus.locked;
    final isDone = status == _LessonStatus.done;
    final isNow = status == _LessonStatus.now;
    final isGroupLesson = data.isGroupLesson;
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
        if (isGroupLesson)
          _LessonTag.groupHere(context, l10n.lessonsGroupIsHere),
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

    final Widget body = (isNow || isGroupLesson)
        ? Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: isGroupLesson
                  ? Color.alphaBlend(
                      palette.accentIcon
                          .withValues(alpha: palette.isDark ? 0.10 : 0.06),
                      palette.card,
                    )
                  : palette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: palette.accentIcon
                    .withValues(alpha: isGroupLesson ? 0.7 : 0.4),
                width: isGroupLesson ? 1.5 : 1,
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
            left: rail / 2 - 1,
            width: 2,
            top: rail,
            bottom: 0,
            child: ColoredBox(color: connectorColor),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : gap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LessonStatusMarker(
                status: status,
                number: topic.position + 1,
                size: rail,
                highlighted: isGroupLesson,
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

  /// Draws an accent ring around the marker for the group's current lesson.
  final bool highlighted;

  const _LessonStatusMarker({
    required this.status,
    required this.number,
    required this.size,
    this.highlighted = false,
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
        fill = palette.gold.withValues(alpha: palette.isDark ? 0.20 : 0.10);
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
          // Accent halo with a page-coloured gap, outside the rail size so
          // the row layout is unchanged.
          boxShadow: highlighted
              ? [
                  BoxShadow(color: palette.accentIcon, spreadRadius: 4.5),
                  BoxShadow(color: palette.page, spreadRadius: 2.5),
                ]
              : null,
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

  /// Solid gold "▶ Now" tag marking the current lesson.
  factory _LessonTag.now(BuildContext context, String label) => _LessonTag(
        label: label,
        icon: Icons.play_arrow_outlined,
        fill: ReaderPalette.of(context).selectedFill,
        ink: ReaderPalette.of(context).onSelected,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      );

  /// Accent-outlined "Group is here" tag marking the group's current lesson.
  factory _LessonTag.groupHere(BuildContext context, String label) {
    final palette = ReaderPalette.of(context);
    return _LessonTag(
      label: label,
      icon: Icons.location_on_rounded,
      fill: palette.accentIcon.withValues(alpha: palette.isDark ? 0.20 : 0.12),
      ink: palette.accentIcon,
      fontWeight: FontWeight.w700,
    );
  }

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
    return SizedBox(
      width: double.infinity,
      child: CommunityCtaPill(
        icon: Icons.skip_next_rounded,
        label: label,
        loading: isLoading,
        onPressed: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AssignPathButton — primary pill to assign the first path; once a path is
// set, a quiet outlined "Change learning path" pill.
// ---------------------------------------------------------------------------

class _AssignPathButton extends StatelessWidget {
  final bool isLoading;
  final bool hasStudy;

  /// The group has finished its path: the button picks the next one.
  final bool finished;
  final VoidCallback onTap;

  const _AssignPathButton({
    required this.isLoading,
    required this.hasStudy,
    this.finished = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!hasStudy) {
      return Center(
        child: CommunityCtaPill(
          icon: Icons.add_circle_outline_rounded,
          label: l10n.lessonsAssignPath,
          loading: isLoading,
          onPressed: onTap,
        ),
      );
    }

    final palette = ReaderPalette.of(context);
    final label =
        finished ? l10n.lessonsChooseNextPath : l10n.lessonsChangePath;
    final border = palette.isDark
        ? Colors.white.withValues(alpha: 0.24)
        : palette.hairline;
    final radius = BorderRadius.circular(24);
    return Semantics(
      container: true,
      button: true,
      enabled: !isLoading,
      label: label,
      onTap: isLoading ? null : onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(palette.text),
                      ),
                    )
                  else
                    Icon(Icons.route_rounded, size: 18, color: palette.text),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        height: 1.25,
                      ),
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
// _MemberProgressSection — mentor-only overview of every member's progress:
// a gold section label with the caught-up count, then one card of member rows.
// ---------------------------------------------------------------------------

class _MemberProgressSection extends StatelessWidget {
  final AppLocalizations l10n;

  /// The fellowship's current lesson index (lessons the group has passed).
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

        return BlocBuilder<FellowshipMembersBloc, FellowshipMembersState>(
          buildWhen: (prev, curr) =>
              prev.members != curr.members ||
              prev.status != curr.status ||
              prev.currentUserId != curr.currentUserId,
          builder: (context, membersState) {
            final members = membersState.members;
            final isLoading = members.isEmpty &&
                membersState.status == FellowshipMembersStatus.loading;
            // Nothing to show once loading ends without members (empty or
            // failed) — the lesson path below stays usable.
            if (members.isEmpty && !isLoading) return const SizedBox.shrink();

            final palette = ReaderPalette.of(context);
            final guideIndex = fellowshipGuideIndex;
            bool isCaughtUp(FellowshipMemberEntity m) =>
                guideIndex != null && (m.topicsCompleted ?? 0) >= guideIndex;
            final caughtUp = members.where(isCaughtUp).length;

            final Widget card;
            if (isLoading) {
              card = Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.gold,
                    ),
                  ),
                ),
              );
            } else {
              final rows = <Widget>[];
              for (var i = 0; i < members.length; i++) {
                if (i > 0) {
                  rows.add(Divider(height: 1, color: palette.hairline));
                }
                final m = members[i];
                rows.add(_MemberProgressRow(
                  member: m,
                  totalTopics: totalTopics,
                  isCaughtUp: isCaughtUp(m),
                  isSelf: membersState.currentUserId != null &&
                      m.userId == membersState.currentUserId,
                ));
              }
              card = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: rows),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Label row ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: CommunitySectionLabel(
                          l10n.lessonsMemberProgress,
                          fontSize: 11,
                        ),
                      ),
                      if (!isLoading && guideIndex != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Text(
                            context.tr(TranslationKeys.communityLessonsCaughtUp,
                                {'count': caughtUp, 'total': members.length}),
                            textAlign: TextAlign.end,
                            style: AppFonts.inter(
                              fontSize: 12.5,
                              color: palette.muted,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // ── Member rows ──────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: palette.hairline),
                  ),
                  child: card,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Per-member progress row ──────────────────────────────────────────────────

class _MemberProgressRow extends StatelessWidget {
  final FellowshipMemberEntity member;
  final int? totalTopics;

  /// Has finished at least as many lessons as the group's current one.
  final bool isCaughtUp;

  /// The row is the signed-in user.
  final bool isSelf;

  const _MemberProgressRow({
    required this.member,
    required this.totalTopics,
    required this.isCaughtUp,
    required this.isSelf,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ReaderPalette.of(context);
    final completed = member.topicsCompleted ?? 0;
    final total = totalTopics ?? 0;
    final progress =
        total > 0 ? (completed / total).clamp(0.0, 1.0).toDouble() : 0.0;
    final isMentorMember = member.role == 'mentor';
    final name = isSelf
        ? context.tr(TranslationKeys.communitySharedMentorYou,
            {'name': member.displayName})
        : member.displayName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          MemberAvatar(
            displayName: member.displayName,
            avatarUrl: member.avatarUrl,
            radius: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            name,
                            style: AppFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: palette.text,
                              height: 1.3,
                            ),
                          ),
                          if (isMentorMember)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: palette.gold.withValues(
                                    alpha: palette.isDark ? 0.18 : 0.14),
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
                    ),
                    if (totalTopics != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        '$completed / $total',
                        style: AppFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isCaughtUp ? palette.gold : palette.muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                CommunityProgressBar(value: progress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
