import '../../domain/entities/review_statistics_entity.dart';

/// Data model for ReviewStatistics with JSON serialization.
///
/// Handles conversion between JSON (API response) and domain entities.
class ReviewStatisticsModel extends ReviewStatisticsEntity {
  const ReviewStatisticsModel({
    required super.totalVerses,
    required super.dueVerses,
    required super.reviewedToday,
    required super.upcomingReviews,
    required super.masteredVerses,
    required super.fullyMasteredVerses,
    super.dailyReviewLimit,
    super.distinctVersesReviewedToday,
  });

  /// Creates a model from domain entity
  factory ReviewStatisticsModel.fromEntity(ReviewStatisticsEntity entity) {
    return ReviewStatisticsModel(
      totalVerses: entity.totalVerses,
      dueVerses: entity.dueVerses,
      reviewedToday: entity.reviewedToday,
      upcomingReviews: entity.upcomingReviews,
      masteredVerses: entity.masteredVerses,
      fullyMasteredVerses: entity.fullyMasteredVerses,
      dailyReviewLimit: entity.dailyReviewLimit,
      distinctVersesReviewedToday: entity.distinctVersesReviewedToday,
    );
  }

  /// Creates a model from JSON (API response)
  factory ReviewStatisticsModel.fromJson(Map<String, dynamic> json) {
    return ReviewStatisticsModel(
      totalVerses: json['total_verses'] as int,
      dueVerses: json['due_verses'] as int,
      reviewedToday: json['reviewed_today'] as int,
      upcomingReviews: json['upcoming_reviews'] as int,
      masteredVerses: json['mastered_verses'] as int,
      fullyMasteredVerses: json['fully_mastered_verses'] as int,
      dailyReviewLimit: json['daily_review_limit'] as int? ?? -1,
      distinctVersesReviewedToday:
          json['distinct_verses_reviewed_today'] as int? ?? 0,
    );
  }

  /// Converts model to JSON
  Map<String, dynamic> toJson() {
    return {
      'total_verses': totalVerses,
      'due_verses': dueVerses,
      'reviewed_today': reviewedToday,
      'upcoming_reviews': upcomingReviews,
      'mastered_verses': masteredVerses,
      'fully_mastered_verses': fullyMasteredVerses,
      'daily_review_limit': dailyReviewLimit,
      'distinct_verses_reviewed_today': distinctVersesReviewedToday,
    };
  }

  /// Converts model to entity (domain layer)
  ReviewStatisticsEntity toEntity() {
    return ReviewStatisticsEntity(
      totalVerses: totalVerses,
      dueVerses: dueVerses,
      reviewedToday: reviewedToday,
      upcomingReviews: upcomingReviews,
      masteredVerses: masteredVerses,
      fullyMasteredVerses: fullyMasteredVerses,
      dailyReviewLimit: dailyReviewLimit,
      distinctVersesReviewedToday: distinctVersesReviewedToday,
    );
  }

  /// Creates a copy with updated fields
  @override
  ReviewStatisticsModel copyWith({
    int? totalVerses,
    int? dueVerses,
    int? reviewedToday,
    int? upcomingReviews,
    int? masteredVerses,
    int? fullyMasteredVerses,
    int? dailyReviewLimit,
    int? distinctVersesReviewedToday,
  }) {
    return ReviewStatisticsModel(
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
}
