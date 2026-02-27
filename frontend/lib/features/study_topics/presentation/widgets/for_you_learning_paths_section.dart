import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/locked_feature_wrapper.dart';
import '../../domain/entities/learning_path.dart';
import '../bloc/learning_paths_bloc.dart';
import '../bloc/learning_paths_state.dart';
import 'learning_path_card.dart';

/// "For You" learning paths section shown on the Study Topics screen.
///
/// Shows ≥3 learning paths in priority order:
///   1. In-progress paths (sorted by progress descending)
///   2. Featured / recommended paths
///   3. Any remaining non-completed paths to fill up to [minCount]
///
/// Reuses [LearningPathsBloc] data — no extra fetch required.
class ForYouLearningPathsSection extends StatelessWidget {
  final void Function(LearningPath path) onPathTap;

  /// Minimum number of paths to show. Filled with featured/any if needed.
  final int minCount;

  const ForYouLearningPathsSection({
    super.key,
    required this.onPathTap,
    this.minCount = 3,
  });

  // ── Level helpers ────────────────────────────────────────────────────────

  static const _levelOrder = ['seeker', 'follower', 'disciple', 'leader'];

  int _levelRank(String level) {
    final idx = _levelOrder.indexOf(level.toLowerCase());
    return idx == -1 ? 0 : idx;
  }

  // ── Priority list builder ────────────────────────────────────────────────

  List<LearningPath> _buildForYouPaths(LearningPathsLoaded state) {
    final result = <LearningPath>[];

    // 1. In-progress paths — highest priority, most progressed first
    final inProgress = state.enrolledPaths.where((p) => p.isInProgress).toList()
      ..sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
    result.addAll(inProgress);

    // Derive minimum level from the user's in-progress paths.
    // Avoids recommending lower-level paths once the user is working at a higher level.
    final minLevelRank = inProgress.isNotEmpty
        ? inProgress
            .map((p) => _levelRank(p.discipleLevel))
            .reduce((a, b) => a > b ? a : b)
        : 0;

    // 2. Featured paths not yet in result, at or above the user's current level
    if (result.length < minCount) {
      final featured = state.allPaths
          .where((p) =>
              p.isFeatured &&
              !result.any((r) => r.id == p.id) &&
              _levelRank(p.discipleLevel) >= minLevelRank)
          .toList();
      result.addAll(featured.take(minCount - result.length));
    }

    // 3. Fill with any non-completed path at or above the user's current level
    if (result.length < minCount) {
      final remaining = state.allPaths
          .where((p) =>
              !p.isCompleted &&
              !result.any((r) => r.id == p.id) &&
              _levelRank(p.discipleLevel) >= minLevelRank)
          .toList();
      result.addAll(remaining.take(minCount - result.length));
    }

    // 4. Fallback without level filter (edge case: not enough paths at user's level)
    if (result.length < minCount) {
      final fallback = state.allPaths
          .where((p) => !p.isCompleted && !result.any((r) => r.id == p.id))
          .toList();
      result.addAll(fallback.take(minCount - result.length));
    }

    return result;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LearningPathsBloc, LearningPathsState>(
      builder: (context, state) {
        if (state is LearningPathsLoading || state is LearningPathsInitial) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ────────────────────────────────────────────────
        Row(
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
                color: isDark
                    ? AppColors.brandPrimaryLight
                    : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'For You',
                  style: AppFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  'Personalised learning paths',
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
        ),
        const SizedBox(height: 16),

        // ── Path cards ────────────────────────────────────────────────────
        LockedFeatureWrapper(
          featureKey: 'learning_paths',
          child: Column(
            children: paths.map((path) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LearningPathCard(
                  path: path,
                  compact: false,
                  onTap: () => onPathTap(path),
                ),
              );
            }).toList(),
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
        // Header skeleton
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
        // Card skeletons
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
