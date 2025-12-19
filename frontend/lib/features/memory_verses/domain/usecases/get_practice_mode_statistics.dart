import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/practice_mode_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for loading practice mode statistics for user.
///
/// Fetches all practice mode performance data including success rates,
/// times practiced, and favorite modes.
class GetPracticeModeStatistics {
  final MemoryVerseRepository repository;

  GetPracticeModeStatistics(this.repository);

  /// Executes the use case.
  ///
  /// **Returns:**
  /// - Right: List of PracticeModeEntity with statistics for all modes
  /// - Left: Failure if operation fails
  Future<Either<Failure, List<PracticeModeEntity>>> call() async {
    return await repository.getPracticeModeStatistics();
  }
}
