import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/http_service.dart';
import '../../domain/entities/recommended_guide_topic.dart';
import '../models/recommended_guide_topic_model.dart';

/// Cache entry for recommended topics
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);

  bool isExpired(Duration cacheExpiry) {
    return DateTime.now().difference(timestamp) > cacheExpiry;
  }
}

/// Service for fetching recommended study guide topics from the backend API.
/// Enhanced with intelligent caching to reduce unnecessary API calls.
class RecommendedGuidesService {
  // API Configuration
  static String get _baseUrl => AppConfig.supabaseUrl;
  static const String _topicsEndpoint = '/functions/v1/topics-recommended';

  final HttpService _httpService;

  // Caching configuration
  static const Duration _defaultCacheExpiry = Duration(hours: 24);
  static const Duration _filteredCacheExpiry = Duration(hours: 6);

  // In-memory cache - now language-aware
  final Map<String, _CacheEntry<List<RecommendedGuideTopic>>> _allTopicsCache =
      {};
  final Map<String, _CacheEntry<List<RecommendedGuideTopic>>>
      _filteredTopicsCache = {};

  RecommendedGuidesService({HttpService? httpService})
      : _httpService = httpService ?? HttpServiceProvider.instance;

  /// Fetches all recommended guide topics from the API with intelligent caching.
  ///
  /// Returns [Right] with list of topics on success,
  /// [Left] with [Failure] on error.
  ///
  /// [language] - Language code for topic translations (optional)
  /// [forceRefresh] - If true, bypasses cache and fetches fresh data
  Future<Either<Failure, List<RecommendedGuideTopic>>> getAllTopics({
    String? language,
    bool forceRefresh = false,
  }) async {
    // Create language-specific cache key
    final cacheKey = 'all_topics_${language ?? 'en'}';

    // Check cache first (unless force refresh is requested)
    if (!forceRefresh && _allTopicsCache.containsKey(cacheKey)) {
      final cacheEntry = _allTopicsCache[cacheKey]!;
      if (!cacheEntry.isExpired(_defaultCacheExpiry)) {
        if (kDebugMode) {
          final cacheAge = DateTime.now().difference(cacheEntry.timestamp);
          print(
              '✅ [TOPICS] Returning cached topics for ${language ?? 'en'} (cached ${cacheAge.inMinutes} minutes ago)');
        }
        return Right(cacheEntry.data);
      } else {
        // Remove expired cache entry
        _allTopicsCache.remove(cacheKey);
      }
    }

    try {
      if (kDebugMode) {
        print(
            '🚀 [TOPICS] ${forceRefresh ? "Force refreshing" : "Cache miss - fetching"} topics from API...');
      }

      // Prepare headers for API request
      final headers = await _httpService.createHeaders();

      // Build query parameters
      final queryParams = <String, String>{};
      if (language != null) queryParams['language'] = language;

      final uri = Uri.parse('$_baseUrl$_topicsEndpoint').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null);

      // Make API request
      final response = await _httpService.get(
        uri.toString(),
        headers: headers,
      );

      if (kDebugMode) {
        print('📡 [TOPICS] API Response Status: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final result = _parseTopicsResponse(response.body);

        // Cache successful responses with language-specific key
        result.fold(
          (failure) => null, // Don't cache failures
          (topics) {
            _allTopicsCache[cacheKey] = _CacheEntry(topics, DateTime.now());
            if (kDebugMode) {
              print(
                  '💾 [TOPICS] Cached ${topics.length} topics for ${language ?? 'en'} for ${_defaultCacheExpiry.inHours} hours');
            }
          },
        );

        return result;
      } else {
        if (kDebugMode) {
          print(
              '❌ [TOPICS] API error: ${response.statusCode} - ${response.body}');
        }
        return Left(ServerFailure(
            message: 'Failed to fetch topics: ${response.statusCode}'));
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('💥 [TOPICS] Exception: $e');
        print('📚 [TOPICS] Stack trace: $stackTrace');
      }

      return Left(
          NetworkFailure(message: 'Failed to connect to topics service: $e'));
    }
  }

  /// Fetches filtered topics based on category, difficulty, and limit with caching.
  ///
  /// [category] - Filter by topic category (optional)
  /// [difficulty] - Filter by difficulty level (optional)
  /// [limit] - Maximum number of topics to return (optional)
  /// [language] - Language code for topic translations (optional)
  /// [forceRefresh] - If true, bypasses cache and fetches fresh data
  Future<Either<Failure, List<RecommendedGuideTopic>>> getFilteredTopics({
    String? category,
    String? difficulty,
    int? limit,
    String? language,
    bool forceRefresh = false,
  }) async {
    // Create cache key for filtered queries
    final cacheKey = _generateCacheKey(category, difficulty, limit, language);

    // Check cache first (unless force refresh is requested)
    if (!forceRefresh && _filteredTopicsCache.containsKey(cacheKey)) {
      final cacheEntry = _filteredTopicsCache[cacheKey]!;
      if (!cacheEntry.isExpired(_filteredCacheExpiry)) {
        if (kDebugMode) {
          final cacheAge = DateTime.now().difference(cacheEntry.timestamp);
          print(
              '✅ [TOPICS] Returning cached filtered topics (cached ${cacheAge.inMinutes} minutes ago)');
        }
        return Right(cacheEntry.data);
      } else {
        // Remove expired cache entry
        _filteredTopicsCache.remove(cacheKey);
      }
    }
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (category != null) queryParams['category'] = category;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (limit != null) queryParams['limit'] = limit.toString();
      if (language != null) queryParams['language'] = language;

      final uri = Uri.parse('$_baseUrl$_topicsEndpoint').replace(
          queryParameters: queryParams.isNotEmpty ? queryParams : null);

      if (kDebugMode) {
        print(
            '🚀 [TOPICS] ${forceRefresh ? "Force refreshing" : "Cache miss - fetching"} filtered topics: $uri');
      }

      // Prepare headers for API request
      final headers = await _httpService.createHeaders();

      final response = await _httpService.get(
        uri.toString(),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final result = _parseTopicsResponse(response.body);

        // Cache successful filtered responses
        result.fold(
          (failure) => null, // Don't cache failures
          (topics) {
            _filteredTopicsCache[cacheKey] =
                _CacheEntry(topics, DateTime.now());
            if (kDebugMode) {
              print(
                  '💾 [TOPICS] Cached ${topics.length} filtered topics for ${_filteredCacheExpiry.inHours} hours');
            }
          },
        );

        return result;
      } else {
        if (kDebugMode) print('💥 [TOPICS] API error ${response.statusCode}');
        return Left(ServerFailure(
            message:
                'Failed to fetch filtered topics: ${response.statusCode}'));
      }
    } catch (e) {
      if (kDebugMode) print('💥 [TOPICS] Filtered topics error: $e');
      return Left(
          NetworkFailure(message: 'Failed to fetch filtered topics: $e'));
    }
  }

  /// Parses the API response and converts to domain entities.
  Either<Failure, List<RecommendedGuideTopic>> _parseTopicsResponse(
      String responseBody) {
    try {
      if (kDebugMode) print('📄 [TOPICS] Parsing response...');
      final Map<String, dynamic> jsonData = json.decode(responseBody);

      // Parse the expected API format using RecommendedGuideTopicsResponse
      if (jsonData.containsKey('topics') ||
          (jsonData.containsKey('data') &&
              jsonData['data'].containsKey('topics'))) {
        // Handle both direct format {"topics": [...]} and nested format {"data": {"topics": [...]}}
        final topicsData =
            jsonData.containsKey('data') ? jsonData['data'] : jsonData;
        final response = RecommendedGuideTopicsResponse.fromJson(topicsData);
        final topics = response.toEntities();

        if (kDebugMode) {
          print('✅ [TOPICS] Successfully parsed ${topics.length} topics');
        }
        return Right(topics);
      } else {
        if (kDebugMode) {
          print('❌ [TOPICS] API response missing topics data: $jsonData');
        }
        return const Left(
            ClientFailure(message: 'API response missing topics data'));
      }
    } catch (e) {
      if (kDebugMode) {
        print('💥 [TOPICS] JSON parsing error: $e');
        print('📄 [TOPICS] Raw response: $responseBody');
      }
      return Left(
          ClientFailure(message: 'Failed to parse topics response: $e'));
    }
  }

  /// Generates a cache key for filtered queries
  String _generateCacheKey(
      String? category, String? difficulty, int? limit, String? language) {
    final parts = <String>[
      'filtered',
      category ?? 'null',
      difficulty ?? 'null',
      limit?.toString() ?? 'null',
      language ?? 'null',
    ];
    return parts.join('_');
  }

  /// Clears all cached data (useful for logout or manual refresh)
  void clearCache() {
    _allTopicsCache.clear();
    _filteredTopicsCache.clear();
    if (kDebugMode) {
      print('🗑️ [TOPICS] All caches cleared');
    }
  }

  /// Gets cache status for debugging
  Map<String, dynamic> getCacheStatus() {
    return {
      'all_topics_caches_count': _allTopicsCache.length,
      'all_topics_cache_keys': _allTopicsCache.keys.toList(),
      'filtered_caches_count': _filteredTopicsCache.length,
      'cache_expiry_hours': _defaultCacheExpiry.inHours,
    };
  }

  /// Disposes of the service resources.
  /// Note: HttpService is a shared singleton, so we don't dispose it here.
  void dispose() {
    // Clear caches on disposal
    clearCache();
    // HttpService is managed by HttpServiceProvider as a singleton
    // Individual services should not dispose shared resources
  }
}
