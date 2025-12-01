import 'package:flutter/material.dart';
import '../../../../core/constants/app_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_utils.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';

/// Reusable card widget for displaying recommended guide topics.
///
/// This widget provides consistent visual styling and behavior across
/// the Home screen and Study Topics screen.
class RecommendedGuideTopicCard extends StatelessWidget {
  /// The RecommendedGuideTopic model data represented by this card.
  final RecommendedGuideTopic topic;

  /// Callback function invoked when the card is tapped.
  final VoidCallback onTap;

  /// Whether the card should be disabled (non-interactive).
  /// When true, the card will appear dimmed and won't respond to taps.
  final bool isDisabled;

  const RecommendedGuideTopicCard({
    super.key,
    required this.topic,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = CategoryUtils.getIconForTopic(topic);
    final color = CategoryUtils.getColorForTopic(context, topic);

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          constraints: const BoxConstraints(minHeight: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:
                MainAxisSize.min, // Important: Don't expand unnecessarily
            children: [
              // Header row with icon
              Row(
                children: [
                  Container(
                    width: 36, // Slightly smaller for better proportions
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      iconData,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8), // Fixed spacing instead of Spacer
                  Flexible(
                    // Use Flexible instead of Spacer
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
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
                ],
              ),

              const SizedBox(height: 12),

              // Title with proper constraints
              Text(
                topic.title,
                style: AppFonts.inter(
                  fontSize: 16, // Increased for better readability
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.2, // Tighter line height
                ),
                maxLines: 2, // Allow 2 lines for longer titles
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6), // Reduced spacing

              // Description with flexible height
              Flexible(
                child: Text(
                  topic.description,
                  style: AppFonts.inter(
                    fontSize: 14, // Increased for better readability
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                    height: 1.3,
                  ),
                  maxLines: 4, // Allow up to 4 lines
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 12), // Fixed spacing instead of Spacer

              // Footer with metadata - commented out for now as entity doesn't have these fields
              // Row(
              //   children: [
              //     Icon(
              //       Icons.schedule,
              //       size: 12,
              //       color: AppTheme.onSurfaceVariant,
              //     ),
              //     const SizedBox(width: 3),
              //     Text(
              //       '${topic.estimatedMinutes}min',
              //       style: AppFonts.inter(
              //         fontSize: 10,
              //         color: AppTheme.onSurfaceVariant,
              //       ),
              //     ),
              //     const SizedBox(width: 12),
              //     Icon(
              //       Icons.book_outlined,
              //       size: 12,
              //       color: AppTheme.onSurfaceVariant,
              //     ),
              //     const SizedBox(width: 3),
              //     Text(
              //       '${topic.scriptureCount}',
              //       style: AppFonts.inter(
              //         fontSize: 10,
              //         color: AppTheme.onSurfaceVariant,
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
