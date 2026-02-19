import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../domain/entities/purchase_history.dart';
import '../../domain/entities/purchase_statistics.dart';

class PurchaseStatisticsCard extends StatelessWidget {
  final PurchaseStatistics statistics;

  const PurchaseStatisticsCard({
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
                    Icons.analytics,
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
                        context.tr('tokens.stats.purchase_summary'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (statistics.firstPurchaseDate != null)
                        Text(
                          '${context.tr('tokens.stats.since')} ${dateFormatter.format(statistics.firstPurchaseDate!)}',
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

            // Statistics Grid
            Row(
              children: [
                Expanded(
                  child: _StatisticItem(
                    context: context,
                    icon: Icons.shopping_cart,
                    label: context.tr('tokens.stats.total_purchases'),
                    value: statistics.totalPurchases.toString(),
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatisticItem(
                    context: context,
                    icon: Icons.token,
                    label: context.tr('tokens.stats.total_tokens'),
                    value: statistics.totalTokens.toString(),
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _StatisticItem(
                    context: context,
                    icon: Icons.currency_rupee,
                    label: context.tr('tokens.stats.total_spent'),
                    value: '₹${statistics.totalSpent.toStringAsFixed(2)}',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatisticItem(
                    context: context,
                    icon: Icons.calculate,
                    label: context.tr('tokens.stats.avg_per_token'),
                    value: statistics.totalTokens > 0
                        ? '₹${(statistics.totalSpent / statistics.totalTokens).toStringAsFixed(3)}'
                        : '₹0.000',
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),

            if (statistics.lastPurchaseDate != null) ...[
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
                      '${context.tr('tokens.stats.last_purchase')}: ${dateFormatter.format(statistics.lastPurchaseDate!)}',
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
                  maxLines: 1,
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
