import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/learning_path.dart';
import '../../domain/repositories/learning_paths_repository.dart';
import '../datasources/learning_paths_remote_datasource.dart';
import '../models/learning_path_download_model.dart';
import '../models/learning_path_model.dart';
import '../../../../core/utils/logger.dart';

/// Implementation of [LearningPathsRepository].
class LearningPathsRepositoryImpl implements LearningPathsRepository {
  final LearningPathsRemoteDataSource _remoteDataSource;

  // Cache for category-grouped paths
  LearningPathCategoriesResult? _cachedCategories;
  DateTime? _categoriesCacheTimestamp;
  String? _categoriesCachedLanguage;

  // Cache for learning paths (flat, used for enrolled paths / recommended)
  LearningPathsResult? _cachedPaths;
  DateTime? _cacheTimestamp;
  String? _pathsCachedLanguage;
  static const _cacheDuration = Duration(hours: 24);

  // Cache for path details
  final Map<String, LearningPathDetail> _detailsCache = {};
  final Map<String, DateTime> _detailsCacheTimestamps = {};
  static const String _detailsPrefKeyPrefix = 'lp_detail_';

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
        _isCacheValid(language)) {
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
        _pathsCachedLanguage = language;
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
    if (!forceRefresh &&
        categoryOffset == 0 &&
        _isCategoriesCacheValid(language)) {
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
        _categoriesCachedLanguage = language;
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

      // Update in-memory and persistent cache
      _detailsCache[cacheKey] = detail;
      _detailsCacheTimestamps[cacheKey] = DateTime.now();
      _persistDetailToPrefs(cacheKey, detail);

      return Right(detail);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      // Return in-memory cache if available (same session)
      if (_detailsCache.containsKey(cacheKey)) {
        Logger.debug(
            '[LearningPathsRepo] Serving path details from in-memory cache (offline)');
        return Right(_detailsCache[cacheKey]!);
      }
      // Fall back to persistent SharedPreferences cache (survives app restarts)
      final persisted = await _loadDetailFromPrefs(cacheKey);
      if (persisted != null) {
        _detailsCache[cacheKey] = persisted;
        Logger.debug(
            '[LearningPathsRepo] Serving path details from persistent cache (offline fallback)');
        return Right(persisted);
      }
      // Last resort: reconstruct from Hive download data (works for all downloaded paths)
      final fromDownload = await _buildDetailFromHiveDownload(pathId);
      if (fromDownload != null) {
        _detailsCache[cacheKey] = fromDownload;
        Logger.debug(
            '[LearningPathsRepo] Reconstructed path details from Hive download data');
        return Right(fromDownload);
      }
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }

  void _persistDetailToPrefs(String cacheKey, LearningPathDetail detail) {
    Future(() async {
      try {
        if (detail is! LearningPathDetailModel) return;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_detailsPrefKeyPrefix$cacheKey',
          jsonEncode(detail.toJson()),
        );
        Logger.debug('[LearningPathsRepo] Persisted path detail for $cacheKey');
      } catch (e) {
        Logger.debug('[LearningPathsRepo] Failed to persist path detail: $e');
      }
    });
  }

  Future<LearningPathDetail?> _loadDetailFromPrefs(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_detailsPrefKeyPrefix$cacheKey');
      if (jsonStr == null) return null;
      return LearningPathDetailModel.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
    } catch (e) {
      Logger.debug(
          '[LearningPathsRepo] Failed to load path detail from prefs: $e');
      return null;
    }
  }

  /// Reconstruct a minimal [LearningPathDetail] from Hive download data.
  /// Used as last-resort offline fallback for paths that were downloaded but
  /// whose detail was never explicitly saved to SharedPreferences.
  Future<LearningPathDetail?> _buildDetailFromHiveDownload(
      String pathId) async {
    try {
      final Box<Map> box;
      if (Hive.isBoxOpen('learning_path_downloads')) {
        box = Hive.box<Map>('learning_path_downloads');
      } else {
        box = await Hive.openBox<Map>('learning_path_downloads');
      }
      final raw = box.get(pathId);
      if (raw == null) return null;

      final download = LearningPathDownloadModel.fromMap(raw);
      final topics = download.topics.asMap().entries.map((entry) {
        final t = entry.value;
        return LearningPathTopicModel(
          position: entry.key + 1,
          isMilestone: false,
          topicId: t.topicId,
          title: t.topicTitle,
          description: t.description,
          category: '',
          inputType: t.inputType,
          xpValue: 50,
          isCompleted: t.status == TopicDownloadStatus.done,
          isInProgress: t.status == TopicDownloadStatus.downloading,
        );
      }).toList();

      final completed = download.topics
          .where((t) => t.status == TopicDownloadStatus.done)
          .length;

      return LearningPathDetailModel(
        id: download.learningPathId,
        slug: '',
        title: download.learningPathTitle,
        description: '',
        iconName: 'school',
        color: '#6A4FB6',
        totalXp: 0,
        estimatedDays: 0,
        discipleLevel: 'believer',
        allowNonSequentialAccess: true,
        topicsCount: topics.length,
        isEnrolled: true,
        progressPercentage: download.totalCount > 0
            ? ((completed / download.totalCount) * 100).round()
            : 0,
        topicsCompleted: completed,
        enrolledAt: download.queuedAt,
        topics: topics,
      );
    } catch (e) {
      Logger.debug(
          '[LearningPathsRepo] Failed to reconstruct detail from Hive: $e');
      return null;
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
    _categoriesCachedLanguage = null;
    _cachedPaths = null;
    _cacheTimestamp = null;
    _pathsCachedLanguage = null;
    _detailsCache.clear();
    _detailsCacheTimestamps.clear();
    _cachedRecommendedPath = null;
    _recommendedPathCacheTimestamp = null;
    _recommendedPathCachedLanguage = null;
    _cachedPersonalizedPaths = null;
    _personalizedPathsCacheTimestamp = null;
    _personalizedPathsCachedLanguage = null;
    // Also clear the persistent Hive cache so stale data is not served after
    // events like enrollment, language change, or DB migrations.
    _remoteDataSource.clearCache();
  }

  bool _isCategoriesCacheValid(String language) {
    if (_cachedCategories == null ||
        _categoriesCacheTimestamp == null ||
        _categoriesCachedLanguage != language) {
      return false;
    }
    return DateTime.now().difference(_categoriesCacheTimestamp!) <
        _cacheDuration;
  }

  bool _isCacheValid(String language) {
    if (_cachedPaths == null ||
        _cacheTimestamp == null ||
        _pathsCachedLanguage != language) {
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

  // Cache for personalized paths (keyed by language)
  String? _personalizedPathsCachedLanguage;
  List<LearningPath>? _cachedPersonalizedPaths;
  DateTime? _personalizedPathsCacheTimestamp;

  // Track cached language for recommended path
  String? _recommendedPathCachedLanguage;

  bool _isRecommendedPathCacheValid(String language) {
    if (_cachedRecommendedPath == null ||
        _recommendedPathCacheTimestamp == null ||
        _recommendedPathCachedLanguage != language) {
      return false;
    }
    return DateTime.now().difference(_recommendedPathCacheTimestamp!) <
        _cacheDuration;
  }

  bool _isPersonalizedPathsCacheValid(String language) {
    if (_cachedPersonalizedPaths == null ||
        _personalizedPathsCacheTimestamp == null ||
        _personalizedPathsCachedLanguage != language) {
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
    if (_isPersonalizedPathsCacheValid(language)) {
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
      _personalizedPathsCachedLanguage = language;
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

    // Check cache first (skip if forceRefresh or language changed)
    if (!forceRefresh && _isRecommendedPathCacheValid(language)) {
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
      _recommendedPathCachedLanguage = language;

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
