import 'package:flutter/material.dart';

import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../domain/entities/review_statistics_entity.dart';

/// Dialog for displaying detailed memory verse statistics.
///
/// Shows comprehensive analytics about the user's memory verse progress
/// including total verses, due for review, reviewed today, upcoming,
/// mastered, and mastery rate.
class StatisticsDialog extends StatelessWidget {
  final ReviewStatisticsEntity statistics;

  const StatisticsDialog({
    super.key,
    required this.statistics,
  });

  /// Shows the statistics dialog.
  static void show(BuildContext context, ReviewStatisticsEntity statistics) {
    showDialog(
      context: context,
      builder: (dialogContext) => StatisticsDialog(statistics: statistics),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        context.tr(TranslationKeys.statsDialogTitle),
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow(
              context,
              icon: Icons.book,
              label: context.tr(TranslationKeys.statsDialogTotalVerses),
              value: statistics.totalVerses.toString(),
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              context,
              icon: Icons.schedule,
              label: context.tr(TranslationKeys.statsDialogDueVerses),
              value: statistics.dueVerses.toString(),
              color: statistics.dueVerses > 0 ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              context,
              icon: Icons.check_circle,
              label: context.tr(TranslationKeys.statsDialogReviewedToday),
              value: statistics.reviewedToday.toString(),
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              context,
              icon: Icons.event,
              label: context.tr(TranslationKeys.statsDialogUpcoming),
              value: statistics.upcomingReviews.toString(),
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              context,
              icon: Icons.star,
              label: context.tr(TranslationKeys.statsDialogMastered),
              value: statistics.masteredVerses.toString(),
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildMasteryRate(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr(TranslationKeys.statsDialogClose)),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMasteryRate(BuildContext context) {
    final theme = Theme.of(context);
    final masteryPercentage = statistics.masteryPercentage;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr(TranslationKeys.statsDialogMasteryRate),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${masteryPercentage.toStringAsFixed(1)}%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getMasteryColor(masteryPercentage),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: masteryPercentage / 100,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getMasteryColor(masteryPercentage),
            ),
          ),
        ),
      ],
    );
  }

  Color _getMasteryColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }
}
