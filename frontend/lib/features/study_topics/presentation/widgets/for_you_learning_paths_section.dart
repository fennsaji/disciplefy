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

class _ForYouLearningPathsSectionState
    extends State<ForYouLearningPathsSection> {
  /// The learning path from the user's best active fellowship study.
  /// Null if the user has no fellowship with an active study.
  LearningPath? _fellowshipPath;

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

  // ── Level helpers ────────────────────────────────────────────────────────

  static const _levelOrder = ['seeker', 'follower', 'disciple', 'leader'];

  int _levelRank(String level) {
    final idx = _levelOrder.indexOf(level.toLowerCase());
    return idx == -1 ? 0 : idx;
  }

  // ── Priority list builder ────────────────────────────────────────────────

  List<LearningPath> _buildForYouPaths(LearningPathsLoaded state) {
    final result = <LearningPath>[];

    // 0. Fellowship active path — resolved in initState (may be from BLoC cache
    //    or fetched directly if its category hasn't loaded yet).
    final fellowshipPath = _fellowshipPath;

    // 1. In-progress paths — most progressed first
    final inProgress = state.enrolledPaths.where((p) => p.isInProgress).toList()
      ..sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
    result.addAll(inProgress);

    // Derive minimum level from the user's in-progress paths.
    final minLevelRank = inProgress.isNotEmpty
        ? inProgress
            .map((p) => _levelRank(p.discipleLevel))
            .reduce((a, b) => a > b ? a : b)
        : 0;

    // 2. Featured paths not yet in result, at or above the user's current level
    if (result.length < widget.minCount) {
      final featured = state.allPaths
          .where((p) =>
              p.isFeatured &&
              !result.any((r) => r.id == p.id) &&
              _levelRank(p.discipleLevel) >= minLevelRank)
          .toList();
      result.addAll(featured.take(widget.minCount - result.length));
    }

    // 3. Fill with any non-completed path at or above the user's current level
    if (result.length < widget.minCount) {
      final remaining = state.allPaths
          .where((p) =>
              !p.isCompleted &&
              !result.any((r) => r.id == p.id) &&
              _levelRank(p.discipleLevel) >= minLevelRank)
          .toList();
      result.addAll(remaining.take(widget.minCount - result.length));
    }

    // 4. Fallback without level filter (edge case: not enough paths at user's level)
    if (result.length < widget.minCount) {
      final fallback = state.allPaths
          .where((p) => !p.isCompleted && !result.any((r) => r.id == p.id))
          .toList();
      result.addAll(fallback.take(widget.minCount - result.length));
    }

    // Prepend the fellowship path at position 0 only if it's not already in
    // the list (deduplication). This way the fellowship commitment is always
    // visible without ever showing the same path twice.
    if (fellowshipPath != null &&
        !result.any((r) => r.id == fellowshipPath.id)) {
      result.insert(0, fellowshipPath);
    }

    return result;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LearningPathsBloc, LearningPathsState>(
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
            color: AppTheme.primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: isDark ? AppColors.brandPrimaryLight : AppTheme.primaryColor,
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
