import 'dart:convert';
import 'package:hive/hive.dart';

import '../models/recommended_guide_topic_model.dart';
import '../../../../core/utils/logger.dart';

/// Local data source for caching recommended topics using Hive.
///
/// Provides persistent storage for recommended topics to reduce API calls
/// and improve app performance. Caches are language-aware and expire after
/// a configurable duration.
class RecommendedTopicsLocalDataSource {
  static const String _boxName = 'recommended_topics_cache';
  static const String _cacheKeyPrefix = 'topics_';
  static const String _timestampSuffix = '_timestamp';

  /// Hive box for storing cached topics
  Box<String>? _cacheBox;

  /// Initialize the Hive box for caching
  Future<void> initialize() async {
    try {
      _cacheBox = await Hive.openBox<String>(_boxName);
      Logger.error('✅ [TOPICS CACHE] Hive box initialized');
    } catch (e) {
      Logger.debug('❌ [TOPICS CACHE] Failed to initialize Hive box: $e');
    }
  }

  /// Gets cached topics for a specific cache key
  ///
  /// Returns null if cache doesn't exist or is expired
  Future<List<RecommendedGuideTopicModel>?> getCachedTopics(
    String cacheKey,
    Duration cacheExpiry,
  ) async {
    // Input validation
    if (cacheKey.trim().isEmpty) {
      throw ArgumentError('cacheKey cannot be empty');
    }
    if (cacheExpiry <= Duration.zero) {
      throw ArgumentError('cacheExpiry must be a positive Duration');
    }

    try {
      final box = _cacheBox;
      if (box == null) {
        Logger.warning('⚠️ [TOPICS CACHE] Box not initialized');
        return null;
      }

      final fullCacheKey = '$_cacheKeyPrefix$cacheKey';
      final timestampKey = '$fullCacheKey$_timestampSuffix';

      // Check if cache exists
      final cachedJson = box.get(fullCacheKey);
      final timestampStr = box.get(timestampKey);

      if (cachedJson == null || timestampStr == null) {
        Logger.debug('📭 [TOPICS CACHE] No cached data for key: $cacheKey');
        return null;
      }

      // Check if cache is expired
      final timestamp = DateTime.parse(timestampStr);
      final cacheAge = DateTime.now().difference(timestamp);

      if (cacheAge > cacheExpiry) {
        Logger.debug(
            '⏰ [TOPICS CACHE] Cache expired for $cacheKey (age: ${cacheAge.inMinutes} minutes)');
        // Remove expired cache
        await box.delete(fullCacheKey);
        await box.delete(timestampKey);
        return null;
      }

      // Parse cached JSON
      final List<dynamic> jsonList = json.decode(cachedJson);
      final topics = jsonList
          .map((json) => RecommendedGuideTopicModel.fromJson(json))
          .toList();

      Logger.debug(
          '✅ [TOPICS CACHE] Retrieved ${topics.length} topics from cache (age: ${cacheAge.inMinutes} minutes)');

      return topics;
    } catch (e) {
      Logger.debug('❌ [TOPICS CACHE] Error reading cache: $e');
      return null;
    }
  }

  /// Saves topics to cache with current timestamp
  ///
  /// **Note**: Empty topic lists are valid and cacheable. An empty list represents
  /// a valid API response indicating "no topics available" for the given criteria,
  /// and should be cached to avoid redundant API calls.
  Future<void> cacheTopics(
    String cacheKey,
    List<RecommendedGuideTopicModel> topics,
  ) async {
    // Input validation
    if (cacheKey.trim().isEmpty) {
      throw ArgumentError('cacheKey cannot be empty');
    }
    // Note: Empty lists are allowed - they represent valid "no topics" responses

    try {
      final box = _cacheBox;
      if (box == null) {
        Logger.debug('⚠️ [TOPICS CACHE] Box not initialized, cannot cache');
        return;
      }

      final fullCacheKey = '$_cacheKeyPrefix$cacheKey';
      final timestampKey = '$fullCacheKey$_timestampSuffix';

      // Convert topics to JSON
      final jsonList = topics.map((topic) => topic.toJson()).toList();
      final jsonString = json.encode(jsonList);

      // Save to Hive with timestamp
      await box.put(fullCacheKey, jsonString);
      await box.put(timestampKey, DateTime.now().toIso8601String());

      Logger.debug(
          '💾 [TOPICS CACHE] Cached ${topics.length} topics for key: $cacheKey');
    } catch (e) {
      Logger.debug('❌ [TOPICS CACHE] Error caching topics: $e');
    }
  }

  /// Clears all cached topics
  Future<void> clearCache() async {
    try {
      final box = _cacheBox;
      if (box == null) return;

      await box.clear();
      Logger.debug('🗑️ [TOPICS CACHE] All caches cleared');
    } catch (e) {
      Logger.debug('❌ [TOPICS CACHE] Error clearing cache: $e');
    }
  }

  /// Clears cached topics for a specific key
  Future<void> clearCacheForKey(String cacheKey) async {
    // Input validation
    if (cacheKey.trim().isEmpty) {
      throw ArgumentError('cacheKey cannot be empty');
    }

    try {
      final box = _cacheBox;
      if (box == null) return;

      final fullCacheKey = '$_cacheKeyPrefix$cacheKey';
      final timestampKey = '$fullCacheKey$_timestampSuffix';

      await box.delete(fullCacheKey);
      await box.delete(timestampKey);

      Logger.debug('🗑️ [TOPICS CACHE] Cache cleared for key: $cacheKey');
    } catch (e) {
      Logger.debug('❌ [TOPICS CACHE] Error clearing cache for key: $e');
    }
  }

  /// Clears all cached topics matching a given prefix
  ///
  /// This is useful for clearing category-specific caches like "for_you_*"
  /// without affecting other cached topics.
  Future<void> clearCacheByPrefix(String prefix) async {
    // Input validation
    if (prefix.trim().isEmpty) {
      throw ArgumentError('prefix cannot be empty');
    }

    try {
      final box = _cacheBox;
      if (box == null) return;

      final fullPrefix = '$_cacheKeyPrefix$prefix';

      // Find all keys that match the prefix
      final keysToDelete = box.keys
          .where((key) => key.toString().startsWith(fullPrefix))
          .toList();

      // Delete all matching keys
      for (final key in keysToDelete) {
        await box.delete(key);
      }

      Logger.debug(
          '🗑️ [TOPICS CACHE] Cleared ${keysToDelete.length} entries with prefix: $prefix');
    } catch (e) {
      Logger.debug('❌ [TOPICS CACHE] Error clearing cache by prefix: $e');
    }
  }

  /// Gets cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    final box = _cacheBox;
    if (box == null) {
      return {'initialized': false};
    }

    final cacheKeys = box.keys
        .where((key) =>
            key.toString().startsWith(_cacheKeyPrefix) &&
            !key.toString().endsWith(_timestampSuffix))
        .toList();

    return {
      'initialized': true,
      'total_cache_entries': cacheKeys.length,
      'cache_keys': cacheKeys,
      'box_size': box.length,
    };
  }

  /// Closes the Hive box
  Future<void> dispose() async {
    await _cacheBox?.close();
  }
}
