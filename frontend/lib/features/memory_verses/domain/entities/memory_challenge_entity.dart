import 'package:equatable/equatable.dart';

/// Enum representing challenge duration types.
enum ChallengeType {
  daily,
  weekly,
  monthly,
}

/// Extension to convert ChallengeType to string and vice versa.
extension ChallengeTypeExtension on ChallengeType {
  /// Converts enum to string format matching database column
  String toJson() {
    switch (this) {
      case ChallengeType.daily:
        return 'daily';
      case ChallengeType.weekly:
        return 'weekly';
      case ChallengeType.monthly:
        return 'monthly';
    }
  }

  /// Parses string from database to enum
  static ChallengeType fromJson(String value) {
    switch (value) {
      case 'daily':
        return ChallengeType.daily;
      case 'weekly':
        return ChallengeType.weekly;
      case 'monthly':
        return ChallengeType.monthly;
      default:
        return ChallengeType.daily;
    }
  }
}

/// Enum representing the target metric for a challenge.
enum ChallengeTargetType {
  reviewsCount, // Complete X reviews
  newVerses, // Add X new verses
  masteryLevel, // Reach X mastery level
  perfectRecalls, // Achieve X perfect recalls (quality = 5)
  streakDays, // Maintain X day streak
  modesTried, // Try X different modes
}

/// Extension to convert ChallengeTargetType to string and vice versa.
extension ChallengeTargetTypeExtension on ChallengeTargetType {
  /// Converts enum to string format matching database column
  String toJson() {
    switch (this) {
      case ChallengeTargetType.reviewsCount:
        return 'reviews_count';
      case ChallengeTargetType.newVerses:
        return 'new_verses';
      case ChallengeTargetType.masteryLevel:
        return 'mastery_level';
      case ChallengeTargetType.perfectRecalls:
        return 'perfect_recalls';
      case ChallengeTargetType.streakDays:
        return 'streak_days';
      case ChallengeTargetType.modesTried:
        return 'modes_tried';
    }
  }

  /// Parses string from database to enum
  static ChallengeTargetType fromJson(String value) {
    switch (value) {
      case 'reviews_count':
        return ChallengeTargetType.reviewsCount;
      case 'new_verses':
        return ChallengeTargetType.newVerses;
      case 'mastery_level':
        return ChallengeTargetType.masteryLevel;
      case 'perfect_recalls':
        return ChallengeTargetType.perfectRecalls;
      case 'streak_days':
        return ChallengeTargetType.streakDays;
      case 'modes_tried':
        return ChallengeTargetType.modesTried;
      default:
        return ChallengeTargetType.reviewsCount;
    }
  }
}

/// Domain entity representing a memory verse challenge.
///
/// Challenges provide time-bound goals to encourage variety and engagement
/// in memory practice. Can be daily, weekly, or monthly with different
/// target types (reviews, streaks, mastery, etc.).
class MemoryChallengeEntity extends Equatable {
  /// Unique identifier for the challenge
  final String id;

  /// Challenge duration type (daily/weekly/monthly)
  final ChallengeType challengeType;

  /// Target metric type (reviews, streaks, mastery, etc.)
  final ChallengeTargetType targetType;

  /// Target value to achieve (e.g., 10 reviews, 7 days streak)
  final int targetValue;

  /// Current user progress toward target
  final int currentProgress;

  /// XP reward for completing the challenge
  final int xpReward;

  /// Badge icon identifier (e.g., "fire", "trophy", "star")
  final String badgeIcon;

  /// Challenge start date/time
  final DateTime startDate;

  /// Challenge end date/time
  final DateTime endDate;

  /// Whether the challenge has been completed by the user
  final bool isCompleted;

  const MemoryChallengeEntity({
    required this.id,
    required this.challengeType,
    required this.targetType,
    required this.targetValue,
    required this.currentProgress,
    required this.xpReward,
    required this.badgeIcon,
    required this.startDate,
    required this.endDate,
    required this.isCompleted,
  });

  /// Returns progress percentage (0.0 - 1.0)
  double get progressPercentage {
    if (targetValue == 0) return 1.0;
    return (currentProgress / targetValue).clamp(0.0, 1.0);
  }

  /// Returns time remaining until challenge ends
  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) {
      return Duration.zero;
    }
    return endDate.difference(now);
  }

  /// Checks if challenge is currently active (within start/end dates)
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// Checks if challenge has expired
  bool get isExpired {
    return DateTime.now().isAfter(endDate);
  }

  /// Checks if challenge hasn't started yet
  bool get isPending {
    return DateTime.now().isBefore(startDate);
  }

  /// Returns display text for the challenge
  String get displayText {
    final targetText = _getTargetDisplayText();
    return '$targetText by ${_getEndDateDisplay()}';
  }

  /// Returns short display text for compact UI
  String get shortDisplayText {
    return _getTargetDisplayText();
  }

  /// Helper: Returns formatted target text (e.g., "Complete 10 reviews")
  String _getTargetDisplayText() {
    switch (targetType) {
      case ChallengeTargetType.reviewsCount:
        return 'Complete $targetValue review${targetValue == 1 ? "" : "s"}';
      case ChallengeTargetType.newVerses:
        return 'Add $targetValue new verse${targetValue == 1 ? "" : "s"}';
      case ChallengeTargetType.masteryLevel:
        return 'Reach $targetValue verse${targetValue == 1 ? "" : "s"} at advanced mastery';
      case ChallengeTargetType.perfectRecalls:
        return 'Achieve $targetValue perfect recall${targetValue == 1 ? "" : "s"}';
      case ChallengeTargetType.streakDays:
        return 'Maintain $targetValue-day practice streak';
      case ChallengeTargetType.modesTried:
        return 'Try $targetValue different practice mode${targetValue == 1 ? "" : "s"}';
    }
  }

  /// Helper: Returns formatted end date display
  String _getEndDateDisplay() {
    switch (challengeType) {
      case ChallengeType.daily:
        return 'today';
      case ChallengeType.weekly:
        return 'this week';
      case ChallengeType.monthly:
        return 'this month';
    }
  }

  /// Returns formatted time remaining (e.g., "2d 5h", "3h 20m", "45m")
  String get formattedTimeRemaining {
    final remaining = timeRemaining;

    if (remaining == Duration.zero) {
      return 'Expired';
    }

    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h';
    }

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }

  /// Returns progress summary (e.g., "7/10 reviews")
  String get progressSummary {
    return '$currentProgress/$targetValue';
  }

  /// Returns detailed progress description
  String get detailedProgress {
    if (isCompleted) {
      return 'Challenge complete! Earned $xpReward XP.';
    }

    if (isExpired) {
      return 'Challenge expired. Better luck next time!';
    }

    final remaining = targetValue - currentProgress;
    final progressPercent = (progressPercentage * 100).round();

    if (progressPercent >= 90) {
      return 'Almost there! Just $remaining more to go.';
    }

    if (progressPercent >= 50) {
      return 'Halfway there! $remaining remaining.';
    }

    return '$remaining more needed. You can do it!';
  }

  /// Returns motivational message based on progress
  String get motivationalMessage {
    if (isCompleted) {
      return 'Challenge complete! Great work! 🎉';
    }

    if (isExpired) {
      return 'Time\'s up! Try the next challenge.';
    }

    final progressPercent = (progressPercentage * 100).round();

    if (progressPercent >= 75) {
      return 'So close! Finish strong! 💪';
    }

    if (progressPercent >= 50) {
      return 'Halfway there! Keep it up! 🔥';
    }

    if (progressPercent >= 25) {
      return 'Good progress! Stay consistent! ✨';
    }

    if (currentProgress > 0) {
      return 'Nice start! Keep going! 👍';
    }

    return 'Ready for the challenge? Let\'s go! 🚀';
  }

  /// Returns emoji indicator for challenge status
  String get statusEmoji {
    if (isCompleted) return '✅';
    if (isExpired) return '⏰';
    if (progressPercentage >= 0.75) return '🔥';
    if (progressPercentage >= 0.5) return '💪';
    if (currentProgress > 0) return '✨';
    return '📌';
  }

  /// Returns challenge type display name
  String get challengeTypeDisplay {
    switch (challengeType) {
      case ChallengeType.daily:
        return 'Daily Challenge';
      case ChallengeType.weekly:
        return 'Weekly Challenge';
      case ChallengeType.monthly:
        return 'Monthly Challenge';
    }
  }

  /// Returns target type display name
  String get targetTypeDisplay {
    switch (targetType) {
      case ChallengeTargetType.reviewsCount:
        return 'Reviews';
      case ChallengeTargetType.newVerses:
        return 'New Verses';
      case ChallengeTargetType.masteryLevel:
        return 'Mastery';
      case ChallengeTargetType.perfectRecalls:
        return 'Perfect Recalls';
      case ChallengeTargetType.streakDays:
        return 'Streak';
      case ChallengeTargetType.modesTried:
        return 'Practice Modes';
    }
  }

  /// Checks if user can claim XP reward (completed but not expired)
  bool get canClaimReward => isCompleted && !isExpired;

  /// Creates a copy of this entity with updated fields
  MemoryChallengeEntity copyWith({
    String? id,
    ChallengeType? challengeType,
    ChallengeTargetType? targetType,
    int? targetValue,
    int? currentProgress,
    int? xpReward,
    String? badgeIcon,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCompleted,
  }) {
    return MemoryChallengeEntity(
      id: id ?? this.id,
      challengeType: challengeType ?? this.challengeType,
      targetType: targetType ?? this.targetType,
      targetValue: targetValue ?? this.targetValue,
      currentProgress: currentProgress ?? this.currentProgress,
      xpReward: xpReward ?? this.xpReward,
      badgeIcon: badgeIcon ?? this.badgeIcon,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        challengeType,
        targetType,
        targetValue,
        currentProgress,
        xpReward,
        badgeIcon,
        startDate,
        endDate,
        isCompleted,
      ];

  @override
  bool get stringify => true;
}
