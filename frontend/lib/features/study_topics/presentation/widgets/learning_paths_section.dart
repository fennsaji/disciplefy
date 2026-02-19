import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../domain/entities/learning_path.dart';
import '../bloc/learning_paths_bloc.dart';
import '../bloc/learning_paths_state.dart';
import 'learning_path_card.dart';

/// A section widget that displays available learning paths.
///
/// Shows curated learning paths with progress indicators for enrolled paths.
class LearningPathsSection extends StatefulWidget {
  /// Callback when a learning path card is tapped.
  final void Function(LearningPath path) onPathTap;

  /// Callback when "See All" is tapped.
  final VoidCallback? onSeeAllTap;

  /// Callback to retry loading.
  final VoidCallback? onRetry;

  /// Number of paths to show initially before "View More"
  static const int initialDisplayCount = 5;

  const LearningPathsSection({
    super.key,
    required this.onPathTap,
    this.onSeeAllTap,
    this.onRetry,
  });

  @override
  State<LearningPathsSection> createState() => _LearningPathsSectionState();
}

class _LearningPathsSectionState extends State<LearningPathsSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LearningPathsBloc, LearningPathsState>(
      builder: (context, state) {
        if (state is LearningPathsInitial) {
          return const SizedBox.shrink();
        }

        if (state is LearningPathsLoading) {
          return _buildLoadingState(context);
        }

        if (state is LearningPathsError) {
          return _buildErrorState(context, state);
        }

        if (state is LearningPathsEmpty) {
          return _buildEmptyState(context);
        }

        if (state is LearningPathsLoaded) {
          return _buildLoadedState(context, state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  void _toggleShowAll() {
    setState(() {
      _showAll = !_showAll;
    });
  }

  Widget _buildSection(
    BuildContext context, {
    required Widget child,
    bool showSeeAll = false,
    int? totalCount,
    int? displayCount,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.route_outlined,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(TranslationKeys.learningPathsTitle),
                      style: AppFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      context.tr(TranslationKeys.learningPathsSubtitle),
                      style: AppFonts.inter(
                        fontSize: 12,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (totalCount != null && displayCount != null)
                Text(
                  '$displayCount of $totalCount',
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else if (showSeeAll && widget.onSeeAllTap != null)
                TextButton(
                  onPressed: widget.onSeeAllTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See All',
                        style: AppFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return _buildSection(
      context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: const [
            LearningPathCardSkeleton(compact: false),
            SizedBox(height: 12),
            LearningPathCardSkeleton(compact: false),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, LearningPathsError state) {
    final theme = Theme.of(context);
    return _buildSection(
      context,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Something went wrong. Please try again.',
                style: AppFonts.inter(
                  fontSize: 14,
                  color: theme.colorScheme.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.onRetry != null)
              TextButton(
                onPressed: widget.onRetry,
                child: Text(
                  'Retry',
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return _buildSection(
      context,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.route_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(TranslationKeys.learningPathsEmpty),
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(TranslationKeys.learningPathsEmptyMessage),
              style: AppFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, LearningPathsLoaded state) {
    if (!state.hasPaths) {
      return _buildEmptyState(context);
    }

    final theme = Theme.of(context);

    // Sort all paths: In Progress first, then not started, then completed at bottom
    final sortedPaths = List<LearningPath>.from(state.paths);

    // Sort by priority: in progress > enrolled not started > featured > rest > completed
    sortedPaths.sort((a, b) {
      // Completed paths go to the bottom
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;

      // First priority: enrolled paths with progress (in progress)
      final aInProgress =
          a.isEnrolled && a.progressPercentage > 0 && !a.isCompleted;
      final bInProgress =
          b.isEnrolled && b.progressPercentage > 0 && !b.isCompleted;
      if (aInProgress && !bInProgress) return -1;
      if (!aInProgress && bInProgress) return 1;

      // Second priority: enrolled paths (even without progress)
      if (a.isEnrolled && !b.isEnrolled) return -1;
      if (!a.isEnrolled && b.isEnrolled) return 1;

      // Third priority: featured paths
      if (a.isFeatured && !b.isFeatured) return -1;
      if (!a.isFeatured && b.isFeatured) return 1;

      // Default: maintain original order
      return 0;
    });

    // Determine how many paths to display
    final totalPaths = sortedPaths.length;
    final hasMore = totalPaths > LearningPathsSection.initialDisplayCount;
    final displayPaths = _showAll
        ? sortedPaths
        : sortedPaths.take(LearningPathsSection.initialDisplayCount).toList();

    return _buildSection(
      context,
      totalCount: totalPaths,
      displayCount: displayPaths.length,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (int index = 0; index < displayPaths.length; index++) ...[
              LearningPathCard(
                path: displayPaths[index],
                onTap: () => widget.onPathTap(displayPaths[index]),
                compact: false,
              ),
              if (index < displayPaths.length - 1) const SizedBox(height: 12),
            ],
            // View More / View Less button
            if (hasMore) ...[
              const SizedBox(height: 16),
              _buildViewMoreButton(context, theme,
                  totalPaths - LearningPathsSection.initialDisplayCount),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewMoreButton(
      BuildContext context, ThemeData theme, int remainingCount) {
    return GestureDetector(
      onTap: _toggleShowAll,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showAll ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              _showAll
                  ? context.tr(TranslationKeys.learningPathsViewLess)
                  : '${context.tr(TranslationKeys.learningPathsViewMore)} $remainingCount',
              style: AppFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCompletedState(BuildContext context, int totalPaths) {
    final theme = Theme.of(context);

    return _buildSection(
      context,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.success.withOpacity(0.1),
              AppColors.success.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.success.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events,
                size: 32,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Congratulations!',
              style: AppFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.successDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ve completed all $totalPaths learning paths!',
              style: AppFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Check back soon for new paths',
              style: AppFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
