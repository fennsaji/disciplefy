import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/reset_progress_result.dart';
import '../repositories/learning_paths_repository.dart';

/// Use case for resetting all of the user's learning path progress.
///
/// This is irreversible. It clears every learning path enrollment, all topic
/// progress, the study streak, and the study/streak achievements. Because
/// leaderboard XP is derived from topic progress, the user's XP and rank
/// reset as a side effect.
///
/// **Usage:**
/// ```dart
/// final result = await sl<ResetLearningProgress>()();
///
/// result.fold(
///   (failure) => showError(failure.message),
///   (counts) => showSuccess(counts.totalAffected),
/// );
/// ```
class ResetLearningProgress {
  final LearningPathsRepository repository;

  ResetLearningProgress(this.repository);

  /// Executes the reset.
  ///
  /// **Returns:**
  /// - `Right(ResetProgressResult)` with the row counts that were removed
  /// - `Left(NetworkFailure)` if offline
  /// - `Left(RateLimitFailure)` if the hourly reset limit is hit
  /// - `Left(AuthenticationFailure)` if the session is invalid or a guest
  /// - `Left(ServerFailure)` on any other backend error
  Future<Either<Failure, ResetProgressResult>> call() =>
      repository.resetLearningProgress();
}
