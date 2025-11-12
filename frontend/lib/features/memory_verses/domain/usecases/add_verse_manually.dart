import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/memory_verse_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for manually adding a custom verse to the memory deck.
///
/// This use case allows users to add any Bible verse they want to memorize,
/// even if it's not from the Daily Verse feature. The verse is validated
/// and added to the memory deck with initial SM-2 state for review.
///
/// **Clean Architecture:**
/// - Domain layer use case (application business rules)
/// - Depends on repository interface (abstraction)
/// - No dependencies on data layer implementations
///
/// **Usage:**
/// ```dart
/// final useCase = AddVerseManually(repository);
/// final result = await useCase(
///   verseReference: 'John 3:16',
///   verseText: 'For God so loved the world...',
///   language: 'en',
/// );
///
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (verse) => print('Added: ${verse.verseReference}'),
/// );
/// ```
class AddVerseManually {
  final MemoryVerseRepository repository;

  AddVerseManually(this.repository);

  /// Executes the use case to add a custom verse to memory deck.
  ///
  /// **Parameters:**
  /// - [verseReference] - Bible verse reference (e.g., "John 3:16")
  /// - [verseText] - Full text of the verse to memorize
  /// - [language] - Optional language code ('en', 'hi', 'ml'). Defaults to 'en'
  ///
  /// **Returns:**
  /// - `Right(MemoryVerseEntity)` on success with the newly created memory verse
  /// - `Left(ValidationFailure)` if inputs are invalid (reference/text too short/long)
  /// - `Left(ServerFailure)` if verse already exists or server error
  /// - `Left(NetworkFailure)` if offline (operation queued for sync)
  ///
  /// **Validation Rules:**
  /// - Verse reference: 3-100 characters
  /// - Verse text: 10-500 characters
  /// - Language: Must be 'en', 'hi', or 'ml'
  ///
  /// **Behavior:**
  /// 1. Validates input parameters
  /// 2. Creates memory verse with initial SM-2 state (ease: 2.5, interval: 1)
  /// 3. Caches locally for offline access
  /// 4. Returns the created memory verse entity
  ///
  /// **Error Handling:**
  /// - Duplicate verse → ServerFailure with code 'VERSE_ALREADY_EXISTS'
  /// - Invalid inputs → ValidationFailure
  /// - Network error → NetworkFailure with operation queued for sync
  Future<Either<Failure, MemoryVerseEntity>> call({
    required String verseReference,
    required String verseText,
    String? language,
  }) {
    return repository.addVerseManually(
      verseReference: verseReference,
      verseText: verseText,
      language: language,
    );
  }
}
