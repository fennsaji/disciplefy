import 'package:equatable/equatable.dart';

/// Sentinel class for copyWith method to distinguish between null and unset values.
const unsetValue = _CopyWithSentinel();

class _CopyWithSentinel {
  const _CopyWithSentinel();
}

/// Domain entity representing a user's memory verse practice streak.
///
/// Tracks daily practice consistency with freeze day protection mechanics.
/// Separate from the general study streak to encourage focused memory practice.
class MemoryStreakEntity extends Equatable {
  /// Current active streak in days
  final int currentStreak;

  /// Longest streak ever achieved
  final int longestStreak;

  /// Date of last practice session (null if never practiced)
  final DateTime? lastPracticeDate;

  /// Total number of days practiced (lifetime count)
  final int totalPracticeDays;

  /// Number of freeze days available to protect streak
  /// Earned by practicing 5+ days in a week, max 5 stored
  final int freezeDaysAvailable;

  /// Total number of freeze days used (lifetime count)
  final int freezeDaysUsed;

  /// Map of milestone day counts to achievement dates
  /// Example: {10: DateTime(...), 30: DateTime(...), 100: null, 365: null}
  /// Null value means milestone not yet reached
  final Map<int, DateTime?> milestones;

  const MemoryStreakEntity({
    required this.currentStreak,
    required this.longestStreak,
    this.lastPracticeDate,
    required this.totalPracticeDays,
    required this.freezeDaysAvailable,
    required this.freezeDaysUsed,
    required this.milestones,
  });

  /// Standard milestone thresholds (in days)
  static const List<int> standardMilestones = [10, 30, 100, 365];

  /// Maximum freeze days that can be stored
  static const int maxFreezeDays = 5;

  /// Minimum practices per week to earn a freeze day
  static const int practicesPerWeekForFreeze = 5;

  /// Checks if user has practiced today
  bool get isPracticedToday {
    if (lastPracticeDate == null) return false;

    final now = DateTime.now();
    final lastPractice = lastPracticeDate!;

    return now.year == lastPractice.year &&
        now.month == lastPractice.month &&
        now.day == lastPractice.day;
  }

  /// Checks if user can use a freeze day (has at least one available)
  bool get canUseFreeze => freezeDaysAvailable > 0;

  /// Checks if streak is at risk (not practiced today)
  bool get isStreakAtRisk {
    if (currentStreak == 0) return false;
    return !isPracticedToday;
  }

  /// Checks if streak would break tomorrow without practice or freeze
  bool get willBreakTomorrow {
    if (lastPracticeDate == null) return false;

    final now = DateTime.now();
    final lastPractice = lastPracticeDate!;
    final daysSinceLastPractice = now.difference(lastPractice).inDays;

    // Streak breaks if 2 days have passed without practice
    return daysSinceLastPractice >= 1 && !isPracticedToday;
  }

  /// Returns the next milestone day count to achieve
  /// Returns null if all milestones reached
  int? get nextMilestone {
    for (final milestone in standardMilestones) {
      if (currentStreak < milestone) {
        return milestone;
      }
    }
    return null; // All milestones reached
  }

  /// Returns days remaining until next milestone
  /// Returns null if all milestones reached
  int? get daysUntilNextMilestone {
    final next = nextMilestone;
    if (next == null) return null;
    return next - currentStreak;
  }

  /// Returns list of achieved milestone days
  List<int> get achievedMilestones {
    return milestones.entries
        .where((entry) => entry.value != null)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  /// Returns list of unachieved milestone days
  List<int> get unachievedMilestones {
    return milestones.entries
        .where((entry) => entry.value == null)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  /// Checks if a specific milestone has been achieved
  bool hasMilestone(int days) {
    return milestones[days] != null;
  }

  /// Returns formatted streak display (e.g., "15 days", "1 day")
  String get streakDisplay {
    if (currentStreak == 0) return 'No streak';
    if (currentStreak == 1) return '1 day';
    return '$currentStreak days';
  }

  /// Returns motivational message based on current streak
  String get motivationalMessage {
    if (currentStreak == 0) {
      return 'Start your practice streak today!';
    }

    if (currentStreak < 3) {
      return 'Great start! Keep the momentum going.';
    }

    if (currentStreak < 7) {
      return 'You\'re building a solid habit!';
    }

    if (currentStreak < 30) {
      return 'Impressive consistency! Keep it up.';
    }

    if (currentStreak < 100) {
      return 'Amazing dedication! You\'re a memory champion.';
    }

    return 'Extraordinary! You\'re an inspiration to others.';
  }

  /// Returns freeze day status message
  String get freezeDayStatus {
    if (freezeDaysAvailable == 0) {
      return 'No freeze days available. Practice 5+ days this week to earn one!';
    }

    if (freezeDaysAvailable == 1) {
      return '1 freeze day available to protect your streak.';
    }

    return '$freezeDaysAvailable freeze days available (max $maxFreezeDays).';
  }

  /// Returns message for next milestone
  String get nextMilestoneMessage {
    final next = nextMilestone;
    final daysUntil = daysUntilNextMilestone;

    if (next == null) {
      return 'All milestones achieved! You\'re a memory master.';
    }

    if (daysUntil == 1) {
      return 'Just 1 day until your $next-day milestone!';
    }

    return '$daysUntil days until your $next-day milestone!';
  }

  /// Returns progress percentage to next milestone (0.0 - 1.0)
  /// Returns 1.0 if all milestones achieved
  double get progressToNextMilestone {
    final next = nextMilestone;
    if (next == null) return 1.0;

    // Find the previous milestone
    int previousMilestone = 0;
    for (final milestone in standardMilestones) {
      if (milestone < next) {
        previousMilestone = milestone;
      } else {
        break;
      }
    }

    final range = next - previousMilestone;
    final progress = currentStreak - previousMilestone;

    return (progress / range).clamp(0.0, 1.0);
  }

  /// Returns color for streak flame icon based on streak length
  /// - 0-6 days: Grey (building)
  /// - 7-29 days: Orange (active)
  /// - 30-99 days: Gold (dedicated)
  /// - 100+ days: Purple (legendary)
  String get streakColorHex {
    if (currentStreak < 7) return '#9E9E9E'; // Grey
    if (currentStreak < 30) return '#FF9800'; // Orange
    if (currentStreak < 100) return '#FFD700'; // Gold
    return '#9C27B0'; // Purple
  }

  /// Checks if streak is considered "legendary" (100+ days)
  bool get isLegendaryStreak => currentStreak >= 100;

  /// Creates a copy of this entity with updated fields
  MemoryStreakEntity copyWith({
    int? currentStreak,
    int? longestStreak,
    Object? lastPracticeDate = unsetValue,
    int? totalPracticeDays,
    int? freezeDaysAvailable,
    int? freezeDaysUsed,
    Map<int, DateTime?>? milestones,
  }) {
    return MemoryStreakEntity(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastPracticeDate: lastPracticeDate == unsetValue
          ? this.lastPracticeDate
          : lastPracticeDate as DateTime?,
      totalPracticeDays: totalPracticeDays ?? this.totalPracticeDays,
      freezeDaysAvailable: freezeDaysAvailable ?? this.freezeDaysAvailable,
      freezeDaysUsed: freezeDaysUsed ?? this.freezeDaysUsed,
      milestones: milestones ?? this.milestones,
    );
  }

  @override
  List<Object?> get props => [
        currentStreak,
        longestStreak,
        lastPracticeDate,
        totalPracticeDays,
        freezeDaysAvailable,
        freezeDaysUsed,
        milestones,
      ];

  @override
  bool get stringify => true;
}
