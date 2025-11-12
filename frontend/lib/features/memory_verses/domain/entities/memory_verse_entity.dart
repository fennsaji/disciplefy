import 'package:equatable/equatable.dart';

/// Domain entity representing a memory verse in the spaced repetition system.
///
/// This is a pure domain model with no knowledge of data sources or UI.
/// Follows Clean Architecture principles - entities are business logic independent.
class MemoryVerseEntity extends Equatable {
  /// Unique identifier for the memory verse
  final String id;

  /// Bible verse reference (e.g., "John 3:16", "Philippians 4:13")
  final String verseReference;

  /// The actual verse text to memorize
  final String verseText;

  /// Language code ('en', 'hi', 'ml')
  final String language;

  /// Source type of the verse ('daily_verse', 'manual', 'ai_generated')
  final String sourceType;

  /// Optional source ID (links to daily_verses table if sourceType is 'daily_verse')
  final String? sourceId;

  /// SM-2 algorithm ease factor (1.3 - 3.0)
  final double easeFactor;

  /// SM-2 algorithm interval in days
  final int intervalDays;

  /// SM-2 algorithm repetition count
  final int repetitions;

  /// Next scheduled review date/time
  final DateTime nextReviewDate;

  /// Date when verse was added to memory deck
  final DateTime addedDate;

  /// Optional: Last time the verse was reviewed
  final DateTime? lastReviewed;

  /// Total number of times this verse has been reviewed
  final int totalReviews;

  /// Timestamp when the entity was created
  final DateTime createdAt;

  const MemoryVerseEntity({
    required this.id,
    required this.verseReference,
    required this.verseText,
    required this.language,
    required this.sourceType,
    this.sourceId,
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.nextReviewDate,
    required this.addedDate,
    this.lastReviewed,
    required this.totalReviews,
    required this.createdAt,
  });

  /// Checks if the verse is due for review (next review date has passed)
  bool get isDue => DateTime.now().isAfter(nextReviewDate);

  /// Checks if the verse is mastered (repetitions >= 5 successful reviews)
  bool get isMastered => repetitions >= 5;

  /// Checks if the verse is new (never successfully reviewed)
  bool get isNew => repetitions == 0;

  /// Returns the difficulty level based on ease factor
  /// - 'hard': easeFactor < 2.0
  /// - 'medium': easeFactor >= 2.0 && easeFactor < 2.5
  /// - 'easy': easeFactor >= 2.5
  String get difficultyLevel {
    if (easeFactor < 2.0) return 'hard';
    if (easeFactor < 2.5) return 'medium';
    return 'easy';
  }

  /// Returns how many days overdue the verse is (0 if not overdue)
  int get daysOverdue {
    if (!isDue) return 0;
    final now = DateTime.now();
    final difference = now.difference(nextReviewDate);
    return difference.inDays;
  }

  /// Returns a user-friendly status string
  String get statusDisplay {
    if (isDue) {
      if (daysOverdue > 0) {
        return 'Overdue by $daysOverdue ${daysOverdue == 1 ? "day" : "days"}';
      }
      return 'Due now';
    }

    if (isMastered) {
      return 'Mastered';
    }

    if (isNew) {
      return 'New';
    }

    return 'In progress';
  }

  /// Creates a copy of this entity with updated fields
  MemoryVerseEntity copyWith({
    String? id,
    String? verseReference,
    String? verseText,
    String? language,
    String? sourceType,
    String? sourceId,
    double? easeFactor,
    int? intervalDays,
    int? repetitions,
    DateTime? nextReviewDate,
    DateTime? addedDate,
    DateTime? lastReviewed,
    int? totalReviews,
    DateTime? createdAt,
  }) {
    return MemoryVerseEntity(
      id: id ?? this.id,
      verseReference: verseReference ?? this.verseReference,
      verseText: verseText ?? this.verseText,
      language: language ?? this.language,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      addedDate: addedDate ?? this.addedDate,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      totalReviews: totalReviews ?? this.totalReviews,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        verseReference,
        verseText,
        language,
        sourceType,
        sourceId,
        easeFactor,
        intervalDays,
        repetitions,
        nextReviewDate,
        addedDate,
        lastReviewed,
        totalReviews,
        createdAt,
      ];

  @override
  bool get stringify => true;
}
