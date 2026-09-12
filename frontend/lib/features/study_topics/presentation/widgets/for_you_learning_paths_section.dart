import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_preference_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/locked_feature_wrapper.dart';
import '../../../community/domain/repositories/community_repository.dart';
import '../../domain/repositories/learning_paths_repository.dart';
import '../../../walkthrough/domain/walkthrough_screen.dart';
import '../../../walkthrough/presentation/showcase_keys.dart';
import '../../../walkthrough/presentation/walkthrough_tooltip.dart';
import '../../domain/entities/learning_path.dart';
import '../bloc/learning_paths_bloc.dart';
import '../bloc/learning_paths_state.dart';
import 'learning_path_card.dart';

/// "For You" learning paths section shown on the Study Topics screen.
///
/// Shows ≥3 learning paths in priority order:
///   0. Fellowship active learning path (if not already in list)
///   1. In-progress paths (sorted by progress descending)
///   2. Featured / recommended paths
///   3. Any remaining non-completed paths to fill up to [minCount]
///
/// Reuses [LearningPathsBloc] data — no extra fetch required.
/// Fellowship path is fetched once on init from [CommunityRepository].
class ForYouLearningPathsSection extends StatefulWidget {
  final void Function(LearningPath path) onPathTap;

  /// Minimum number of paths to show. Filled with featured/any if needed.
  final int minCount;

  /// Called when the user taps "Got it →" on the step-1 walkthrough tooltip.
  /// Pass null to skip the walkthrough step entirely.
  final VoidCallback? onNext;

  const ForYouLearningPathsSection({
    super.key,
    required this.onPathTap,
    this.minCount = 3,
    this.onNext,
  });

  @override
  State<ForYouLearningPathsSection> createState() =>
      _ForYouLearningPathsSectionState();
}

class _ForYouLearningPathsSectionState extends State<ForYouLearningPathsSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// The learning path from the user's best active fellowship study.
  /// Null if the user has no fellowship with an active study.
  LearningPath? _fellowshipPath;

  /// Paths the user's fellowships have already finished. Never recommended.
  Set<String> _fellowshipCompletedPathIds = const {};

  /// True while the fellowship path fetch is in progress.
  /// Keeps the skeleton visible until both BLoC and fellowship are ready.
  bool _isFellowshipLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFellowshipActivePath();
  }

  /// Fetches fellowships and resolves the LearningPath for the most recently
  /// started active fellowship study.
  ///
  /// "Active" means: currentStudy != null AND completedAt == null.
  /// When multiple fellowships qualify, picks the one with the latest startedAt.
  ///
  /// Resolution order:
  ///   1. Already in LearningPathsBloc state (fast, no extra call)
  ///   2. Fetch via getLearningPathDetails (path is in a not-yet-loaded category)
  Future<void> _loadFellowshipActivePath() async {
    try {
      final language =
          await sl<LanguagePreferenceService>().getStudyContentLanguage();
      final fellowshipsResult =
          await sl<CommunityRepository>().getFellowships(language.code);

      String? pathId;
      fellowshipsResult.fold(
        (_) => null,
        (fellowships) {
          final completed =
              fellowships.expand((f) => f.completedPathIds).toSet();
          if (completed.isNotEmpty && mounted) {
            setState(() => _fellowshipCompletedPathIds = completed);
          }
          final active = fellowships
              .where((f) =>
                  f.currentStudy != null && f.currentStudy!.completedAt == null)
              .toList();
          if (active.isEmpty) return;
          active.sort((a, b) =>
              b.currentStudy!.startedAt.compareTo(a.currentStudy!.startedAt));
          pathId = active.first.currentStudy!.learningPathId;
        },
      );

      if (pathId == null || !mounted) return;

      // Try BLoC state first — no extra network call needed
      final blocState = context.read<LearningPathsBloc>().state;
      if (blocState is LearningPathsLoaded) {
        final found =
            blocState.allPaths.where((p) => p.id == pathId).firstOrNull;
        if (found != null) {
          setState(() => _fellowshipPath = found);
          return;
        }
      }

      // Path not yet in loaded categories — fetch it directly
      final detailResult =
          await sl<LearningPathsRepository>().getLearningPathDetails(
        pathId: pathId!,
        language: language.code,
        // This card shows progress and leads the section, so it must not come
        // from the persisted copy: a path finished since it was cached kept
        // reading "1/8 Topics, 12%" and stayed at the top of For You.
        forceRefresh: true,
      );
      detailResult.fold(
        (_) => null,
        (detail) {
          if (mounted) setState(() => _fellowshipPath = detail);
        },
      );
    } catch (_) {
      // Fellowship path is supplementary — never block the For You section
    } finally {
      if (mounted) setState(() => _isFellowshipLoading = false);
    }
  }

  // ── Priority list builder ────────────────────────────────────────────────

  List<LearningPath> _buildForYouPaths(LearningPathsLoaded state) =>
      buildForYouPaths(
        state: state,
        fellowshipCompletedPathIds: _fellowshipCompletedPathIds,
        fellowshipPath: _fellowshipPath,
        minCount: widget.minCount,
      );

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Re-resolve the fellowship's path whenever the listing reloads. The
    // section's initState runs once — the tab is kept alive by the
    // IndexedStack — so without this the card kept the progress it was built
    // with, even after the path was finished.
    return BlocListener<LearningPathsBloc, LearningPathsState>(
      listenWhen: (previous, current) =>
          current is LearningPathsLoaded && previous is! LearningPathsLoaded,
      listener: (_, __) => _loadFellowshipActivePath(),
      child: BlocBuilder<LearningPathsBloc, LearningPathsState>(
        // A progress reset emits LearningPathsResetting / LearningPathsResetSuccess
        // / LearningPathsResetError as siblings of LearningPathsLoaded on the same
        // bloc — ignore them here so the currently displayed paths don't flash
        // away (or disappear entirely, since this builder's fallback is
        // SizedBox.shrink()) mid-reset or on a failed reset. The follow-up
        // LoadLearningPaths(forceRefresh: true) emits LearningPathsLoading /
        // LearningPathsLoaded normally, which this builder still reacts to.
        buildWhen: (previous, current) =>
            current is! LearningPathsResetting &&
            current is! LearningPathsResetSuccess &&
            current is! LearningPathsResetError,
        builder: (context, state) {
          if (state is LearningPathsLoading ||
              state is LearningPathsInitial ||
              _isFellowshipLoading) {
            return _buildSkeleton(context);
          }
          if (state is LearningPathsLoaded) {
            final paths = _buildForYouPaths(state);
            if (paths.isEmpty) return const SizedBox.shrink();
            return _buildContent(context, paths);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<LearningPath> paths) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final header = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appBrandAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color:
                isDark ? AppColors.brandPrimaryLight : context.appBrandAccent,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.walkthroughForYouTitle,
              style: AppFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withOpacity(0.9)
                    : const Color(0xFF1F2937),
              ),
            ),
            Text(
              AppLocalizations.of(context)!.forYouSectionSubtitle,
              style: AppFonts.inter(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withOpacity(0.6)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 16),
        LockedFeatureWrapper(
          featureKey: 'learning_paths',
          child: Column(
            children: [
              for (int i = 0; i < paths.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: i == 0 && widget.onNext != null
                      ? WalkthroughTooltip(
                          showcaseKey: ShowcaseKeys.topicsPathList,
                          title: AppLocalizations.of(context)!
                              .walkthroughForYouTitle,
                          description: AppLocalizations.of(context)!
                              .walkthroughForYouDesc,
                          screen: WalkthroughScreen.learningPaths,
                          stepNumber: 1,
                          totalSteps: 2,
                          onNext: widget.onNext!,
                          tooltipPosition: TooltipPosition.bottom,
                          child: LearningPathCard(
                            path: paths[i],
                            compact: false,
                            onTap: () => widget.onPathTap(paths[i]),
                          ),
                        )
                      : LearningPathCard(
                          path: paths[i],
                          compact: false,
                          onTap: () => widget.onPathTap(paths[i]),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shimmerBase =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: shimmerBase,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 80,
                    height: 14,
                    decoration: BoxDecoration(
                        color: shimmerBase,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 4),
                Container(
                    width: 160,
                    height: 11,
                    decoration: BoxDecoration(
                        color: shimmerBase,
                        borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: shimmerBase,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Selection logic (pure — unit tested in for_you_path_selection_test.dart)
// ---------------------------------------------------------------------------

/// A path is "done" if the user finished it themselves or their fellowship
/// finished it as a group.
///
/// Group study records no personal per-topic progress, so a path a fellowship
/// worked through still reads as 0% for each member and
/// [LearningPath.isCompleted] alone is not enough to keep it out of the
/// recommendations.
bool _isDone(LearningPath path, Set<String> fellowshipCompletedPathIds) =>
    path.isCompleted || fellowshipCompletedPathIds.contains(path.id);

/// Chooses the paths shown in the For You section, in priority order:
/// the fellowship's active study, then in-progress paths, then personalized
/// (or featured) recommendations, then anything left. Nothing already done
/// appears at any position.
List<LearningPath> buildForYouPaths({
  required LearningPathsLoaded state,
  required Set<String> fellowshipCompletedPathIds,
  required LearningPath? fellowshipPath,
  required int minCount,
}) {
  final result = <LearningPath>[];
  bool done(LearningPath p) => _isDone(p, fellowshipCompletedPathIds);

  // 0. Fellowship active path — prefer the version from the current BLoC
  //    state so it reflects the latest language after a language switch.
  final fellowshipPathId = fellowshipPath?.id;
  final resolvedFellowshipPath = fellowshipPathId != null
      ? (state.allPaths.where((p) => p.id == fellowshipPathId).firstOrNull ??
          fellowshipPath)
      : null;

  // 1. In-progress paths — most progressed first
  final inProgress = state.enrolledPaths
      .where((p) => p.isInProgress && !done(p))
      .toList()
    ..sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
  result.addAll(inProgress);

  // 2. Fill remaining slots from questionnaire-personalized paths (scored by
  //    the backend algorithm based on faith_stage, spiritual_goals, etc.).
  //    Falls back to featured paths when personalizedPaths is empty
  //    (e.g. not yet loaded, unauthenticated, or questionnaire not completed).
  final personalizedSource = state.personalizedPaths.isNotEmpty
      ? state.personalizedPaths
      : state.allPaths.where((p) => p.isFeatured).toList();

  if (result.length < minCount) {
    final candidates = personalizedSource
        .where((p) => !done(p) && !result.any((r) => r.id == p.id))
        .toList();
    result.addAll(candidates.take(minCount - result.length));
  }

  // 3. Final fallback: any path that is neither done nor already listed.
  if (result.length < minCount) {
    final fallback = state.allPaths
        .where((p) => !done(p) && !result.any((r) => r.id == p.id))
        .toList();
    result.addAll(fallback.take(minCount - result.length));
  }

  // The fellowship's active study leads the list, unless it is already there
  // or already done.
  if (resolvedFellowshipPath != null &&
      !done(resolvedFellowshipPath) &&
      !result.any((r) => r.id == resolvedFellowshipPath.id)) {
    result.insert(0, resolvedFellowshipPath);
  }

  return result;
}
