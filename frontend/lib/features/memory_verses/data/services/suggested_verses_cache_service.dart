import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/suggested_verse_entity.dart';
import '../../../../core/utils/logger.dart';

/// Local caching service for suggested verses using Hive
///
/// Caches suggested verses per language and category combination to reduce
/// unnecessary API calls. Cache is valid for 7 days since suggested verses
/// don't change frequently.
class SuggestedVersesCacheService {
  static const String _boxName = 'suggested_verses_cache';
  static const int _cacheDurationDays = 7; // Cache valid for 7 days

  late Box<Map> _cacheBox;
  bool _isInitialized = false;

  /// Initialize the cache service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive if not already done
      if (!Hive.isBoxOpen(_boxName)) {
        _cacheBox = await Hive.openBox<Map>(_boxName);
      } else {
        _cacheBox = Hive.box<Map>(_boxName);
      }
      _isInitialized = true;

      // Clean up old entries
      await _cleanupOldEntries();
    } catch (e) {
      Logger.debug('⚠️ Failed to initialize suggested verses cache: $e');
      throw Exception('Failed to initialize suggested verses cache: $e');
    }
  }

  /// Cache suggested verses for a specific language and category
  Future<void> cacheVerses({
    required List<SuggestedVerseEntity> verses,
    required List<SuggestedVerseCategory> categories,
    required String language,
    String? category,
  }) async {
    await _ensureInitialized();

    try {
      final cacheKey = _generateCacheKey(language, category);
      final cacheData = {
        'verses': verses.map((v) => _verseToMap(v)).toList(),
        'categories': categories.map((c) => c.name).toList(),
        'language': language,
        'category': category,
        'total': verses.length,
        'cached_at': DateTime.now().toIso8601String(),
      };

      await _cacheBox.put(cacheKey, cacheData);

      Logger.debug(
          '✅ [CACHE] Cached ${verses.length} suggested verses ($cacheKey)');
    } catch (e) {
      Logger.debug('❌ [CACHE] Failed to cache suggested verses: $e');
    }
  }

  /// Get cached suggested verses for a specific language and category
  Future<CachedSuggestedVersesData?> getCachedVerses({
    required String language,
    String? category,
  }) async {
    await _ensureInitialized();

    try {
      final cacheKey = _generateCacheKey(language, category);
      final cacheData = _cacheBox.get(cacheKey);

      if (cacheData == null) {
        Logger.debug('📭 [CACHE] No cached verses found ($cacheKey)');
        return null;
      }

      // Check if cache is still valid
      final cachedAt = DateTime.parse(cacheData['cached_at'] as String);
      final cacheAge = DateTime.now().difference(cachedAt);

      if (cacheAge.inDays > _cacheDurationDays) {
        Logger.debug(
            '⏰ [CACHE] Cache expired (${cacheAge.inDays} days old) ($cacheKey)');
        await _cacheBox.delete(cacheKey);
        return null;
      }

      // Convert cached data back to entities
      final verses = (cacheData['verses'] as List)
          .map((v) => _mapToVerse(v as Map))
          .toList();
      final categories = (cacheData['categories'] as List)
          .map((c) => SuggestedVerseCategory.fromString(c as String))
          .toList();

      Logger.debug(
          '✅ [CACHE] Using cached verses (${verses.length} verses, ${cacheAge.inHours}h old) ($cacheKey)');

      return CachedSuggestedVersesData(
        verses: verses,
        categories: categories,
        total: cacheData['total'] as int,
        cachedAt: cachedAt,
      );
    } catch (e) {
      Logger.debug('❌ [CACHE] Error reading cache: $e');
      return null;
    }
  }

  /// Check if cache exists and is valid for specific language/category
  Future<bool> isCacheValid({
    required String language,
    String? category,
  }) async {
    await _ensureInitialized();

    try {
      final cacheKey = _generateCacheKey(language, category);
      final cacheData = _cacheBox.get(cacheKey);

      if (cacheData == null) return false;

      final cachedAt = DateTime.parse(cacheData['cached_at'] as String);
      final cacheAge = DateTime.now().difference(cachedAt);

      return cacheAge.inDays <= _cacheDurationDays;
    } catch (e) {
      return false;
    }
  }

  /// Clear all cached suggested verses
  Future<void> clearCache() async {
    await _ensureInitialized();

    try {
      await _cacheBox.clear();
      Logger.debug('🗑️ [CACHE] Cleared all suggested verses cache');
    } catch (e) {
      Logger.debug('❌ [CACHE] Failed to clear cache: $e');
    }
  }

  /// Clear cache for specific language/category
  Future<void> clearCacheForKey({
    required String language,
    String? category,
  }) async {
    await _ensureInitialized();

    try {
      final cacheKey = _generateCacheKey(language, category);
      await _cacheBox.delete(cacheKey);
      Logger.debug('🗑️ [CACHE] Cleared cache for $cacheKey');
    } catch (e) {
      Logger.debug('❌ [CACHE] Failed to clear cache for key: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    await _ensureInitialized();

    return {
      'total_cache_entries': _cacheBox.length,
      'cache_size_estimate_bytes': _cacheBox.length * 10000, // ~10KB per entry
      'cache_duration_days': _cacheDurationDays,
    };
  }

  /// Generate cache key from language and category
  String _generateCacheKey(String language, String? category) {
    return category != null ? '${language}_$category' : '${language}_all';
  }

  /// Convert verse entity to map for storage
  Map<String, dynamic> _verseToMap(SuggestedVerseEntity verse) {
    return {
      'id': verse.id,
      'reference': verse.reference,
      'localized_reference': verse.localizedReference,
      'verse_text': verse.verseText,
      'book': verse.book,
      'chapter': verse.chapter,
      'verse_start': verse.verseStart,
      'verse_end': verse.verseEnd,
      'category': verse.category.name,
      'tags': verse.tags,
      'is_already_added': verse.isAlreadyAdded,
    };
  }

  /// Convert map back to verse entity
  SuggestedVerseEntity _mapToVerse(Map map) {
    return SuggestedVerseEntity(
      id: map['id'] as String,
      reference: map['reference'] as String,
      localizedReference: map['localized_reference'] as String,
      verseText: map['verse_text'] as String,
      book: map['book'] as String,
      chapter: map['chapter'] as int,
      verseStart: map['verse_start'] as int,
      verseEnd: map['verse_end'] as int?,
      category: SuggestedVerseCategory.fromString(map['category'] as String),
      tags: List<String>.from(map['tags'] as List),
      isAlreadyAdded: map['is_already_added'] as bool,
    );
  }

  /// Cleanup old cache entries (older than cache duration)
  Future<void> _cleanupOldEntries() async {
    try {
      final cutoffDate =
          DateTime.now().subtract(Duration(days: _cacheDurationDays));
      final keysToDelete = <String>[];

      for (final key in _cacheBox.keys) {
        final cacheData = _cacheBox.get(key);
        if (cacheData != null && cacheData['cached_at'] != null) {
          final cachedAt = DateTime.parse(cacheData['cached_at'] as String);
          if (cachedAt.isBefore(cutoffDate)) {
            keysToDelete.add(key as String);
          }
        }
      }

      for (final key in keysToDelete) {
        await _cacheBox.delete(key);
      }

      if (kDebugMode && keysToDelete.isNotEmpty) {
        Logger.debug(
            '🗑️ [CACHE] Cleaned up ${keysToDelete.length} old cache entries');
      }
    } catch (e) {
      Logger.debug('⚠️ [CACHE] Failed to cleanup old entries: $e');
    }
  }

  /// Ensure cache is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_isInitialized && _cacheBox.isOpen) {
      await _cacheBox.close();
      _isInitialized = false;
    }
  }
}

/// Data class for cached suggested verses
class CachedSuggestedVersesData {
  final List<SuggestedVerseEntity> verses;
  final List<SuggestedVerseCategory> categories;
  final int total;
  final DateTime cachedAt;

  const CachedSuggestedVersesData({
    required this.verses,
    required this.categories,
    required this.total,
    required this.cachedAt,
  });
}
