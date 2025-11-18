import 'package:equatable/equatable.dart';

/// Domain entity representing a single review session.
///
/// Records the user's performance on a specific memory verse review,
/// including the quality rating and resulting SM-2 algorithm state.
class ReviewSessionEntity extends Equatable {
  /// Unique identifier for the review session
  final String id;

  /// ID of the user who performed the review
  final String userId;

  /// ID of the memory verse that was reviewed
  final String memoryVerseId;

  /// Date and time when the review was performed
  final DateTime reviewDate;

  /// Quality rating given by the user (0-5 SM-2 scale)
  /// - 0: Complete blackout
  /// - 1: Incorrect response, correct answer seemed familiar
  /// - 2: Incorrect response, correct answer remembered
  /// - 3: Correct response, but required significant effort
  /// - 4: Correct response, after some hesitation
  /// - 5: Perfect recall
  final int qualityRating;

  /// New ease factor calculated after this review
  final double newEaseFactor;

  /// New interval in days calculated after this review
  final int newIntervalDays;

  /// New repetition count after this review
  final int newRepetitions;

  /// Optional: Time spent on this review in seconds
  final int? timeSpentSeconds;

  /// Timestamp when the session was created
  final DateTime createdAt;

  const ReviewSessionEntity({
    required this.id,
    required this.userId,
    required this.memoryVerseId,
    required this.reviewDate,
    required this.qualityRating,
    required this.newEaseFactor,
    required this.newIntervalDays,
    required this.newRepetitions,
    this.timeSpentSeconds,
    required this.createdAt,
  });

  /// Checks if the review was successful (quality rating >= 3)
  bool get wasSuccessful => qualityRating >= 3;

  /// Returns a user-friendly quality description
  String get qualityDescription {
    switch (qualityRating) {
      case 0:
        return 'Complete blackout';
      case 1:
        return 'Incorrect, but familiar';
      case 2:
        return 'Incorrect, but remembered';
      case 3:
        return 'Correct with difficulty';
      case 4:
        return 'Correct with hesitation';
      case 5:
        return 'Perfect recall';
      default:
        return 'Unknown';
    }
  }

  /// Returns a performance grade (A, B, C, D, F)
  String get performanceGrade {
    if (qualityRating == 5) return 'A';
    if (qualityRating == 4) return 'B';
    if (qualityRating == 3) return 'C';
    if (qualityRating == 2) return 'D';
    return 'F';
  }

  /// Creates a copy of this entity with updated fields
  ReviewSessionEntity copyWith({
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
    return ReviewSessionEntity(
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

  @override
  List<Object?> get props => [
        id,
        userId,
        memoryVerseId,
        reviewDate,
        qualityRating,
        newEaseFactor,
        newIntervalDays,
        newRepetitions,
        timeSpentSeconds,
        createdAt,
      ];

  @override
  bool get stringify => true;
}
