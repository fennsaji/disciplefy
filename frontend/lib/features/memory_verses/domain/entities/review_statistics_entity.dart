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

  /// Number of mastered verses (basic mastery: repetitions >= 5)
  final int masteredVerses;

  /// Number of fully mastered verses (comprehensive mastery criteria)
  final int fullyMasteredVerses;

  /// Daily review limit for the user's plan (-1 = unlimited)
  final int dailyReviewLimit;

  /// Number of distinct verses reviewed today
  final int distinctVersesReviewedToday;

  const ReviewStatisticsEntity({
    required this.totalVerses,
    required this.dueVerses,
    required this.reviewedToday,
    required this.upcomingReviews,
    required this.masteredVerses,
    required this.fullyMasteredVerses,
    this.dailyReviewLimit = -1,
    this.distinctVersesReviewedToday = 0,
  });

  /// Whether the user has reached their daily review limit
  bool get isDailyReviewLimitReached =>
      dailyReviewLimit != -1 && distinctVersesReviewedToday >= dailyReviewLimit;

  /// Remaining daily reviews (-1 = unlimited)
  int get remainingReviews => dailyReviewLimit == -1
      ? -1
      : (dailyReviewLimit - distinctVersesReviewedToday)
          .clamp(0, dailyReviewLimit);

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
    if (isDailyReviewLimitReached) {
      return 'You\'ve used all $dailyReviewLimit daily verse reviews. Upgrade for more!';
    }

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
    int? fullyMasteredVerses,
    int? dailyReviewLimit,
    int? distinctVersesReviewedToday,
  }) {
    return ReviewStatisticsEntity(
      totalVerses: totalVerses ?? this.totalVerses,
      dueVerses: dueVerses ?? this.dueVerses,
      reviewedToday: reviewedToday ?? this.reviewedToday,
      upcomingReviews: upcomingReviews ?? this.upcomingReviews,
      masteredVerses: masteredVerses ?? this.masteredVerses,
      fullyMasteredVerses: fullyMasteredVerses ?? this.fullyMasteredVerses,
      dailyReviewLimit: dailyReviewLimit ?? this.dailyReviewLimit,
      distinctVersesReviewedToday:
          distinctVersesReviewedToday ?? this.distinctVersesReviewedToday,
    );
  }

  @override
  List<Object?> get props => [
        totalVerses,
        dueVerses,
        reviewedToday,
        upcomingReviews,
        masteredVerses,
        fullyMasteredVerses,
        dailyReviewLimit,
        distinctVersesReviewedToday,
      ];

  @override
  bool get stringify => true;
}
