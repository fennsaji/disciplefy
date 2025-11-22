import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for deleting a memory verse from the user's deck.
///
/// This use case removes a verse from the user's memory deck, including
/// all associated review sessions and history. This action is irreversible.
///
/// **Clean Architecture:**
/// - Domain layer use case (application business rules)
/// - Depends on repository interface (abstraction)
/// - No dependencies on data layer implementations
///
/// **Usage:**
/// ```dart
/// final useCase = DeleteVerse(repository);
/// final result = await useCase('verse-uuid');
///
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (_) => print('Verse deleted successfully'),
/// );
/// ```
class DeleteVerse {
  final MemoryVerseRepository repository;

  DeleteVerse(this.repository);

  /// Executes the use case to delete a memory verse.
  ///
  /// **Parameters:**
  /// - [verseId]: UUID of the memory verse to delete
  ///
  /// **Returns:**
  /// - `Right(Unit)` on successful deletion
  /// - `Left(ServerFailure)` if server error occurs
  /// - `Left(NetworkFailure)` if offline (operation may be queued)
  /// - `Left(NotFoundFailure)` if verse doesn't exist
  ///
  /// **Offline Behavior:**
  /// - If offline, the delete operation is queued for later sync
  /// - Returns NetworkFailure with code 'OFFLINE_QUEUED'
  /// - Verse is removed from local cache immediately
  ///
  /// **Side Effects:**
  /// - Removes verse from memory_verses table
  /// - Cascades to delete associated review_sessions
  /// - Updates review_history accordingly
  Future<Either<Failure, Unit>> call(String verseId) {
    return repository.deleteVerse(verseId);
  }
}
