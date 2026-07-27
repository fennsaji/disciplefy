import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/reset_progress_result.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for deleting the user's entire memory verse deck.
///
/// This is irreversible. It removes every verse along with all review
/// sessions, review history, mastery, practice-mode stats, collections,
/// daily goals, unlocked modes, memory challenge progress, memory badges,
/// and the memory streak. The local cache is emptied only after the server
/// confirms the delete.
///
/// **Usage:**
/// ```dart
/// final result = await sl<ResetMemoryProgress>()();
///
/// result.fold(
///   (failure) => showError(failure.message),
///   (counts) => showSuccess(counts.counts['verses_deleted'] ?? 0),
/// );
/// ```
class ResetMemoryProgress {
  final MemoryVerseRepository repository;

  ResetMemoryProgress(this.repository);

  /// Executes the reset.
  ///
  /// **Returns:**
  /// - `Right(ResetProgressResult)` with the row counts that were removed
  /// - `Left(NetworkFailure)` if offline — nothing is deleted locally
  /// - `Left(RateLimitFailure)` if the hourly reset limit is hit
  /// - `Left(AuthenticationFailure)` if the session is invalid or a guest
  /// - `Left(ServerFailure)` on any other backend error
  Future<Either<Failure, ResetProgressResult>> call() =>
      repository.resetMemoryProgress();
}
