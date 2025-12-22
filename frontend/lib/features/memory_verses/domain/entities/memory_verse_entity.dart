import 'package:equatable/equatable.dart';
import 'practice_mode_entity.dart';

/// Sentinel class for copyWith method to distinguish between null and unset values.
///
/// This is used internally by MemoryVerseEntity.copyWith and MemoryVerseModel.copyWith
/// to allow callers to explicitly pass null to clear nullable fields.
class CopyWithSentinel {
  const CopyWithSentinel();
}

/// Sentinel constant used in copyWith to detect when a parameter is not provided.
///
/// Used to distinguish between:
/// - Parameter not provided (use current value)
/// - Parameter explicitly set to null (clear the field)
/// - Parameter set to a new value (update the field)
const unsetValue = CopyWithSentinel();

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

  /// Cached comprehensive mastery status from backend
  /// Updated via database trigger when practice sessions are submitted
  final bool isFullyMasteredCached;

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
    this.isFullyMasteredCached = false,
  });

  /// Checks if the verse is due for review (next review date has passed)
  bool get isDue => DateTime.now().isAfter(nextReviewDate);

  /// Checks if the verse is mastered (repetitions >= 5 successful reviews)
  ///
  /// **Note**: This is a simplified mastery check based only on SM-2 repetitions.
  /// For comprehensive mastery criteria, use [isFullyMastered] which requires
  /// practice mode mastery and spaced review intervals.
  bool get isMastered => repetitions >= 5;

  /// Checks if the verse is fully mastered with comprehensive criteria v2.0 (stricter).
  ///
  /// **IMPORTANT**: Prefer using [isFullyMasteredCached] field which is calculated and
  /// cached by the backend with complete criteria including total reviews and success rate.
  /// This method provides client-side validation but cannot check all backend criteria.
  ///
  /// **Enhanced Mastery Requirements v2.0 (Stricter):**
  /// 1. At least 6 different practice modes mastered (80%+ over 8+ practices each)
  /// 2. Both hard modes mastered (Audio AND Type It Out with 80%+ over 8+ practices)
  /// 3. Reviews spaced over at least 21 days (intervalDays >= 21)
  /// 4. At least 8 consecutive successful SM-2 reviews (repetitions >= 8)
  ///
  /// **Additional backend-only criteria** (not checkable here):
  /// 5. Total reviews >= 20 (from total_reviews field)
  /// 6. Successful reviews >= 15 (75%+ success rate from review_sessions table)
  /// 7. Days since added >= 60 (2+ months elapsed since verse was added)
  ///
  /// **Edge Cases:**
  /// - Returns `false` if `practiceModes` is empty or contains invalid data
  /// - Returns `false` if fewer than 6 unique modes have been practiced
  /// - Requires ALL criteria to be met simultaneously
  /// - Duplicate modes are automatically deduplicated using Set
  ///
  /// **Parameters:**
  /// - [practiceModes] - List of practice mode entities with performance stats.
  ///                     Must contain unique modes with valid statistics.
  ///
  /// **Returns:**
  /// - `true` if ALL client-checkable mastery criteria are met
  /// - `false` if ANY criterion fails or input is invalid
  ///
  /// **Example:**
  /// ```dart
  /// // Prefer using the cached backend value:
  /// if (verse.isFullyMasteredCached) {
  ///   print('Verse fully mastered (verified by backend)!');
  /// }
  ///
  /// // Or for client-side validation (incomplete check):
  /// final modes = await repository.getPracticeModeStatistics(verseId);
  /// final isFullyMastered = verse.isFullyMastered(modes);
  /// ```
  bool isFullyMastered(List<PracticeModeEntity> practiceModes) {
    // Input validation: Check for empty list
    if (practiceModes.isEmpty) return false;

    // Criterion 1: SM-2 consecutive successful reviews (must have 8+ repetitions)
    if (repetitions < 8) return false;

    // Criterion 2: Review interval (reviews must be spaced over at least 21 days / 3 weeks)
    if (intervalDays < 21) return false;

    // Criterion 3: Count unique mastered modes (80%+ success rate over 8+ practices)
    // Use Set to ensure uniqueness and prevent duplicate mode counting
    // Note: isMastered checks times_practiced >= 8 and success_rate >= 80
    final uniqueMasteredModes = practiceModes
        .where((mode) => mode.isMastered)
        .map((mode) => mode.modeType)
        .toSet();

    if (uniqueMasteredModes.length < 6) return false;

    // Criterion 4: Both hard modes mastered (Audio AND Type It Out)
    // Count unique hard modes that are mastered
    final masteredHardModes = practiceModes
        .where((mode) => mode.isMastered && mode.difficulty == Difficulty.hard)
        .map((mode) => mode.modeType)
        .toSet();

    if (masteredHardModes.length < 2) return false;

    // All client-checkable criteria met
    // Note: Backend also checks total_reviews >= 20, successful_reviews >= 15, days >= 60
    return true;
  }

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

  /// Creates a copy of this entity with updated fields.
  ///
  /// For nullable fields (sourceId, lastReviewed), you can:
  /// - Omit the parameter to keep the current value
  /// - Pass null explicitly to clear the field
  /// - Pass a new value to update the field
  ///
  /// Example:
  /// ```dart
  /// // Keep current sourceId
  /// verse.copyWith(verseText: 'New text');
  ///
  /// // Clear sourceId
  /// verse.copyWith(sourceId: null);
  ///
  /// // Update sourceId
  /// verse.copyWith(sourceId: 'new-id');
  /// ```
  MemoryVerseEntity copyWith({
    String? id,
    String? verseReference,
    String? verseText,
    String? language,
    String? sourceType,
    Object? sourceId = unsetValue,
    double? easeFactor,
    int? intervalDays,
    int? repetitions,
    DateTime? nextReviewDate,
    DateTime? addedDate,
    Object? lastReviewed = unsetValue,
    int? totalReviews,
    DateTime? createdAt,
    bool? isFullyMasteredCached,
  }) {
    return MemoryVerseEntity(
      id: id ?? this.id,
      verseReference: verseReference ?? this.verseReference,
      verseText: verseText ?? this.verseText,
      language: language ?? this.language,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId == unsetValue ? this.sourceId : sourceId as String?,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      addedDate: addedDate ?? this.addedDate,
      lastReviewed: lastReviewed == unsetValue
          ? this.lastReviewed
          : lastReviewed as DateTime?,
      totalReviews: totalReviews ?? this.totalReviews,
      createdAt: createdAt ?? this.createdAt,
      isFullyMasteredCached:
          isFullyMasteredCached ?? this.isFullyMasteredCached,
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
        isFullyMasteredCached,
      ];

  @override
  bool get stringify => true;
}
