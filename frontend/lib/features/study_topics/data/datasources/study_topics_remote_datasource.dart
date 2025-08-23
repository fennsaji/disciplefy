import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/services/http_service.dart';
import '../../../home/data/models/recommended_guide_topic_model.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../../domain/entities/study_topics_filter.dart';

/// Result containing topics and total count from the API.
class TopicsResult {
  final List<RecommendedGuideTopic> topics;
  final int total;

  const TopicsResult({
    required this.topics,
    required this.total,
  });
}

/// Remote data source for study topics API operations.
///
/// Provides network-based access to Bible study topics and categories
/// from the backend API. Handles HTTP requests, response parsing, and
/// error conditions for the study topics feature.
abstract class StudyTopicsRemoteDataSource {
  /// Fetches study topics from the remote API with optional filtering.
  ///
  /// Returns a [TopicsResult] containing both the topics list and total count
  /// available on the server. The [filter] parameter controls pagination,
  /// language selection, and category filtering:
  /// - Uses filter.limit and filter.offset for pagination
  /// - Respects filter.language for localization (defaults to 'en')
  /// - Applies filter.selectedCategories for category-based filtering
  ///
  /// Throws [ServerException] for API errors (4xx/5xx responses).
  /// Throws [NetworkException] for connection failures.
  /// Returns empty topics list if API returns no results.
  Future<TopicsResult> getTopics({StudyTopicsFilter filter});

  /// Fetches available topic categories from the remote API.
  ///
  /// Returns a list of category names that can be used for filtering topics.
  /// Categories are returned in display order based on faith level progression.
  ///
  /// Throws [ServerException] for API errors (4xx/5xx responses).
  /// Throws [NetworkException] for connection failures.
  /// Returns empty list if no categories are available.
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
  Future<TopicsResult> getTopics({
    StudyTopicsFilter filter = const StudyTopicsFilter(),
  }) async {
    try {
      _logDebug('🚀 [STUDY_TOPICS] Fetching topics with filter: $filter');

      final uri = _buildTopicsUri(filter);
      final response = await _executeTopicsRequest(uri);

      if (response.statusCode == 200) {
        return _handleSuccessfulTopicsResponse(response.body);
      } else {
        _handleTopicsError(response);
      }
    } catch (e) {
      return _handleTopicsException(e);
    }
  }

  /// Logs debug message if debug mode is enabled.
  void _logDebug(String message) {
    if (kDebugMode) print(message);
  }

  /// Builds the URI for topics API request with query parameters.
  Uri _buildTopicsUri(StudyTopicsFilter filter) {
    final queryParams = <String, String>{
      'language': filter.language,
      'limit': filter.limit.toString(),
      'offset': filter.offset.toString(),
    };

    if (filter.hasCategoryFilters) {
      queryParams['categories'] = filter.categoriesAsString!;
    }

    final uri = Uri.parse('$_baseUrl$_topicsEndpoint')
        .replace(queryParameters: queryParams);

    _logDebug('📡 [STUDY_TOPICS] API URL: $uri');
    return uri;
  }

  /// Executes the HTTP request to topics API.
  Future<dynamic> _executeTopicsRequest(Uri uri) async {
    final headers = await _httpService.createHeaders();
    final response = await _httpService.get(uri.toString(), headers: headers);

    _logDebug('📡 [STUDY_TOPICS] API Response Status: ${response.statusCode}');
    return response;
  }

  /// Handles successful topics API response.
  TopicsResult _handleSuccessfulTopicsResponse(String responseBody) {
    final result = _parseTopicsResponse(responseBody);

    _logDebug(
        '✅ [STUDY_TOPICS] Successfully fetched ${result.topics.length} topics (total: ${result.total})');
    return result;
  }

  /// Handles topics API error responses.
  Never _handleTopicsError(dynamic response) {
    _logDebug(
        '❌ [STUDY_TOPICS] API error: ${response.statusCode} - ${response.body}');

    throw ServerException(
      message: 'Failed to fetch topics: ${response.statusCode}',
      code: 'TOPICS_API_ERROR',
    );
  }

  /// Handles exceptions during topics request.
  Never _handleTopicsException(Object e) {
    _logDebug('💥 [STUDY_TOPICS] Exception in getTopics: $e');

    if (e is ServerException) throw e;

    throw NetworkException(
      message: 'Failed to connect to topics service: $e',
      code: 'TOPICS_NETWORK_ERROR',
    );
  }

  /// Fetches available topic categories from the API.
  @override
  Future<List<String>> getCategories() async {
    try {
      if (kDebugMode) print('🚀 [STUDY_TOPICS] Fetching categories...');

      final headers = await _buildCategoriesHeaders();
      final response = await _fetchCategoriesResponse(headers);
      return _handleCategoriesSuccess(response.body);
    } catch (e) {
      if (kDebugMode) print('💥 [STUDY_TOPICS] Exception in getCategories: $e');

      if (e is ServerException) rethrow;

      throw NetworkException(
        message: 'Failed to connect to categories service: $e',
        code: 'CATEGORIES_NETWORK_ERROR',
      );
    }
  }

  /// Builds headers for categories API request.
  Future<Map<String, String>> _buildCategoriesHeaders() async {
    return await _httpService.createHeaders();
  }

  /// Fetches categories response from the API.
  Future<dynamic> _fetchCategoriesResponse(Map<String, String> headers) async {
    final response = await _httpService.get(
      '$_baseUrl$_categoriesEndpoint',
      headers: headers,
    );

    if (kDebugMode) {
      print(
          '📡 [STUDY_TOPICS] Categories API Response Status: ${response.statusCode}');
    }

    if (response.statusCode == 200) {
      return response;
    } else {
      _handleCategoriesError(response);
    }
  }

  /// Handles successful categories response.
  List<String> _handleCategoriesSuccess(String responseBody) {
    final categories = _parseCategoriesResponse(responseBody);

    if (kDebugMode) {
      print(
          '✅ [STUDY_TOPICS] Successfully fetched ${categories.length} categories');
    }

    return categories;
  }

  /// Handles categories API error responses.
  Never _handleCategoriesError(dynamic response) {
    if (kDebugMode) {
      print(
          '❌ [STUDY_TOPICS] Categories API error: ${response.statusCode} - ${response.body}');
    }

    throw ServerException(
      message: 'Failed to fetch categories: ${response.statusCode}',
      code: 'CATEGORIES_API_ERROR',
    );
  }

  /// Parses topics API response and converts to domain entities with total count.
  TopicsResult _parseTopicsResponse(String responseBody) {
    try {
      if (kDebugMode) print('📄 [STUDY_TOPICS] Parsing topics response...');

      final jsonData = json.decode(responseBody) as Map<String, dynamic>;
      _validateTopicsResponse(jsonData);

      final data = jsonData['data'] as Map<String, dynamic>;
      final response = RecommendedGuideTopicsResponse.fromJson(data);
      final topics = response.toEntities();
      final total = response.total;

      if (kDebugMode) {
        print(
            '✅ [STUDY_TOPICS] Successfully parsed ${topics.length} topics (total: $total)');
      }
      return TopicsResult(topics: topics, total: total);
    } catch (e) {
      if (kDebugMode) {
        print('💥 [STUDY_TOPICS] JSON parsing error: $e');
        print('📄 [STUDY_TOPICS] Raw response: $responseBody');
      }

      if (e is ClientException) rethrow;

      throw ClientException(
        message: 'Failed to parse categories response: $e',
        code: 'CATEGORIES_JSON_ERROR',
      );
    }
  }

  /// Validates that the topics response has the expected structure.
  void _validateTopicsResponse(Map<String, dynamic> jsonData) {
    if (jsonData['success'] != true) {
      if (kDebugMode) {
        print('❌ [STUDY_TOPICS] Unexpected API response format: $jsonData');
      }
      throw const ClientException(
        message: 'API response missing topics data',
        code: 'TOPICS_PARSE_ERROR',
      );
    }

    final data = jsonData['data'];
    if (data is! Map<String, dynamic> ||
        !data.containsKey('topics') ||
        !data.containsKey('total')) {
      if (kDebugMode) {
        print('❌ [STUDY_TOPICS] Unexpected API response format: $jsonData');
      }
      throw const ClientException(
        message: 'API response missing topics data',
        code: 'TOPICS_PARSE_ERROR',
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
          final categoriesData = data['categories'];
          if (categoriesData is List) {
            final categories = List<String>.from(categoriesData);

            if (kDebugMode) {
              print(
                  '✅ [STUDY_TOPICS] Successfully parsed ${categories.length} categories');
            }
            return categories;
          }
        }
      }

      // If we reach here, the response format is unexpected
      if (kDebugMode) {
        print('❌ [STUDY_TOPICS] Unexpected API response format: $jsonData');
      }
      throw const ClientException(
        message: 'API response missing categories data',
        code: 'CATEGORIES_PARSE_ERROR',
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
}
