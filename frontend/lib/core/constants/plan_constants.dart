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
      dailyLimit: 8,
      isUnlimited: false,
      canPurchaseTokens: true,
      description: 'Free plan with 8 daily tokens',
    ),
    UserPlan.standard: PlanConfig(
      dailyLimit: 20,
      isUnlimited: false,
      canPurchaseTokens: true,
      description: 'Authenticated users with 20 daily tokens + purchase option',
    ),
    UserPlan.plus: PlanConfig(
      dailyLimit: 50,
      isUnlimited: false,
      canPurchaseTokens: true,
      description: 'Plus plan users with 50 daily tokens + purchase option',
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
