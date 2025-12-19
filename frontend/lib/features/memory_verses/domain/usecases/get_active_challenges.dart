import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/memory_challenge_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for loading active challenges.
///
/// Fetches ongoing weekly/monthly challenges with
/// progress tracking and time remaining.
class GetActiveChallenges {
  final MemoryVerseRepository repository;

  GetActiveChallenges(this.repository);

  /// Executes the use case.
  ///
  /// **Returns:**
  /// - Right: List of active MemoryChallengeEntity with progress
  /// - Left: Failure if operation fails
  Future<Either<Failure, List<MemoryChallengeEntity>>> call() async {
    return await repository.getActiveChallenges();
  }
}
