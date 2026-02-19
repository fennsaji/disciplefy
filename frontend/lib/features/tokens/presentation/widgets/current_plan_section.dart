import 'package:flutter/material.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';

import '../../domain/entities/token_status.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Widget that displays the current user plan information
/// with a unified "My Plan" button for all plan management actions.
class CurrentPlanSection extends StatelessWidget {
  final TokenStatus tokenStatus;
  final VoidCallback onMyPlan;
  final bool isCancelledButActive;
  final bool isTrialActive;
  final DateTime? trialEndDate;

  const CurrentPlanSection({
    super.key,
    required this.tokenStatus,
    required this.onMyPlan,
    this.isCancelledButActive = false,
    this.isTrialActive = false,
    this.trialEndDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planColor = _getPlanColor(tokenStatus.userPlan);

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
                  color: planColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('tokens.plans.current_plan'),
                  style: AppFonts.inter(
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
                    color: planColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: planColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    tokenStatus.userPlan.displayName,
                    style: AppFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: planColor,
                    ),
                  ),
                ),
                const Spacer(),
                // Single unified "My Plan" button - always visible
                OutlinedButton.icon(
                  onPressed: onMyPlan,
                  icon: Icon(Icons.assignment_outlined,
                      size: 18,
                      color: isDark
                          ? Theme.of(context).colorScheme.onSurface
                          : planColor),
                  label: const Text('My Plan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? Theme.of(context).colorScheme.onSurface
                        : planColor,
                    side: BorderSide(
                      color: isDark
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5)
                          : planColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getPlanDescription(tokenStatus.userPlan, context),
              style: AppFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            // Cancelled but active subscription notice
            if (isCancelledButActive) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.warning.withOpacity(0.15)
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppColors.warning.withOpacity(0.4)
                        : AppColors.warning,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16,
                        color:
                            isDark ? AppColors.warning : AppColors.warningDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr(TranslationKeys.plansCancelledNotice),
                        style: AppFonts.inter(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.warning
                              : AppColors.warningDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Standard trial info banner
            if (tokenStatus.userPlan == UserPlan.standard &&
                isTrialActive &&
                trialEndDate != null) ...[
              const SizedBox(height: 8),
              _buildTrialBanner(context, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrialBanner(BuildContext context, bool isDark) {
    const standardColor = Color(0xFF6A4FB6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            isDark ? standardColor.withOpacity(0.15) : const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isDark ? standardColor.withOpacity(0.4) : const Color(0xFFD8B4FE),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              size: 16,
              color: isDark ? const Color(0xFFB794F4) : standardColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Free until ${_formatDate(trialEndDate!)}',
              style: AppFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFB794F4) : standardColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPlanIcon(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return Icons.person;
      case UserPlan.standard:
        return Icons.auto_awesome;
      case UserPlan.plus:
        return Icons.workspace_premium;
      case UserPlan.premium:
        return Icons.star;
    }
  }

  Color _getPlanColor(UserPlan plan) {
    switch (plan) {
      case UserPlan.free:
        return Colors.grey[600]!;
      case UserPlan.standard:
        return const Color(0xFF6A4FB6);
      case UserPlan.plus:
        return Colors.purple[600]!;
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
      case UserPlan.plus:
        return context.tr('tokens.plans.plus_description');
      case UserPlan.premium:
        return context.tr('tokens.plans.premium_description');
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
