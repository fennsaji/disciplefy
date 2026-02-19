import 'package:flutter/material.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../../core/theme/app_colors.dart';

import '../../domain/entities/token_status.dart';
import '../../../../core/extensions/translation_extension.dart';

/// Widget that displays a comparison of all available plans
class PlanComparisonSection extends StatelessWidget {
  final TokenStatus tokenStatus;

  const PlanComparisonSection({
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
              context.tr('tokens.plans.comparison'),
              style: AppFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            PlanCard(
              plan: UserPlan.free,
              title: context.tr('tokens.plans.free'),
              subtitle: context.tr('tokens.plans.free_subtitle'),
              description: context.tr('tokens.plans.free_desc'),
              isCurrentPlan: tokenStatus.userPlan == UserPlan.free,
            ),
            const SizedBox(height: 12),
            PlanCard(
              plan: UserPlan.standard,
              title: context.tr('tokens.plans.standard'),
              subtitle: context.tr('tokens.plans.standard_subtitle'),
              description: context.tr('tokens.plans.standard_desc'),
              isCurrentPlan: tokenStatus.userPlan == UserPlan.standard,
            ),
            const SizedBox(height: 12),
            PlanCard(
              plan: UserPlan.plus,
              title: context.tr('tokens.plans.plus'),
              subtitle: context.tr('tokens.plans.plus_subtitle'),
              description: context.tr('tokens.plans.plus_desc'),
              isCurrentPlan: tokenStatus.userPlan == UserPlan.plus,
            ),
            const SizedBox(height: 12),
            PlanCard(
              plan: UserPlan.premium,
              title: context.tr('tokens.plans.premium'),
              subtitle: context.tr('tokens.plans.premium_subtitle'),
              description: context.tr('tokens.plans.premium_desc'),
              isCurrentPlan: tokenStatus.userPlan == UserPlan.premium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual plan card widget
class PlanCard extends StatelessWidget {
  final UserPlan plan;
  final String title;
  final String subtitle;
  final String description;
  final bool isCurrentPlan;

  const PlanCard({
    super.key,
    required this.plan,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.isCurrentPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPlan
            ? _getPlanColor(plan).withOpacity(0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlan
              ? _getPlanColor(plan)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: isCurrentPlan ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getPlanIcon(plan),
            color: _getPlanColor(plan),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (isCurrentPlan) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getPlanColor(plan),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          context.tr('tokens.plans.current'),
                          style: AppFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: AppFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _getPlanColor(plan),
                  ),
                ),
                Text(
                  description,
                  style: AppFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
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
        return Icons.business;
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
        return AppColors.info;
      case UserPlan.plus:
        return Colors.purple[600]!;
      case UserPlan.premium:
        return Colors.amber[700]!;
    }
  }
}
