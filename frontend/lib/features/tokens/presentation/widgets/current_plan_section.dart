import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/token_status.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Widget that displays the current user plan information
class CurrentPlanSection extends StatelessWidget {
  final TokenStatus tokenStatus;
  final VoidCallback onUpgrade;
  final VoidCallback? onManageSubscription;
  final bool isCancelledButActive;
  final VoidCallback? onContinueSubscription;

  const CurrentPlanSection({
    super.key,
    required this.tokenStatus,
    required this.onUpgrade,
    this.onManageSubscription,
    this.isCancelledButActive = false,
    this.onContinueSubscription,
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
                  context.tr('tokens.plans.current_plan'),
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
                if (tokenStatus.userPlan == UserPlan.premium &&
                    isCancelledButActive &&
                    onContinueSubscription != null)
                  // Show "Continue Subscription" for cancelled but active subscriptions
                  OutlinedButton.icon(
                    onPressed: onContinueSubscription,
                    icon: const Icon(Icons.restart_alt),
                    label: Text(
                        context.tr(TranslationKeys.plansContinueSubscription)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      side: BorderSide(color: Colors.green[700]!),
                    ),
                  )
                else if (tokenStatus.userPlan == UserPlan.premium &&
                    onManageSubscription != null)
                  OutlinedButton.icon(
                    onPressed: onManageSubscription,
                    icon: const Icon(Icons.settings),
                    label: Text(context.tr(TranslationKeys.plansManage)),
                  )
                else if (tokenStatus.userPlan != UserPlan.premium)
                  OutlinedButton(
                    onPressed: onUpgrade,
                    child: Text(
                      tokenStatus.userPlan == UserPlan.free
                          ? context.tr('tokens.plans.upgrade_plan')
                          : context.tr('tokens.plans.go_premium'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getPlanDescription(tokenStatus.userPlan, context),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (isCancelledButActive) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr(TranslationKeys.plansCancelledNotice),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.orange[900],
                        ),
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

  String _getPlanDescription(UserPlan plan, BuildContext context) {
    switch (plan) {
      case UserPlan.free:
        return context.tr('tokens.plans.free_description');
      case UserPlan.standard:
        return context.tr('tokens.plans.standard_description');
      case UserPlan.premium:
        return context.tr('tokens.plans.premium_description');
    }
  }
}
