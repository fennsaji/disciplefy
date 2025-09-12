import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/token_status.dart';
import '../extensions/duration_extensions.dart';

/// Widget that displays detailed usage information for user's tokens
class UsageInfoSection extends StatelessWidget {
  final TokenStatus tokenStatus;

  const UsageInfoSection({
    super.key,
    required this.tokenStatus,
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
              'Usage Information',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (!tokenStatus.isPremium) ...[
              _buildInfoRow(
                  context, 'Daily Limit', '${tokenStatus.dailyLimit} tokens'),
              _buildInfoRow(context, 'Daily Available',
                  '${tokenStatus.availableTokens} tokens'),
              _buildInfoRow(context, 'Purchased Tokens',
                  '${tokenStatus.purchasedTokens} tokens'),
              _buildInfoRow(context, 'Total Available',
                  '${tokenStatus.totalTokens} tokens'),
              _buildInfoRow(context, 'Used Today',
                  '${tokenStatus.totalConsumedToday} tokens'),
              _buildInfoRow(context, 'Next Reset',
                  tokenStatus.timeUntilReset.toShortLabel()),
            ] else ...[
              Row(
                children: [
                  Icon(
                    Icons.all_inclusive,
                    color: Colors.amber[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Unlimited tokens available',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Generate as many study guides as you want!',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
