import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/memory_verse_repository.dart';
import '../../../../core/utils/logger.dart';

/// Use case for fetching comprehensive memory verse statistics.
///
/// This use case retrieves detailed statistics about the user's memory verse
/// practice including:
/// - Activity heat map data (12 weeks)
/// - Current and longest practice streaks
/// - Mastery level distribution (Beginner → Master)
/// - Practice mode statistics and success rates
/// - Overall statistics (total verses, reviews, perfect recalls, practice days)
///
/// **Clean Architecture:**
/// - Domain layer use case (application business rules)
/// - Depends on repository interface (abstraction)
/// - No dependencies on data layer implementations
///
/// **Usage:**
/// ```dart
/// final useCase = GetMemoryStatistics(repository);
/// final result = await useCase();
///
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (stats) {
///     Logger.debug('Total verses: ${stats['total_verses']}');
///     Logger.debug('Current streak: ${stats['current_streak']}');
///     Logger.debug('Mastery distribution: ${stats['mastery_distribution']}');
///   },
/// );
/// ```
class GetMemoryStatistics {
  final MemoryVerseRepository repository;

  GetMemoryStatistics(this.repository);

  /// Executes the use case to fetch comprehensive memory statistics.
  ///
  /// **Returns:**
  /// - `Right(Map<String, dynamic>)` on success with:
  ///   - `activity_data`: Map of dates to review counts (12-week heat map)
  ///   - `current_streak`: Current consecutive practice days
  ///   - `longest_streak`: Longest streak ever achieved
  ///   - `total_practice_days`: Total unique days practiced
  ///   - `mastery_distribution`: Count of verses per mastery level
  ///   - `practice_modes`: List of practice mode statistics
  ///   - `total_verses`: Total memory verses
  ///   - `total_reviews`: Total review sessions
  ///   - `perfect_recalls`: Number of quality=5 reviews
  ///
  /// - `Left(ServerFailure)` if server error occurs
  /// - `Left(NetworkFailure)` if offline and no cached data
  /// - `Left(AuthFailure)` if authentication is required
  ///
  /// **Performance Note:**
  /// - This endpoint fetches comprehensive statistics in a single API call
  /// - Response is cached for 60 seconds on the backend
  /// - Client-side caching recommended for dashboard displays
  ///
  /// **Error Handling:**
  /// - Network error + empty cache → NetworkFailure with 'CACHE_EMPTY'
  /// - Server error → ServerFailure with appropriate error code
  /// - Authentication error → AuthFailure with 401 code
  Future<Either<Failure, Map<String, dynamic>>> call() {
    return repository.getMemoryStatistics();
  }
}
