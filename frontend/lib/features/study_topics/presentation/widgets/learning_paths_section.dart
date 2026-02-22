import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../domain/entities/learning_path.dart';
import '../bloc/learning_paths_bloc.dart';
import '../bloc/learning_paths_event.dart';
import '../bloc/learning_paths_state.dart';
import 'learning_path_card.dart';

/// Displays learning paths grouped by category.
///
/// Each category row is always expanded and horizontally scrollable
/// (max 3 paths shown per category, with a load-more ghost card when
/// more paths exist). Initially 4 categories are shown; "Show More"
/// loads the next page of categories from the server.
class LearningPathsSection extends StatefulWidget {
  final void Function(LearningPath path) onPathTap;
  final VoidCallback? onSeeAllTap;
  final VoidCallback? onRetry;

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
  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LearningPathsBloc, LearningPathsState>(
      builder: (context, state) {
        if (state is LearningPathsInitial) return const SizedBox.shrink();
        if (state is LearningPathsLoading) return _buildLoadingState(context);
        if (state is LearningPathsError) {
          return _buildErrorState(context, state);
        }
        if (state is LearningPathsEmpty) return _buildEmptyState(context);
        if (state is LearningPathsLoaded) {
          return _buildLoadedState(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  // -------------------------------------------------------------------------
  // Section chrome (shared header)
  // -------------------------------------------------------------------------

  Widget _buildSection(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
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
              if (widget.onSeeAllTap != null)
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
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Loading / Error / Empty states
  // -------------------------------------------------------------------------

  Widget _buildLoadingState(BuildContext context) {
    return _buildSection(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategorySkeletonRow(context, label: 'Foundations'),
          _buildCategorySkeletonRow(context, label: 'Growth'),
        ],
      ),
    );
  }

  Widget _buildCategorySkeletonRow(BuildContext context,
      {required String label}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: 100,
              height: 14,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                LearningPathCardSkeleton(),
                SizedBox(width: 12),
                LearningPathCardSkeleton(),
              ],
            ),
          ),
        ],
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
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Something went wrong. Please try again.',
                style: AppFonts.inter(
                    fontSize: 14, color: theme.colorScheme.error),
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
              color: theme.colorScheme.outline.withValues(alpha: 0.1)),
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

  // -------------------------------------------------------------------------
  // Loaded state — category rows
  // -------------------------------------------------------------------------

  Widget _buildLoadedState(BuildContext context, LearningPathsLoaded state) {
    if (!state.hasPaths) return _buildEmptyState(context);

    return _buildSection(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final category in state.categories)
            _buildCategoryRow(context, category: category, state: state),

          // Footer
          if (state.isFetchingMoreCategories)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.hasMoreCategories)
            _buildShowMoreCategoriesButton(context),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Category row
  // -------------------------------------------------------------------------

  Widget _buildCategoryRow(
    BuildContext context, {
    required LearningPathCategory category,
    required LearningPathsLoaded state,
  }) {
    final theme = Theme.of(context);
    final hasActive = category.paths.any((p) => p.isInProgress || p.isEnrolled);
    final isLoadingMore = state.loadingCategories.contains(category.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category label row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (hasActive) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  category.name,
                  style: AppFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: hasActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // IntrinsicHeight measures the tallest card in the row and
          // constrains all siblings to that height via CrossAxisAlignment.stretch.
          IntrinsicHeight(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < category.paths.length; i++) ...[
                    LearningPathCard(
                      path: category.paths[i],
                      onTap: () => widget.onPathTap(category.paths[i]),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Load-more ghost card
                  if (category.hasMoreInCategory || isLoadingMore)
                    _buildLoadMoreCard(context, category.name, isLoadingMore),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Per-category load-more ghost card
  // -------------------------------------------------------------------------

  Widget _buildLoadMoreCard(
      BuildContext context, String categoryName, bool isLoading) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 120,
      child: Material(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isLoading
              ? null
              : () => context.read<LearningPathsBloc>().add(
                    LoadMorePathsForCategory(category: categoryName),
                  ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_arrow_right,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'More',
                          style: AppFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
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

  // -------------------------------------------------------------------------
  // Show More Categories button
  // -------------------------------------------------------------------------

  Widget _buildShowMoreCategoriesButton(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: GestureDetector(
        onTap: () =>
            context.read<LearningPathsBloc>().add(const LoadMoreCategories()),
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
                Icons.keyboard_arrow_down,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Show More Categories',
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
