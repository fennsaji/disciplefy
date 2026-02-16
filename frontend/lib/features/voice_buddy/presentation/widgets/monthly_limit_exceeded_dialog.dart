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
    final pricingService = sl<PricingService>();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.block, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Monthly Limit Reached',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Conversations Used:',
                    style: TextStyle(fontSize: 14),
                  ),
                  Text(
                    '$conversationsUsed / $limit',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to get more conversations:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildPlanOption(
              context,
              'Standard',
              '3 conversations/month',
              pricingService.getFormattedPricePerMonth('standard'),
            ),
            _buildPlanOption(
              context,
              'Plus',
              '10 conversations/month',
              pricingService.getFormattedPricePerMonth('plus'),
            ),
            _buildPlanOption(
              context,
              'Premium',
              'Unlimited conversations',
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
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$name: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '$conversations '),
                  TextSpan(
                    text: '($price)',
                    style: TextStyle(color: Colors.grey[600]),
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
