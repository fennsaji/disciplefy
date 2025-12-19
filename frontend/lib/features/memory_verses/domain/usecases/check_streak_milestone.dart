import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for checking streak milestone achievement.
///
/// Verifies if user reached 10, 30, 100, or 365-day milestone.
class CheckStreakMilestone {
  final MemoryVerseRepository repository;

  CheckStreakMilestone(this.repository);

  /// Executes the use case.
  ///
  /// **Returns:**
  /// - Right: Tuple of (milestone reached, milestone number or null)
  /// - Left: Failure if operation fails
  Future<Either<Failure, (bool, int?)>> call() async {
    return await repository.checkStreakMilestone();
  }
}
