import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/memory_verse_entity.dart';

/// List item widget for displaying a memory verse card.
///
/// Shows:
/// - Verse reference
/// - Verse text (truncated)
/// - Due status indicator
/// - Days overdue badge
/// - Difficulty level indicator
/// - Next review date
/// - SM-2 state indicators
class MemoryVerseListItem extends StatelessWidget {
  final MemoryVerseEntity verse;
  final VoidCallback onTap;

  const MemoryVerseListItem({
    super.key,
    required this.verse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Reference and Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      verse.verseReference,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  _buildStatusBadge(context),
                ],
              ),

              const SizedBox(height: 12),

              // Verse text (truncated)
              Text(
                verse.verseText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 12),

              // Footer: Stats and difficulty
              Row(
                children: [
                  // Difficulty indicator
                  _buildDifficultyChip(context),
                  const SizedBox(width: 8),

                  // Repetitions
                  _buildStatChip(
                    context: context,
                    icon: Icons.repeat,
                    label: '${verse.repetitions}x',
                    tooltip: 'Review count',
                  ),
                  const SizedBox(width: 8),

                  // Interval
                  _buildStatChip(
                    context: context,
                    icon: Icons.schedule,
                    label: '${verse.intervalDays}d',
                    tooltip: 'Current interval',
                  ),

                  const Spacer(),

                  // Next review date or overdue indicator
                  if (verse.daysOverdue > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Colors.red[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${verse.daysOverdue}d overdue',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Next: ${_formatDate(verse.nextReviewDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final theme = Theme.of(context);

    if (verse.isMastered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              size: 16,
              color: Colors.amber[700],
            ),
            const SizedBox(width: 4),
            Text(
              'Mastered',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.amber[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (verse.isNew) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fiber_new,
              size: 16,
              color: Colors.blue[700],
            ),
            const SizedBox(width: 4),
            Text(
              'New',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (verse.isDue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.green[700],
            ),
            const SizedBox(width: 4),
            Text(
              'Review',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDifficultyChip(BuildContext context) {
    final theme = Theme.of(context);
    Color chipColor;
    IconData chipIcon;
    String label;

    switch (verse.difficultyLevel) {
      case 'hard':
        chipColor = Colors.red;
        chipIcon = Icons.trending_up;
        label = 'Hard';
        break;
      case 'medium':
        chipColor = Colors.orange;
        chipIcon = Icons.trending_flat;
        label = 'Medium';
        break;
      case 'easy':
      default:
        chipColor = Colors.green;
        chipIcon = Icons.trending_down;
        label = 'Easy';
    }

    return Tooltip(
      message:
          'Difficulty based on ease factor (${verse.easeFactor.toStringAsFixed(1)})',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: chipColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              chipIcon,
              size: 14,
              color: chipColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: chipColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String tooltip,
  }) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow';
    } else if (dateOnly.isBefore(today.add(const Duration(days: 7)))) {
      return DateFormat('EEE').format(date); // Day name
    } else {
      return DateFormat('MMM d').format(date); // Month day
    }
  }
}
