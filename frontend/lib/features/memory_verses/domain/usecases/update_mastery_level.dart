import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/mastery_progress_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for updating mastery level for a verse.
///
/// Triggers recalculation and update of mastery level based on
/// recent performance and mode diversity.
class UpdateMasteryLevel {
  final MemoryVerseRepository repository;

  UpdateMasteryLevel(this.repository);

  /// Executes the use case.
  ///
  /// **Parameters:**
  /// - [verseId] - UUID of the verse
  /// - [newMasteryLevel] - New mastery level to set
  ///
  /// **Returns:**
  /// - Right: Updated MasteryProgressEntity
  /// - Left: Failure if operation fails
  Future<Either<Failure, MasteryProgressEntity>> call({
    required String verseId,
    required MasteryLevel newMasteryLevel,
  }) async {
    return await repository.updateMasteryLevel(
      verseId: verseId,
      newMasteryLevel: newMasteryLevel,
    );
  }
}
