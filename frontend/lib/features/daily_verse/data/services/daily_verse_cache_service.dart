import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/daily_verse_entity.dart';
import 'daily_verse_cache_interface.dart';
import '../../../../core/utils/logger.dart';

/// Local caching service for daily verses using Hive for structured data
/// and SharedPreferences for simple settings
class DailyVerseCacheService implements DailyVerseCacheInterface {
  static const String _boxName = 'daily_verses';
  static const String _lastFetchKey = 'last_daily_verse_fetch';
  static const String _preferredLanguageKey = 'preferred_verse_language';

  late Box<Map> _verseBox;
  bool _isInitialized = false;

  /// Initialize the cache service
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive if not already done
      if (!Hive.isAdapterRegistered(0)) {
        await Hive.initFlutter();
      }

      // Open verse cache box
      _verseBox = await Hive.openBox<Map>(_boxName);
      _isInitialized = true;

      // Clean up old entries
      await _cleanupOldEntries();
    } catch (e) {
      throw Exception('Failed to initialize daily verse cache: $e');
    }
  }

  /// Cache a daily verse
  @override
  Future<void> cacheVerse(DailyVerseEntity verse) async {
    await _ensureInitialized();

    try {
      final dateKey = _formatDateKey(verse.date);
      final verseData = {
        'id': verse.id, // UUID from backend
        'reference': verse.reference,
        'referenceEn': verse.referenceTranslations.en,
        'referenceHi': verse.referenceTranslations.hi,
        'referenceMl': verse.referenceTranslations.ml,
        'esv': verse.translations.esv,
        'hindi': verse.translations.hindi,
        'malayalam': verse.translations.malayalam,
        'date': verse.date.toIso8601String(),
        'cached_at': DateTime.now().toIso8601String(),
      };

      await _verseBox.put(dateKey, verseData);
      await _updateLastFetchTime();
    } catch (e) {
      throw Exception('Failed to cache daily verse: $e');
    }
  }

  /// Get cached verse for a specific date
  @override
  Future<DailyVerseEntity?> getCachedVerse(DateTime date) async {
    await _ensureInitialized();

    try {
      final dateKey = _formatDateKey(date);
      final verseData = _verseBox.get(dateKey);

      if (verseData == null) return null;

      // Use cached ID or generate a temporary one for legacy cached entries
      final id = verseData['id'] as String? ?? 'temp-$dateKey';

      return DailyVerseEntity(
        id: id,
        reference: verseData['reference'] as String,
        referenceTranslations: ReferenceTranslations(
          en: verseData['referenceEn'] as String? ??
              verseData['reference'] as String,
          hi: verseData['referenceHi'] as String? ??
              verseData['reference'] as String,
          ml: verseData['referenceMl'] as String? ??
              verseData['reference'] as String,
        ),
        translations: DailyVerseTranslations(
          esv: verseData['esv'] as String,
          hindi: verseData['hindi'] as String,
          malayalam: verseData['malayalam'] as String,
        ),
        date: DateTime.parse(verseData['date'] as String),
      );
    } catch (e) {
      // Return null if parsing fails
      return null;
    }
  }

  /// Get today's cached verse
  @override
  Future<DailyVerseEntity?> getTodaysCachedVerse() async =>
      getCachedVerse(DateTime.now());

  /// Check if we need to fetch a new verse
  /// Uses same midnight boundary logic as shouldRefresh() for consistency
  @override
  Future<bool> shouldFetchTodaysVerse() async {
    await _ensureInitialized();

    // Check if we have today's verse cached
    final todaysVerse = await getTodaysCachedVerse();
    if (todaysVerse == null) return true;

    // Check if the cached verse is actually for today
    if (!todaysVerse.isToday) return true;

    // Check if last fetch was before today's midnight (same as shouldRefresh)
    final lastFetch = await getLastFetchTime();
    if (lastFetch == null) return true;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // Refresh if last fetch was before today's midnight
    return lastFetch.isBefore(todayMidnight);
  }

  /// Check if verse is cached for a specific date
  Future<bool> isVerseCached(DateTime date) async {
    await _ensureInitialized();
    final dateKey = _formatDateKey(date);
    return _verseBox.containsKey(dateKey);
  }

  /// Get preferred verse language
  @override
  Future<VerseLanguage> getPreferredLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_preferredLanguageKey) ?? 'en';

      switch (languageCode) {
        case 'hi':
          return VerseLanguage.hindi;
        case 'ml':
          return VerseLanguage.malayalam;
        default:
          return VerseLanguage.english;
      }
    } catch (e) {
      return VerseLanguage.english; // Default fallback
    }
  }

  /// Set preferred verse language
  @override
  Future<void> setPreferredLanguage(VerseLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferredLanguageKey, language.code);
    } catch (e) {
      throw Exception('Failed to save preferred language: $e');
    }
  }

  /// Get last fetch time
  Future<DateTime?> getLastFetchTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastFetchKey);

      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      return null;
    }
  }

  /// Check if cache should be refreshed (daily, at midnight)
  /// Returns true if we need to fetch a new verse because:
  /// - No verse has been cached yet
  /// - The last fetch was before today (midnight has passed)
  /// - Today's verse is not cached
  @override
  Future<bool> shouldRefresh() async {
    final lastFetch = await getLastFetchTime();
    if (lastFetch == null) return true;

    // Check if last fetch was before today's midnight (start of day)
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // If last fetch was before today's midnight, we need to refresh
    if (lastFetch.isBefore(todayMidnight)) {
      return true;
    }

    // Also check if today's verse is actually cached
    final todaysVerse = await getTodaysCachedVerse();
    return todaysVerse == null || !todaysVerse.isToday;
  }

  /// Get cache statistics
  @override
  Future<Map<String, dynamic>> getCacheStats() async {
    await _ensureInitialized();

    return {
      'total_cached_verses': _verseBox.length,
      'last_fetch': await getLastFetchTime(),
      'preferred_language': (await getPreferredLanguage()).displayName,
      'cache_size_bytes': _estimateCacheSize(),
    };
  }

  /// Clear all cached verses
  @override
  Future<void> clearCache() async {
    await _ensureInitialized();

    try {
      await _verseBox.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastFetchKey);
    } catch (e) {
      throw Exception('Failed to clear cache: $e');
    }
  }

  /// Cleanup old cache entries (older than 30 days)
  Future<void> _cleanupOldEntries() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final keysToDelete = <String>[];

      for (final key in _verseBox.keys) {
        final verseData = _verseBox.get(key);
        if (verseData != null && verseData['cached_at'] != null) {
          final cachedAt = DateTime.parse(verseData['cached_at'] as String);
          if (cachedAt.isBefore(cutoffDate)) {
            keysToDelete.add(key as String);
          }
        }
      }

      for (final key in keysToDelete) {
        await _verseBox.delete(key);
      }
    } catch (e) {
      // Non-critical error, just log and continue
      Logger.debug('Warning: Failed to cleanup old cache entries: $e');
    }
  }

  /// Update last fetch timestamp
  Future<void> _updateLastFetchTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastFetchKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Non-critical error
      Logger.debug('Warning: Failed to update last fetch time: $e');
    }
  }

  /// Format date as key for consistent caching
  String _formatDateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Estimate cache size in bytes (rough approximation)
  int _estimateCacheSize() {
    return _verseBox.length * 1500; // Rough estimate: ~1.5KB per verse
  }

  /// Ensure cache is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (_isInitialized) {
      await _verseBox.close();
      _isInitialized = false;
    }
  }
}
