import '../../domain/entities/token_status.dart';

/// Data model for TokenStatus that handles JSON serialization
class TokenStatusModel extends TokenStatus {
  const TokenStatusModel({
    required super.availableTokens,
    required super.purchasedTokens,
    required super.totalTokens,
    required super.dailyLimit,
    required super.totalConsumedToday,
    required super.userPlan,
    required super.lastReset,
    required super.nextResetTime,
    required super.authenticationType,
    required super.isPremium,
    required super.unlimitedUsage,
    required super.canPurchaseTokens,
    required super.planDescription,
  });

  /// Create TokenStatusModel from API response
  factory TokenStatusModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;

    return TokenStatusModel(
      // Handle both camelCase (from confirm-payment API) and snake_case (from other APIs)
      availableTokens:
          ((data['availableTokens'] ?? data['available_tokens']) as num)
              .toInt(),
      purchasedTokens:
          ((data['purchasedTokens'] ?? data['purchased_tokens']) as num)
              .toInt(),
      totalTokens:
          ((data['totalTokens'] ?? data['total_tokens']) as num).toInt(),
      dailyLimit: ((data['dailyLimit'] ?? data['daily_limit']) as num).toInt(),
      totalConsumedToday:
          ((data['totalConsumedToday'] ?? data['total_consumed_today']) as num)
              .toInt(),
      userPlan:
          _parseUserPlan((data['userPlan'] ?? data['user_plan']) as String),
      lastReset:
          DateTime.parse((data['lastReset'] ?? data['last_reset']) as String),
      nextResetTime: (data['nextResetTime'] ?? data['next_reset_time']) != null
          ? DateTime.parse(
              (data['nextResetTime'] ?? data['next_reset_time']) as String)
          : DateTime.now().add(const Duration(days: 1)),
      authenticationType: _parseAuthType((data['authenticationType'] ??
              data['authentication_type']) as String? ??
          'authenticated'),
      isPremium: (data['isPremium'] ?? data['is_premium']) as bool? ?? false,
      unlimitedUsage:
          (data['unlimitedUsage'] ?? data['unlimited_usage']) as bool? ?? false,
      canPurchaseTokens:
          (data['canPurchaseTokens'] ?? data['can_purchase_tokens']) as bool? ??
              // Default to true for standard users if not explicitly provided
              ((data['userPlan'] ?? data['user_plan']) == 'standard'),
      planDescription:
          (data['planDescription'] ?? data['plan_description']) as String? ??
              _getDefaultPlanDescription(
                  (data['userPlan'] ?? data['user_plan']) as String? ?? 'free'),
    );
  }

  /// Parse user plan from string
  static UserPlan _parseUserPlan(String planString) {
    switch (planString.toLowerCase()) {
      case 'free':
        return UserPlan.free;
      case 'standard':
        return UserPlan.standard;
      case 'premium':
        return UserPlan.premium;
      default:
        return UserPlan.free;
    }
  }

  /// Parse authentication type from string
  static AuthenticationType _parseAuthType(String authTypeString) {
    switch (authTypeString.toLowerCase()) {
      case 'anonymous':
        return AuthenticationType.anonymous;
      case 'authenticated':
        return AuthenticationType.authenticated;
      default:
        return AuthenticationType.anonymous;
    }
  }

  /// Get default plan description based on user plan
  static String _getDefaultPlanDescription(String userPlan) {
    switch (userPlan.toLowerCase()) {
      case 'free':
        return 'Free users with daily token limit';
      case 'standard':
        return 'Authenticated users with 100 tokens daily + purchase option';
      case 'premium':
        return 'Premium users with unlimited token usage';
      default:
        return 'Free users with daily token limit';
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'available_tokens': availableTokens,
      'purchased_tokens': purchasedTokens,
      'total_tokens': totalTokens,
      'daily_limit': dailyLimit,
      'total_consumed_today': totalConsumedToday,
      'user_plan': userPlan.name,
      'last_reset': lastReset.toIso8601String(),
      'next_reset_time': nextResetTime.toIso8601String(),
      'authentication_type': authenticationType.name,
      'is_premium': isPremium,
      'unlimited_usage': unlimitedUsage,
      'can_purchase_tokens': canPurchaseTokens,
      'plan_description': planDescription,
    };
  }

  /// Convert to domain entity
  TokenStatus toEntity() {
    return TokenStatus(
      availableTokens: availableTokens,
      purchasedTokens: purchasedTokens,
      totalTokens: totalTokens,
      dailyLimit: dailyLimit,
      totalConsumedToday: totalConsumedToday,
      userPlan: userPlan,
      lastReset: lastReset,
      nextResetTime: nextResetTime,
      authenticationType: authenticationType,
      isPremium: isPremium,
      unlimitedUsage: unlimitedUsage,
      canPurchaseTokens: canPurchaseTokens,
      planDescription: planDescription,
    );
  }

  /// Create from domain entity
  factory TokenStatusModel.fromEntity(TokenStatus entity) {
    return TokenStatusModel(
      availableTokens: entity.availableTokens,
      purchasedTokens: entity.purchasedTokens,
      totalTokens: entity.totalTokens,
      dailyLimit: entity.dailyLimit,
      totalConsumedToday: entity.totalConsumedToday,
      userPlan: entity.userPlan,
      lastReset: entity.lastReset,
      nextResetTime: entity.nextResetTime,
      authenticationType: entity.authenticationType,
      isPremium: entity.isPremium,
      unlimitedUsage: entity.unlimitedUsage,
      canPurchaseTokens: entity.canPurchaseTokens,
      planDescription: entity.planDescription,
    );
  }

  @override
  String toString() => 'TokenStatusModel('
      'availableTokens: $availableTokens, '
      'purchasedTokens: $purchasedTokens, '
      'totalTokens: $totalTokens, '
      'userPlan: $userPlan, '
      'isPremium: $isPremium'
      ')';
}
