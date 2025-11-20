import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/memory_verse_entity.dart';
import '../entities/review_session_entity.dart';
import '../entities/review_statistics_entity.dart';

/// Repository interface for memory verse operations.
///
/// Defines the contract for accessing memory verse data.
/// Implementations handle data sources (Supabase API, Hive cache).
/// Follows Clean Architecture - domain layer defines interfaces.
abstract class MemoryVerseRepository {
  /// Adds a verse from Daily Verse to the memory deck
  ///
  /// [dailyVerseId] - UUID of the Daily Verse to add
  /// [language] - Optional language code ('en', 'hi', 'ml') - if not provided, auto-detects
  ///
  /// Returns the created MemoryVerseEntity on success, or Failure on error.
  Future<Either<Failure, MemoryVerseEntity>> addVerseFromDaily({
    required String dailyVerseId,
    String? language,
  });

  /// Adds a custom verse manually to the memory deck
  ///
  /// Returns the created MemoryVerseEntity on success, or Failure on error.
  Future<Either<Failure, MemoryVerseEntity>> addVerseManually({
    required String verseReference,
    required String verseText,
    String? language,
  });

  /// Fetches all verses that are due for review
  ///
  /// [limit] - Maximum number of verses to fetch (default: 20)
  /// [offset] - Number of verses to skip for pagination (default: 0)
  /// [language] - Optional language filter ('en', 'hi', 'ml')
  ///
  /// Returns a tuple of (verses, statistics) on success, or Failure on error.
  Future<Either<Failure, (List<MemoryVerseEntity>, ReviewStatisticsEntity)>>
      getDueVerses({
    int limit = 20,
    int offset = 0,
    String? language,
  });

  /// Submits a review for a memory verse
  ///
  /// [memoryVerseId] - ID of the verse being reviewed
  /// [qualityRating] - Quality rating (0-5 SM-2 scale)
  /// [timeSpentSeconds] - Optional time spent on review
  ///
  /// Returns updated MemoryVerseEntity on success, or Failure on error.
  Future<Either<Failure, MemoryVerseEntity>> submitReview({
    required String memoryVerseId,
    required int qualityRating,
    int? timeSpentSeconds,
  });

  /// Fetches review statistics for the user
  ///
  /// Returns ReviewStatisticsEntity on success, or Failure on error.
  Future<Either<Failure, ReviewStatisticsEntity>> getStatistics();

  /// Fetches a single memory verse by ID
  ///
  /// Returns MemoryVerseEntity on success, or Failure on error.
  Future<Either<Failure, MemoryVerseEntity>> getVerseById(String id);

  /// Fetches all memory verses (for backup/export)
  ///
  /// Returns list of all verses on success, or Failure on error.
  Future<Either<Failure, List<MemoryVerseEntity>>> getAllVerses();

  /// Deletes a memory verse
  ///
  /// Returns Unit (success) or Failure on error.
  Future<Either<Failure, Unit>> deleteVerse(String id);

  /// Fetches review history for a specific verse
  ///
  /// [memoryVerseId] - ID of the verse
  /// [limit] - Maximum number of sessions to fetch
  ///
  /// Returns list of ReviewSessionEntity on success, or Failure on error.
  Future<Either<Failure, List<ReviewSessionEntity>>> getReviewHistory({
    required String memoryVerseId,
    int limit = 50,
  });

  /// Syncs local cache with remote data
  ///
  /// Uploads pending local changes and downloads remote updates.
  /// Returns Unit (success) or Failure on error.
  Future<Either<Failure, Unit>> syncWithRemote();

  /// Clears local cache (for logout or data reset)
  ///
  /// Returns Unit (success) or Failure on error.
  Future<Either<Failure, Unit>> clearLocalCache();
}
