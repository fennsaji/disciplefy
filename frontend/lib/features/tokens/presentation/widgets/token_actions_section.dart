import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/token_status.dart';

/// Widget that displays action buttons for token-related operations
class TokenActionsSection extends StatelessWidget {
  final TokenStatus tokenStatus;
  final VoidCallback onPurchase;
  final VoidCallback onUpgrade;

  const TokenActionsSection({
    super.key,
    required this.tokenStatus,
    required this.onPurchase,
    required this.onUpgrade,
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
              'Actions',
              style: GoogleFonts.inter(
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
                  label: const Text('Purchase Tokens'),
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
                  label: const Text('Upgrade to Standard'),
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
                  label: const Text('Upgrade to Premium'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
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
