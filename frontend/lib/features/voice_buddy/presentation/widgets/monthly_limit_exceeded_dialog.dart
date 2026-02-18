import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/pricing_service.dart';
import '../../../../core/di/injection_container.dart';

/// Dialog shown when user exceeds their monthly voice conversation limit.
/// Displays current usage, upgrade options, and navigation to pricing page.
class MonthlyLimitExceededDialog extends StatelessWidget {
  final int conversationsUsed;
  final int limit;
  final String tier;
  final String month;

  const MonthlyLimitExceededDialog({
    super.key,
    required this.conversationsUsed,
    required this.limit,
    required this.tier,
    required this.month,
  });

  /// Show the monthly limit exceeded dialog.
  static void show(
    BuildContext context, {
    required int conversationsUsed,
    required int limit,
    required String tier,
    required String month,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MonthlyLimitExceededDialog(
        conversationsUsed: conversationsUsed,
        limit: limit,
        tier: tier,
        month: month,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pricingService = sl<PricingService>();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.error.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.block, color: colorScheme.error, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Monthly Limit Reached',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve used all $limit voice conversation${limit > 1 ? 's' : ''} for this month.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Conversations Used:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    '$conversationsUsed / $limit',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Upgrade to get more conversations:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            _buildPlanOption(
              context,
              'Standard',
              pricingService.getVoiceQuotaLabel('standard'),
              pricingService.getFormattedPricePerMonth('standard'),
            ),
            _buildPlanOption(
              context,
              'Plus',
              pricingService.getVoiceQuotaLabel('plus'),
              pricingService.getFormattedPricePerMonth('plus'),
            ),
            _buildPlanOption(
              context,
              'Premium',
              pricingService.getVoiceQuotaLabel('premium'),
              pricingService.getFormattedPricePerMonth('premium'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.pushNamed(context, AppRoutes.pricing);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('View Plans'),
        ),
      ],
    );
  }

  Widget _buildPlanOption(
    BuildContext context,
    String name,
    String conversations,
    String price,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '$conversations '),
                  TextSpan(
                    text: '($price)',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
