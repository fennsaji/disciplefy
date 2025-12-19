import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/memory_streak_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for loading memory streak data.
///
/// Fetches current streak, longest streak, milestones,
/// freeze days available, and practice history.
class GetMemoryStreak {
  final MemoryVerseRepository repository;

  GetMemoryStreak(this.repository);

  /// Executes the use case.
  ///
  /// **Returns:**
  /// - Right: MemoryStreakEntity with complete streak data
  /// - Left: Failure if operation fails
  Future<Either<Failure, MemoryStreakEntity>> call() async {
    return await repository.getMemoryStreak();
  }
}
