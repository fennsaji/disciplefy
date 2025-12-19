import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/practice_mode_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for selecting a practice mode for a verse.
///
/// Loads practice mode statistics and sets the selected mode
/// for the upcoming practice session.
class SelectPracticeMode {
  final MemoryVerseRepository repository;

  SelectPracticeMode(this.repository);

  /// Executes the use case.
  ///
  /// **Parameters:**
  /// - [verseId] - UUID of the verse to practice
  /// - [practiceMode] - Selected practice mode type
  ///
  /// **Returns:**
  /// - Right: PracticeModeEntity with statistics
  /// - Left: Failure if operation fails
  Future<Either<Failure, PracticeModeEntity>> call({
    required String verseId,
    required PracticeModeType practiceMode,
  }) async {
    return await repository.selectPracticeMode(
      verseId: verseId,
      practiceMode: practiceMode,
    );
  }
}
