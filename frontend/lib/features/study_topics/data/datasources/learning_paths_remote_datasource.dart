import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../models/learning_path_model.dart';

/// Remote data source for learning paths operations.
abstract class LearningPathsRemoteDataSource {
  /// Get available learning paths.
  Future<LearningPathsResponseModel> getLearningPaths({
    String language = 'en',
    bool includeEnrolled = true,
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
}

/// Implementation of [LearningPathsRemoteDataSource] using Edge Functions.
class LearningPathsRemoteDataSourceImpl
    implements LearningPathsRemoteDataSource {
  static String get _baseUrl => AppConfig.supabaseUrl;
  static const String _endpoint = '/functions/v1/learning-paths';

  final HttpService _httpService;

  LearningPathsRemoteDataSourceImpl({HttpService? httpService})
      : _httpService = httpService ?? HttpServiceProvider.instance;

  @override
  Future<LearningPathsResponseModel> getLearningPaths({
    String language = 'en',
    bool includeEnrolled = true,
  }) async {
    try {
      _logDebug('Fetching learning paths (language: $language)');

      final headers = await _httpService.createHeaders();
      final body = jsonEncode({
        'language': language,
        'includeEnrolled': includeEnrolled,
      });

      final response = await _httpService.post(
        '$_baseUrl$_endpoint',
        headers: headers,
        body: body,
      );

      _logDebug('Learning paths API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return _parsePathsResponse(response.body);
      } else {
        _logDebug('API error: ${response.statusCode} - ${response.body}');
        throw ServerException(
          message: 'Failed to fetch learning paths: ${response.statusCode}',
          code: 'LEARNING_PATHS_API_ERROR',
        );
      }
    } catch (e) {
      _logDebug('Exception in getLearningPaths: $e');

      if (e is ServerException) rethrow;

      throw NetworkException(
        message: 'Failed to connect to learning paths service: $e',
        code: 'LEARNING_PATHS_NETWORK_ERROR',
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
    } catch (e) {
      _logDebug('Exception in getLearningPathDetails: $e');

      if (e is ServerException) rethrow;

      throw NetworkException(
        message: 'Failed to connect to learning paths service: $e',
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
        return _parseEnrollmentResponse(response.body);
      } else {
        _logDebug('API error: ${response.statusCode} - ${response.body}');
        throw ServerException(
          message: 'Failed to enroll in learning path: ${response.statusCode}',
          code: 'ENROLLMENT_API_ERROR',
        );
      }
    } catch (e) {
      _logDebug('Exception in enrollInPath: $e');

      if (e is ServerException) rethrow;

      throw NetworkException(
        message: 'Failed to enroll in learning path: $e',
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
    } catch (e) {
      _logDebug('Exception in getRecommendedPath: $e');

      if (e is ServerException) rethrow;

      throw NetworkException(
        message: 'Failed to connect to learning paths service: $e',
        code: 'RECOMMENDED_PATH_NETWORK_ERROR',
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

  void _logDebug(String message) {
    if (kDebugMode) print('[LEARNING_PATHS] $message');
  }
}
