import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import 'recommended_guide_topic_card.dart';

/// Grid view widget for displaying topics in a responsive layout.
///
/// Displays topics in a 2-column grid with optional loading indicators
/// and "Load More" functionality for pagination.
class TopicsGridView extends StatelessWidget {
  /// List of RecommendedGuideTopic objects to display in the grid.
  final List<RecommendedGuideTopic> topics;

  /// Callback function invoked when a topic card is tapped.
  /// Receives the tapped RecommendedGuideTopic as parameter.
  final Function(RecommendedGuideTopic) onTopicTap;

  /// Whether a loading indicator should be shown at the bottom.
  /// When true, displays a circular progress indicator.
  final bool isLoading;

  /// Optional callback to request loading more topics.
  /// If null, no "Load More" button is shown.
  final VoidCallback? onLoadMore;

  /// Whether more topics are available to load.
  /// Controls visibility of "Load More" button when not loading.
  final bool hasMore;

  const TopicsGridView({
    super.key,
    required this.topics,
    required this.onTopicTap,
    this.isLoading = false,
    this.onLoadMore,
    this.hasMore = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate spacing between cards
        const double spacing = 16.0;

        return Column(
          children: [
            // Topics grid using rows for uniform heights
            ...List.generate((topics.length / 2).ceil(), (rowIndex) {
              final startIndex = rowIndex * 2;
              final endIndex = math.min(startIndex + 2, topics.length);
              final rowTopics = topics.sublist(startIndex, endIndex);

              return Padding(
                padding: EdgeInsets.only(
                    bottom: rowIndex < (topics.length / 2).ceil() - 1
                        ? spacing
                        : 0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < rowTopics.length; i++) ...[
                        Expanded(
                          child: RecommendedGuideTopicCard(
                            topic: rowTopics[i],
                            onTap: () => onTopicTap(rowTopics[i]),
                          ),
                        ),
                        if (i < rowTopics.length - 1) SizedBox(width: spacing),
                      ],
                      // Add spacer if only one card in the row
                      if (rowTopics.length == 1)
                        SizedBox(
                            width:
                                spacing + (constraints.maxWidth - spacing) / 2),
                    ],
                  ),
                ),
              );
            }),

            // Load more section
            if (hasMore || isLoading) ...[
              const SizedBox(height: 24),
              _buildLoadMoreSection(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLoadMoreSection() {
    if (isLoading) {
      return const Center(
        child: Column(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            SizedBox(height: 8),
            Text(
              'Loading more topics...',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (hasMore && onLoadMore != null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: onLoadMore,
          icon: const Icon(Icons.expand_more),
          label: Text(
            'Load More Topics',
            style: AppFonts.inter(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Loading skeleton for topics grid
class TopicsGridLoadingSkeleton extends StatelessWidget {
  /// Number of skeleton loading items to render in the grid.
  /// Defaults to 6 items to fill typical mobile screen space.
  final int itemCount;

  const TopicsGridLoadingSkeleton({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 16.0;
        final double cardWidth = (constraints.maxWidth - spacing) / 2;

        return Column(
          children: [
            ...List.generate((itemCount / 2).ceil(), (rowIndex) {
              final startIndex = rowIndex * 2;
              final endIndex = (startIndex + 2).clamp(0, itemCount).toInt();
              final itemsInRow = endIndex - startIndex;

              return Padding(
                padding: EdgeInsets.only(
                    bottom:
                        rowIndex < (itemCount / 2).ceil() - 1 ? spacing : 0),
                child: Row(
                  children: [
                    for (int i = 0; i < itemsInRow; i++) ...[
                      Expanded(
                        child: _buildLoadingTopicCard(context, cardWidth),
                      ),
                      if (i < itemsInRow - 1) SizedBox(width: spacing),
                    ],
                    // Add spacer if only one card in the row
                    if (itemsInRow == 1) SizedBox(width: spacing + cardWidth),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildLoadingTopicCard(BuildContext context, double cardWidth) {
    return Container(
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row skeleton
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 20,
                width: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Title skeleton
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(height: 6),

          // Description skeleton
          Container(
            height: 11,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(height: 4),

          Container(
            height: 11,
            width: cardWidth * 0.6,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(height: 12),

          // Footer skeleton
          Row(
            children: [
              Container(
                height: 10,
                width: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 10,
                width: 20,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
