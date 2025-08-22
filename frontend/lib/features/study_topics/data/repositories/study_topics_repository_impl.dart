import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../home/domain/entities/recommended_guide_topic.dart';
import '../../domain/entities/study_topics_filter.dart';
import '../../domain/repositories/study_topics_repository.dart';
import '../datasources/study_topics_remote_datasource.dart';

/// Cache entry for storing data with timestamp
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;

  _CacheEntry(this.data, this.timestamp);

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
  final Map<String, _CacheEntry<List<RecommendedGuideTopic>>> _topicsCache = {};
  _CacheEntry<List<String>>? _categoriesCache;

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
            print(
                '✅ [STUDY_TOPICS_REPO] Returning cached topics (cached ${cacheAge.inMinutes} minutes ago)');
          }

          // Apply client-side search filtering
          final filteredTopics =
              _applySearchFilter(cacheEntry.data, filter.searchQuery);
          return Right(filteredTopics);
        } else {
          // Remove expired cache entry
          _topicsCache.remove(cacheKey);
        }
      }

      if (kDebugMode) {
        print(
            '🚀 [STUDY_TOPICS_REPO] ${forceRefresh ? "Force refreshing" : "Cache miss - fetching"} topics...');
      }

      // Create filter without search for API call (search is client-side)
      final apiFilter = filter.copyWith(searchQuery: '');

      // Fetch from remote data source
      final topics = await _remoteDataSource.getTopics(filter: apiFilter);

      // Cache the results
      _topicsCache[cacheKey] = _CacheEntry(topics, DateTime.now());

      if (kDebugMode) {
        print(
            '💾 [STUDY_TOPICS_REPO] Cached ${topics.length} topics for ${_topicsCacheExpiry.inHours} hours');
      }

      // Apply client-side search filtering
      final filteredTopics = _applySearchFilter(topics, filter.searchQuery);

      return Right(filteredTopics);
    } on NetworkException catch (e) {
      if (kDebugMode) {
        print('🌐 [STUDY_TOPICS_REPO] Network error: ${e.message}');
      }
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      if (kDebugMode) {
        print('🔥 [STUDY_TOPICS_REPO] Server error: ${e.message}');
      }
      return Left(ServerFailure(message: e.message));
    } on ClientException catch (e) {
      if (kDebugMode) {
        print('📱 [STUDY_TOPICS_REPO] Client error: ${e.message}');
      }
      return Left(ClientFailure(message: e.message));
    } catch (e) {
      if (kDebugMode) {
        print('💥 [STUDY_TOPICS_REPO] Unexpected error: $e');
      }
      return Left(ClientFailure(message: 'Unexpected error occurred: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getCategories({
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first (unless force refresh is requested)
      if (!forceRefresh &&
          _categoriesCache != null &&
          !_categoriesCache!.isExpired(_categoriesCacheExpiry)) {
        if (kDebugMode) {
          final cacheAge =
              DateTime.now().difference(_categoriesCache!.timestamp);
          print(
              '✅ [STUDY_TOPICS_REPO] Returning cached categories (cached ${cacheAge.inMinutes} minutes ago)');
        }
        return Right(_categoriesCache!.data);
      }

      if (kDebugMode) {
        print(
            '🚀 [STUDY_TOPICS_REPO] ${forceRefresh ? "Force refreshing" : "Cache miss - fetching"} categories...');
      }

      // Fetch from remote data source
      final categories = await _remoteDataSource.getCategories();

      // Cache the results
      _categoriesCache = _CacheEntry(categories, DateTime.now());

      if (kDebugMode) {
        print(
            '💾 [STUDY_TOPICS_REPO] Cached ${categories.length} categories for ${_categoriesCacheExpiry.inHours} hours');
      }

      return Right(categories);
    } on NetworkException catch (e) {
      if (kDebugMode) {
        print('🌐 [STUDY_TOPICS_REPO] Network error: ${e.message}');
      }
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      if (kDebugMode) {
        print('🔥 [STUDY_TOPICS_REPO] Server error: ${e.message}');
      }
      return Left(ServerFailure(message: e.message));
    } on ClientException catch (e) {
      if (kDebugMode) {
        print('📱 [STUDY_TOPICS_REPO] Client error: ${e.message}');
      }
      return Left(ClientFailure(message: e.message));
    } catch (e) {
      if (kDebugMode) {
        print('💥 [STUDY_TOPICS_REPO] Unexpected error: $e');
      }
      return Left(ClientFailure(message: 'Unexpected error occurred: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> getTopicsCount({
    StudyTopicsFilter filter = const StudyTopicsFilter(),
  }) async {
    // For now, we'll get the total from the API response
    // In a more sophisticated implementation, we might have a separate count endpoint
    final result = await getAllTopics(filter: filter.copyWith(limit: 1));

    return result.fold(
      (failure) => Left(failure),
      (topics) {
        // This is a simplified implementation - in reality we'd need total count from API
        // For now, return the number of topics we got (which may be limited by pagination)
        return Right(topics.length);
      },
    );
  }

  @override
  void clearCache() {
    _topicsCache.clear();
    _categoriesCache = null;
    if (kDebugMode) {
      print('🗑️ [STUDY_TOPICS_REPO] All caches cleared');
    }
  }

  /// Generates cache key for topics based on filter criteria (excluding search)
  String _generateTopicsCacheKey(StudyTopicsFilter filter) {
    final parts = <String>[
      'topics',
      filter.selectedCategories.join(','),
      filter.language,
      filter.limit.toString(),
      filter.offset.toString(),
    ];
    return parts.join('_');
  }

  /// Applies client-side search filtering to topics list
  List<RecommendedGuideTopic> _applySearchFilter(
    List<RecommendedGuideTopic> topics,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) {
      return topics;
    }

    final query = searchQuery.toLowerCase();
    return topics.where((topic) {
      return topic.title.toLowerCase().contains(query) ||
          topic.description.toLowerCase().contains(query) ||
          topic.category.toLowerCase().contains(query) ||
          topic.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }
}
