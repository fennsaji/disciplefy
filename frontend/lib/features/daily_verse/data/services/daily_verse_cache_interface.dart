import '../../domain/entities/daily_verse_entity.dart';

/// Abstract interface for daily verse caching services
/// This allows for platform-specific implementations (Hive for mobile, SharedPreferences for web)
abstract class DailyVerseCacheInterface {
  /// Initialize the cache service
  Future<void> initialize();

  /// Cache a daily verse
  Future<void> cacheVerse(DailyVerseEntity verse);

  /// Get cached verse for a specific date
  Future<DailyVerseEntity?> getCachedVerse(DateTime date);

  /// Get today's cached verse
  Future<DailyVerseEntity?> getTodaysCachedVerse();

  /// Check if we need to fetch a new verse
  Future<bool> shouldFetchTodaysVerse();

  /// Check if we should refresh the cache (used by repository)
  Future<bool> shouldRefresh();

  /// Set preferred language
  Future<void> setPreferredLanguage(VerseLanguage language);

  /// Get preferred language
  Future<VerseLanguage> getPreferredLanguage();

  /// Clear all cached verses
  Future<void> clearCache();

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats();
}
