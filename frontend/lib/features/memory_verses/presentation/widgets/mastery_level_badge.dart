import 'package:flutter/material.dart';
import '../../domain/entities/mastery_progress_entity.dart';

/// Mastery level badge widget with color-coded visual indicator.
///
/// Displays:
/// - Color-coded badge (Beginner=Green, Intermediate=Blue, Advanced=Purple, Expert=Orange, Master=Gold)
/// - Level name
/// - Optional compact mode for smaller displays
class MasteryLevelBadge extends StatelessWidget {
  final MasteryLevel masteryLevel;
  final bool isCompact;
  final double size;

  const MasteryLevelBadge({
    super.key,
    required this.masteryLevel,
    this.isCompact = false,
    this.size = 24.0,
  });

  Color get _levelColor {
    // Use MasteryProgressEntity helper to get color
    final dummyEntity = MasteryProgressEntity(
      masteryLevel: masteryLevel,
      masteryPercentage: 0.0,
      modesMastered: 0,
      perfectRecalls: 0,
    );
    return dummyEntity.levelColor;
  }

  IconData get _levelIcon {
    // Use MasteryProgressEntity helper to get icon
    final dummyEntity = MasteryProgressEntity(
      masteryLevel: masteryLevel,
      masteryPercentage: 0.0,
      modesMastered: 0,
      perfectRecalls: 0,
    );
    return dummyEntity.levelIcon;
  }

  String get _levelName {
    // Use MasteryProgressEntity helper to get display name
    final dummyEntity = MasteryProgressEntity(
      masteryLevel: masteryLevel,
      masteryPercentage: 0.0,
      modesMastered: 0,
      perfectRecalls: 0,
    );
    return dummyEntity.levelDisplayName;
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      // Compact mode - just icon with color
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _levelColor.withAlpha((0.2 * 255).round()),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          _levelIcon,
          size: size,
          color: _levelColor,
        ),
      );
    }

    // Full mode - icon + text
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _levelColor.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _levelColor.withAlpha((0.5 * 255).round()),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _levelIcon,
            size: size,
            color: _levelColor,
          ),
          const SizedBox(width: 6),
          Text(
            _levelName,
            style: TextStyle(
              color: _levelColor,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.65,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mastery progress card showing level and progress to next level.
///
/// Displays:
/// - Current mastery level badge
/// - Progress bar to next level
/// - Percentage indicator
/// - Next level requirements
class MasteryProgressCard extends StatelessWidget {
  final MasteryLevel currentLevel;
  final double progressPercentage; // 0.0 to 100.0
  final String? nextLevelRequirement;
  final VoidCallback? onTap;

  const MasteryProgressCard({
    super.key,
    required this.currentLevel,
    required this.progressPercentage,
    this.nextLevelRequirement,
    this.onTap,
  });

  MasteryLevel? get _nextLevel {
    switch (currentLevel) {
      case MasteryLevel.beginner:
        return MasteryLevel.intermediate;
      case MasteryLevel.intermediate:
        return MasteryLevel.advanced;
      case MasteryLevel.advanced:
        return MasteryLevel.expert;
      case MasteryLevel.expert:
        return MasteryLevel.master;
      case MasteryLevel.master:
        return null; // Already at max level
    }
  }

  Color get _currentLevelColor {
    switch (currentLevel) {
      case MasteryLevel.beginner:
        return Colors.green;
      case MasteryLevel.intermediate:
        return Colors.blue;
      case MasteryLevel.advanced:
        return Colors.purple;
      case MasteryLevel.expert:
        return Colors.orange;
      case MasteryLevel.master:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMaster = currentLevel == MasteryLevel.master;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current level badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MasteryLevelBadge(
                    masteryLevel: currentLevel,
                    size: 20,
                  ),
                  if (!isMaster)
                    Text(
                      '${progressPercentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _currentLevelColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),

              if (!isMaster) ...[
                const SizedBox(height: 12),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressPercentage / 100.0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_currentLevelColor),
                    minHeight: 8,
                  ),
                ),

                if (_nextLevel != null) ...[
                  const SizedBox(height: 8),

                  // Next level indicator
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      MasteryLevelBadge(
                        masteryLevel: _nextLevel!,
                        isCompact: true,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nextLevelRequirement ?? 'Keep practicing to advance',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.verified,
                      size: 20,
                      color: _currentLevelColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Master Level - You\'ve achieved the highest mastery!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _currentLevelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mastery distribution widget showing count of verses at each level.
///
/// Displays:
/// - Bar chart or list view of mastery level distribution
/// - Count of verses at each level
/// - Color-coded visual indicators
class MasteryDistributionWidget extends StatelessWidget {
  final Map<MasteryLevel, int> distribution;
  final bool showAsChart;

  const MasteryDistributionWidget({
    super.key,
    required this.distribution,
    this.showAsChart = true,
  });

  int get _totalVerses {
    return distribution.values.fold(0, (sum, count) => sum + count);
  }

  Color _getLevelColor(MasteryLevel level) {
    switch (level) {
      case MasteryLevel.beginner:
        return Colors.green;
      case MasteryLevel.intermediate:
        return Colors.blue;
      case MasteryLevel.advanced:
        return Colors.purple;
      case MasteryLevel.expert:
        return Colors.orange;
      case MasteryLevel.master:
        return Colors.amber;
    }
  }

  String _getLevelName(MasteryLevel level) {
    switch (level) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_totalVerses == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_books,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant
                    .withAlpha((0.5 * 255).round()),
              ),
              const SizedBox(height: 12),
              Text(
                'No memory verses yet',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Mastery Distribution',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...MasteryLevel.values.map((level) {
          final count = distribution[level] ?? 0;
          final percentage = _totalVerses > 0 ? (count / _totalVerses) : 0.0;

          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    _getLevelName(level),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(_getLevelColor(level)),
                      minHeight: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 40,
                  child: Text(
                    count.toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getLevelColor(level),
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(
              color: theme.colorScheme.onSurfaceVariant
                  .withAlpha((0.2 * 255).round())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Verses',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _totalVerses.toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
