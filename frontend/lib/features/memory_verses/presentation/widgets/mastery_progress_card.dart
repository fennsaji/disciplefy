import 'package:flutter/material.dart';

import '../../domain/entities/mastery_progress_entity.dart';

/// Extension to add display name to MasteryLevel enum
extension MasteryLevelDisplay on MasteryLevel {
  String get displayName {
    switch (this) {
      case MasteryLevel.beginner:
        return 'Beginner';
      case MasteryLevel.intermediate:
        return 'Intermediate';
      case MasteryLevel.advanced:
        return 'Advanced';
      case MasteryLevel.expert:
        return 'Expert';
      case MasteryLevel.master:
        return 'Master';
    }
  }
}

/// Mastery progress card widget.
///
/// Displays verse mastery information with:
/// - Mastery level badge (Beginner → Master)
/// - Progress bar to next level
/// - Mastery percentage
/// - Modes mastered count
/// - Perfect recall count
/// - Color-coded level indicator
class MasteryProgressCard extends StatelessWidget {
  final MasteryProgressEntity masteryProgress;
  final VoidCallback? onTap;

  const MasteryProgressCard({
    super.key,
    required this.masteryProgress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelColor = _getMasteryLevelColor();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with level badge and percentage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Mastery level badge
                  _MasteryLevelBadge(
                    masteryLevel: masteryProgress.masteryLevel,
                    color: levelColor,
                  ),
                  // Mastery percentage
                  Text(
                    '${masteryProgress.masteryPercentage.toStringAsFixed(0)}%',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: levelColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress bar to next level
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress to ${masteryProgress.nextLevelDisplayName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (masteryProgress.canLevelUp)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha((0.1 * 255).round()),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_upward,
                                size: 14,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ready',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: masteryProgress.masteryPercentage / 100,
                      backgroundColor:
                          levelColor.withAlpha((0.2 * 255).round()),
                      valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Statistics row
              Row(
                children: [
                  // Modes mastered
                  Expanded(
                    child: _StatisticItem(
                      icon: Icons.grade,
                      label: 'Modes',
                      value: '${masteryProgress.modesMastered}/8',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Perfect recalls
                  Expanded(
                    child: _StatisticItem(
                      icon: Icons.star,
                      label: 'Perfect',
                      value: '${masteryProgress.perfectRecalls}',
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Confidence rating
                  Expanded(
                    child: _StatisticItem(
                      icon: Icons.psychology,
                      label: 'Confidence',
                      value: masteryProgress.confidenceRating != null
                          ? masteryProgress.confidenceRating!.toStringAsFixed(1)
                          : 'N/A',
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),

              // Next level requirements hint
              if (!masteryProgress.canLevelUp) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withAlpha((0.5 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          masteryProgress.nextLevelRequirements,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getMasteryLevelColor() {
    return masteryProgress.levelColor;
  }
}

/// Mastery level badge widget
class _MasteryLevelBadge extends StatelessWidget {
  final MasteryLevel masteryLevel;
  final Color color;

  const _MasteryLevelBadge({
    required this.masteryLevel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withAlpha((0.7 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((0.3 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getMasteryIcon(),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            masteryLevel.displayName,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMasteryIcon() {
    switch (masteryLevel) {
      case MasteryLevel.beginner:
        return Icons.rocket_launch;
      case MasteryLevel.intermediate:
        return Icons.trending_up;
      case MasteryLevel.advanced:
        return Icons.military_tech;
      case MasteryLevel.expert:
        return Icons.emoji_events;
      case MasteryLevel.master:
        return Icons.workspace_premium;
    }
  }
}

/// Statistic item widget
class _StatisticItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatisticItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
