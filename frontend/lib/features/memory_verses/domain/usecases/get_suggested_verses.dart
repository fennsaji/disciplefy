import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/suggested_verse_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Parameters for fetching suggested verses
class GetSuggestedVersesParams {
  /// Optional category filter
  final SuggestedVerseCategory? category;

  /// Language code ('en', 'hi', 'ml')
  final String language;

  const GetSuggestedVersesParams({
    this.category,
    this.language = 'en',
  });
}

/// Use case for fetching suggested/popular Bible verses.
///
/// Retrieves curated verses organized by category that users can
/// browse and add to their memory deck.
class GetSuggestedVerses {
  final MemoryVerseRepository repository;

  GetSuggestedVerses(this.repository);

  /// Executes the use case.
  ///
  /// **Parameters:**
  /// - [params] - Optional filtering parameters (category, language)
  ///
  /// **Returns:**
  /// - Right: SuggestedVersesResponse with verses, categories, and total count
  /// - Left: Failure if operation fails
  Future<Either<Failure, SuggestedVersesResponse>> call({
    GetSuggestedVersesParams? params,
  }) async {
    return await repository.getSuggestedVerses(
      category: params?.category,
      language: params?.language ?? 'en',
    );
  }
}
