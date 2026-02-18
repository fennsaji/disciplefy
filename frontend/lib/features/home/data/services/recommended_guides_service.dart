import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/http_service.dart';
import '../../domain/entities/recommended_guide_topic.dart';
import '../models/recommended_guide_topic_model.dart';
import '../datasources/recommended_topics_local_datasource.dart';
import '../../../../core/utils/logger.dart';

/// Result container for "For You" topics API response.
///
/// Contains both the list of personalized topics and a flag indicating
/// whether the user has completed the personalization questionnaire.
class ForYouTopicsResult {
  /// List of personalized topics recommended for the user.
  final List<RecommendedGuideTopic> topics;

  /// Whether the user has completed the personalization questionnaire.
  ///
  /// If false, the topics are based on study history only, and the UI
  /// should show the personalization prompt card.
  final bool hasCompletedQuestionnaire;

  const ForYouTopicsResult({
    required this.topics,
    required this.hasCompletedQuestionnaire,
  });
}

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
/// Supports both generic topics and personalized "For You" topics.
class RecommendedGuidesService {
  // API Configuration
  static String get _baseUrl => AppConfig.supabaseUrl;
  static const String _topicsEndpoint = '/functions/v1/topics-recommended';
  static const String _forYouEndpoint = '/functions/v1/topics-for-you';

  // Cache version - increment this when adding new fields to invalidate old cache
  // v2: Added learning path fields (learning_path_id, learning_path_name, position_in_path, total_topics_in_path)
  static const String _cacheVersion = 'v2';

  final HttpService _httpService;
  final RecommendedTopicsLocalDataSource _localDataSource;

  // Caching configuration
  static const Duration _defaultCacheExpiry = Duration(hours: 24);
  static const Duration _filteredCacheExpiry = Duration(hours: 6);
  static const Duration _forYouCacheExpiry = Duration(hours: 6);

  // In-memory cache - now language-aware (for faster access during same session)
  final Map<String, _CacheEntry<List<RecommendedGuideTopic>>> _allTopicsCache =
      {};
  final Map<String, _CacheEntry<List<RecommendedGuideTopic>>>
      _filteredTopicsCache = {};

  // Capture initialization Future to prevent race conditions
  late final Future<void> _initFuture;

  // Lock for serializing cache access to prevent race conditions
  final Lock _cacheLock = Lock();

  /// Creates a new [RecommendedGuidesService] instance.
  ///
  /// This service manages recommended study guide topics with intelligent
  /// two-tier caching (in-memory + persistent Hive storage).
  ///
  /// **Parameters:**
  /// - [httpService] - Optional HTTP service for making API requests.
  ///   If not provided, uses the shared [HttpServiceProvider.instance].
  /// - [localDataSource] - Optional local datasource for persistent caching.
  ///   If not provided, creates a new [RecommendedTopicsLocalDataSource] instance.
  ///
  /// **Initialization:**
  /// The constructor captures the initialization Future of the local datasource
  /// to ensure proper async setup before any cache operations. All public methods
  /// automatically await this initialization before proceeding.
  ///
  /// **Thread Safety:**
  /// All cache operations are serialized using an internal lock to prevent
  /// race conditions from concurrent [getAllTopics] and [getFilteredTopics] calls.
  ///
  /// **Example:**
  /// ```dart
  /// final service = RecommendedGuidesService();
  /// final result = await service.getAllTopics(language: 'en');
  /// ```
  RecommendedGuidesService({
    HttpService? httpService,
    RecommendedTopicsLocalDataSource? localDataSource,
  })  : _httpService = httpService ?? HttpServiceProvider.instance,
        _localDataSource =
            localDataSource ?? RecommendedTopicsLocalDataSource() {
    // Initialize local datasource and capture Future
    _initFuture = _localDataSource.initialize();
  }

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
    // Serialize all cache operations with lock to prevent race conditions
    return await _cacheLock.synchronized(() async {
      // Wait for local datasource initialization
      await _initFuture;

      // Create language-specific cache key
      final cacheKey = 'all_topics_${language ?? 'en'}';

      // Check in-memory cache first (unless force refresh is requested)
      if (!forceRefresh && _allTopicsCache.containsKey(cacheKey)) {
        final cacheEntry = _allTopicsCache[cacheKey]!;
        if (!cacheEntry.isExpired(_defaultCacheExpiry)) {
          if (kDebugMode) {
            final cacheAge = DateTime.now().difference(cacheEntry.timestamp);
            Logger.debug(
                '✅ [TOPICS] Returning in-memory cached topics for ${language ?? 'en'} (cached ${cacheAge.inMinutes} minutes ago)');
          }
          return Right(cacheEntry.data);
        } else {
          // Remove expired cache entry
          _allTopicsCache.remove(cacheKey);
        }
      }

      // Check persistent local cache (Hive) if not force refresh
      if (!forceRefresh) {
        final cachedTopics = await _localDataSource.getCachedTopics(
            cacheKey, _defaultCacheExpiry);
        if (cachedTopics != null && cachedTopics.isNotEmpty) {
          // Convert models to entities
          final topics = cachedTopics.map((model) => model.toEntity()).toList();
          // Also populate in-memory cache for faster access
          _allTopicsCache[cacheKey] = _CacheEntry(topics, DateTime.now());
          Logger.debug(
              '✅ [TOPICS] Returning persistent cached topics for ${language ?? 'en'} (${topics.length} topics)');
          return Right(topics);
        }
      }

      try {
        Logger.debug(
            '🚀 [TOPICS] ${forceRefresh ? "Force refreshing" : "Cache miss - fetching"} topics from API...');

        // Prepare headers for API request
        final headers = await _httpService.createHeaders();

        // Build query parameters - normalize language to 'en' default
        final normalizedLanguage = language ?? 'en';
        final queryParams = <String, String>{
          'language': normalizedLanguage,
        };

        final uri = Uri.parse('$_baseUrl$_topicsEndpoint').replace(
            queryParameters: queryParams.isNotEmpty ? queryParams : null);

        // Make API request
        final response = await _httpService.get(
          uri.toString(),
          headers: headers,
        );

        Logger.info('📡 [TOPICS] API Response Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final result = _parseTopicsResponse(response.body);

          // Cache successful responses with language-specific key
          result.fold(
            (failure) => null, // Don't cache failures
            (topics) async {
              // Cache in-memory
              _allTopicsCache[cacheKey] = _CacheEntry(topics, DateTime.now());

              // Cache persistently to Hive
              final topicModels = topics
                  .map((topic) => RecommendedGuideTopicModel.fromEntity(topic))
                  .toList();
              await _localDataSource.cacheTopics(cacheKey, topicModels);

              Logger.debug(
                  '💾 [TOPICS] Cached ${topics.length} topics for ${language ?? 'en'} (in-memory + persistent) for ${_defaultCacheExpiry.inHours} hours');
            },
          );

          return result;
        } else {
          Logger.error(
              '❌ [TOPICS] API error: ${response.statusCode} - ${response.body}');
          return Left(ServerFailure(
              message: 'Failed to fetch topics: ${response.statusCode}'));
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          Logger.debug('💥 [TOPICS] Exception: $e');
          Logger.debug('📚 [TOPICS] Stack trace: $stackTrace');
        }

        return Left(
            NetworkFailure(message: 'Failed to connect to topics service: $e'));
      }
    });
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
    // Serialize all cache operations with lock to prevent race conditions
    return await _cacheLock.synchronized(() async {
      // Wait for local datasource initialization
      await _initFuture;

      // Create cache key for filtered queries
      final cacheKey = _generateCacheKey(category, difficulty, limit, language);

      // Check in-memory cache first (unless force refresh is requested)
      if (!forceRefresh && _filteredTopicsCache.containsKey(cacheKey)) {
        final cacheEntry = _filteredTopicsCache[cacheKey]!;
        if (!cacheEntry.isExpired(_filteredCacheExpiry)) {
          if (kDebugMode) {
            final cacheAge = DateTime.now().difference(cacheEntry.timestamp);
            Logger.debug(
                '✅ [TOPICS] Returning in-memory cached filtered topics (cached ${cacheAge.inMinutes} minutes ago)');
          }
          return Right(cacheEntry.data);
        } else {
          // Remove expired cache entry
          _filteredTopicsCache.remove(cacheKey);
        }
      }

      // Check persistent local cache (Hive) if not force refresh
      if (!forceRefresh) {
        final cachedTopics = await _localDataSource.getCachedTopics(
            cacheKey, _filteredCacheExpiry);
        if (cachedTopics != null && cachedTopics.isNotEmpty) {
          // Convert models to entities
          final topics = cachedTopics.map((model) => model.toEntity()).toList();
          // Also populate in-memory cache for faster access
          _filteredTopicsCache[cacheKey] = _CacheEntry(topics, DateTime.now());
          Logger.debug(
              '✅ [TOPICS] Returning persistent cached filtered topics (${topics.length} topics)');
          return Right(topics);
        }
      }

      try {
        // Build query parameters - normalize language to 'en' default
        final normalizedLanguage = language ?? 'en';
        final queryParams = <String, String>{
          'language': normalizedLanguage,
        };
        if (category != null) queryParams['category'] = category;
        if (difficulty != null) queryParams['difficulty'] = difficulty;
        if (limit != null) queryParams['limit'] = limit.toString();

        final uri = Uri.parse('$_baseUrl$_topicsEndpoint').replace(
            queryParameters: queryParams.isNotEmpty ? queryParams : null);

        Logger.debug(
            '🚀 [TOPICS] ${forceRefresh ? "Force refreshing" : "Cache miss - fetching"} filtered topics: $uri');

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
            (topics) async {
              // Cache in-memory
              _filteredTopicsCache[cacheKey] =
                  _CacheEntry(topics, DateTime.now());

              // Cache persistently to Hive
              final topicModels = topics
                  .map((topic) => RecommendedGuideTopicModel.fromEntity(topic))
                  .toList();
              await _localDataSource.cacheTopics(cacheKey, topicModels);

              Logger.debug(
                  '💾 [TOPICS] Cached ${topics.length} filtered topics (in-memory + persistent) for ${_filteredCacheExpiry.inHours} hours');
            },
          );

          return result;
        } else {
          if (kDebugMode) {
            Logger.debug('💥 [TOPICS] API error ${response.statusCode}');
          }
          return Left(ServerFailure(
              message:
                  'Failed to fetch filtered topics: ${response.statusCode}'));
        }
      } catch (e) {
        if (kDebugMode) Logger.debug('💥 [TOPICS] Filtered topics error: $e');
        return Left(
            NetworkFailure(message: 'Failed to fetch filtered topics: $e'));
      }
    });
  }

  /// Fetches personalized "For You" topics based on user's questionnaire responses.
  ///
  /// This endpoint returns topics tailored to the user's spiritual journey,
  /// what they're seeking, and their time commitment preferences.
  ///
  /// [language] - Language code for topic translations (optional, defaults to 'en')
  /// [limit] - Maximum number of topics to return (optional, defaults to 4)
  /// [forceRefresh] - If true, bypasses cache and fetches fresh data
  ///
  /// Returns a tuple containing:
  /// - [Right] with list of personalized topics on success
  /// - [hasCompletedQuestionnaire] flag indicating if user has completed the questionnaire
  /// - [Left] with [Failure] on error
  Future<Either<Failure, ForYouTopicsResult>> getForYouTopics({
    String? language,
    int limit = 4,
    bool forceRefresh = false,
  }) async {
    // Serialize all cache operations with lock to prevent race conditions
    return await _cacheLock.synchronized(() async {
      // Wait for local datasource initialization
      await _initFuture;

      // Create language-specific cache key for "For You" topics
      // Include cache version to invalidate old cache when new fields are added
      final cacheKey = 'for_you_${_cacheVersion}_${language ?? 'en'}_$limit';

      // Check in-memory cache first (unless force refresh is requested)
      if (!forceRefresh && _filteredTopicsCache.containsKey(cacheKey)) {
        final cacheEntry = _filteredTopicsCache[cacheKey]!;
        if (!cacheEntry.isExpired(_forYouCacheExpiry)) {
          if (kDebugMode) {
            final cacheAge = DateTime.now().difference(cacheEntry.timestamp);
            Logger.debug(
                '✅ [FOR YOU] Returning in-memory cached topics for ${language ?? 'en'} (cached ${cacheAge.inMinutes} minutes ago)');
          }
          // INVARIANT: We only cache results when hasCompletedQuestionnaire was true
          // (see caching logic at lines 464-480), so returning true here is safe.
          return Right(ForYouTopicsResult(
            topics: cacheEntry.data,
            hasCompletedQuestionnaire: true,
          ));
        } else {
          // Remove expired cache entry
          _filteredTopicsCache.remove(cacheKey);
        }
      }

      // Check persistent local cache (Hive) if not force refresh
      if (!forceRefresh) {
        final cachedTopics = await _localDataSource.getCachedTopics(
            cacheKey, _forYouCacheExpiry);
        if (cachedTopics != null && cachedTopics.isNotEmpty) {
          // Convert models to entities
          final topics = cachedTopics.map((model) => model.toEntity()).toList();
          // Also populate in-memory cache for faster access
          _filteredTopicsCache[cacheKey] = _CacheEntry(topics, DateTime.now());
          Logger.debug(
              '✅ [FOR YOU] Returning persistent cached topics for ${language ?? 'en'} (${topics.length} topics)');
          // INVARIANT: We only cache results when hasCompletedQuestionnaire was true
          // (see caching logic at lines 464-480), so returning true here is safe.
          return Right(ForYouTopicsResult(
            topics: topics,
            hasCompletedQuestionnaire: true,
          ));
        }
      }

      try {
        Logger.debug(
            '🚀 [FOR YOU] ${forceRefresh ? "Force refreshing" : "Cache miss - fetching"} personalized topics from API...');

        // Prepare headers for API request (includes auth token for user identification)
        final headers = await _httpService.createHeaders();

        // Build request body
        final normalizedLanguage = language ?? 'en';
        final requestBody = jsonEncode({
          'language': normalizedLanguage,
          'limit': limit,
        });

        final uri = Uri.parse('$_baseUrl$_forYouEndpoint');

        // Make API request (POST for personalized topics)
        final response = await _httpService.post(
          uri.toString(),
          headers: headers,
          body: requestBody,
        );

        Logger.info('📡 [FOR YOU] API Response Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final result = _parseForYouTopicsResponse(response.body);

          // Cache successful responses only if questionnaire was completed
          if (result.isRight()) {
            final forYouResult = result.getOrElse(
              () => const ForYouTopicsResult(
                topics: [],
                hasCompletedQuestionnaire: false,
              ),
            );
            if (forYouResult.hasCompletedQuestionnaire &&
                forYouResult.topics.isNotEmpty) {
              // Cache in-memory
              _filteredTopicsCache[cacheKey] =
                  _CacheEntry(forYouResult.topics, DateTime.now());

              // Cache persistently to Hive
              final topicModels = forYouResult.topics
                  .map((topic) => RecommendedGuideTopicModel.fromEntity(topic))
                  .toList();
              await _localDataSource.cacheTopics(cacheKey, topicModels);

              Logger.debug(
                  '💾 [FOR YOU] Cached ${forYouResult.topics.length} topics for ${language ?? 'en'} (in-memory + persistent) for ${_forYouCacheExpiry.inHours} hours');
            }
          }

          return result;
        } else {
          Logger.error(
              '❌ [FOR YOU] API error: ${response.statusCode} - ${response.body}');
          return Left(ServerFailure(
              message:
                  'Failed to fetch personalized topics: ${response.statusCode}'));
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          Logger.debug('💥 [FOR YOU] Exception: $e');
          Logger.debug('📚 [FOR YOU] Stack trace: $stackTrace');
        }

        return Left(NetworkFailure(
            message: 'Failed to connect to personalized topics service: $e'));
      }
    });
  }

  /// Parses the "For You" API response and converts to domain entities.
  Either<Failure, ForYouTopicsResult> _parseForYouTopicsResponse(
      String responseBody) {
    try {
      if (kDebugMode) Logger.debug('📄 [FOR YOU] Parsing response...');
      final Map<String, dynamic> jsonData = json.decode(responseBody);

      // Handle nested response format: {"success": true, "data": {...}}
      final Map<String, dynamic> topicsData =
          jsonData.containsKey('data') && jsonData['data'] is Map
              ? jsonData['data'] as Map<String, dynamic>
              : jsonData;

      // Extract the hasCompletedQuestionnaire flag
      final hasCompletedQuestionnaire =
          topicsData['hasCompletedQuestionnaire'] as bool? ?? false;

      // Log suggested learning path if present
      if (kDebugMode && topicsData.containsKey('suggestedLearningPath')) {
        Logger.info(
            '🎯 [FOR YOU] Suggested Learning Path: ${topicsData['suggestedLearningPath']}');
      }

      // Parse the topics using existing model
      if (topicsData.containsKey('topics')) {
        final response = RecommendedGuideTopicsResponse.fromJson(topicsData);
        final topics = response.toEntities();

        if (kDebugMode) {
          Logger.info(
              '✅ [FOR YOU] Successfully parsed ${topics.length} topics (questionnaire completed: $hasCompletedQuestionnaire)');
          // Log learning path fields for each topic
          for (final topic in topics) {
            if (topic.isFromLearningPath) {
              Logger.debug(
                  '  📍 Topic "${topic.title}" - Path: ${topic.learningPathName}, Position: ${topic.positionInPath}/${topic.totalTopicsInPath}');
            } else {
              Logger.debug(
                  '  📍 Topic "${topic.title}" - No learning path (learningPathId: ${topic.learningPathId})');
            }
          }
        }
        return Right(ForYouTopicsResult(
          topics: topics,
          hasCompletedQuestionnaire: hasCompletedQuestionnaire,
        ));
      } else {
        Logger.error(
            '❌ [FOR YOU] API response missing topics data: $topicsData');
        return const Left(
            ClientFailure(message: 'API response missing topics data'));
      }
    } catch (e) {
      if (kDebugMode) {
        Logger.error('💥 [FOR YOU] JSON parsing error: $e');
        Logger.debug('📄 [FOR YOU] Raw response: $responseBody');
      }
      return Left(ClientFailure(
          message: 'Failed to parse personalized topics response: $e'));
    }
  }

  /// Parses the API response and converts to domain entities.
  Either<Failure, List<RecommendedGuideTopic>> _parseTopicsResponse(
      String responseBody) {
    try {
      if (kDebugMode) Logger.debug('📄 [TOPICS] Parsing response...');
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

        Logger.info('✅ [TOPICS] Successfully parsed ${topics.length} topics');
        return Right(topics);
      } else {
        Logger.error('❌ [TOPICS] API response missing topics data: $jsonData');
        return const Left(
            ClientFailure(message: 'API response missing topics data'));
      }
    } catch (e) {
      if (kDebugMode) {
        Logger.error('💥 [TOPICS] JSON parsing error: $e');
        Logger.debug('📄 [TOPICS] Raw response: $responseBody');
      }
      return Left(
          ClientFailure(message: 'Failed to parse topics response: $e'));
    }
  }

  /// Generates a cache key for filtered queries
  String _generateCacheKey(
      String? category, String? difficulty, int? limit, String? language) {
    final normalizedLanguage = language ?? 'en';
    final parts = <String>[
      'filtered',
      category ?? 'null',
      difficulty ?? 'null',
      limit?.toString() ?? 'null',
      normalizedLanguage,
    ];
    return parts.join('_');
  }

  /// Clears the "For You" topics cache from both in-memory and persistent storage.
  ///
  /// This method specifically targets only the personalized "For You" cache entries,
  /// preserving other cached topics (all-topics, filtered-topics) for efficiency.
  ///
  /// **Use Cases:**
  /// - Study guide completion (completed topics should no longer appear in "For You")
  /// - After completing personalization questionnaire
  /// - When user's study history changes
  ///
  /// **Thread Safety:**
  /// This method is protected by an internal lock to ensure thread-safe
  /// cache clearing even during concurrent cache operations.
  ///
  /// **Example:**
  /// ```dart
  /// await recommendedGuidesService.clearForYouCache();
  /// // Only "For You" cache entries are cleared, other caches remain
  /// ```
  Future<void> clearForYouCache() async {
    await _cacheLock.synchronized(() async {
      await _initFuture;

      // Find and remove all "for_you_*" cache entries from in-memory cache
      final forYouKeys = _filteredTopicsCache.keys
          .where((key) => key.startsWith('for_you_'))
          .toList();

      for (final key in forYouKeys) {
        _filteredTopicsCache.remove(key);
      }

      // Clear persistent cache entries for "for_you_*" keys
      await _localDataSource.clearCacheByPrefix('for_you_');

      Logger.debug(
          '🗑️ [FOR YOU] Cleared ${forYouKeys.length} For You cache entries (in-memory + persistent)');
    });
  }

  /// Clears all cached data from both in-memory and persistent storage.
  ///
  /// This method removes all cached topics (both all-topics and filtered-topics)
  /// from the in-memory cache maps and from the persistent Hive storage.
  ///
  /// **Use Cases:**
  /// - User logout (to clear personal cached data)
  /// - Manual refresh request (to force fetch fresh data)
  /// - Language change (to clear language-specific cached topics)
  /// - Cache invalidation after data corruption
  ///
  /// **Thread Safety:**
  /// This method is protected by an internal lock to ensure thread-safe
  /// cache clearing even during concurrent [getAllTopics] or [getFilteredTopics] calls.
  ///
  /// **Example:**
  /// ```dart
  /// await recommendedGuidesService.clearCache();
  /// // All cached topics are now cleared
  /// ```
  Future<void> clearCache() async {
    // Serialize cache clearing with lock to prevent race conditions
    await _cacheLock.synchronized(() async {
      // Wait for local datasource initialization
      await _initFuture;

      _allTopicsCache.clear();
      _filteredTopicsCache.clear();
      await _localDataSource.clearCache();
      Logger.debug('🗑️ [TOPICS] All caches cleared (in-memory + persistent)');
    });
  }

  /// Retrieves comprehensive cache statistics for debugging and monitoring.
  ///
  /// Returns a map containing detailed information about the current cache state:
  /// - `in_memory_all_topics_caches_count` - Number of language-specific all-topics caches
  /// - `in_memory_all_topics_cache_keys` - List of cache keys for all-topics (e.g., 'all_topics_en')
  /// - `in_memory_filtered_caches_count` - Number of filtered-topics caches
  /// - `cache_expiry_hours` - Default cache expiration time in hours (24 hours)
  /// - `persistent_cache_stats` - Statistics from Hive persistent storage
  ///
  /// **Use Cases:**
  /// - Debugging cache issues
  /// - Monitoring cache hit/miss rates
  /// - Verifying cache invalidation
  /// - Understanding cache memory usage
  ///
  /// **Thread Safety:**
  /// This method is protected by an internal lock to ensure consistent
  /// snapshot of cache state even during concurrent modifications.
  ///
  /// **Example:**
  /// ```dart
  /// final status = await recommendedGuidesService.getCacheStatus();
  /// Logger.debug('Total all-topics caches: ${status['in_memory_all_topics_caches_count']}');
  /// Logger.debug('Cache keys: ${status['in_memory_all_topics_cache_keys']}');
  /// ```
  Future<Map<String, dynamic>> getCacheStatus() async {
    // Serialize cache status reading with lock to prevent race conditions
    return await _cacheLock.synchronized(() async {
      // Wait for local datasource initialization
      await _initFuture;

      return {
        'in_memory_all_topics_caches_count': _allTopicsCache.length,
        'in_memory_all_topics_cache_keys': _allTopicsCache.keys.toList(),
        'in_memory_filtered_caches_count': _filteredTopicsCache.length,
        'cache_expiry_hours': _defaultCacheExpiry.inHours,
        'persistent_cache_stats': _localDataSource.getCacheStats(),
      };
    });
  }

  /// Releases all resources held by this service and clears all caches.
  ///
  /// This method performs cleanup operations when the service is no longer needed:
  /// - Clears all in-memory cached topics (both all-topics and filtered-topics)
  /// - Clears all persistent Hive storage caches
  /// - Disposes the local datasource (closes Hive box)
  ///
  /// **Important Notes:**
  /// - The [HttpService] is managed by [HttpServiceProvider] as a shared singleton,
  ///   so this method does NOT dispose the HTTP service. Individual service instances
  ///   should not dispose shared resources.
  /// - This method should be called when the service is no longer needed to prevent
  ///   memory leaks and release Hive resources.
  ///
  /// **Thread Safety:**
  /// This method is protected by an internal lock to ensure safe disposal
  /// even if other operations are attempting to access caches concurrently.
  ///
  /// **Use Cases:**
  /// - Application shutdown
  /// - Service dependency injection cleanup
  /// - Widget disposal (if service is tied to a specific widget lifecycle)
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// void dispose() {
  ///   recommendedGuidesService.dispose();
  ///   super.dispose();
  /// }
  /// ```
  Future<void> dispose() async {
    // Serialize disposal with lock to prevent race conditions
    await _cacheLock.synchronized(() async {
      // Wait for local datasource initialization
      await _initFuture;

      // Clear caches on disposal (clearCache also uses lock, but we're already inside it)
      _allTopicsCache.clear();
      _filteredTopicsCache.clear();
      await _localDataSource.clearCache();

      // Dispose local datasource
      await _localDataSource.dispose();
      // HttpService is managed by HttpServiceProvider as a singleton
      // Individual services should not dispose shared resources
    });
  }
}
