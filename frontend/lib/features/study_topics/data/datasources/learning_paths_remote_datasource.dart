import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../models/learning_path_model.dart';
import '../services/learning_paths_cache_service.dart';
import '../../../../core/utils/logger.dart';

/// Remote data source for learning paths operations.
abstract class LearningPathsRemoteDataSource {
  /// Get available learning paths (flat list, used for enrolled paths etc.).
  Future<LearningPathsResponseModel> getLearningPaths({
    String language = 'en',
    bool includeEnrolled = true,
    int limit = 10,
    int offset = 0,
    String? search,
    String? fellowshipId,
  });

  /// Get learning paths grouped by category (primary listing endpoint).
  Future<LearningPathCategoriesResponseModel> getLearningPathCategories({
    String language = 'en',
    bool includeEnrolled = true,
    int categoryLimit = 4,
    int categoryOffset = 0,
  });

  /// Clears all persistent cache entries.
  Future<void> clearCache();

  /// Get more paths for a single category (per-category load more).
  Future<LearningPathCategoryPathsResponseModel> getLearningPathsForCategory({
    required String category,
    String language = 'en',
    int limit = 3,
    int offset = 0,
  });

  /// Get learning path details with topics.
  Future<LearningPathDetailModel> getLearningPathDetails({
    required String pathId,
    String language = 'en',
  });

  /// Enroll in a learning path.
  Future<EnrollmentResultModel> enrollInPath({
    required String pathId,
  });

  /// Get the recommended learning path for the current user.
  ///
  /// Returns based on priority: active > personalized > featured
  Future<RecommendedPathResponseModel> getRecommendedPath({
    String language = 'en',
  });

  /// Get top N personalized learning paths for the current user.
  ///
  /// Returns paths scored by the questionnaire algorithm, or featured paths
  /// for unauthenticated / non-personalized users.
  Future<PersonalizedPathsResponseModel> getPersonalizedPaths({
    String language = 'en',
    int limit = 5,
  });
}

/// Implementation of [LearningPathsRemoteDataSource] using Edge Functions.
class LearningPathsRemoteDataSourceImpl
    implements LearningPathsRemoteDataSource {
  static String get _baseUrl => AppConfig.supabaseUrl;
  static const String _endpoint = '/functions/v1/learning-paths';

  final HttpService _httpService;
  final LearningPathsCacheService _cache;

  LearningPathsRemoteDataSourceImpl({
    HttpService? httpService,
    LearningPathsCacheService? cache,
  })  : _httpService = httpService ?? HttpServiceProvider.instance,
        _cache = cache ?? LearningPathsCacheService();

  @override
  Future<LearningPathsResponseModel> getLearningPaths({
    String language = 'en',
    bool includeEnrolled = true,
    int limit = 10,
    int offset = 0,
    String? search,
    String? fellowshipId,
  }) async {
    // Only use persistent cache when not searching and no fellowship context
    if (offset == 0 && search == null && fellowshipId == null) {
      final cached =
          await _cache.getCachedResponse(type: 'paths', language: language);
      if (cached != null) {
        _logDebug('Returning cached learning paths ($language)');
        return _parsePathsResponse(cached);
      }
    }

    try {
      _logDebug(
          'Fetching learning paths (language: $language, limit: $limit, offset: $offset, search: $search, fellowshipId: $fellowshipId)');

      final headers = await _httpService.createHeaders();
      final bodyMap = <String, dynamic>{
        'language': language,
        'includeEnrolled': includeEnrolled,
        'limit': limit,
        'offset': offset,
        'format': 'flat',
      };
      if (search != null && search.isNotEmpty) {
        bodyMap['search'] = search;
      }
      if (fellowshipId != null) {
        bodyMap['fellowship_id'] = fellowshipId;
      }
      final body = jsonEncode(bodyMap);

      final response = await _httpService.post(
        '$_baseUrl$_endpoint',
        headers: headers,
        body: body,
      );

      _logDebug('Learning paths API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Only cache non-search first-page results
        if (offset == 0 && search == null) {
          await _cache.cacheResponse(
              type: 'paths', language: language, responseBody: response.body);
        }
        return _parsePathsResponse(response.body);
      } else {
        _logDebug('API error: ${response.statusCode} - ${response.body}');
        throw ServerException(
          message: 'Failed to fetch learning paths: ${response.statusCode}',
          code: 'LEARNING_PATHS_API_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } on ClientException {
      rethrow;
    } catch (e) {
      _logDebug('Exception in getLearningPaths: $e');
      throw NetworkException(
        message: 'Failed to connect to learning paths service',
        code: 'LEARNING_PATHS_NETWORK_ERROR',
      );
    }
  }

  @override
  Future<LearningPathCategoriesResponseModel> getLearningPathCategories({
    String language = 'en',
    bool includeEnrolled = true,
    int categoryLimit = 4,
    int categoryOffset = 0,
  }) async {
    // Check persistent cache for first page only
    if (categoryOffset == 0) {
      final cached = await _cache.getCachedResponse(
          type: 'categories', language: language);
      if (cached != null) {
        final result = _parseCategoriesResponse(cached);
        // Guard: don't serve stale empty cache (e.g. from a DB outage).
        // If no category has any paths, treat as a cache miss and fetch fresh.
        if (result.categories.any((c) => c.paths.isNotEmpty)) {
          _logDebug('Returning cached learning path categories ($language)');
          return result;
        }
        _logDebug(
            'Cached categories have no paths — bypassing stale cache ($language)');
      }
    }

    try {
      _logDebug(
          'Fetching learning path categories (language: $language, categoryLimit: $categoryLimit, categoryOffset: $categoryOffset)');

      final headers = await _httpService.createHeaders();
      final body = jsonEncode({
        'language': language,
        'includeEnrolled': includeEnrolled,
        'categoryLimit': categoryLimit,
        'categoryOffset': categoryOffset,
      });

      final response = await _httpService.post(
        '$_baseUrl$_endpoint',
        headers: headers,
        body: body,
      );

      _logDebug(
          'Learning path categories API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (categoryOffset == 0) {
          await _cache.cacheResponse(
              type: 'categories',
              language: language,
              responseBody: response.body);
        }
        return _parseCategoriesResponse(response.body);
      } else {
        _logDebug('API error: ${response.statusCode} - ${response.body}');
        throw ServerException(
          message:
              'Failed to fetch learning path categories: ${response.statusCode}',
          code: 'LEARNING_PATH_CATEGORIES_API_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } on ClientException {
      rethrow;
    } catch (e) {
      _logDebug('Exception in getLearningPathCategories: $e');
      throw NetworkException(
        message: 'Failed to connect to learning paths service',
        code: 'LEARNING_PATH_CATEGORIES_NETWORK_ERROR',
      );
    }
  }

  @override
  Future<LearningPathCategoryPathsResponseModel> getLearningPathsForCategory({
    required String category,
    String language = 'en',
    int limit = 3,
    int offset = 0,
  }) async {
    try {
      _logDebug(
          'Fetching paths for category "$category" (language: $language, limit: $limit, offset: $offset)');

      final headers = await _httpService.createHeaders();
      final body = jsonEncode({
        'action': 'category_paths',
        'category': category,
        'language': language,
        'limit': limit,
        'offset': offset,
      });

      final response = await _httpService.post(
        '$_baseUrl$_endpoint',
        headers: headers,
        body: body,
      );

      _logDebug(
          'Category paths API response for "$category": ${response.statusCode}');

      if (response.statusCode == 200) {
        return _parseCategoryPathsResponse(response.body);
      } else {
        _logDebug('API error: ${response.statusCode} - ${response.body}');
        throw ServerException(
          message: 'Failed to fetch category paths: ${response.statusCode}',
          code: 'CATEGORY_PATHS_API_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } on ClientException {
      rethrow;
    } catch (e) {
      _logDebug('Exception in getLearningPathsForCategory: $e');
      throw NetworkException(
        message: 'Failed to connect to learning paths service',
        code: 'CATEGORY_PATHS_NETWORK_ERROR',
      );
    }
  }

  @override
  Future<LearningPathDetailModel> getLearningPathDetails({
    required String pathId,
    String language = 'en',
  }) async {
    try {
      _logDebug(
          'Fetching learning path details (pathId: $pathId, language: $language)');

      final headers = await _httpService.createHeaders();
      final body = jsonEncode({
        'pathId': pathId,
        'language': language,
      });

      final response = await _httpService.post(
        '$_baseUrl$_endpoint',
        headers: headers,
        body: body,
      );

      _logDebug('Learning path details API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _parseDetailResponse(response.body);
      } else {
        _logDebug('API error: ${response.statusCode} - ${response.body}');
        throw ServerException(
          message:
              'Failed to fetch learning path details: ${response.statusCode}',
          code: 'LEARNING_PATH_DETAIL_API_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } on ClientException {
      rethrow;
    } catch (e) {
      _logDebug('Exception in getLearningPathDetails: $e');

      throw NetworkException(
        message: 'Failed to connect to learning paths service',
        code: 'LEARNING_PATH_DETAIL_NETWORK_ERROR',
      );
    }
  }

  @override
  Future<EnrollmentResultModel> enrollInPath({
    required String pathId,
  }) async {
    try {
      _logDebug('Enrolling in learning path: $pathId');

      final headers = await _httpService.createHeaders();
      final body = jsonEncode({
        'pathId': pathId,
      });

      final response = await _httpService.post(
        '$_baseUrl$_endpoint?action=enroll',
        headers: headers,
        body: body,
      );

      _logDebug('Enrollment API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Invalidate persistent cache so enrollment state is reflected on next load
        await _cache.clearCache();
        return _parseEnrollmentResponse(response.body);
      } else {
        _logDebug('API error: ${response.statusCode} - ${response.body}');
        throw ServerException(
          message: 'Failed to enroll in learning path: ${response.statusCode}',
          code: 'ENROLLMENT_API_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } on ClientException {
      rethrow;
    } catch (e) {
      _logDebug('Exception in enrollInPath: $e');

      throw NetworkException(
        message: 'Failed to enroll in learning path',
        code: 'ENROLLMENT_NETWORK_ERROR',
      );
    }
  }

  LearningPathsResponseModel _parsePathsResponse(String responseBody) {
    try {
      final jsonData = json.decode(responseBody) as Map<String, dynamic>;

      if (jsonData['success'] != true) {
        throw const ClientException(
          message: 'API returned unsuccessful response',
          code: 'LEARNING_PATHS_API_FAILURE',
        );
      }

      return LearningPathsResponseModel.fromJson(jsonData);
    } catch (e) {
      _logDebug('JSON parsing error: $e');
      if (e is ClientException) rethrow;

      throw ClientException(
        message: 'Failed to parse learning paths response: $e',
        code: 'LEARNING_PATHS_PARSE_ERROR',
      );
    }
  }

  LearningPathDetailModel _parseDetailResponse(String responseBody) {
    try {
      final jsonData = json.decode(responseBody) as Map<String, dynamic>;

      if (jsonData['success'] != true) {
        throw const ClientException(
          message: 'API returned unsuccessful response',
          code: 'LEARNING_PATH_DETAIL_API_FAILURE',
        );
      }

      final data = jsonData['data'] as Map<String, dynamic>;
      return LearningPathDetailModel.fromJson(data);
    } catch (e) {
      _logDebug('JSON parsing error: $e');
      if (e is ClientException) rethrow;

      throw ClientException(
        message: 'Failed to parse learning path details response: $e',
        code: 'LEARNING_PATH_DETAIL_PARSE_ERROR',
      );
    }
  }

  EnrollmentResultModel _parseEnrollmentResponse(String responseBody) {
    try {
      final jsonData = json.decode(responseBody) as Map<String, dynamic>;

      if (jsonData['success'] != true) {
        throw const ClientException(
          message: 'API returned unsuccessful response',
          code: 'ENROLLMENT_API_FAILURE',
        );
      }

      final data = jsonData['data'] as Map<String, dynamic>;
      return EnrollmentResultModel.fromJson(data);
    } catch (e) {
      _logDebug('JSON parsing error: $e');
      if (e is ClientException) rethrow;

      throw ClientException(
        message: 'Failed to parse enrollment response: $e',
        code: 'ENROLLMENT_PARSE_ERROR',
      );
    }
  }

  @override
  Future<RecommendedPathResponseModel> getRecommendedPath({
    String language = 'en',
  }) async {
    try {
      _logDebug('Fetching recommended learning path (language: $language)');

      final headers = await _httpService.createHeaders();
      final body = jsonEncode({
        'language': language,
      });

      final response = await _httpService.post(
        '$_baseUrl$_endpoint?action=recommended',
        headers: headers,
        body: body,
      );

      _logDebug('Recommended path API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _parseRecommendedPathResponse(response.body);
      } else {
        _logDebug('API error: ${response.statusCode} - ${response.body}');
        throw ServerException(
          message: 'Failed to fetch recommended path: ${response.statusCode}',
          code: 'RECOMMENDED_PATH_API_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } on ClientException {
      rethrow;
    } catch (e) {
      _logDebug('Exception in getRecommendedPath: $e');

      throw NetworkException(
        message: 'Failed to connect to learning paths service',
        code: 'RECOMMENDED_PATH_NETWORK_ERROR',
      );
    }
  }

  @override
  Future<PersonalizedPathsResponseModel> getPersonalizedPaths({
    String language = 'en',
    int limit = 5,
  }) async {
    try {
      _logDebug(
          'Fetching personalized paths (language: $language, limit: $limit)');

      final headers = await _httpService.createHeaders();
      final body = jsonEncode({'language': language, 'limit': limit});

      final response = await _httpService.post(
        '$_baseUrl$_endpoint?action=recommended_paths',
        headers: headers,
        body: body,
      );

      _logDebug('Personalized paths API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        if (jsonData['success'] != true) {
          throw const ClientException(
            message: 'API returned unsuccessful response',
            code: 'PERSONALIZED_PATHS_API_FAILURE',
          );
        }
        return PersonalizedPathsResponseModel.fromJson(jsonData);
      } else {
        throw ServerException(
          message: 'Failed to fetch personalized paths: ${response.statusCode}',
          code: 'PERSONALIZED_PATHS_API_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } on ClientException {
      rethrow;
    } catch (e) {
      _logDebug('Exception in getPersonalizedPaths: $e');
      throw NetworkException(
        message: 'Failed to connect to learning paths service',
        code: 'PERSONALIZED_PATHS_NETWORK_ERROR',
      );
    }
  }

  RecommendedPathResponseModel _parseRecommendedPathResponse(
      String responseBody) {
    try {
      final jsonData = json.decode(responseBody) as Map<String, dynamic>;

      if (jsonData['success'] != true) {
        throw const ClientException(
          message: 'API returned unsuccessful response',
          code: 'RECOMMENDED_PATH_API_FAILURE',
        );
      }

      return RecommendedPathResponseModel.fromJson(jsonData);
    } catch (e) {
      _logDebug('JSON parsing error: $e');
      if (e is ClientException) rethrow;

      throw ClientException(
        message: 'Failed to parse recommended path response: $e',
        code: 'RECOMMENDED_PATH_PARSE_ERROR',
      );
    }
  }

  LearningPathCategoriesResponseModel _parseCategoriesResponse(
      String responseBody) {
    try {
      final jsonData = json.decode(responseBody) as Map<String, dynamic>;

      if (jsonData['success'] != true) {
        throw const ClientException(
          message: 'API returned unsuccessful response',
          code: 'LEARNING_PATH_CATEGORIES_API_FAILURE',
        );
      }

      return LearningPathCategoriesResponseModel.fromJson(jsonData);
    } catch (e) {
      _logDebug('JSON parsing error: $e');
      if (e is ClientException) rethrow;

      throw ClientException(
        message: 'Failed to parse learning path categories response: $e',
        code: 'LEARNING_PATH_CATEGORIES_PARSE_ERROR',
      );
    }
  }

  LearningPathCategoryPathsResponseModel _parseCategoryPathsResponse(
      String responseBody) {
    try {
      final jsonData = json.decode(responseBody) as Map<String, dynamic>;

      if (jsonData['success'] != true) {
        throw const ClientException(
          message: 'API returned unsuccessful response',
          code: 'CATEGORY_PATHS_API_FAILURE',
        );
      }

      return LearningPathCategoryPathsResponseModel.fromJson(jsonData);
    } catch (e) {
      _logDebug('JSON parsing error: $e');
      if (e is ClientException) rethrow;

      throw ClientException(
        message: 'Failed to parse category paths response: $e',
        code: 'CATEGORY_PATHS_PARSE_ERROR',
      );
    }
  }

  @override
  Future<void> clearCache() => _cache.clearCache();

  void _logDebug(String message) {
    if (kDebugMode) Logger.debug('[LEARNING_PATHS] $message');
  }
}
