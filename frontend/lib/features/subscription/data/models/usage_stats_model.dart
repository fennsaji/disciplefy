import '../../domain/entities/usage_stats.dart';

/// Data model for usage statistics with JSON serialization
class UsageStatsModel extends UsageStats {
  const UsageStatsModel({
    required super.tokensUsed,
    required super.tokensTotal,
    required super.tokensRemaining,
    required super.percentage,
    required super.streakDays,
    required super.currentPlan,
    required super.isUnlimited,
    required super.thresholdState,
    required super.monthYear,
  });

  /// Create from JSON response
  factory UsageStatsModel.fromJson(Map<String, dynamic> json) {
    // Parse threshold state
    final thresholdStr = json['threshold_state'] as String? ?? 'normal';
    final thresholdState = ThresholdState.values.firstWhere(
      (e) => e.name == thresholdStr,
      orElse: () => ThresholdState.normal,
    );

    return UsageStatsModel(
      tokensUsed: json['tokens_used'] as int? ?? 0,
      tokensTotal: json['tokens_total'] as int? ?? 100,
      tokensRemaining: json['tokens_remaining'] as int? ?? 0,
      percentage: json['percentage'] as int? ?? 0,
      streakDays: json['streak_days'] as int? ?? 0,
      currentPlan: json['current_plan'] as String? ?? 'free',
      isUnlimited: json['is_unlimited'] as bool? ?? false,
      thresholdState: thresholdState,
      monthYear: json['month_year'] as String? ?? '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'tokens_used': tokensUsed,
      'tokens_total': tokensTotal,
      'tokens_remaining': tokensRemaining,
      'percentage': percentage,
      'streak_days': streakDays,
      'current_plan': currentPlan,
      'is_unlimited': isUnlimited,
      'threshold_state': thresholdState.name,
      'month_year': monthYear,
    };
  }

  /// Convert to domain entity
  UsageStats toEntity() {
    return UsageStats(
      tokensUsed: tokensUsed,
      tokensTotal: tokensTotal,
      tokensRemaining: tokensRemaining,
      percentage: percentage,
      streakDays: streakDays,
      currentPlan: currentPlan,
      isUnlimited: isUnlimited,
      thresholdState: thresholdState,
      monthYear: monthYear,
    );
  }
}
