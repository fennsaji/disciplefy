import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/memory_verse_entity.dart';
import '../repositories/memory_verse_repository.dart';
import '../../../../core/utils/logger.dart';

/// Use case for submitting a review for a memory verse.
///
/// This use case processes a user's review of a memory verse, applying the
/// SM-2 spaced repetition algorithm to calculate the next review date and
/// update the verse's learning state (ease factor, interval, repetitions).
///
/// **Clean Architecture:**
/// - Domain layer use case (application business rules)
/// - Depends on repository interface (abstraction)
/// - No dependencies on data layer implementations
///
/// **SM-2 Algorithm:**
/// The quality rating determines how the verse's learning state evolves:
/// - Rating < 3: Resets interval to 1 day (verse needs re-learning)
/// - Rating >= 3: Increases interval based on ease factor
/// - Ease factor adjusts based on performance (higher rating = easier verse)
///
/// **Usage:**
/// ```dart
/// final useCase = SubmitReview(repository);
/// final result = await useCase(
///   memoryVerseId: 'verse-uuid',
///   qualityRating: 4,
///   timeSpentSeconds: 45,
/// );
///
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (updatedVerse) {
///     Logger.debug('Next review: ${updatedVerse.nextReviewDate}');
///     Logger.debug('New interval: ${updatedVerse.intervalDays} days');
///   },
/// );
/// ```
class SubmitReview {
  final MemoryVerseRepository repository;

  SubmitReview(this.repository);

  /// Executes the use case to submit a verse review.
  ///
  /// **Parameters:**
  /// - [memoryVerseId] - UUID of the memory verse being reviewed
  /// - [qualityRating] - Quality of recall on 0-5 scale (SM-2):
  ///   - 0: Complete blackout (couldn't recall at all)
  ///   - 1: Incorrect, but recognized verse when shown
  ///   - 2: Incorrect, but remembered some parts
  ///   - 3: Correct with significant difficulty
  ///   - 4: Correct with slight hesitation
  ///   - 5: Perfect recall, no hesitation
  /// - [timeSpentSeconds] - Optional time spent on this review (for analytics)
  ///
  /// **Returns:**
  /// - `Right(MemoryVerseEntity)` on success with updated SM-2 state:
  ///   - `easeFactor`: Adjusted difficulty (1.3-3.0)
  ///   - `intervalDays`: Days until next review (1, 6, or EF-based)
  ///   - `repetitions`: Consecutive successful reviews (resets to 0 if rating < 3)
  ///   - `nextReviewDate`: DateTime of next review
  ///   - `lastReviewed`: Updated to current DateTime
  ///   - `totalReviews`: Incremented review count
  /// - `Left(ServerFailure)` if verse not found or server error
  /// - `Left(NetworkFailure)` if offline (review queued for sync)
  ///
  /// **SM-2 State Updates:**
  /// ```
  /// Quality < 3 (Failed recall):
  ///   - intervalDays = 1
  ///   - repetitions = 0
  ///   - easeFactor adjusted down
  ///
  /// Quality >= 3 (Successful recall):
  ///   - repetitions += 1
  ///   - intervalDays = 1 (first), 6 (second), then EF-based
  ///   - easeFactor adjusted based on quality (min 1.3)
  /// ```
  ///
  /// **Offline Behavior:**
  /// - Review is queued in sync queue
  /// - Local cache is NOT updated (SM-2 calculation happens server-side)
  /// - Returns NetworkFailure with code 'OFFLINE_QUEUED'
  /// - When back online, sync processes queue and updates cache
  ///
  /// **Error Handling:**
  /// - Verse not found → ServerFailure with code 'VERSE_NOT_FOUND'
  /// - Invalid quality rating → ValidationFailure
  /// - Network error → NetworkFailure with review queued for sync
  Future<Either<Failure, MemoryVerseEntity>> call({
    required String memoryVerseId,
    required int qualityRating,
    int? timeSpentSeconds,
  }) {
    return repository.submitReview(
      memoryVerseId: memoryVerseId,
      qualityRating: qualityRating,
      timeSpentSeconds: timeSpentSeconds,
    );
  }
}
