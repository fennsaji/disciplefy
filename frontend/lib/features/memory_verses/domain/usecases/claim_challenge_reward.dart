import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/memory_challenge_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for claiming challenge reward.
///
/// Marks challenge as complete and awards XP bonus.
class ClaimChallengeReward {
  final MemoryVerseRepository repository;

  ClaimChallengeReward(this.repository);

  /// Executes the use case.
  ///
  /// **Parameters:**
  /// - [challengeId] - UUID of the challenge to claim
  ///
  /// **Returns:**
  /// - Right: Tuple of (updated challenge, XP earned)
  /// - Left: Failure if operation fails or challenge not completed
  Future<Either<Failure, (MemoryChallengeEntity, int)>> call({
    required String challengeId,
  }) async {
    return await repository.claimChallengeReward(challengeId: challengeId);
  }
}
