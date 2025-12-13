import 'package:flutter/material.dart';

import '../../../../core/constants/app_fonts.dart';
import '../../domain/entities/achievement.dart';
import 'achievement_badge.dart';

/// Widget to display a grid of achievements
class AchievementsGrid extends StatelessWidget {
  final List<Achievement> achievements;
  final Map<AchievementCategory, int>? progressMap;
  final Function(Achievement)? onAchievementTap;
  final bool showHeader;
  final bool showAllAchievements;

  const AchievementsGrid({
    super.key,
    required this.achievements,
    this.progressMap,
    this.onAchievementTap,
    this.showHeader = true,
    this.showAllAchievements = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final totalCount = achievements.length;

    // Group achievements by category
    final groupedAchievements = <AchievementCategory, List<Achievement>>{};
    for (final achievement in achievements) {
      groupedAchievements.putIfAbsent(achievement.category, () => []);
      groupedAchievements[achievement.category]!.add(achievement);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Achievements',
                  style: AppFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unlockedCount/$totalCount',
                    style: AppFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalCount > 0 ? unlockedCount / totalCount : 0,
                minHeight: 6,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (showAllAchievements)
            ..._buildCategorizedList(context, groupedAchievements)
          else
            _buildCompactGrid(context),
        ],
      ),
    );
  }

  Widget _buildCompactGrid(BuildContext context) {
    // Show only a compact grid of badges (unlocked first, then locked)
    final sortedAchievements = List<Achievement>.from(achievements)
      ..sort((a, b) {
        if (a.isUnlocked && !b.isUnlocked) return -1;
        if (!a.isUnlocked && b.isUnlocked) return 1;
        return 0;
      });

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sortedAchievements.map((achievement) {
        return AchievementBadge(
          achievement: achievement,
          currentProgress: _getProgressForCategory(achievement.category),
          onTap: onAchievementTap != null
              ? () => onAchievementTap!(achievement)
              : null,
        );
      }).toList(),
    );
  }

  List<Widget> _buildCategorizedList(
    BuildContext context,
    Map<AchievementCategory, List<Achievement>> groupedAchievements,
  ) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];

    final categoryOrder = [
      AchievementCategory.study,
      AchievementCategory.streak,
      AchievementCategory.memory,
      AchievementCategory.voice,
      AchievementCategory.saved,
    ];

    for (final category in categoryOrder) {
      final categoryAchievements = groupedAchievements[category];
      if (categoryAchievements == null || categoryAchievements.isEmpty) {
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            _getCategoryTitle(category),
            style: AppFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      );

      for (final achievement in categoryAchievements) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AchievementBadge(
              achievement: achievement,
              currentProgress: _getProgressForCategory(category),
              showDetails: true,
              onTap: onAchievementTap != null
                  ? () => onAchievementTap!(achievement)
                  : null,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  String _getCategoryTitle(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.study:
        return '📚 Study Guides';
      case AchievementCategory.streak:
        return '🔥 Study Streaks';
      case AchievementCategory.memory:
        return '🧠 Memory Verses';
      case AchievementCategory.voice:
        return '🎙️ Voice Discipler';
      case AchievementCategory.saved:
        return '📕 Saved Guides';
    }
  }

  int? _getProgressForCategory(AchievementCategory category) {
    return progressMap?[category];
  }
}
