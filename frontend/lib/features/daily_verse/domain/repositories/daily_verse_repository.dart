import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/daily_verse_entity.dart';

/// Repository interface for daily verse operations
abstract class DailyVerseRepository {
  /// Get today's daily verse with caching support
  Future<Either<Failure, DailyVerseEntity>> getTodaysVerse(
      [VerseLanguage? language]);

  /// Get daily verse for a specific date
  Future<Either<Failure, DailyVerseEntity>> getDailyVerse(DateTime date,
      [VerseLanguage? language]);

  /// Get cached verse if available (offline support)
  Future<DailyVerseEntity?> getCachedVerse(DateTime date);

  /// Cache a verse for offline access
  Future<void> cacheVerse(DailyVerseEntity verse);

  /// Get preferred verse language
  Future<VerseLanguage> getPreferredLanguage();

  /// Set preferred verse language
  Future<void> setPreferredLanguage(VerseLanguage language);

  /// Check if service is available
  Future<bool> isServiceAvailable();

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats();

  /// Clear all cached data
  Future<void> clearCache();
}
