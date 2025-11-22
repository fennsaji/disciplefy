import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/fetched_verse_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for fetching verse text from the Bible API.
///
/// This use case retrieves the text of a Bible verse given its
/// book, chapter, and verse reference. It supports verse ranges
/// and multiple languages.
///
/// **Clean Architecture:**
/// - Domain layer use case (application business rules)
/// - Depends on repository interface (abstraction)
/// - No dependencies on data layer implementations
class FetchVerseText {
  final MemoryVerseRepository repository;

  FetchVerseText(this.repository);

  /// Executes the use case to fetch verse text from API.
  ///
  /// **Parameters:**
  /// - [book] - Book name (e.g., "John", "Genesis")
  /// - [chapter] - Chapter number
  /// - [verseStart] - Starting verse number
  /// - [verseEnd] - Optional ending verse for ranges
  /// - [language] - Language code ('en', 'hi', 'ml')
  ///
  /// **Returns:**
  /// - `Right(FetchedVerseEntity)` on success with verse text and localized reference
  /// - `Left(ServerFailure)` if verse not found or server error
  /// - `Left(NetworkFailure)` if network error
  Future<Either<Failure, FetchedVerseEntity>> call({
    required String book,
    required int chapter,
    required int verseStart,
    int? verseEnd,
    required String language,
  }) {
    return repository.fetchVerseText(
      book: book,
      chapter: chapter,
      verseStart: verseStart,
      verseEnd: verseEnd,
      language: language,
    );
  }
}
