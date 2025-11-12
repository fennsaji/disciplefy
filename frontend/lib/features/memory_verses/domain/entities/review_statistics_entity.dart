import 'package:equatable/equatable.dart';

/// Domain entity representing aggregated review statistics.
///
/// Provides comprehensive analytics about the user's memory verse progress,
/// including counts, streaks, and performance metrics.
class ReviewStatisticsEntity extends Equatable {
  /// Total number of verses in the memory deck
  final int totalVerses;

  /// Number of verses currently due for review
  final int dueVerses;

  /// Number of reviews completed today
  final int reviewedToday;

  /// Number of reviews scheduled within the next 7 days
  final int upcomingReviews;

  /// Number of mastered verses (repetitions >= 5)
  final int masteredVerses;

  const ReviewStatisticsEntity({
    required this.totalVerses,
    required this.dueVerses,
    required this.reviewedToday,
    required this.upcomingReviews,
    required this.masteredVerses,
  });

  /// Percentage of verses that are mastered (0-100)
  double get masteryPercentage {
    if (totalVerses == 0) return 0.0;
    return (masteredVerses / totalVerses * 100);
  }

  /// Percentage of daily goal completed (assuming goal of 10 reviews/day)
  double get dailyGoalProgress {
    const dailyGoal = 10;
    return (reviewedToday / dailyGoal * 100).clamp(0.0, 100.0);
  }

  /// Number of verses in progress (not new, not mastered)
  int get inProgressVerses {
    return totalVerses - masteredVerses;
  }

  /// Checks if there are any verses due for review
  bool get hasDueVerses => dueVerses > 0;

  /// Checks if daily goal is reached
  bool get isDailyGoalReached => reviewedToday >= 10;

  /// Returns a motivational message based on progress
  String get motivationalMessage {
    if (dueVerses == 0 && reviewedToday > 0) {
      return 'Great job! All reviews completed for today! 🎉';
    }

    if (reviewedToday >= 10) {
      return 'Amazing! You\'ve reached your daily goal! 💪';
    }

    if (dueVerses > 10) {
      return 'You have $dueVerses verses waiting. Let\'s practice! 📖';
    }

    if (dueVerses > 0) {
      return 'You have $dueVerses ${dueVerses == 1 ? 'verse' : 'verses'} to review today.';
    }

    if (totalVerses == 0) {
      return 'Start your journey by adding your first verse! ✨';
    }

    return 'Keep up the great work! 🌟';
  }

  /// Creates a copy of this entity with updated fields
  ReviewStatisticsEntity copyWith({
    int? totalVerses,
    int? dueVerses,
    int? reviewedToday,
    int? upcomingReviews,
    int? masteredVerses,
  }) {
    return ReviewStatisticsEntity(
      totalVerses: totalVerses ?? this.totalVerses,
      dueVerses: dueVerses ?? this.dueVerses,
      reviewedToday: reviewedToday ?? this.reviewedToday,
      upcomingReviews: upcomingReviews ?? this.upcomingReviews,
      masteredVerses: masteredVerses ?? this.masteredVerses,
    );
  }

  @override
  List<Object?> get props => [
        totalVerses,
        dueVerses,
        reviewedToday,
        upcomingReviews,
        masteredVerses,
      ];

  @override
  bool get stringify => true;
}
