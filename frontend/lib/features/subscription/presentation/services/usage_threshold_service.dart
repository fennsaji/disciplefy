import 'package:flutter/material.dart';
import '../widgets/soft_paywall_dialog.dart';

/// Service for tracking and triggering soft paywall dialogs at usage thresholds
///
/// Thresholds: 30%, 50%, 80% of daily token usage
/// Prevents showing the same threshold multiple times per day
/// Resets automatically when a new day starts (called from home_screen.dart)
class UsageThresholdService {
  // Track which thresholds have been shown this session
  final Set<int> _shownThresholds = {};

  // Last usage percentage checked (to detect increases only)
  int _lastPercentage = 0;

  /// Check if a soft paywall should be shown based on current usage
  ///
  /// Returns true if dialog was shown, false otherwise
  Future<bool> checkAndShowThreshold({
    required BuildContext context,
    required int tokensUsed,
    required int tokensTotal,
    int streakDays = 0,
  }) async {
    // Don't show soft paywalls for invalid token totals or unlimited plans
    if (tokensTotal == 0 || tokensTotal == -1) return false;

    final percentage = ((tokensUsed / tokensTotal) * 100).round();

    // Only trigger on increasing usage (not when it decreases due to reset)
    if (percentage <= _lastPercentage) {
      _lastPercentage = percentage;
      return false;
    }

    _lastPercentage = percentage;

    // Check thresholds in order (30%, 50%, 80%)
    int? thresholdToShow;

    if (percentage >= 80 && !_shownThresholds.contains(80)) {
      thresholdToShow = 80;
    } else if (percentage >= 50 && !_shownThresholds.contains(50)) {
      thresholdToShow = 50;
    } else if (percentage >= 30 && !_shownThresholds.contains(30)) {
      thresholdToShow = 30;
    }

    if (thresholdToShow != null && context.mounted) {
      _shownThresholds.add(thresholdToShow);

      final tokensRemaining = tokensTotal - tokensUsed;

      await SoftPaywallDialog.show(
        context,
        percentage: percentage,
        tokensRemaining: tokensRemaining,
        streakDays: streakDays,
      );

      return true;
    }

    return false;
  }

  /// Reset threshold tracking (call on new day or app restart)
  void reset() {
    _shownThresholds.clear();
    _lastPercentage = 0;
  }

  /// Check if a specific threshold has been shown
  bool hasShownThreshold(int threshold) {
    return _shownThresholds.contains(threshold);
  }
}
