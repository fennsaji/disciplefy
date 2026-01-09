import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../domain/entities/token_usage_history.dart';

class UsageHistoryListItem extends StatelessWidget {
  final TokenUsageHistory usage;

  const UsageHistoryListItem({
    super.key,
    required this.usage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row - Content Title + Token Cost Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    usage.displayTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.token,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${usage.tokenCost}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Subtitle - Operation Type
            Text(
              _getOperationTypeLabel(usage.operationType),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),

            // Details Row - Study Mode + Language Chips
            if (usage.studyMode != null || usage.language.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (usage.studyMode != null)
                    _DetailChip(
                      icon: Icons.book,
                      label: _getStudyModeLabel(usage.studyMode!),
                      color: Colors.blue,
                    ),
                  if (usage.language.isNotEmpty)
                    _DetailChip(
                      icon: Icons.language,
                      label: _getLanguageLabel(usage.language),
                      color: Colors.teal,
                    ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            // Token Source Row - Daily vs Purchased
            Row(
              children: [
                Icon(
                  Icons.donut_small,
                  size: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${context.tr('tokens.usage.daily')}: ${usage.dailyTokensUsed} | ${context.tr('tokens.usage.purchased')}: ${usage.purchasedTokensUsed}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Footer - Timestamp
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(usage.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Format timestamp as relative if < 24h, otherwise absolute
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inHours < 24) {
      // Relative time for recent entries
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        return '${difference.inHours}h ago';
      }
    } else {
      // Absolute time for older entries
      final dateFormatter = DateFormat('MMM dd, yyyy • hh:mm a');
      return dateFormatter.format(timestamp);
    }
  }

  /// Map operation type to user-friendly label
  String _getOperationTypeLabel(String operationType) {
    switch (operationType) {
      case 'study_generation':
        return 'Study Generation';
      case 'follow_up_question':
        return 'Follow-up Question';
      case 'token_consumption':
        return 'Token Usage';
      default:
        return operationType
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  /// Map study mode to user-friendly label
  String _getStudyModeLabel(String studyMode) {
    switch (studyMode) {
      case 'quick':
        return 'Quick';
      case 'standard':
        return 'Standard';
      case 'deep':
        return 'Deep';
      case 'lectio':
        return 'Lectio';
      case 'sermon':
        return 'Sermon';
      default:
        return studyMode[0].toUpperCase() + studyMode.substring(1);
    }
  }

  /// Map language code to display label
  String _getLanguageLabel(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी';
      case 'ml':
        return 'മലയാളം';
      default:
        return languageCode.toUpperCase();
    }
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
