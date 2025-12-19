import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/daily_goal_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for setting custom daily goal targets.
///
/// Updates user's preferred daily review and new verse targets.
class SetDailyGoalTargets {
  final MemoryVerseRepository repository;

  SetDailyGoalTargets(this.repository);

  /// Executes the use case.
  ///
  /// **Parameters:**
  /// - [targetReviews] - Number of reviews to complete daily (must be positive)
  /// - [targetNewVerses] - Number of new verses to add daily (must be non-negative)
  ///
  /// **Returns:**
  /// - Right: Updated DailyGoalEntity with new targets
  /// - Left: Failure if operation fails or validation fails
  Future<Either<Failure, DailyGoalEntity>> call({
    required int targetReviews,
    required int targetNewVerses,
  }) async {
    // Validate targets
    if (targetReviews < 1) {
      return const Left(ValidationFailure(
        message: 'Target reviews must be at least 1',
        code: 'INVALID_TARGET_REVIEWS',
      ));
    }

    if (targetNewVerses < 0) {
      return const Left(ValidationFailure(
        message: 'Target new verses cannot be negative',
        code: 'INVALID_TARGET_NEW_VERSES',
      ));
    }

    if (targetReviews > 100) {
      return const Left(ValidationFailure(
        message: 'Target reviews cannot exceed 100',
        code: 'TARGET_REVIEWS_TOO_HIGH',
      ));
    }

    if (targetNewVerses > 20) {
      return const Left(ValidationFailure(
        message: 'Target new verses cannot exceed 20',
        code: 'TARGET_NEW_VERSES_TOO_HIGH',
      ));
    }

    return await repository.setDailyGoalTargets(
      targetReviews: targetReviews,
      targetNewVerses: targetNewVerses,
    );
  }
}
