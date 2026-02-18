import 'package:equatable/equatable.dart';

/// Usage statistics for a user
///
/// Contains daily token consumption, streak data, and plan information
/// Used for usage meter display and soft paywall triggers
///
/// Daily Limits:
/// - Free: 8 tokens/day
/// - Standard: 20 tokens/day
/// - Plus: 50 tokens/day
/// - Premium: Unlimited
class UsageStats extends Equatable {
  /// Tokens used today (resets daily)
  final int tokensUsed;

  /// Daily token limit for current plan
  final int tokensTotal;

  /// Tokens remaining today (-1 for unlimited)
  final int tokensRemaining;

  /// Usage percentage (0-100)
  final int percentage;

  /// Consecutive days of study activity
  final int streakDays;

  /// Current subscription plan code (free, standard, plus, premium)
  final String currentPlan;

  /// Whether user has unlimited tokens
  final bool isUnlimited;

  /// Threshold state for UI optimization
  final ThresholdState thresholdState;

  /// Date for this usage data (e.g., "2026-01-18")
  final String monthYear;

  const UsageStats({
    required this.tokensUsed,
    required this.tokensTotal,
    required this.tokensRemaining,
    required this.percentage,
    required this.streakDays,
    required this.currentPlan,
    required this.isUnlimited,
    required this.thresholdState,
    required this.monthYear,
  });

  @override
  List<Object?> get props => [
        tokensUsed,
        tokensTotal,
        tokensRemaining,
        percentage,
        streakDays,
        currentPlan,
        isUnlimited,
        thresholdState,
        monthYear,
      ];

  /// Check if usage is at or above a specific percentage
  bool isAtThreshold(int threshold) => percentage >= threshold;

  /// Check if user should see soft paywall
  bool shouldShowSoftPaywall(int threshold) {
    return !isUnlimited && isAtThreshold(threshold);
  }

  /// Get display text for tokens
  String get tokensDisplay {
    if (isUnlimited) return 'Unlimited';
    return '$tokensUsed / $tokensTotal';
  }
}

/// Threshold state for UI optimization
enum ThresholdState {
  normal,
  warning,
  critical;

  /// Get color indicator for UI
  bool get isWarning => this == ThresholdState.warning;
  bool get isCritical => this == ThresholdState.critical;
  bool get isNormal => this == ThresholdState.normal;
}
