import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/memory_streak_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for using a streak freeze day.
///
/// Applies a freeze day to protect the streak on a missed day.
class UseStreakFreeze {
  final MemoryVerseRepository repository;

  UseStreakFreeze(this.repository);

  /// Executes the use case.
  ///
  /// **Parameters:**
  /// - [freezeDate] - Date to protect (must be yesterday or today)
  ///
  /// **Returns:**
  /// - Right: Updated MemoryStreakEntity with freeze applied
  /// - Left: Failure if operation fails or freeze cannot be applied
  Future<Either<Failure, MemoryStreakEntity>> call({
    required DateTime freezeDate,
  }) async {
    // Validate freeze date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final freezeDateOnly = DateTime(
      freezeDate.year,
      freezeDate.month,
      freezeDate.day,
    );

    if (freezeDateOnly != today && freezeDateOnly != yesterday) {
      return const Left(ValidationFailure(
        message: 'Freeze day can only be used for yesterday or today',
        code: 'INVALID_FREEZE_DATE',
      ));
    }

    return await repository.useStreakFreeze(freezeDate: freezeDate);
  }
}
