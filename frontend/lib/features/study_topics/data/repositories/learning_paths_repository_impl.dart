import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/learning_path.dart';
import '../../domain/repositories/learning_paths_repository.dart';
import '../datasources/learning_paths_remote_datasource.dart';

/// Implementation of [LearningPathsRepository].
class LearningPathsRepositoryImpl implements LearningPathsRepository {
  final LearningPathsRemoteDataSource _remoteDataSource;

  // Cache for learning paths
  LearningPathsResult? _cachedPaths;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 5);

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
  }) async {
    // Check cache
    if (!forceRefresh && _isCacheValid()) {
      return Right(_cachedPaths!);
    }

    try {
      final response = await _remoteDataSource.getLearningPaths(
        language: language,
        includeEnrolled: includeEnrolled,
      );

      final result = response.toEntity();

      // Update cache
      _cachedPaths = result;
      _cacheTimestamp = DateTime.now();

      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      // Return cached data if available
      if (_cachedPaths != null) {
        return Right(_cachedPaths!);
      }
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
    debugPrint(
        '[LearningPathsRepo] getLearningPathDetails called for $pathId with forceRefresh: $forceRefresh');

    // Check cache
    if (!forceRefresh && _isDetailsCacheValid(pathId)) {
      debugPrint(
          '[LearningPathsRepo] Returning cached path details (progress: ${_detailsCache[pathId]?.progressPercentage}%)');
      return Right(_detailsCache[pathId]!);
    }

    debugPrint('[LearningPathsRepo] Fetching fresh path details from API...');
    try {
      final detail = await _remoteDataSource.getLearningPathDetails(
        pathId: pathId,
        language: language,
      );

      debugPrint(
          '[LearningPathsRepo] Got fresh path details - progress: ${detail.progressPercentage}%');

      // Update cache
      _detailsCache[pathId] = detail;
      _detailsCacheTimestamps[pathId] = DateTime.now();

      return Right(detail);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      // Return cached data if available
      if (_detailsCache.containsKey(pathId)) {
        return Right(_detailsCache[pathId]!);
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
    _cachedPaths = null;
    _cacheTimestamp = null;
    _detailsCache.clear();
    _detailsCacheTimestamps.clear();
    _cachedRecommendedPath = null;
    _recommendedPathCacheTimestamp = null;
  }

  bool _isCacheValid() {
    if (_cachedPaths == null || _cacheTimestamp == null) {
      return false;
    }
    return DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
  }

  bool _isDetailsCacheValid(String pathId) {
    if (!_detailsCache.containsKey(pathId) ||
        !_detailsCacheTimestamps.containsKey(pathId)) {
      return false;
    }
    return DateTime.now().difference(_detailsCacheTimestamps[pathId]!) <
        _cacheDuration;
  }

  bool _isRecommendedPathCacheValid() {
    if (_cachedRecommendedPath == null ||
        _recommendedPathCacheTimestamp == null) {
      return false;
    }
    return DateTime.now().difference(_recommendedPathCacheTimestamp!) <
        _cacheDuration;
  }

  @override
  Future<Either<Failure, RecommendedPathResult>> getRecommendedPath({
    String language = 'en',
    bool forceRefresh = false,
  }) async {
    debugPrint(
        '[LearningPathsRepo] getRecommendedPath called with forceRefresh: $forceRefresh');

    // Check cache first (skip if forceRefresh)
    if (!forceRefresh && _isRecommendedPathCacheValid()) {
      debugPrint(
          '[LearningPathsRepo] Returning cached data (progress: ${_cachedRecommendedPath?.path.progressPercentage}%)');
      return Right(_cachedRecommendedPath!);
    }

    debugPrint('[LearningPathsRepo] Fetching fresh data from API...');
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

      debugPrint(
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
