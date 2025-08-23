import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../entities/study_topics_filter.dart';

/// Abstract repository for study topics operations.
///
/// This repository defines the contract for fetching topics with various
/// filtering, searching, and pagination capabilities.
abstract class StudyTopicsRepository {
  /// Fetches all study topics with optional filtering and pagination.
  ///
  /// [filter] - Filter criteria including categories, search, pagination
  /// [forceRefresh] - If true, bypasses cache and fetches fresh data
  ///
  /// Returns [Right] with topics list on success,
  /// [Left] with [Failure] on error.
  Future<Either<Failure, List<RecommendedGuideTopic>>> getAllTopics({
    StudyTopicsFilter filter = const StudyTopicsFilter(),
    bool forceRefresh = false,
  });

  /// Fetches available topic categories.
  ///
  /// [language] - Language code for localization (defaults to 'en')
  /// [forceRefresh] - If true, bypasses cache and fetches fresh data
  ///
  /// Returns [Right] with categories list on success,
  /// [Left] with [Failure] on error.
  Future<Either<Failure, List<String>>> getCategories({
    String language = 'en',
    bool forceRefresh = false,
  });

  /// Gets the total count of topics matching the filter.
  ///
  /// [filter] - Filter criteria for counting
  ///
  /// Returns [Right] with total count on success,
  /// [Left] with [Failure] on error.
  Future<Either<Failure, int>> getTopicsCount({
    StudyTopicsFilter filter = const StudyTopicsFilter(),
  });

  /// Clears all cached data.
  void clearCache();
}
