import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/learning_path.dart';

/// Repository interface for learning paths operations.
abstract class LearningPathsRepository {
  /// Get all available learning paths.
  ///
  /// [language] - The language for localized content (default: 'en')
  /// [includeEnrolled] - Whether to include paths user is already enrolled in
  /// [forceRefresh] - Whether to bypass cache and force refresh
  /// [limit] - Page size (default: 10)
  /// [offset] - Page offset (default: 0)
  Future<Either<Failure, LearningPathsResult>> getLearningPaths({
    String language = 'en',
    bool includeEnrolled = true,
    bool forceRefresh = false,
    int limit = 10,
    int offset = 0,
  });

  /// Get learning paths grouped by category (primary section listing).
  ///
  /// [language] - The language for localized content
  /// [includeEnrolled] - Whether to include paths user is already enrolled in
  /// [categoryLimit] - Number of categories per page (default: 4)
  /// [categoryOffset] - Page offset for categories (default: 0)
  /// [forceRefresh] - Whether to bypass cache and force refresh
  Future<Either<Failure, LearningPathCategoriesResult>>
      getLearningPathCategories({
    String language = 'en',
    bool includeEnrolled = true,
    int categoryLimit = 4,
    int categoryOffset = 0,
    bool forceRefresh = false,
  });

  /// Get more paths for a single category (per-category pagination).
  ///
  /// [category] - The category name to load more paths for
  /// [language] - The language for localized content
  /// [limit] - Number of paths per page (default: 3)
  /// [offset] - Page offset within the category (default: 0)
  Future<Either<Failure, LearningPathCategory>> getLearningPathsForCategory({
    required String category,
    String language = 'en',
    int limit = 3,
    int offset = 0,
  });

  /// Get learning path details with topics.
  ///
  /// [pathId] - The ID of the learning path
  /// [language] - The language for localized content
  /// [forceRefresh] - Whether to bypass cache and force refresh
  Future<Either<Failure, LearningPathDetail>> getLearningPathDetails({
    required String pathId,
    String language = 'en',
    bool forceRefresh = false,
  });

  /// Enroll in a learning path.
  ///
  /// [pathId] - The ID of the learning path to enroll in
  Future<Either<Failure, EnrollmentResult>> enrollInPath({
    required String pathId,
  });

  /// Get user's enrolled learning paths with progress.
  ///
  /// [language] - The language for localized content
  Future<Either<Failure, List<LearningPath>>> getEnrolledPaths({
    String language = 'en',
  });

  /// Clear cached learning paths data.
  void clearCache();

  /// Get the recommended learning path for the current user.
  ///
  /// Returns a learning path based on priority:
  /// 1. Active (in-progress) learning path for authenticated users
  /// 2. Personalized path based on questionnaire for authenticated users
  /// 3. Featured path as fallback (works for all users including anonymous)
  ///
  /// [language] - The language for localized content (default: 'en')
  /// [forceRefresh] - Whether to bypass cache and force refresh
  Future<Either<Failure, RecommendedPathResult>> getRecommendedPath({
    String language = 'en',
    bool forceRefresh = false,
  });
}
