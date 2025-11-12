import 'package:flutter/material.dart';

import '../../domain/entities/review_statistics_entity.dart';

/// Widget displaying memory verse statistics.
///
/// Shows key metrics in a visually appealing card layout:
/// - Total verses in deck
/// - Verses due for review
/// - Mastered verses (repetitions >= 5)
/// - Mastery percentage with progress bar
class StatisticsCard extends StatelessWidget {
  final ReviewStatisticsEntity statistics;

  const StatisticsCard({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Top row: Total and Due
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context: context,
                    icon: Icons.library_books,
                    label: 'Total Verses',
                    value: statistics.totalVerses.toString(),
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    context: context,
                    icon: Icons.schedule,
                    label: 'Due Today',
                    value: statistics.dueVerses.toString(),
                    color:
                        statistics.dueVerses > 0 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Middle row: Reviewed Today and Mastered
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context: context,
                    icon: Icons.check_circle,
                    label: 'Reviewed Today',
                    value: statistics.reviewedToday.toString(),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    context: context,
                    icon: Icons.star,
                    label: 'Mastered',
                    value: statistics.masteredVerses.toString(),
                    color: Colors.amber,
                  ),
                ),
              ],
            ),

            // Mastery Progress Bar
            if (statistics.totalVerses > 0) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mastery Progress',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${statistics.masteryPercentage.toStringAsFixed(0)}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: statistics.masteryPercentage / 100,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getMasteryColor(statistics.masteryPercentage),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getMasteryMessage(statistics.masteryPercentage),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Brighten colors in dark mode for better visibility
    final displayColor = isDarkMode ? _brightenColor(color) : color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? displayColor.withOpacity(0.15)
            : displayColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: isDarkMode
            ? Border.all(color: displayColor.withOpacity(0.3))
            : null,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: displayColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: displayColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Brightens a color for better visibility in dark mode
  Color _brightenColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    // Increase lightness to at least 60% for dark mode
    final brightened = hsl.withLightness((hsl.lightness + 0.3).clamp(0.6, 1.0));
    return brightened.toColor();
  }

  Color _getMasteryColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.blue;
    if (percentage >= 25) return Colors.orange;
    return Colors.red;
  }

  String _getMasteryMessage(double percentage) {
    if (percentage >= 75) return 'Excellent! Keep up the great work!';
    if (percentage >= 50) return 'Great progress! You\'re doing well!';
    if (percentage >= 25) return 'Good start! Keep practicing!';
    return 'Just getting started. You can do it!';
  }
}
