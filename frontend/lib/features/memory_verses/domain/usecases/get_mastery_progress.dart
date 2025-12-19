import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/mastery_progress_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for loading mastery progress for a verse.
///
/// Fetches mastery level, percentage, modes mastered,
/// and perfect recall count for a specific verse.
class GetMasteryProgress {
  final MemoryVerseRepository repository;

  GetMasteryProgress(this.repository);

  /// Executes the use case.
  ///
  /// **Parameters:**
  /// - [verseId] - UUID of the verse
  ///
  /// **Returns:**
  /// - Right: MasteryProgressEntity with complete mastery data
  /// - Left: Failure if operation fails
  Future<Either<Failure, MasteryProgressEntity>> call({
    required String verseId,
  }) async {
    return await repository.getMasteryProgress(verseId: verseId);
  }
}
