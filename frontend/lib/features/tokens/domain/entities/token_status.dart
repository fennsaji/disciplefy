import 'package:equatable/equatable.dart';

/// Enum representing different user plan types
enum UserPlan {
  free,
  standard,
  premium;

  String get displayName {
    switch (this) {
      case UserPlan.free:
        return 'Free';
      case UserPlan.standard:
        return 'Standard';
      case UserPlan.premium:
        return 'Premium';
    }
  }

  String get description {
    switch (this) {
      case UserPlan.free:
        return 'Anonymous users with 20 tokens daily';
      case UserPlan.standard:
        return 'Authenticated users with 100 tokens daily';
      case UserPlan.premium:
        return 'Premium users with unlimited tokens';
    }
  }

  bool get canPurchaseTokens => this == UserPlan.standard;
  bool get isUnlimited => this == UserPlan.premium;
}

/// Enum representing authentication types
enum AuthenticationType {
  anonymous,
  authenticated;

  String get displayName {
    switch (this) {
      case AuthenticationType.anonymous:
        return 'Anonymous';
      case AuthenticationType.authenticated:
        return 'Authenticated';
    }
  }
}

/// Entity representing the current token status for a user
class TokenStatus extends Equatable {
  /// Number of daily allocation tokens remaining
  final int availableTokens;

  /// Number of purchased tokens (never reset)
  final int purchasedTokens;

  /// Total tokens available (available + purchased)
  final int totalTokens;

  /// Maximum daily token limit for user's plan
  final int dailyLimit;

  /// Total tokens consumed today since last reset
  final int totalConsumedToday;

  /// User's subscription plan
  final UserPlan userPlan;

  /// Date of last daily reset
  final DateTime lastReset;

  /// Next scheduled reset time
  final DateTime nextResetTime;

  /// Type of authentication (anonymous or authenticated)
  final AuthenticationType authenticationType;

  /// Whether user has premium unlimited access
  final bool isPremium;

  /// Whether user has unlimited token usage
  final bool unlimitedUsage;

  /// Whether user can purchase additional tokens
  final bool canPurchaseTokens;

  /// Plan description text
  final String planDescription;

  const TokenStatus({
    required this.availableTokens,
    required this.purchasedTokens,
    required this.totalTokens,
    required this.dailyLimit,
    required this.totalConsumedToday,
    required this.userPlan,
    required this.lastReset,
    required this.nextResetTime,
    required this.authenticationType,
    required this.isPremium,
    required this.unlimitedUsage,
    required this.canPurchaseTokens,
    required this.planDescription,
  });

  /// Create a TokenStatus with updated values
  TokenStatus copyWith({
    int? availableTokens,
    int? purchasedTokens,
    int? totalTokens,
    int? dailyLimit,
    int? totalConsumedToday,
    UserPlan? userPlan,
    DateTime? lastReset,
    DateTime? nextResetTime,
    AuthenticationType? authenticationType,
    bool? isPremium,
    bool? unlimitedUsage,
    bool? canPurchaseTokens,
    String? planDescription,
  }) {
    return TokenStatus(
      availableTokens: availableTokens ?? this.availableTokens,
      purchasedTokens: purchasedTokens ?? this.purchasedTokens,
      totalTokens: totalTokens ?? this.totalTokens,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      totalConsumedToday: totalConsumedToday ?? this.totalConsumedToday,
      userPlan: userPlan ?? this.userPlan,
      lastReset: lastReset ?? this.lastReset,
      nextResetTime: nextResetTime ?? this.nextResetTime,
      authenticationType: authenticationType ?? this.authenticationType,
      isPremium: isPremium ?? this.isPremium,
      unlimitedUsage: unlimitedUsage ?? this.unlimitedUsage,
      canPurchaseTokens: canPurchaseTokens ?? this.canPurchaseTokens,
      planDescription: planDescription ?? this.planDescription,
    );
  }

  /// Calculate usage percentage (0.0 to 1.0)
  double get usagePercentage {
    if (isPremium || dailyLimit == 0) return 0.0;
    return (totalConsumedToday / dailyLimit).clamp(0.0, 1.0);
  }

  /// Check if tokens are running low (less than 25% remaining)
  bool get isRunningLow {
    if (isPremium) return false;
    return totalTokens < (dailyLimit * 0.25);
  }

  /// Check if user has sufficient tokens for an operation
  bool hasSufficientTokens(int required) {
    if (isPremium) return true;
    return totalTokens >= required;
  }

  /// Time remaining until next reset
  Duration get timeUntilReset {
    final now = DateTime.now();
    return nextResetTime.isAfter(now)
        ? nextResetTime.difference(now)
        : Duration.zero;
  }

  /// Format time until reset as human-readable string
  String get formattedTimeUntilReset {
    final duration = timeUntilReset;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return 'Soon';
    }
  }

  @override
  List<Object?> get props => [
        availableTokens,
        purchasedTokens,
        totalTokens,
        dailyLimit,
        totalConsumedToday,
        userPlan,
        lastReset,
        nextResetTime,
        authenticationType,
        isPremium,
        unlimitedUsage,
        canPurchaseTokens,
        planDescription,
      ];

  @override
  String toString() => 'TokenStatus('
      'availableTokens: $availableTokens, '
      'purchasedTokens: $purchasedTokens, '
      'totalTokens: $totalTokens, '
      'dailyLimit: $dailyLimit, '
      'userPlan: $userPlan, '
      'isPremium: $isPremium'
      ')';
}
