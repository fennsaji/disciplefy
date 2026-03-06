import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/utils/logger.dart';

/// Persistent cache for learning paths API responses using Hive.
///
/// Caches raw JSON response strings keyed by type + language (e.g., 'categories_en').
/// Cache is valid for 24 hours and survives app restarts.
class LearningPathsCacheService {
  static const String _boxName = 'learning_paths_cache';
  static const int _cacheDurationHours = 24;

  late Box<Map> _cacheBox;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _cacheBox = Hive.isBoxOpen(_boxName)
          ? Hive.box<Map>(_boxName)
          : await Hive.openBox<Map>(_boxName);
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
      await _cacheBox.put(key, {
        'response_body': responseBody,
        'cached_at': DateTime.now().toIso8601String(),
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
      final data = _cacheBox.get(key);
      if (data == null) return null;

      final cachedAt = DateTime.parse(data['cached_at'] as String);
      if (DateTime.now().difference(cachedAt).inHours >= _cacheDurationHours) {
        await _cacheBox.delete(key);
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
      await _cacheBox.clear();
      Logger.debug('🗑️ [LP_CACHE] Cache cleared');
    } catch (e) {
      Logger.debug('❌ [LP_CACHE] Failed to clear cache: $e');
    }
  }

  String _cacheKey(String type, String language) => '${type}_$language';

  Future<void> _cleanupOldEntries() async {
    try {
      final cutoff =
          DateTime.now().subtract(const Duration(hours: _cacheDurationHours));
      final toDelete = <dynamic>[];
      for (final key in _cacheBox.keys) {
        final data = _cacheBox.get(key);
        if (data?['cached_at'] != null) {
          final cachedAt = DateTime.parse(data!['cached_at'] as String);
          if (cachedAt.isBefore(cutoff)) toDelete.add(key);
        }
      }
      for (final key in toDelete) {
        await _cacheBox.delete(key);
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
