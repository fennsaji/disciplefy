import 'package:flutter/material.dart';

import '../../features/tokens/domain/entities/token_status.dart';
import 'app_colors.dart';

/// The single source of truth for subscription-plan accent colours.
///
/// This ramp previously existed as five hand-copied `_getPlanColor` helpers
/// (token balance, plan comparison, current plan, my plan, upgrade dialog),
/// which had already drifted: `standard` had three different values and the
/// upgrade dialog painted `premium` purple while everywhere else used amber.
/// The amber was `Colors.amber[700]`, which measured 2.04:1 as text.
Color planAccent(BuildContext context, UserPlan plan) {
  switch (plan) {
    case UserPlan.free:
      return context.appTextSecondary;
    case UserPlan.standard:
      return context.appBrandAccent;
    case UserPlan.plus:
      return AppColors.masteryAdvanced;
    case UserPlan.premium:
      // Top of the ramp — brand gold, theme-aware so it clears AA on both
      // grounds.
      return context.appStreakAccent;
  }
}

/// Name-keyed variant for callers that only hold a plan string.
Color planAccentFromName(BuildContext context, String plan) {
  switch (plan.toLowerCase()) {
    case 'standard':
      return planAccent(context, UserPlan.standard);
    case 'plus':
      return planAccent(context, UserPlan.plus);
    case 'premium':
      return planAccent(context, UserPlan.premium);
    case 'free':
    default:
      return planAccent(context, UserPlan.free);
  }
}
