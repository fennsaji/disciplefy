import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/memory_verse_entity.dart';
import '../entities/review_statistics_entity.dart';
import '../repositories/memory_verse_repository.dart';
import '../../../../core/utils/logger.dart';

/// Use case for fetching verses that are due for review.
///
/// This use case retrieves all memory verses whose `next_review_date` has
/// passed, sorted by due date (most overdue first). It also returns statistics
/// about the user's memory verse progress for dashboard display.
///
/// **Clean Architecture:**
/// - Domain layer use case (application business rules)
/// - Depends on repository interface (abstraction)
/// - No dependencies on data layer implementations
///
/// **Offline-First:**
/// - Tries remote API first for fresh data
/// - Falls back to local cache if offline
/// - Returns cached statistics when offline
///
/// **Usage:**
/// ```dart
/// final useCase = GetDueVerses(repository);
/// final result = await useCase(limit: 10, offset: 0);
///
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (data) {
///     final (verses, stats) = data;
///     Logger.debug('Due verses: ${verses.length}');
///     Logger.debug('Total verses: ${stats.totalVerses}');
///   },
/// );
/// ```
class GetDueVerses {
  final MemoryVerseRepository repository;

  GetDueVerses(this.repository);

  /// Executes the use case to fetch due verses and statistics.
  ///
  /// **Parameters:**
  /// - [limit] - Maximum number of verses to fetch (default: 20)
  /// - [offset] - Number of verses to skip for pagination (default: 0)
  /// - [language] - Optional language filter ('en', 'hi', 'ml')
  ///
  /// **Returns:**
  /// - `Right((verses, statistics))` on success with:
  ///   - List of due memory verses sorted by next_review_date
  ///   - Statistics entity with counts and progress metrics
  /// - `Left(ServerFailure)` if server error occurs
  /// - `Left(NetworkFailure)` if offline and no cached data available
  ///
  /// **Returned Data:**
  /// - **Verses:** Ordered by most overdue first (earliest next_review_date)
  /// - **Statistics:** Contains:
  ///   - `totalVerses`: Total memory verses in deck
  ///   - `dueVerses`: Number of verses due for review
  ///   - `reviewedToday`: Verses reviewed in last 24 hours
  ///   - `upcomingReviews`: Verses due in next 7 days
  ///   - `masteredVerses`: Verses with repetitions >= 5
  ///
  /// **Offline Behavior:**
  /// - Uses cached verses filtered by next_review_date
  /// - Statistics may be approximate when offline:
  ///   - `totalVerses` = cached count
  ///   - `dueVerses` = cached due count
  ///   - `reviewedToday` = 0 (not tracked offline)
  ///   - `upcomingReviews` = 0 (not calculated offline)
  ///   - `masteredVerses` = cached count where repetitions >= 5
  ///
  /// **Error Handling:**
  /// - Network error + empty cache → NetworkFailure with 'CACHE_EMPTY'
  /// - Server error → ServerFailure with appropriate error code
  Future<Either<Failure, (List<MemoryVerseEntity>, ReviewStatisticsEntity)>>
      call({
    int limit = 20,
    int offset = 0,
    String? language,
  }) {
    return repository.getDueVerses(
      limit: limit,
      offset: offset,
      language: language,
    );
  }
}
