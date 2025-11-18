import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/memory_verse_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for adding a verse from Daily Verse to the memory deck.
///
/// This use case encapsulates the business logic for converting a daily verse
/// into a memory verse for spaced repetition review. It delegates to the
/// repository which handles offline-first caching and API communication.
///
/// **Clean Architecture:**
/// - Domain layer use case (application business rules)
/// - Depends on repository interface (abstraction)
/// - No dependencies on data layer implementations
///
/// **Usage:**
/// ```dart
/// final useCase = AddVerseFromDaily(repository);
/// final result = await useCase('daily-verse-uuid');
///
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (verse) => print('Added: ${verse.verseReference}'),
/// );
/// ```
class AddVerseFromDaily {
  final MemoryVerseRepository repository;

  AddVerseFromDaily(this.repository);

  /// Executes the use case to add a Daily Verse to memory deck.
  ///
  /// **Parameters:**
  /// - [dailyVerseId] - UUID of the Daily Verse to add
  ///
  /// **Returns:**
  /// - `Right(MemoryVerseEntity)` on success with the newly created memory verse
  /// - `Left(ServerFailure)` if verse doesn't exist or server error occurs
  /// - `Left(NetworkFailure)` if offline (operation queued for sync)
  ///
  /// **Behavior:**
  /// 1. Validates daily verse exists
  /// 2. Creates memory verse with initial SM-2 state (ease: 2.5, interval: 1)
  /// 3. Caches locally for offline access
  /// 4. Returns the created memory verse entity
  ///
  /// **Error Handling:**
  /// - Duplicate verse → ServerFailure with code 'VERSE_ALREADY_EXISTS'
  /// - Daily verse not found → ServerFailure with code 'DAILY_VERSE_NOT_FOUND'
  /// - Network error → NetworkFailure with operation queued for sync
  Future<Either<Failure, MemoryVerseEntity>> call(String dailyVerseId) {
    return repository.addVerseFromDaily(dailyVerseId: dailyVerseId);
  }
}
