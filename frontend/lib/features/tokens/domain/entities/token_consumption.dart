import 'package:equatable/equatable.dart';
import 'token_status.dart';

/// Entity representing token consumption details from an API operation
class TokenConsumption extends Equatable {
  /// Number of tokens consumed in the operation
  final int consumed;

  /// Remaining token information after consumption
  final TokenRemaining remaining;

  /// Daily token limit for the user plan
  final int dailyLimit;

  /// User plan at the time of consumption
  final UserPlan userPlan;

  const TokenConsumption({
    required this.consumed,
    required this.remaining,
    required this.dailyLimit,
    required this.userPlan,
  });

  /// Create TokenConsumption from API response
  factory TokenConsumption.fromJson(Map<String, dynamic> json) {
    final remainingData =
        json['remaining'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return TokenConsumption(
      consumed: (json['consumed'] as num?)?.toInt() ?? 0,
      remaining: TokenRemaining.fromJson(remainingData),
      dailyLimit: (json['daily_limit'] as num?)?.toInt() ?? 50,
      userPlan: _parseUserPlan(json['user_plan'] as String? ?? 'free'),
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

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'consumed': consumed,
      'remaining': remaining.toJson(),
      'daily_limit': dailyLimit,
      'user_plan': userPlan.name,
    };
  }

  /// Check if consumption left user with low tokens
  bool get isRunningLow {
    return remaining.totalTokens < (dailyLimit * 0.25);
  }

  /// Check if user has no tokens left
  bool get isExhausted {
    return remaining.totalTokens == 0;
  }

  @override
  List<Object?> get props => [
        consumed,
        remaining,
        dailyLimit,
        userPlan,
      ];

  @override
  String toString() => 'TokenConsumption('
      'consumed: $consumed, '
      'remaining: ${remaining.totalTokens}, '
      'userPlan: $userPlan'
      ')';
}

/// Entity representing remaining token information
class TokenRemaining extends Equatable {
  /// Remaining daily allocation tokens
  final int availableTokens;

  /// Remaining purchased tokens
  final int purchasedTokens;

  /// Total remaining tokens (available + purchased)
  final int totalTokens;

  const TokenRemaining({
    required this.availableTokens,
    required this.purchasedTokens,
    required this.totalTokens,
  });

  /// Create TokenRemaining from API response
  factory TokenRemaining.fromJson(Map<String, dynamic> json) {
    return TokenRemaining(
      availableTokens: (json['available_tokens'] as num?)?.toInt() ?? 0,
      purchasedTokens: (json['purchased_tokens'] as num?)?.toInt() ?? 0,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'available_tokens': availableTokens,
      'purchased_tokens': purchasedTokens,
      'total_tokens': totalTokens,
    };
  }

  @override
  List<Object?> get props => [
        availableTokens,
        purchasedTokens,
        totalTokens,
      ];

  @override
  String toString() => 'TokenRemaining('
      'availableTokens: $availableTokens, '
      'purchasedTokens: $purchasedTokens, '
      'totalTokens: $totalTokens'
      ')';
}
