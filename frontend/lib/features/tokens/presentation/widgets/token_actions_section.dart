import 'package:flutter/material.dart';
import '../../../../core/constants/app_fonts.dart';

import '../../domain/entities/token_status.dart';
import '../../../../core/extensions/translation_extension.dart';

/// Widget that displays action buttons for token-related operations
class TokenActionsSection extends StatelessWidget {
  final TokenStatus tokenStatus;
  final VoidCallback onPurchase;
  final VoidCallback onUpgrade;
  final VoidCallback? onViewHistory;

  const TokenActionsSection({
    super.key,
    required this.tokenStatus,
    required this.onPurchase,
    required this.onUpgrade,
    this.onViewHistory,
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (tokenStatus.userPlan == UserPlan.free) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onUpgrade,
                  icon: const Icon(Icons.upgrade),
                  label: Text(context.tr('tokens.plans.upgrade_to_standard')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            ] else if (tokenStatus.userPlan == UserPlan.standard) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onUpgrade,
                  icon: const Icon(Icons.star),
                  label: Text(context.tr('tokens.plans.upgrade_to_premium')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
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
                  icon: const Icon(Icons.history),
                  label: Text(context.tr('tokens.management.view_history')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outline),
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
