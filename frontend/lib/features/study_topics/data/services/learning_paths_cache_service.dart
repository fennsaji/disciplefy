import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/utils/logger.dart';
import 'package:disciplefy_bible_study/features/study_topics/data/services/learning_cache_scope.dart';

/// Persistent cache for learning paths API responses using Hive.
///
/// Caches raw JSON response strings keyed by user + type + language
/// (e.g., `'userId|categories_en'`). The responses carry the user's enrollment
/// and progress, and this box survives logout, so the user id is part of the
/// key: another account never reads them.
///
/// Entries are valid for 24 hours, except the recommended ("continue
/// learning") path, which is kept for [_recommendedCacheDurationHours] — it is
/// only ever shown while a fresh copy is being fetched.
class LearningPathsCacheService {
  static const String _boxName = 'learning_paths_cache';
  static const int _cacheDurationHours = 24;
  static const int _recommendedCacheDurationHours = 24 * 7;

  /// Cache type of the recommended ("continue learning") path.
  static const String recommendedType = 'recommended';

  // Never hold onto the Box. Logout calls a global `Hive.close()`
  // (LocalStoreRepositoryImpl.clearAll), which closes every box; a cached
  // reference then throws "Box has already been closed" on the next access.
  // Re-resolve (reopening if needed) each time instead.
  Future<Box<Map>> get _box async => Hive.isBoxOpen(_boxName)
      ? Hive.box<Map>(_boxName)
      : await Hive.openBox<Map>(_boxName);

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _box;
      _isInitialized = true;
      await _cleanupOldEntries();
    } catch (e) {
      Logger.debug('⚠️ [LP_CACHE] Failed to initialize: $e');
    }
  }

  /// Store a raw JSON response string in the cache.
  Future<void> cacheResponse({
    required String type,
    required String language,
    required String responseBody,
  }) async {
    await _ensureInitialized();
    try {
      final key = _cacheKey(type, language);
      await (await _box).put(key, {
        'response_body': responseBody,
        'cached_at': DateTime.now().toIso8601String(),
        'ttl_hours': _ttlHours(type),
      });
      Logger.debug('✅ [LP_CACHE] Cached $key');
    } catch (e) {
      Logger.debug('❌ [LP_CACHE] Failed to cache $type/$language: $e');
    }
  }

  /// Returns the cached raw JSON response body, or null if absent/expired.
  Future<String?> getCachedResponse({
    required String type,
    required String language,
  }) async {
    await _ensureInitialized();
    try {
      final key = _cacheKey(type, language);
      final data = (await _box).get(key);
      if (data == null) return null;

      final cachedAt = DateTime.parse(data['cached_at'] as String);
      if (DateTime.now().difference(cachedAt).inHours >= _ttlHours(type)) {
        await (await _box).delete(key);
        Logger.debug('⏰ [LP_CACHE] Expired: $key');
        return null;
      }

      Logger.debug('✅ [LP_CACHE] Cache hit: $key');
      return data['response_body'] as String;
    } catch (e) {
      Logger.debug('❌ [LP_CACHE] Error reading cache: $e');
      return null;
    }
  }

  /// Clears all cached learning paths data (call after enrollment).
  Future<void> clearCache() async {
    await _ensureInitialized();
    try {
      await (await _box).clear();
      Logger.debug('🗑️ [LP_CACHE] Cache cleared');
    } catch (e) {
      Logger.debug('❌ [LP_CACHE] Failed to clear cache: $e');
    }
  }

  String _cacheKey(String type, String language) =>
      '${LearningCacheScope.currentUserKey()}|${type}_$language';

  static int _ttlHours(String type) => type == recommendedType
      ? _recommendedCacheDurationHours
      : _cacheDurationHours;

  Future<void> _cleanupOldEntries() async {
    try {
      final now = DateTime.now();
      final toDelete = <dynamic>[];
      for (final key in (await _box).keys) {
        final data = (await _box).get(key);
        if (data?['cached_at'] != null) {
          final cachedAt = DateTime.parse(data!['cached_at'] as String);
          final ttl = (data['ttl_hours'] as int?) ?? _cacheDurationHours;
          if (now.difference(cachedAt).inHours >= ttl) toDelete.add(key);
        }
      }
      for (final key in toDelete) {
        await (await _box).delete(key);
      }
      if (toDelete.isNotEmpty) {
        Logger.debug(
            '🗑️ [LP_CACHE] Cleaned up ${toDelete.length} expired entries');
      }
    } catch (e) {
      Logger.debug('⚠️ [LP_CACHE] Cleanup failed: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await initialize();
  }
}
