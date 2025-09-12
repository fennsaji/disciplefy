import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/token_status.dart';

/// Widget that displays the current user plan information
class CurrentPlanSection extends StatelessWidget {
  final TokenStatus tokenStatus;
  final VoidCallback onUpgrade;

  const CurrentPlanSection({
    super.key,
    required this.tokenStatus,
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
            Row(
              children: [
                Icon(
                  _getPlanIcon(tokenStatus.userPlan),
                  color: _getPlanColor(tokenStatus.userPlan),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Current Plan',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPlanColor(tokenStatus.userPlan).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          _getPlanColor(tokenStatus.userPlan).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    tokenStatus.userPlan.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _getPlanColor(tokenStatus.userPlan),
                    ),
                  ),
                ),
                const Spacer(),
                if (tokenStatus.userPlan != UserPlan.premium)
                  OutlinedButton(
                    onPressed: onUpgrade,
                    child: Text(
                      tokenStatus.userPlan == UserPlan.free
                          ? 'Upgrade Plan'
                          : 'Go Premium',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getPlanDescription(tokenStatus.userPlan),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPlanIcon(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return Icons.person;
      case UserPlan.standard:
        return Icons.business;
      case UserPlan.premium:
        return Icons.star;
    }
  }

  Color _getPlanColor(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return Colors.grey[600]!;
      case UserPlan.standard:
        return Colors.blue[600]!;
      case UserPlan.premium:
        return Colors.amber[700]!;
    }
  }

  String _getPlanDescription(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return 'Get 20 daily tokens to generate Bible study guides. Perfect for personal study and exploration.';
      case UserPlan.standard:
        return 'Enjoy 100 daily tokens plus the ability to purchase additional tokens. Great for group leaders and regular users.';
      case UserPlan.premium:
        return 'Unlimited token access for unlimited Bible study generation. Perfect for pastors, teachers, and heavy users.';
    }
  }
}
