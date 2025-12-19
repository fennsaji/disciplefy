import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/daily_goal_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for loading today's daily goal progress.
///
/// Fetches goal targets and completion status for the current day.
class GetDailyGoal {
  final MemoryVerseRepository repository;

  GetDailyGoal(this.repository);

  /// Executes the use case.
  ///
  /// **Returns:**
  /// - Right: DailyGoalEntity with today's targets and progress
  /// - Left: Failure if operation fails
  Future<Either<Failure, DailyGoalEntity>> call() async {
    return await repository.getDailyGoal();
  }
}
