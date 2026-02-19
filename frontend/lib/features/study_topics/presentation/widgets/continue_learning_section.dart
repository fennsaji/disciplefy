import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/utils/category_utils.dart';
import '../../domain/entities/topic_progress.dart';

/// A section widget that displays topics the user has started but not completed.
///
/// This widget shows a "Continue Learning" header with a horizontal
/// scrollable list of in-progress topic cards.
class ContinueLearningSection extends StatelessWidget {
  /// List of in-progress topics to display.
  final List<InProgressTopic> topics;

  /// Callback when a topic card is tapped.
  final void Function(InProgressTopic topic) onTopicTap;

  /// Whether the section is currently loading.
  final bool isLoading;

  /// Error message if loading failed.
  final String? errorMessage;

  /// Callback to retry loading.
  final VoidCallback? onRetry;

  const ContinueLearningSection({
    super.key,
    required this.topics,
    required this.onTopicTap,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show section if no topics and not loading
    if (topics.isEmpty && !isLoading && errorMessage == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_outline,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr(TranslationKeys.continueLearningTitle),
                style: AppFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (topics.isNotEmpty)
                Text(
                  context.tr(
                    TranslationKeys.continueLearningInProgress,
                    {'count': topics.length},
                  ),
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Content area
        if (isLoading)
          _buildLoadingState(context)
        else if (errorMessage != null)
          _buildErrorState(context)
        else
          _buildTopicsList(context),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return SizedBox(
      height: 185,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _ContinueLearningCardSkeleton(),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                context.tr(TranslationKeys.commonRetry),
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicsList(BuildContext context) {
    return SizedBox(
      height: 185,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: topics.length,
        itemBuilder: (context, index) {
          final topic = topics[index];
          return Padding(
            padding: EdgeInsets.only(right: index < topics.length - 1 ? 12 : 0),
            child: _ContinueLearningCard(
              topic: topic,
              onTap: () => onTopicTap(topic),
            ),
          );
        },
      ),
    );
  }
}

/// Card widget for displaying an in-progress topic.
class _ContinueLearningCard extends StatelessWidget {
  final InProgressTopic topic;
  final VoidCallback onTap;

  const _ContinueLearningCard({
    required this.topic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = CategoryUtils.getColorForCategory(context, topic.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: topic.isFromLearningPath
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : color.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (topic.isFromLearningPath ? theme.colorScheme.primary : color)
                      .withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Learning path badge with progress (if from a learning path)
            if (topic.isFromLearningPath) ...[
              _buildLearningPathHeader(context, theme),
              const SizedBox(height: 12),
            ] else ...[
              // Category badge only shown for standalone topics
              _buildCategoryHeader(context, theme, color),
              const SizedBox(height: 10),
            ],

            // Title
            Text(
              topic.title,
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const Spacer(),

            // Footer with XP and continue/start button
            Row(
              children: [
                Icon(
                  Icons.star_outline,
                  size: 14,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '+${topic.xpValue} XP',
                  style: AppFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: topic.isFromLearningPath
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        topic.timeSpentSeconds > 0
                            ? context.tr(
                                TranslationKeys.continueLearningContinueAction)
                            : context.tr(TranslationKeys.continueLearningStart),
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: topic.isFromLearningPath
                              ? theme.colorScheme.primary
                              : color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: topic.isFromLearningPath
                            ? theme.colorScheme.primary
                            : color,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build enhanced learning path header with progress
  Widget _buildLearningPathHeader(BuildContext context, ThemeData theme) {
    // Calculate progress based on completed topics, not position
    final progress = topic.topicsCompletedInPath != null &&
            topic.totalTopicsInPath != null &&
            topic.totalTopicsInPath! > 0
        ? topic.topicsCompletedInPath! / topic.totalTopicsInPath!
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Learning path name and position
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  topic.learningPathName ?? 'Learning Path',
                  style: AppFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (topic.topicsCompletedInPath != null &&
                  topic.totalTopicsInPath != null)
                Builder(builder: (context) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      context.tr(
                        TranslationKeys.continueLearningOfDone,
                        {
                          'completed': topic.topicsCompletedInPath,
                          'total': topic.totalTopicsInPath,
                        },
                      ),
                      style: AppFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  /// Build category header for standalone topics
  Widget _buildCategoryHeader(
      BuildContext context, ThemeData theme, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            topic.category,
            style: AppFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        if (topic.timeSpentSeconds > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 2),
              Text(
                topic.formattedTimeSpent,
                style: AppFonts.inter(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
      ],
    );
  }
}

/// Skeleton loading card for the continue learning section.
class _ContinueLearningCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Learning path header skeleton
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 50,
                      height: 16,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Title skeleton line 1
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(height: 6),

          // Title skeleton line 2
          Container(
            width: 140,
            height: 16,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const Spacer(),

          // Footer skeleton
          Row(
            children: [
              Container(
                width: 55,
                height: 14,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: 80,
                height: 28,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
