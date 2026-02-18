import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../../domain/entities/study_topics_filter.dart';
import '../../domain/repositories/study_topics_repository.dart';
import '../../domain/utils/topic_search_utils.dart';
import '../datasources/study_topics_remote_datasource.dart';
import '../../../../core/utils/logger.dart';

/// Cache entry for storing data with timestamp
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);

  bool isExpired(Duration cacheExpiry) {
    return DateTime.now().difference(timestamp) > cacheExpiry;
  }
}

/// Cache entry specifically for topics that includes total count
class _TopicsCacheEntry {
  final List<RecommendedGuideTopic> topics;
  final int total;
  final DateTime timestamp;

  _TopicsCacheEntry(this.topics, this.total, this.timestamp);

  bool isExpired(Duration cacheExpiry) {
    return DateTime.now().difference(timestamp) > cacheExpiry;
  }
}

/// Implementation of StudyTopicsRepository with intelligent caching.
class StudyTopicsRepositoryImpl implements StudyTopicsRepository {
  final StudyTopicsRemoteDataSource _remoteDataSource;

  // Caching configuration
  static const Duration _topicsCacheExpiry = Duration(hours: 6);
  static const Duration _categoriesCacheExpiry = Duration(hours: 24);

  // In-memory cache
  final Map<String, _TopicsCacheEntry> _topicsCache = {};
  final Map<String, _CacheEntry<List<String>>> _categoriesCache = {};

  StudyTopicsRepositoryImpl({
    required StudyTopicsRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, List<RecommendedGuideTopic>>> getAllTopics({
    StudyTopicsFilter filter = const StudyTopicsFilter(),
    bool forceRefresh = false,
  }) async {
    try {
      // Create cache key based on filter (excluding search which is client-side)
      final cacheKey = _generateTopicsCacheKey(filter);

      // Check cache first (unless force refresh is requested)
      if (!forceRefresh && _topicsCache.containsKey(cacheKey)) {
        final cacheEntry = _topicsCache[cacheKey]!;
        if (!cacheEntry.isExpired(_topicsCacheExpiry)) {
          if (kDebugMode) {
            final cacheAge = DateTime.now().difference(cacheEntry.timestamp);
            Logger.debug(
                '✅ [STUDY_TOPICS_REPO] Returning cached topics (cached ${cacheAge.inMinutes} minutes ago)');
          }

          // Apply client-side search filtering
          final filteredTopics = TopicSearchUtils.applySearchFilter(
              cacheEntry.topics, filter.searchQuery);
          return Right(filteredTopics);
        } else {
          // Remove expired cache entry
          _topicsCache.remove(cacheKey);
        }
      }

      Logger.debug(
          '🚀 [STUDY_TOPICS_REPO] ${forceRefresh ? "Force refreshing" : "Cache miss - fetching"} topics...');

      // Create filter without search for API call (search is client-side)
      final apiFilter = filter.copyWith(searchQuery: '');

      // Fetch from remote data source
      final result = await _remoteDataSource.getTopics(filter: apiFilter);

      // Cache the results
      _topicsCache[cacheKey] =
          _TopicsCacheEntry(result.topics, result.total, DateTime.now());

      Logger.debug(
          '💾 [STUDY_TOPICS_REPO] Cached ${result.topics.length} topics (total: ${result.total}) for ${_topicsCacheExpiry.inHours} hours');

      // Apply client-side search filtering
      final filteredTopics =
          TopicSearchUtils.applySearchFilter(result.topics, filter.searchQuery);

      return Right(filteredTopics);
    } on NetworkException catch (e) {
      Logger.error('🌐 [STUDY_TOPICS_REPO] Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      Logger.error('🔥 [STUDY_TOPICS_REPO] Server error: ${e.message}');
      return Left(ServerFailure(message: e.message));
    } on ClientException catch (e) {
      Logger.error('📱 [STUDY_TOPICS_REPO] Client error: ${e.message}');
      return Left(ClientFailure(message: e.message));
    } catch (e) {
      Logger.error('💥 [STUDY_TOPICS_REPO] Unexpected error: $e');
      return Left(ClientFailure(message: 'Unexpected error occurred: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getCategories({
    String language = 'en',
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first (unless force refresh is requested)
      if (!forceRefresh && _categoriesCache.containsKey(language)) {
        final cacheEntry = _categoriesCache[language]!;
        if (!cacheEntry.isExpired(_categoriesCacheExpiry)) {
          if (kDebugMode) {
            final cacheAge = DateTime.now().difference(cacheEntry.timestamp);
            Logger.debug(
                '✅ [STUDY_TOPICS_REPO] Returning cached categories for $language (cached ${cacheAge.inMinutes} minutes ago)');
          }
          return Right(cacheEntry.data);
        } else {
          // Remove expired cache entry
          _categoriesCache.remove(language);
        }
      }

      Logger.debug(
          '🚀 [STUDY_TOPICS_REPO] ${forceRefresh ? "Force refreshing" : "Cache miss - fetching"} categories for language: $language...');

      // Fetch from remote data source
      final categories =
          await _remoteDataSource.getCategories(language: language);

      // Cache the results
      _categoriesCache[language] = _CacheEntry(categories, DateTime.now());

      Logger.debug(
          '💾 [STUDY_TOPICS_REPO] Cached ${categories.length} categories for $language for ${_categoriesCacheExpiry.inHours} hours');

      return Right(categories);
    } on NetworkException catch (e) {
      Logger.error('🌐 [STUDY_TOPICS_REPO] Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      Logger.error('🔥 [STUDY_TOPICS_REPO] Server error: ${e.message}');
      return Left(ServerFailure(message: e.message));
    } on ClientException catch (e) {
      Logger.error('📱 [STUDY_TOPICS_REPO] Client error: ${e.message}');
      return Left(ClientFailure(message: e.message));
    } catch (e) {
      Logger.error('💥 [STUDY_TOPICS_REPO] Unexpected error: $e');
      return Left(ClientFailure(message: 'Unexpected error occurred: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> getTopicsCount({
    StudyTopicsFilter filter = const StudyTopicsFilter(),
  }) async {
    try {
      // Create cache key based on filter (excluding search which doesn't affect total count)
      final cacheKey =
          _generateTopicsCacheKey(filter.copyWith(searchQuery: ''));

      // Check if we have cached data with total count
      if (_topicsCache.containsKey(cacheKey)) {
        final cacheEntry = _topicsCache[cacheKey]!;
        if (!cacheEntry.isExpired(_topicsCacheExpiry)) {
          Logger.debug(
              '✅ [STUDY_TOPICS_REPO] Returning cached total count: ${cacheEntry.total}');
          return Right(cacheEntry.total);
        } else {
          // Remove expired cache entry
          _topicsCache.remove(cacheKey);
        }
      }

      Logger.debug(
          '🚀 [STUDY_TOPICS_REPO] Cache miss - fetching topics to get total count...');

      // Create filter without search for API call (search is client-side)
      // Also set a minimal limit since we only need the total count
      final apiFilter = filter.copyWith(searchQuery: '', limit: 1);

      // Fetch from remote data source to get total count
      final result = await _remoteDataSource.getTopics(filter: apiFilter);

      // Cache the results for future use
      _topicsCache[cacheKey] =
          _TopicsCacheEntry(result.topics, result.total, DateTime.now());

      Logger.info('✅ [STUDY_TOPICS_REPO] Fetched total count: ${result.total}');

      return Right(result.total);
    } on NetworkException catch (e) {
      Logger.error(
          '🌐 [STUDY_TOPICS_REPO] Network error in getTopicsCount: ${e.message}');
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      Logger.error(
          '🔥 [STUDY_TOPICS_REPO] Server error in getTopicsCount: ${e.message}');
      return Left(ServerFailure(message: e.message));
    } on ClientException catch (e) {
      Logger.error(
          '📱 [STUDY_TOPICS_REPO] Client error in getTopicsCount: ${e.message}');
      return Left(ClientFailure(message: e.message));
    } catch (e) {
      Logger.error(
          '💥 [STUDY_TOPICS_REPO] Unexpected error in getTopicsCount: $e');
      return Left(ClientFailure(message: 'Unexpected error occurred: $e'));
    }
  }

  @override
  void clearCache() {
    _topicsCache.clear();
    _categoriesCache.clear();
    Logger.debug('🗑️ [STUDY_TOPICS_REPO] All caches cleared');
  }

  /// Generates cache key for topics based on filter criteria (excluding search)
  String _generateTopicsCacheKey(StudyTopicsFilter filter) {
    // Sort selectedCategories deterministically to ensure consistent cache keys
    final sortedCategories = filter.selectedCategories.toList()..sort();

    final parts = <String>[
      'topics',
      sortedCategories.join(','),
      filter.language,
      filter.limit.toString(),
      filter.offset.toString(),
    ];
    return parts.join('_');
  }
}
