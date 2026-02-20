import 'package:flutter/material.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';

import '../../domain/entities/token_status.dart';
import '../../../../core/extensions/translation_extension.dart';

/// Widget that displays action buttons for token-related operations
class TokenActionsSection extends StatelessWidget {
  final TokenStatus tokenStatus;
  final VoidCallback onPurchase;
  final VoidCallback onUpgrade;
  final VoidCallback? onViewHistory;
  final VoidCallback? onViewUsageHistory;

  const TokenActionsSection({
    super.key,
    required this.tokenStatus,
    required this.onPurchase,
    required this.onUpgrade,
    this.onViewHistory,
    this.onViewUsageHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('tokens.management.actions'),
              style: AppFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (tokenStatus.canPurchaseTokens) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPurchase,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(context.tr('tokens.purchase.title')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandSecondary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (tokenStatus.userPlan == UserPlan.free ||
                tokenStatus.userPlan == UserPlan.standard) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onUpgrade,
                  icon: const Icon(Icons.arrow_circle_up_rounded),
                  label: Text(context.tr('tokens.plans.upgrade')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.streakFlame,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            ],
            // Purchase History button (always show if callback provided)
            if (onViewHistory != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewHistory,
                  icon: Icon(Icons.receipt_long,
                      color: Theme.of(context).colorScheme.onSurface),
                  label: Text(context.tr('tokens.management.view_history')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ],
            // Usage History button (always show if callback provided)
            if (onViewUsageHistory != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onViewUsageHistory,
                  icon: Icon(Icons.history, color: AppTheme.usageHistoryColor),
                  label:
                      Text(context.tr('tokens.management.view_usage_history')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.usageHistoryColor,
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(
                      color: AppTheme.usageHistoryColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
