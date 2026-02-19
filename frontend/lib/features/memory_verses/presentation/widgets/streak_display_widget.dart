import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/memory_streak_entity.dart';

/// Streak display widget.
///
/// Displays memory verse practice streak with:
/// - Flame icon with current streak count
/// - Longest streak badge
/// - Freeze days indicator
/// - Streak status (active/at risk)
/// - Next milestone countdown
class StreakDisplayWidget extends StatelessWidget {
  final MemoryStreakEntity memoryStreak;
  final VoidCallback? onTap;
  final bool showMilestoneProgress;

  const StreakDisplayWidget({
    super.key,
    required this.memoryStreak,
    this.onTap,
    this.showMilestoneProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = memoryStreak.isPracticedToday;
    final streakColor =
        isActive ? AppColors.streakFlame : AppColors.lightTextSecondary;

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
              // Header: Current streak with flame icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Current streak
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isActive
                                ? [
                                    AppColors.streakFlame,
                                    AppColors.streakGlow,
                                  ]
                                : [
                                    AppColors.lightTextSecondary,
                                    AppColors.darkTextTertiary,
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.streakFlame
                                        .withAlpha((0.3 * 255).round()),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: const Icon(
                          Icons.local_fire_department,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${memoryStreak.currentStreak} Day${memoryStreak.currentStreak != 1 ? 's' : ''}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: streakColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Current Streak',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Longest streak badge
                  if (memoryStreak.longestStreak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.masteryMaster
                            .withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.masteryMaster),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: AppColors.masteryMaster,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${memoryStreak.longestStreak}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.masteryMaster,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Best',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.warningDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Freeze days indicator
              if (memoryStreak.freezeDaysAvailable > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.info.withAlpha((0.3 * 255).round()),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.ac_unit,
                        color: AppColors.info,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${memoryStreak.freezeDaysAvailable} Freeze Day${memoryStreak.freezeDaysAvailable != 1 ? 's' : ''} Available',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.infoLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (memoryStreak.canUseFreeze)
                        const Icon(
                          Icons.shield,
                          color: AppColors.infoLight,
                          size: 20,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Streak status or milestone progress
              if (showMilestoneProgress &&
                  memoryStreak.nextMilestone != null) ...[
                _MilestoneProgress(
                  currentStreak: memoryStreak.currentStreak,
                  nextMilestone: memoryStreak.nextMilestone!,
                  daysUntilMilestone: memoryStreak.daysUntilNextMilestone!,
                  milestones: memoryStreak.milestones,
                ),
              ] else ...[
                // Simple streak status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.success.withAlpha((0.1 * 255).round())
                        : AppColors.warning.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.check_circle : Icons.warning,
                        color: isActive ? AppColors.success : AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isActive
                              ? 'Streak active! Keep it up.'
                              : 'Practice today to keep your streak alive!',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isActive
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Total practice days
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${memoryStreak.totalPracticeDays} total practice day${memoryStreak.totalPracticeDays != 1 ? 's' : ''}',
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
}

/// Milestone progress indicator widget
class _MilestoneProgress extends StatelessWidget {
  final int currentStreak;
  final int nextMilestone;
  final int daysUntilMilestone;
  final Map<int, DateTime?> milestones;

  const _MilestoneProgress({
    required this.currentStreak,
    required this.nextMilestone,
    required this.daysUntilMilestone,
    required this.milestones,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = currentStreak / nextMilestone;
    final isClose = daysUntilMilestone <= 3;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.masteryAdvanced.withAlpha((0.1 * 255).round()),
            AppColors.brandPrimaryDeep.withAlpha((0.1 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.masteryAdvanced.withAlpha((0.3 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with milestone icon and days remaining
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getMilestoneIcon(nextMilestone),
                    color: AppColors.masteryAdvanced,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$nextMilestone-Day Milestone',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.masteryAdvanced,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isClose)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha((0.2 * 255).round()),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.trending_up,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Almost there!',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor:
                  AppColors.masteryAdvanced.withAlpha((0.2 * 255).round()),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.masteryAdvanced),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),

          // Days remaining text
          Text(
            '$daysUntilMilestone more day${daysUntilMilestone != 1 ? 's' : ''} to reach this milestone',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          // Achieved milestones chips
          if (milestones.values.where((date) => date != null).isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: milestones.entries
                  .where((entry) => entry.value != null)
                  .map((entry) => _MilestoneChip(days: entry.key))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getMilestoneIcon(int milestone) {
    switch (milestone) {
      case 10:
        return Icons.looks_one;
      case 30:
        return Icons.calendar_month;
      case 100:
        return Icons.military_tech;
      case 365:
        return Icons.workspace_premium;
      default:
        return Icons.flag;
    }
  }
}

/// Small chip showing achieved milestone
class _MilestoneChip extends StatelessWidget {
  final int days;

  const _MilestoneChip({required this.days});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: 4),
          Text(
            '$days',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
