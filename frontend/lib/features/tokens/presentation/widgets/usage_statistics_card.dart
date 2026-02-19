import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../domain/entities/usage_statistics.dart';

class UsageStatisticsCard extends StatelessWidget {
  final UsageStatistics statistics;

  const UsageStatisticsCard({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('MMM dd, yyyy');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.insights,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('tokens.stats.usage_summary'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (statistics.firstUsageDate != null)
                        Text(
                          '${context.tr('tokens.stats.since')} ${dateFormatter.format(statistics.firstUsageDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Statistics Grid - Row 1
            Row(
              children: [
                Expanded(
                  child: _StatisticItem(
                    context: context,
                    icon: Icons.token,
                    label: context.tr('tokens.stats.total_tokens_used'),
                    value: statistics.totalTokens.toString(),
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatisticItem(
                    context: context,
                    icon: Icons.file_copy,
                    label: context.tr('tokens.stats.total_operations'),
                    value: statistics.totalOperations.toString(),
                    color: Colors.teal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Statistics Grid - Row 2
            Row(
              children: [
                Expanded(
                  child: _StatisticItem(
                    context: context,
                    icon: Icons.calculate,
                    label: context.tr('tokens.stats.avg_per_operation'),
                    value:
                        statistics.averageTokensPerOperation.toStringAsFixed(1),
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatisticItem(
                    context: context,
                    icon: Icons.shopping_bag,
                    label: context.tr('tokens.stats.purchased_percentage'),
                    value:
                        '${statistics.purchasedTokensPercentage.toStringAsFixed(0)}%',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),

            // Token Source Breakdown
            if (statistics.totalTokens > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.donut_small,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${context.tr('tokens.stats.daily_tokens')}: ${statistics.dailyTokensConsumed} | ${context.tr('tokens.stats.purchased_tokens')}: ${statistics.purchasedTokensConsumed}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Most Used Feature/Language/Mode
            if (statistics.mostUsedFeature != null ||
                statistics.mostUsedLanguage != null ||
                statistics.mostUsedMode != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.teal.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('tokens.stats.most_used'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (statistics.mostUsedFeature != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${context.tr('tokens.stats.feature')}: ${_getFeatureName(statistics.mostUsedFeature!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                    if (statistics.mostUsedLanguage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${context.tr('tokens.stats.language')}: ${_getLanguageName(statistics.mostUsedLanguage!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                    if (statistics.mostUsedMode != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${context.tr('tokens.stats.study_mode')}: ${_getStudyModeName(statistics.mostUsedMode!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Last Usage Date
            if (statistics.lastUsageDate != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${context.tr('tokens.stats.last_usage')}: ${dateFormatter.format(statistics.lastUsageDate!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Map feature names to user-friendly display names
  String _getFeatureName(String featureName) {
    switch (featureName) {
      case 'study_generate':
        return 'Study Generation';
      case 'study_followup':
        return 'Follow-up Questions';
      case 'continue_learning':
        return 'Continue Learning';
      default:
        return featureName
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  /// Map language codes to display names
  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी (Hindi)';
      case 'ml':
        return 'മലയാളം (Malayalam)';
      default:
        return languageCode.toUpperCase();
    }
  }

  /// Map study mode codes to display names
  String _getStudyModeName(String modeCode) {
    switch (modeCode) {
      case 'quick':
        return 'Quick Study';
      case 'standard':
        return 'Standard Study';
      case 'deep':
        return 'Deep Study';
      case 'lectio':
        return 'Lectio Divina';
      case 'sermon':
        return 'Sermon Outline';
      default:
        return modeCode[0].toUpperCase() + modeCode.substring(1);
    }
  }
}

class _StatisticItem extends StatelessWidget {
  final BuildContext context;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatisticItem({
    required this.context,
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
