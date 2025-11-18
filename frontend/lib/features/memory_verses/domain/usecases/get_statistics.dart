import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/review_statistics_entity.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for fetching memory verse review statistics.
///
/// This use case retrieves comprehensive statistics about the user's memory
/// verse progress, including total verses, due reviews, completion counts,
/// and mastery metrics. Used primarily for dashboard and progress displays.
///
/// **Clean Architecture:**
/// - Domain layer use case (application business rules)
/// - Depends on repository interface (abstraction)
/// - No dependencies on data layer implementations
///
/// **Implementation Note:**
/// Currently delegates to `getDueVerses(limit: 1)` to fetch statistics
/// without loading full verse list. Future optimization could add a dedicated
/// statistics-only API endpoint if performance becomes an issue.
///
/// **Usage:**
/// ```dart
/// final useCase = GetStatistics(repository);
/// final result = await useCase();
///
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (stats) {
///     print('Total verses: ${stats.totalVerses}');
///     print('Due now: ${stats.dueVerses}');
///     print('Mastery: ${stats.masteryPercentage.toStringAsFixed(1)}%');
///     print('Motivation: ${stats.motivationalMessage}');
///   },
/// );
/// ```
class GetStatistics {
  final MemoryVerseRepository repository;

  GetStatistics(this.repository);

  /// Executes the use case to fetch review statistics.
  ///
  /// **Returns:**
  /// - `Right(ReviewStatisticsEntity)` on success with:
  ///   - `totalVerses`: Total memory verses in user's deck
  ///   - `dueVerses`: Number of verses currently due for review
  ///   - `reviewedToday`: Number of verses reviewed in last 24 hours
  ///   - `upcomingReviews`: Number of verses due in next 7 days
  ///   - `masteredVerses`: Number of verses with repetitions >= 5
  ///
  /// - `Left(ServerFailure)` if server error occurs
  /// - `Left(NetworkFailure)` if offline and no cached data
  ///
  /// **Computed Properties:**
  /// The returned entity includes helpful computed properties:
  /// - `masteryPercentage`: (masteredVerses / totalVerses) * 100
  /// - `dailyGoalProgress`: reviewedToday / 10 (assumes daily goal of 10)
  /// - `motivationalMessage`: Context-aware encouragement message:
  ///   - "Great job! All reviews completed for today! 🎉" (no due, some reviewed)
  ///   - "Amazing! You've reached your daily goal! 💪" (10+ reviewed)
  ///   - "Keep it up! You're on a roll! 🔥" (5-9 reviewed)
  ///   - "Great start! Keep reviewing! 📚" (1-4 reviewed)
  ///   - "You have X verses waiting for review." (due verses pending)
  ///   - "No verses to review yet. Add your first verse!" (no verses)
  ///
  /// **Offline Behavior:**
  /// - Statistics are calculated from cached data
  /// - `reviewedToday` may be 0 (not tracked offline)
  /// - `upcomingReviews` may be 0 (not calculated offline)
  /// - Other metrics are accurate based on local cache
  ///
  /// **Performance Note:**
  /// - Current implementation fetches statistics as a side effect of getDueVerses()
  /// - This is efficient for the initial load when verses are needed anyway
  /// - For statistics-only views, consider adding a dedicated endpoint in future
  ///
  /// **Error Handling:**
  /// - Network error + empty cache → NetworkFailure with 'CACHE_EMPTY'
  /// - Server error → ServerFailure with appropriate error code
  Future<Either<Failure, ReviewStatisticsEntity>> call() {
    return repository.getStatistics();
  }
}
