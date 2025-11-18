import '../../domain/entities/review_session_entity.dart';

/// Data model for ReviewSession with JSON serialization.
///
/// Handles conversion between JSON (API/Hive) and domain entities.
class ReviewSessionModel extends ReviewSessionEntity {
  const ReviewSessionModel({
    required super.id,
    required super.userId,
    required super.memoryVerseId,
    required super.reviewDate,
    required super.qualityRating,
    required super.newEaseFactor,
    required super.newIntervalDays,
    required super.newRepetitions,
    super.timeSpentSeconds,
    required super.createdAt,
  });

  /// Creates a model from domain entity
  factory ReviewSessionModel.fromEntity(ReviewSessionEntity entity) {
    return ReviewSessionModel(
      id: entity.id,
      userId: entity.userId,
      memoryVerseId: entity.memoryVerseId,
      reviewDate: entity.reviewDate,
      qualityRating: entity.qualityRating,
      newEaseFactor: entity.newEaseFactor,
      newIntervalDays: entity.newIntervalDays,
      newRepetitions: entity.newRepetitions,
      timeSpentSeconds: entity.timeSpentSeconds,
      createdAt: entity.createdAt,
    );
  }

  /// Creates a model from JSON (API response or Hive)
  factory ReviewSessionModel.fromJson(Map<String, dynamic> json) {
    return ReviewSessionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      memoryVerseId: json['memory_verse_id'] as String,
      reviewDate: DateTime.parse(json['review_date'] as String),
      qualityRating: json['quality_rating'] as int,
      newEaseFactor: (json['new_ease_factor'] as num).toDouble(),
      newIntervalDays: json['new_interval_days'] as int,
      newRepetitions: json['new_repetitions'] as int,
      timeSpentSeconds: json['time_spent_seconds'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Converts model to JSON (for API requests or Hive storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'memory_verse_id': memoryVerseId,
      'review_date': reviewDate.toIso8601String(),
      'quality_rating': qualityRating,
      'new_ease_factor': newEaseFactor,
      'new_interval_days': newIntervalDays,
      'new_repetitions': newRepetitions,
      'time_spent_seconds': timeSpentSeconds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Converts model to entity (domain layer)
  ReviewSessionEntity toEntity() {
    return ReviewSessionEntity(
      id: id,
      userId: userId,
      memoryVerseId: memoryVerseId,
      reviewDate: reviewDate,
      qualityRating: qualityRating,
      newEaseFactor: newEaseFactor,
      newIntervalDays: newIntervalDays,
      newRepetitions: newRepetitions,
      timeSpentSeconds: timeSpentSeconds,
      createdAt: createdAt,
    );
  }

  /// Creates a copy with updated fields
  @override
  ReviewSessionModel copyWith({
    String? id,
    String? userId,
    String? memoryVerseId,
    DateTime? reviewDate,
    int? qualityRating,
    double? newEaseFactor,
    int? newIntervalDays,
    int? newRepetitions,
    int? timeSpentSeconds,
    DateTime? createdAt,
  }) {
    return ReviewSessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      memoryVerseId: memoryVerseId ?? this.memoryVerseId,
      reviewDate: reviewDate ?? this.reviewDate,
      qualityRating: qualityRating ?? this.qualityRating,
      newEaseFactor: newEaseFactor ?? this.newEaseFactor,
      newIntervalDays: newIntervalDays ?? this.newIntervalDays,
      newRepetitions: newRepetitions ?? this.newRepetitions,
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
