import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import 'recommended_guide_topic_card.dart';

/// Grid view widget for displaying topics in a responsive layout.
class TopicsGridView extends StatelessWidget {
  final List<RecommendedGuideTopic> topics;
  final Function(RecommendedGuideTopic) onTopicTap;
  final bool isLoading;
  final VoidCallback? onLoadMore;
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
        // Calculate optimal card width (accounting for spacing)
        const double spacing = 16.0;
        final double cardWidth = (constraints.maxWidth - spacing) / 2;

        return Column(
          children: [
            // Topics grid
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: topics
                  .map((topic) => SizedBox(
                        width: cardWidth,
                        child: RecommendedGuideTopicCard(
                          topic: topic,
                          onTap: () => onTopicTap(topic),
                        ),
                      ))
                  .toList(),
            ),

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
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            itemCount,
            (index) => SizedBox(
              width: cardWidth,
              child: _buildLoadingTopicCard(context, cardWidth),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingTopicCard(BuildContext context, double cardWidth) {
    return Container(
      height: 180,
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
