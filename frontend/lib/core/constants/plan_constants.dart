import '../../../features/tokens/domain/entities/token_status.dart';

/// Centralized plan configuration - Single source of truth for frontend
///
/// IMPORTANT: These values must match backend configuration in:
/// backend/supabase/functions/_shared/types/token-types.ts (DEFAULT_PLAN_CONFIGS)
///
/// Any changes to plan limits should be made in the backend first,
/// then reflected here to keep frontend and backend in sync.

/// Configuration for a single plan
class PlanConfig {
  final int dailyLimit;
  final bool isUnlimited;
  final bool canPurchaseTokens;
  final String description;

  const PlanConfig({
    required this.dailyLimit,
    required this.isUnlimited,
    required this.canPurchaseTokens,
    required this.description,
  });
}

/// Centralized plan configurations
///
/// This is the single source of truth for plan limits and features.
/// Backend should always send accurate data, but this serves as fallback
/// and for client-side validation.
class PlanConstants {
  PlanConstants._(); // Private constructor to prevent instantiation

  /// Plan configurations matching backend DEFAULT_PLAN_CONFIGS
  static const Map<UserPlan, PlanConfig> configs = {
    UserPlan.free: PlanConfig(
      dailyLimit: 15,
      isUnlimited: false,
      canPurchaseTokens: true,
      description: 'Free plan — 15 daily tokens (1 Quick in any language)',
    ),
    UserPlan.standard: PlanConfig(
      dailyLimit: 40,
      isUnlimited: false,
      canPurchaseTokens: true,
      description:
          'Standard plan — 40 daily tokens (1 Standard in any language)',
    ),
    UserPlan.plus: PlanConfig(
      dailyLimit: 60,
      isUnlimited: false,
      canPurchaseTokens: true,
      description: 'Plus plan — 60 daily tokens (1 Deep in any language)',
    ),
    UserPlan.premium: PlanConfig(
      dailyLimit: -1, // Unlimited
      isUnlimited: true,
      canPurchaseTokens: false,
      description: 'Premium users with unlimited tokens',
    ),
  };

  /// Get daily limit for a plan
  static int getDailyLimit(UserPlan plan) {
    return configs[plan]?.dailyLimit ?? configs[UserPlan.free]!.dailyLimit;
  }

  /// Get plan description
  static String getDescription(UserPlan plan) {
    return configs[plan]?.description ?? configs[UserPlan.free]!.description;
  }

  /// Check if plan is unlimited
  static bool isUnlimited(UserPlan plan) {
    return configs[plan]?.isUnlimited ?? false;
  }

  /// Check if plan can purchase tokens
  static bool canPurchaseTokens(UserPlan plan) {
    return configs[plan]?.canPurchaseTokens ?? true;
  }
}
