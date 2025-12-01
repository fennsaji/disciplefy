import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/utils/category_utils.dart';
import '../../domain/entities/learning_path.dart';

/// Card widget for displaying a learning path.
///
/// Shows path title, description, progress (if enrolled), XP value,
/// and number of topics.
class LearningPathCard extends StatelessWidget {
  /// The learning path data.
  final LearningPath path;

  /// Callback when the card is tapped.
  final VoidCallback onTap;

  /// Whether to show as a compact card (for horizontal lists).
  final bool compact;

  const LearningPathCard({
    super.key,
    required this.path,
    required this.onTap,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _parseColor(path.color);
    final isEnrolled = path.isEnrolled;
    final isCompleted = path.isCompleted;
    final isInProgress = path.isInProgress;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: compact ? 260 : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? Colors.green.withValues(alpha: 0.4)
                : color.withValues(alpha: 0.3),
            width: isCompleted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.1)
                  : color.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon and status
            Row(
              children: [
                // Path icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.2),
                        color.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForPath(path.iconName),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Disciple level badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getDiscipleLevelColor(path.discipleLevel)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getTranslatedDiscipleLevel(
                              context, path.discipleLevel),
                          style: AppFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getDiscipleLevelColor(path.discipleLevel),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Topics count
                      Text(
                        '${path.topicsCount} ${context.tr(TranslationKeys.learningPathsTopics)}',
                        style: AppFonts.inter(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                _buildStatusBadge(
                    context, isEnrolled, isCompleted, isInProgress),
              ],
            ),

            const SizedBox(height: 14),

            // Title
            Text(
              path.title,
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
            Text(
              path.description,
              style: AppFonts.inter(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.3,
              ),
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Progress bar (if enrolled)
            if (isEnrolled) ...[
              _buildProgressBar(context, color),
              const SizedBox(height: 12),
            ],

            // Footer with XP and duration
            Row(
              children: [
                // XP indicator
                Icon(
                  isCompleted ? Icons.star : Icons.star_outline,
                  size: 16,
                  color: isCompleted ? Colors.green : color,
                ),
                const SizedBox(width: 4),
                Text(
                  '${path.totalXp} XP',
                  style: AppFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.green : color,
                  ),
                ),
                const SizedBox(width: 16),
                // Duration estimate
                Icon(
                  Icons.schedule_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${path.estimatedDays} ${context.tr(TranslationKeys.learningPathsDays)}',
                  style: AppFonts.inter(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const Spacer(),
                // Action button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withValues(alpha: 0.1)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCompleted
                            ? context.tr(TranslationKeys.learningPathsReview)
                            : (isInProgress
                                ? context
                                    .tr(TranslationKeys.learningPathsContinue)
                                : context
                                    .tr(TranslationKeys.learningPathsExplore)),
                        style: AppFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? Colors.green : color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: isCompleted ? Colors.green : color,
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

  Widget _buildStatusBadge(
    BuildContext context,
    bool isEnrolled,
    bool isCompleted,
    bool isInProgress,
  ) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              size: 14,
              color: Colors.green,
            ),
            const SizedBox(width: 4),
            Text(
              context.tr(TranslationKeys.learningPathsCompleted),
              style: AppFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    if (isInProgress) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_filled,
              size: 14,
              color: Colors.orange.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              context.tr(TranslationKeys.learningPathsInProgress),
              style: AppFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
      );
    }

    if (path.isFeatured) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 14,
              color: Colors.amber,
            ),
            const SizedBox(width: 4),
            Text(
              context.tr(TranslationKeys.learningPathsFeatured),
              style: AppFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildProgressBar(BuildContext context, Color color) {
    final theme = Theme.of(context);
    final progress = path.progressPercentage / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr(TranslationKeys.learningPathsProgress),
              style: AppFonts.inter(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '${path.progressPercentage}%',
              style: AppFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: path.isCompleted ? Colors.green : color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(
              path.isCompleted ? Colors.green : color,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF6A4FB6); // Default purple
    }
  }

  IconData _getIconForPath(String iconName) {
    return CategoryUtils.getIconForCategory(iconName);
  }

  Color _getDiscipleLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'seeker':
        return Colors.blue;
      case 'believer':
        return Colors.green;
      case 'disciple':
        return Colors.orange;
      case 'leader':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getTranslatedDiscipleLevel(BuildContext context, String level) {
    switch (level.toLowerCase()) {
      case 'seeker':
        return context.tr(TranslationKeys.discipleLevelSeeker);
      case 'believer':
        return context.tr(TranslationKeys.discipleLevelBeliever);
      case 'disciple':
        return context.tr(TranslationKeys.discipleLevelDisciple);
      case 'leader':
        return context.tr(TranslationKeys.discipleLevelLeader);
      default:
        return _capitalize(level);
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// Skeleton loading card for learning paths.
class LearningPathCardSkeleton extends StatelessWidget {
  final bool compact;

  const LearningPathCardSkeleton({
    super.key,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Container(
      width: compact ? 260 : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 70,
                      height: 18,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 50,
                      height: 12,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Title skeleton
          Container(
            width: double.infinity,
            height: 18,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(height: 8),

          // Description skeleton
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 160,
            height: 14,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(height: 16),

          // Footer skeleton
          Row(
            children: [
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 50,
                height: 16,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: 80,
                height: 30,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
