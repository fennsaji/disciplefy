import 'package:equatable/equatable.dart';

/// Domain entity representing daily memory verse practice goals.
///
/// Tracks user's daily targets for reviews and new verses, providing
/// clear objectives and progress tracking to encourage consistent practice.
class DailyGoalEntity extends Equatable {
  /// Target number of reviews to complete today
  final int targetReviews;

  /// Number of reviews completed so far today
  final int completedReviews;

  /// Target number of new verses to add today
  final int targetNewVerses;

  /// Number of new verses added so far today
  final int addedNewVerses;

  /// Whether the daily goal has been fully achieved
  final bool goalAchieved;

  /// Bonus XP awarded for achieving the daily goal
  final int bonusXpAwarded;

  const DailyGoalEntity({
    required this.targetReviews,
    required this.completedReviews,
    required this.targetNewVerses,
    required this.addedNewVerses,
    required this.goalAchieved,
    required this.bonusXpAwarded,
  });

  /// Standard daily goal targets (can be customized by user)
  static const int defaultTargetReviews = 5;
  static const int defaultTargetNewVerses = 1;

  /// Standard bonus XP for completing daily goals
  static const int standardBonusXp = 50;

  /// Returns progress percentage for reviews (0.0 - 1.0)
  double get reviewsProgress {
    if (targetReviews == 0) return 1.0;
    return (completedReviews / targetReviews).clamp(0.0, 1.0);
  }

  /// Returns progress percentage for new verses (0.0 - 1.0)
  double get newVersesProgress {
    if (targetNewVerses == 0) return 1.0;
    return (addedNewVerses / targetNewVerses).clamp(0.0, 1.0);
  }

  /// Returns overall progress percentage (0.0 - 1.0)
  /// Weighted average: 70% reviews, 30% new verses
  double get overallProgress {
    // If target is 0 for both, consider fully complete
    if (targetReviews == 0 && targetNewVerses == 0) return 1.0;

    // Calculate weighted progress
    final reviewWeight = targetReviews > 0 ? 0.7 : 0.0;
    final newVerseWeight = targetNewVerses > 0 ? 0.3 : 0.0;

    // If only one target is set, give it full weight
    if (targetReviews == 0) {
      return newVersesProgress;
    }
    if (targetNewVerses == 0) {
      return reviewsProgress;
    }

    return (reviewsProgress * reviewWeight) +
        (newVersesProgress * newVerseWeight);
  }

  /// Checks if the goal is fully completed
  bool get isCompleted {
    final reviewsComplete = completedReviews >= targetReviews;
    final newVersesComplete = addedNewVerses >= targetNewVerses;
    return reviewsComplete && newVersesComplete;
  }

  /// Checks if reviews target is met
  bool get areReviewsComplete => completedReviews >= targetReviews;

  /// Checks if new verses target is met
  bool get areNewVersesComplete => addedNewVerses >= targetNewVerses;

  /// Returns number of reviews remaining
  int get reviewsRemaining =>
      (targetReviews - completedReviews).clamp(0, targetReviews);

  /// Returns number of new verses remaining
  int get newVersesRemaining =>
      (targetNewVerses - addedNewVerses).clamp(0, targetNewVerses);

  /// Returns motivational message based on progress
  String get motivationalMessage {
    if (isCompleted) {
      return 'Goal achieved! You earned $bonusXpAwarded bonus XP!';
    }

    final progressPercent = (overallProgress * 100).round();

    if (progressPercent >= 75) {
      return 'Almost there! Just a bit more to reach your goal.';
    }

    if (progressPercent >= 50) {
      return 'Halfway there! Keep up the great work.';
    }

    if (progressPercent >= 25) {
      return 'Good start! You\'re making steady progress.';
    }

    if (completedReviews > 0 || addedNewVerses > 0) {
      return 'Nice! Every practice session counts.';
    }

    return 'Ready to start? Let\'s achieve your daily goal!';
  }

  /// Returns summary of progress (e.g., "3/5 reviews, 1/1 new verses")
  String get progressSummary {
    final parts = <String>[];

    if (targetReviews > 0) {
      parts.add('$completedReviews/$targetReviews reviews');
    }

    if (targetNewVerses > 0) {
      parts.add('$addedNewVerses/$targetNewVerses new verses');
    }

    if (parts.isEmpty) {
      return 'No goals set';
    }

    return parts.join(', ');
  }

  /// Returns detailed progress description
  String get detailedProgress {
    final messages = <String>[];

    if (targetReviews > 0) {
      if (areReviewsComplete) {
        messages.add('✓ Reviews complete');
      } else {
        messages.add(
            '$reviewsRemaining review${reviewsRemaining == 1 ? "" : "s"} remaining');
      }
    }

    if (targetNewVerses > 0) {
      if (areNewVersesComplete) {
        messages.add('✓ New verses complete');
      } else {
        messages.add(
            '$newVersesRemaining new verse${newVersesRemaining == 1 ? "" : "s"} remaining');
      }
    }

    if (messages.isEmpty) {
      return 'No active goals';
    }

    return messages.join(' • ');
  }

  /// Returns call-to-action message based on what's remaining
  String get callToAction {
    if (isCompleted) {
      return 'Great job! Come back tomorrow for more practice.';
    }

    if (!areReviewsComplete && !areNewVersesComplete) {
      return 'Start your practice sessions to make progress!';
    }

    if (!areReviewsComplete) {
      return 'Review $reviewsRemaining more verse${reviewsRemaining == 1 ? "" : "s"} to complete your goal!';
    }

    if (!areNewVersesComplete) {
      return 'Add $newVersesRemaining more verse${newVersesRemaining == 1 ? "" : "s"} to complete your goal!';
    }

    return 'Keep going! You\'re doing great.';
  }

  /// Returns emoji indicator for progress level
  String get progressEmoji {
    if (isCompleted) return '🎉';

    final progressPercent = (overallProgress * 100).round();

    if (progressPercent >= 75) return '🔥';
    if (progressPercent >= 50) return '💪';
    if (progressPercent >= 25) return '👍';
    if (completedReviews > 0 || addedNewVerses > 0) return '✨';

    return '📚';
  }

  /// Checks if user is on track to complete goal (> 50% progress)
  bool get isOnTrack => overallProgress >= 0.5;

  /// Creates a copy of this entity with updated fields
  DailyGoalEntity copyWith({
    int? targetReviews,
    int? completedReviews,
    int? targetNewVerses,
    int? addedNewVerses,
    bool? goalAchieved,
    int? bonusXpAwarded,
  }) {
    return DailyGoalEntity(
      targetReviews: targetReviews ?? this.targetReviews,
      completedReviews: completedReviews ?? this.completedReviews,
      targetNewVerses: targetNewVerses ?? this.targetNewVerses,
      addedNewVerses: addedNewVerses ?? this.addedNewVerses,
      goalAchieved: goalAchieved ?? this.goalAchieved,
      bonusXpAwarded: bonusXpAwarded ?? this.bonusXpAwarded,
    );
  }

  @override
  List<Object?> get props => [
        targetReviews,
        completedReviews,
        targetNewVerses,
        addedNewVerses,
        goalAchieved,
        bonusXpAwarded,
      ];

  @override
  bool get stringify => true;
}
