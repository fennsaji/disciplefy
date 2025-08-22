import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../../../home/data/models/recommended_guide_topic_model.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../../domain/entities/study_topics_filter.dart';

/// Remote data source for study topics API operations.
abstract class StudyTopicsRemoteDataSource {
  Future<List<RecommendedGuideTopic>> getTopics({StudyTopicsFilter filter});
  Future<List<String>> getCategories();
}

class StudyTopicsRemoteDataSourceImpl implements StudyTopicsRemoteDataSource {
  // API Configuration
  static String get _baseUrl => AppConfig.supabaseUrl;
  static const String _topicsEndpoint = '/functions/v1/topics-recommended';
  static const String _categoriesEndpoint = '/functions/v1/topics-categories';

  final HttpService _httpService;

  StudyTopicsRemoteDataSourceImpl({HttpService? httpService})
      : _httpService = httpService ?? HttpServiceProvider.instance;

  /// Fetches topics from the API with filtering and pagination.
  @override
  Future<List<RecommendedGuideTopic>> getTopics({
    StudyTopicsFilter filter = const StudyTopicsFilter(),
  }) async {
    try {
      if (kDebugMode) {
        print('🚀 [STUDY_TOPICS] Fetching topics with filter: $filter');
      }

      // Build query parameters
      final queryParams = <String, String>{
        'language': filter.language,
        'limit': filter.limit.toString(),
        'offset': filter.offset.toString(),
      };

      // Add category filtering if categories are selected
      if (filter.hasCategoryFilters) {
        queryParams['categories'] = filter.categoriesAsString!;
      }

      final uri = Uri.parse('$_baseUrl$_topicsEndpoint')
          .replace(queryParameters: queryParams);

      if (kDebugMode) {
        print('📡 [STUDY_TOPICS] API URL: $uri');
      }

      // Prepare headers for API request
      final headers = await _httpService.createHeaders();

      final response = await _httpService.get(
        uri.toString(),
        headers: headers,
      );

      if (kDebugMode) {
        print('📡 [STUDY_TOPICS] API Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final topics = _parseTopicsResponse(response.body);

        if (kDebugMode) {
          print(
              '✅ [STUDY_TOPICS] Successfully fetched ${topics.length} topics');
        }

        return topics;
      } else {
        if (kDebugMode) {
          print(
              '❌ [STUDY_TOPICS] API error: ${response.statusCode} - ${response.body}');
        }
        throw ServerException(
          message: 'Failed to fetch topics: ${response.statusCode}',
          code: 'TOPICS_API_ERROR',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 [STUDY_TOPICS] Exception in getTopics: $e');
      }

      if (e is ServerException) {
        rethrow;
      }

      throw NetworkException(
        message: 'Failed to connect to topics service: $e',
        code: 'TOPICS_NETWORK_ERROR',
      );
    }
  }

  /// Fetches available topic categories from the API.
  @override
  Future<List<String>> getCategories() async {
    try {
      if (kDebugMode) {
        print('🚀 [STUDY_TOPICS] Fetching categories...');
      }

      // Prepare headers for API request
      final headers = await _httpService.createHeaders();

      final response = await _httpService.get(
        '$_baseUrl$_categoriesEndpoint',
        headers: headers,
      );

      if (kDebugMode) {
        print(
            '📡 [STUDY_TOPICS] Categories API Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final categories = _parseCategoriesResponse(response.body);

        if (kDebugMode) {
          print(
              '✅ [STUDY_TOPICS] Successfully fetched ${categories.length} categories');
        }

        return categories;
      } else {
        if (kDebugMode) {
          print(
              '❌ [STUDY_TOPICS] Categories API error: ${response.statusCode} - ${response.body}');
        }
        throw ServerException(
          message: 'Failed to fetch categories: ${response.statusCode}',
          code: 'CATEGORIES_API_ERROR',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 [STUDY_TOPICS] Exception in getCategories: $e');
      }

      if (e is ServerException) {
        rethrow;
      }

      throw NetworkException(
        message: 'Failed to connect to categories service: $e',
        code: 'CATEGORIES_NETWORK_ERROR',
      );
    }
  }

  /// Parses topics API response and converts to domain entities.
  List<RecommendedGuideTopic> _parseTopicsResponse(String responseBody) {
    try {
      if (kDebugMode) print('📄 [STUDY_TOPICS] Parsing topics response...');

      final Map<String, dynamic> jsonData = json.decode(responseBody);

      // Parse the expected API format
      if (jsonData.containsKey('success') && jsonData['success'] == true) {
        final data = jsonData['data'] as Map<String, dynamic>;
        if (data.containsKey('topics')) {
          final response = RecommendedGuideTopicsResponse.fromJson(data);
          final topics = response.toEntities();

          if (kDebugMode) {
            print(
                '✅ [STUDY_TOPICS] Successfully parsed ${topics.length} topics');
          }
          return topics;
        }
      }

      // If we reach here, the response format is unexpected
      if (kDebugMode) {
        print('❌ [STUDY_TOPICS] Unexpected API response format: $jsonData');
      }
      throw const ClientException(
        message: 'API response missing topics data',
        code: 'TOPICS_PARSE_ERROR',
      );
    } catch (e) {
      if (kDebugMode) {
        print('💥 [STUDY_TOPICS] JSON parsing error: $e');
        print('📄 [STUDY_TOPICS] Raw response: $responseBody');
      }

      if (e is ClientException) {
        rethrow;
      }

      throw ClientException(
        message: 'Failed to parse topics response: $e',
        code: 'TOPICS_JSON_ERROR',
      );
    }
  }

  /// Parses categories API response and extracts category names.
  List<String> _parseCategoriesResponse(String responseBody) {
    try {
      if (kDebugMode) print('📄 [STUDY_TOPICS] Parsing categories response...');

      final Map<String, dynamic> jsonData = json.decode(responseBody);

      // Parse the expected API format
      if (jsonData.containsKey('success') && jsonData['success'] == true) {
        final data = jsonData['data'] as Map<String, dynamic>;
        if (data.containsKey('categories')) {
          final categories = List<String>.from(data['categories'] as List);

          if (kDebugMode) {
            print(
                '✅ [STUDY_TOPICS] Successfully parsed ${categories.length} categories');
          }
          return categories;
        }
      }

      // If we reach here, the response format is unexpected
      if (kDebugMode) {
        print(
            '❌ [STUDY_TOPICS] Unexpected categories API response format: $jsonData');
      }
      throw const ClientException(
        message: 'API response missing categories data',
        code: 'CATEGORIES_PARSE_ERROR',
      );
    } catch (e) {
      if (kDebugMode) {
        print('💥 [STUDY_TOPICS] Categories JSON parsing error: $e');
        print('📄 [STUDY_TOPICS] Raw response: $responseBody');
      }

      if (e is ClientException) {
        rethrow;
      }

      throw ClientException(
        message: 'Failed to parse categories response: $e',
        code: 'CATEGORIES_JSON_ERROR',
      );
    }
  }
}
