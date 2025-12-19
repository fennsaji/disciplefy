import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/daily_goal_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for updating daily goal progress after practice.
///
/// Increments review count or new verse count and checks
/// for goal completion with bonus XP award.
class UpdateDailyGoalProgress {
  final MemoryVerseRepository repository;

  UpdateDailyGoalProgress(this.repository);

  /// Executes the use case.
  ///
  /// **Parameters:**
  /// - [isNewVerse] - True if adding a new verse, false if reviewing
  ///
  /// **Returns:**
  /// - Right: Updated DailyGoalEntity with new progress
  /// - Left: Failure if operation fails
  Future<Either<Failure, DailyGoalEntity>> call({
    required bool isNewVerse,
  }) async {
    return await repository.updateDailyGoalProgress(isNewVerse: isNewVerse);
  }
}
