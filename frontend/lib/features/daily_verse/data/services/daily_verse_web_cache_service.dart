import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../domain/entities/daily_verse_entity.dart';
import 'daily_verse_cache_interface.dart';

/// Web-compatible caching service for daily verses using SharedPreferences only
/// This service provides the same interface as DailyVerseCacheService but works on web
class DailyVerseWebCacheService implements DailyVerseCacheInterface {
  static const String _keyPrefix = 'daily_verse_';
  static const String _lastFetchKey = 'last_daily_verse_fetch';
  static const String _preferredLanguageKey = 'preferred_verse_language';

  bool _isInitialized = false;

  /// Initialize the cache service (no-op for web)
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (kDebugMode) {
      print('🌐 [DAILY VERSE WEB CACHE] Initialized (using SharedPreferences)');
    }
  }

  /// Cache a daily verse using SharedPreferences
  @override
  Future<void> cacheVerse(DailyVerseEntity verse) async {
    await _ensureInitialized();

    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = _formatDateKey(verse.date);
      final verseData = {
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

      await prefs.setString('$_keyPrefix$dateKey', jsonEncode(verseData));
      await prefs.setString(_lastFetchKey, DateTime.now().toIso8601String());

      if (kDebugMode) {
        print('🌐 [DAILY VERSE WEB CACHE] Cached verse for $dateKey');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🌐 [DAILY VERSE WEB CACHE] Cache error: $e');
      }
    }
  }

  /// Get cached verse for a specific date
  @override
  Future<DailyVerseEntity?> getCachedVerse(DateTime date) async {
    await _ensureInitialized();

    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKey = _formatDateKey(date);
      final cachedData = prefs.getString('$_keyPrefix$dateKey');

      if (cachedData == null) return null;

      final verseMap = jsonDecode(cachedData) as Map<String, dynamic>;
      return _createVerseFromMap(verseMap);
    } catch (e) {
      if (kDebugMode) {
        print('🌐 [DAILY VERSE WEB CACHE] Get cache error: $e');
      }
      return null;
    }
  }

  /// Get today's cached verse
  @override
  Future<DailyVerseEntity?> getTodaysCachedVerse() async {
    return getCachedVerse(DateTime.now());
  }

  /// Check if we need to fetch a new verse (always true for web to ensure fresh content)
  @override
  Future<bool> shouldFetchTodaysVerse() async {
    // For web, we'll be more conservative and fetch fresh content more often
    // to avoid stale data since SharedPreferences is less reliable than Hive
    return true;
  }

  /// Check if cache should be refreshed (used by repository)
  @override
  Future<bool> shouldRefresh() async {
    // For web, always refresh to ensure fresh content
    // SharedPreferences is less reliable than Hive for caching
    return true;
  }

  /// Set preferred language
  @override
  Future<void> setPreferredLanguage(VerseLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferredLanguageKey, language.code);
    } catch (e) {
      if (kDebugMode) {
        print('🌐 [DAILY VERSE WEB CACHE] Set language error: $e');
      }
    }
  }

  /// Get preferred language
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
      if (kDebugMode) {
        print('🌐 [DAILY VERSE WEB CACHE] Get language error: $e');
      }
      return VerseLanguage.english;
    }
  }

  /// Clear all cached verses
  @override
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final verseKeys = keys.where((key) => key.startsWith(_keyPrefix));

      for (final String key in verseKeys) {
        await prefs.remove(key);
      }

      if (kDebugMode) {
        print(
            '🌐 [DAILY VERSE WEB CACHE] Cleared ${verseKeys.length} cached verses');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🌐 [DAILY VERSE WEB CACHE] Clear cache error: $e');
      }
    }
  }

  /// Get cache statistics (simplified for web)
  @override
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final verseKeys = keys.where((key) => key.startsWith(_keyPrefix));

      return {
        'total_verses': verseKeys.length,
        'cache_type': 'SharedPreferences (Web)',
        'last_cleanup': 'Not applicable',
      };
    } catch (e) {
      return {
        'total_verses': 0,
        'cache_type': 'SharedPreferences (Web)',
        'error': e.toString(),
      };
    }
  }

  /// Format date key for consistent storage
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Create verse entity from stored map
  DailyVerseEntity _createVerseFromMap(Map<String, dynamic> map) {
    return DailyVerseEntity(
      reference: map['reference'] as String,
      referenceTranslations: ReferenceTranslations(
        en: map['referenceEn'] as String? ?? map['reference'] as String,
        hi: map['referenceHi'] as String? ?? map['reference'] as String,
        ml: map['referenceMl'] as String? ?? map['reference'] as String,
      ),
      translations: DailyVerseTranslations(
        esv: map['esv'] as String,
        hindi: map['hindi'] as String,
        malayalam: map['malayalam'] as String,
      ),
      date: DateTime.parse(map['date'] as String),
    );
  }

  /// Ensure the service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }
}
