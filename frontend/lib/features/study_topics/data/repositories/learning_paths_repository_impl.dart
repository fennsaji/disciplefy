import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/learning_path.dart';
import '../../domain/repositories/learning_paths_repository.dart';
import '../datasources/learning_paths_remote_datasource.dart';
import '../../../../core/utils/logger.dart';

/// Implementation of [LearningPathsRepository].
class LearningPathsRepositoryImpl implements LearningPathsRepository {
  final LearningPathsRemoteDataSource _remoteDataSource;

  // Cache for category-grouped paths
  LearningPathCategoriesResult? _cachedCategories;
  DateTime? _categoriesCacheTimestamp;

  // Cache for learning paths (flat, used for enrolled paths / recommended)
  LearningPathsResult? _cachedPaths;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(hours: 24);

  // Cache for path details
  final Map<String, LearningPathDetail> _detailsCache = {};
  final Map<String, DateTime> _detailsCacheTimestamps = {};

  // Cache for recommended path
  RecommendedPathResult? _cachedRecommendedPath;
  DateTime? _recommendedPathCacheTimestamp;

  LearningPathsRepositoryImpl({
    required LearningPathsRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, LearningPathsResult>> getLearningPaths({
    String language = 'en',
    bool includeEnrolled = true,
    bool forceRefresh = false,
    int limit = 10,
    int offset = 0,
    String? search,
    String? fellowshipId,
  }) async {
    // Only use cache for non-search, non-fellowship first-page requests without force-refresh
    if (!forceRefresh &&
        offset == 0 &&
        search == null &&
        fellowshipId == null &&
        _isCacheValid()) {
      return Right(_cachedPaths!);
    }

    try {
      final response = await _remoteDataSource.getLearningPaths(
        language: language,
        includeEnrolled: includeEnrolled,
        limit: limit,
        offset: offset,
        search: search,
        fellowshipId: fellowshipId,
      );

      final result = response.toEntity();

      // Cache only non-search first-page results
      if (offset == 0 && search == null) {
        _cachedPaths = result;
        _cacheTimestamp = DateTime.now();
      }

      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      // Return cached data if available (first page only)
      if (_cachedPaths != null && offset == 0) {
        return Right(_cachedPaths!);
      }
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, LearningPathCategoriesResult>>
      getLearningPathCategories({
    String language = 'en',
    bool includeEnrolled = true,
    int categoryLimit = 4,
    int categoryOffset = 0,
    bool forceRefresh = false,
  }) async {
    // Only cache the first page
    if (!forceRefresh && categoryOffset == 0 && _isCategoriesCacheValid()) {
      return Right(_cachedCategories!);
    }

    try {
      final response = await _remoteDataSource.getLearningPathCategories(
        language: language,
        includeEnrolled: includeEnrolled,
        categoryLimit: categoryLimit,
        categoryOffset: categoryOffset,
      );

      final result = response.toEntity();

      if (categoryOffset == 0) {
        _cachedCategories = result;
        _categoriesCacheTimestamp = DateTime.now();
      }

      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      if (_cachedCategories != null && categoryOffset == 0) {
        return Right(_cachedCategories!);
      }
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, LearningPathCategory>> getLearningPathsForCategory({
    required String category,
    String language = 'en',
    int limit = 3,
    int offset = 0,
  }) async {
    try {
      final response = await _remoteDataSource.getLearningPathsForCategory(
        category: category,
        language: language,
        limit: limit,
        offset: offset,
      );

      return Right(LearningPathCategory(
        name: response.category,
        paths: response.paths,
        hasMoreInCategory: response.hasMore,
        nextPathOffset: offset + response.paths.length,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, LearningPathDetail>> getLearningPathDetails({
    required String pathId,
    String language = 'en',
    bool forceRefresh = false,
  }) async {
    Logger.debug(
        '[LearningPathsRepo] getLearningPathDetails called for $pathId with forceRefresh: $forceRefresh');

    // Cache key includes language so a language change always fetches fresh data
    final cacheKey = '${pathId}_$language';

    // Check cache
    if (!forceRefresh && _isDetailsCacheValid(cacheKey)) {
      Logger.debug(
          '[LearningPathsRepo] Returning cached path details (progress: ${_detailsCache[cacheKey]?.progressPercentage}%)');
      return Right(_detailsCache[cacheKey]!);
    }

    Logger.debug('[LearningPathsRepo] Fetching fresh path details from API...');
    try {
      final detail = await _remoteDataSource.getLearningPathDetails(
        pathId: pathId,
        language: language,
      );

      Logger.debug(
          '[LearningPathsRepo] Got fresh path details - progress: ${detail.progressPercentage}%');

      // Update cache
      _detailsCache[cacheKey] = detail;
      _detailsCacheTimestamps[cacheKey] = DateTime.now();

      return Right(detail);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      // Return cached data if available
      if (_detailsCache.containsKey(cacheKey)) {
        return Right(_detailsCache[cacheKey]!);
      }
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, EnrollmentResult>> enrollInPath({
    required String pathId,
  }) async {
    try {
      final result = await _remoteDataSource.enrollInPath(pathId: pathId);

      // Invalidate caches after enrollment
      clearCache();

      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LearningPath>>> getEnrolledPaths({
    String language = 'en',
  }) async {
    // Get all paths and filter enrolled ones
    final result = await getLearningPaths(
      language: language,
    );

    return result.fold(
      (failure) => Left(failure),
      (pathsResult) {
        final enrolledPaths =
            pathsResult.paths.where((p) => p.isEnrolled).toList();
        return Right(enrolledPaths);
      },
    );
  }

  @override
  void clearCache() {
    _cachedCategories = null;
    _categoriesCacheTimestamp = null;
    _cachedPaths = null;
    _cacheTimestamp = null;
    _detailsCache.clear();
    _detailsCacheTimestamps.clear();
    _cachedRecommendedPath = null;
    _recommendedPathCacheTimestamp = null;
    _cachedPersonalizedPaths = null;
    _personalizedPathsCacheTimestamp = null;
    // Also clear the persistent Hive cache so stale data is not served after
    // events like enrollment, language change, or DB migrations.
    _remoteDataSource.clearCache();
  }

  bool _isCategoriesCacheValid() {
    if (_cachedCategories == null || _categoriesCacheTimestamp == null) {
      return false;
    }
    return DateTime.now().difference(_categoriesCacheTimestamp!) <
        _cacheDuration;
  }

  bool _isCacheValid() {
    if (_cachedPaths == null || _cacheTimestamp == null) {
      return false;
    }
    return DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
  }

  bool _isDetailsCacheValid(String cacheKey) {
    if (!_detailsCache.containsKey(cacheKey) ||
        !_detailsCacheTimestamps.containsKey(cacheKey)) {
      return false;
    }
    return DateTime.now().difference(_detailsCacheTimestamps[cacheKey]!) <
        _cacheDuration;
  }

  // Cache for personalized paths
  List<LearningPath>? _cachedPersonalizedPaths;
  DateTime? _personalizedPathsCacheTimestamp;

  bool _isRecommendedPathCacheValid() {
    if (_cachedRecommendedPath == null ||
        _recommendedPathCacheTimestamp == null) {
      return false;
    }
    return DateTime.now().difference(_recommendedPathCacheTimestamp!) <
        _cacheDuration;
  }

  bool _isPersonalizedPathsCacheValid() {
    if (_cachedPersonalizedPaths == null ||
        _personalizedPathsCacheTimestamp == null) {
      return false;
    }
    return DateTime.now().difference(_personalizedPathsCacheTimestamp!) <
        _cacheDuration;
  }

  @override
  Future<Either<Failure, List<LearningPath>>> getPersonalizedPaths({
    String language = 'en',
    int limit = 5,
  }) async {
    if (_isPersonalizedPathsCacheValid()) {
      return Right(_cachedPersonalizedPaths!);
    }

    try {
      final response = await _remoteDataSource.getPersonalizedPaths(
        language: language,
        limit: limit,
      );
      final paths = response.toEntity();
      _cachedPersonalizedPaths = paths;
      _personalizedPathsCacheTimestamp = DateTime.now();
      return Right(paths);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      if (_cachedPersonalizedPaths != null) {
        return Right(_cachedPersonalizedPaths!);
      }
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, RecommendedPathResult>> getRecommendedPath({
    String language = 'en',
    bool forceRefresh = false,
  }) async {
    Logger.debug(
        '[LearningPathsRepo] getRecommendedPath called with forceRefresh: $forceRefresh');

    // Check cache first (skip if forceRefresh)
    if (!forceRefresh && _isRecommendedPathCacheValid()) {
      Logger.debug(
          '[LearningPathsRepo] Returning cached data (progress: ${_cachedRecommendedPath?.path.progressPercentage}%)');
      return Right(_cachedRecommendedPath!);
    }

    Logger.debug('[LearningPathsRepo] Fetching fresh data from API...');
    try {
      final response = await _remoteDataSource.getRecommendedPath(
        language: language,
      );

      final result = response.toEntity();

      if (result == null) {
        return const Left(ServerFailure(
          message: 'No learning path available',
        ));
      }

      Logger.debug(
          '[LearningPathsRepo] Got fresh data - progress: ${result.path.progressPercentage}%, reason: ${result.reason}');

      // Update cache
      _cachedRecommendedPath = result;
      _recommendedPathCacheTimestamp = DateTime.now();

      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      // Return cached data if available
      if (_cachedRecommendedPath != null) {
        return Right(_cachedRecommendedPath!);
      }
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }
}
