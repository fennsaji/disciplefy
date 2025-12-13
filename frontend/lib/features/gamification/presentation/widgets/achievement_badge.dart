import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/achievement.dart';

/// Widget to display a single achievement badge
class AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final int? currentProgress;
  final VoidCallback? onTap;
  final bool showDetails;

  const AchievementBadge({
    super.key,
    required this.achievement,
    this.currentProgress,
    this.onTap,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlocked = achievement.isUnlocked;

    if (showDetails) {
      return _buildDetailedView(context, theme, isUnlocked);
    }

    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: achievement.name,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isUnlocked
                ? _getCategoryColor(achievement.category).withOpacity(0.15)
                : theme.colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnlocked
                  ? _getCategoryColor(achievement.category).withOpacity(0.3)
                  : theme.colorScheme.onSurface.withOpacity(0.1),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              isUnlocked ? achievement.icon : '🔒',
              style: TextStyle(
                fontSize: isUnlocked ? 28 : 20,
                color: isUnlocked
                    ? null
                    : theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedView(
      BuildContext context, ThemeData theme, bool isUnlocked) {
    final progress = currentProgress != null && achievement.threshold != null
        ? achievement.getProgress(currentProgress!)
        : (isUnlocked ? 1.0 : 0.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUnlocked
              ? _getCategoryColor(achievement.category).withOpacity(0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? _getCategoryColor(achievement.category).withOpacity(0.3)
                : theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? _getCategoryColor(achievement.category).withOpacity(0.2)
                    : theme.colorScheme.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  isUnlocked ? achievement.icon : '🔒',
                  style: TextStyle(
                    fontSize: isUnlocked ? 28 : 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.name,
                    style: AppFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isUnlocked
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: AppFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isUnlocked && achievement.threshold != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor:
                                  theme.colorScheme.primary.withOpacity(0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getCategoryColor(achievement.category),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${currentProgress ?? 0}/${achievement.threshold}',
                          style: AppFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isUnlocked && achievement.unlockedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${AppLocalizations.of(context)!.progressUnlocked} ${_formatDate(context, achievement.unlockedAt!)}',
                      style: AppFonts.inter(
                        fontSize: 11,
                        color: _getCategoryColor(achievement.category),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // XP reward
            if (achievement.xpReward > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${achievement.xpReward} XP',
                  style: AppFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.study:
        return Colors.purple;
      case AchievementCategory.streak:
        return Colors.orange;
      case AchievementCategory.memory:
        return Colors.blue;
      case AchievementCategory.voice:
        return Colors.green;
      case AchievementCategory.saved:
        return Colors.teal;
    }
  }

  String _formatDate(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return l10n.progressToday;
    } else if (diff.inDays == 1) {
      return l10n.progressYesterday;
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ${l10n.progressDaysAgo}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
