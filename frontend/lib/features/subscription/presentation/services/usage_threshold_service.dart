import 'package:flutter/material.dart';
import '../widgets/soft_paywall_dialog.dart';

/// Service for tracking and triggering soft paywall dialogs at usage thresholds
///
/// Thresholds: 80% and 100% of daily token usage
/// Prevents showing the same threshold multiple times per day
/// Automatically resets when a new day starts, tracked internally via currentDate
class UsageThresholdService {
  // Track which thresholds have been shown today
  final Set<int> _shownThresholds = {};

  // Last usage percentage checked (to detect increases only)
  int _lastPercentage = 0;

  // Track the last date we checked (format: "2026-01-18")
  // Stored here (not in widget state) so it survives widget rebuilds
  String? _lastCheckedDate;

  /// Check if a soft paywall should be shown based on current usage.
  ///
  /// Pass [currentDate] (e.g. from usageStats.monthYear) to enable automatic
  /// daily reset — the service resets itself when the date changes.
  ///
  /// Pass [purchasedTokens] so the dialog is suppressed when the user already
  /// has purchased tokens available (daily limit exhausted ≠ truly out of tokens).
  ///
  /// Returns true if a dialog was shown, false otherwise.
  Future<bool> checkAndShowThreshold({
    required BuildContext context,
    required int tokensUsed,
    required int tokensTotal,
    int streakDays = 0,
    String userPlan = 'free',
    String? currentDate,
    int purchasedTokens = 0,
  }) async {
    // Don't show soft paywalls for invalid token totals or unlimited plans
    if (tokensTotal == 0 || tokensTotal == -1) return false;

    // Don't show if the user has purchased tokens — they already have capacity
    if (purchasedTokens > 0) return false;

    // Reset if it's a new day (date changed since last check)
    if (currentDate != null && currentDate != _lastCheckedDate) {
      _shownThresholds.clear();
      _lastPercentage = 0;
      _lastCheckedDate = currentDate;
    }

    final percentage = ((tokensUsed / tokensTotal) * 100).round();

    // Only trigger on increasing usage (not when it decreases due to reset/purchase)
    if (percentage <= _lastPercentage) {
      _lastPercentage = percentage;
      return false;
    }

    _lastPercentage = percentage;

    // Check thresholds in order: 100% then 80%
    int? thresholdToShow;

    if (percentage >= 100 && !_shownThresholds.contains(100)) {
      thresholdToShow = 100;
    } else if (percentage >= 80 && !_shownThresholds.contains(80)) {
      thresholdToShow = 80;
    }

    if (thresholdToShow != null && context.mounted) {
      _shownThresholds.add(thresholdToShow);

      final tokensRemaining = tokensTotal - tokensUsed;

      await SoftPaywallDialog.show(
        context,
        percentage: percentage,
        tokensRemaining: tokensRemaining,
        streakDays: streakDays,
        userPlan: userPlan,
      );

      return true;
    }

    return false;
  }

  /// Force-reset threshold tracking (e.g. on explicit app restart).
  /// Prefer passing [currentDate] to [checkAndShowThreshold] for automatic daily resets.
  void reset() {
    _shownThresholds.clear();
    _lastPercentage = 0;
    _lastCheckedDate = null;
  }

  /// Check if a specific threshold has been shown today
  bool hasShownThreshold(int threshold) {
    return _shownThresholds.contains(threshold);
  }
}
