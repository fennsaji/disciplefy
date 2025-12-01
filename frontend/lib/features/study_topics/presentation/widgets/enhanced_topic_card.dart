import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/utils/category_utils.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../../domain/entities/topic_progress.dart';

/// Enhanced card widget for displaying study topics with progress indicators.
///
/// This widget extends the visual styling of the original topic card
/// with completion badges, XP indicators, and progress status.
class EnhancedTopicCard extends StatelessWidget {
  /// The topic data.
  final RecommendedGuideTopic topic;

  /// Progress data for this topic (null if no progress).
  final TopicProgress? progress;

  /// XP value for completing this topic.
  final int xpValue;

  /// Callback when the card is tapped.
  final VoidCallback onTap;

  /// Whether the card should be disabled.
  final bool isDisabled;

  const EnhancedTopicCard({
    super.key,
    required this.topic,
    this.progress,
    this.xpValue = 50,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconData = CategoryUtils.getIconForTopic(topic);
    final color = CategoryUtils.getColorForTopic(context, topic);
    final isCompleted = progress?.isCompleted ?? false;
    final isInProgress = progress?.isInProgress ?? false;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          constraints: const BoxConstraints(minHeight: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.4)
                  : color.withValues(alpha: 0.2),
              width: isCompleted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isCompleted
                    ? Colors.green.withValues(alpha: 0.1)
                    : color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row with icon and status
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          iconData,
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  topic.category,
                                  style: AppFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Status indicator
                            _buildStatusIndicator(
                                context, isCompleted, isInProgress),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Title
                  Text(
                    topic.title,
                    style: AppFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Description
                  Flexible(
                    child: Text(
                      topic.description,
                      style: AppFonts.inter(
                        fontSize: 14,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Footer with XP and time spent
                  _buildFooter(context, isCompleted, isInProgress, color),
                ],
              ),

              // Completion checkmark overlay
              if (isCompleted)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context,
    bool isCompleted,
    bool isInProgress,
  ) {
    if (isCompleted) {
      return const SizedBox.shrink(); // Handled by overlay
    }

    if (isInProgress) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 12,
              color: Colors.orange.shade700,
            ),
            const SizedBox(width: 2),
            Text(
              'In Progress',
              style: AppFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFooter(
    BuildContext context,
    bool isCompleted,
    bool isInProgress,
    Color color,
  ) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Row(
      children: [
        // XP indicator
        if (!isCompleted) ...[
          Icon(
            Icons.star_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '+$xpValue XP',
            style: AppFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ] else ...[
          Icon(
            Icons.star,
            size: 14,
            color: Colors.green,
          ),
          const SizedBox(width: 2),
          Text(
            '${progress?.xpEarned ?? xpValue} XP earned',
            style: AppFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.green,
            ),
          ),
        ],

        const Spacer(),

        // Time spent indicator (if in progress or completed)
        if (progress != null && progress!.timeSpentSeconds > 0) ...[
          Icon(
            Icons.schedule,
            size: 12,
            color: onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          Text(
            progress!.formattedTimeSpent,
            style: AppFonts.inter(
              fontSize: 10,
              color: onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
