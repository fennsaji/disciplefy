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
      availableTokens: data['available_tokens'] as int,
      purchasedTokens: data['purchased_tokens'] as int,
      totalTokens: data['total_tokens'] as int,
      dailyLimit: data['daily_limit'] as int,
      totalConsumedToday: data['total_consumed_today'] as int,
      userPlan: _parseUserPlan(data['user_plan'] as String),
      lastReset: DateTime.parse(data['last_reset'] as String),
      nextResetTime: DateTime.parse(data['next_reset_time'] as String),
      authenticationType: _parseAuthType(data['authentication_type'] as String),
      isPremium: data['is_premium'] as bool? ?? false,
      unlimitedUsage: data['unlimited_usage'] as bool? ?? false,
      canPurchaseTokens: data['can_purchase_tokens'] as bool? ?? false,
      planDescription: data['plan_description'] as String? ?? '',
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
