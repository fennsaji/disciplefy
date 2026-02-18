import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../datasources/memory_verse_local_datasource.dart';
import '../models/memory_verse_model.dart';
import '../services/memory_verse_sync_service.dart';
import '../../../../core/utils/logger.dart';

/// Helper class for common repository operations.
///
/// Provides reusable error handling, logging, and cache management functions
/// to reduce code duplication across repository methods.
class MemoryVerseRepositoryHelper {
  final MemoryVerseLocalDataSource _localDataSource;
  final MemoryVerseSyncService _syncService;

  const MemoryVerseRepositoryHelper({
    required MemoryVerseLocalDataSource localDataSource,
    required MemoryVerseSyncService syncService,
  })  : _localDataSource = localDataSource,
        _syncService = syncService;

  /// Executes a remote operation with automatic caching and error handling.
  ///
  /// Handles:
  /// - Debug logging
  /// - Remote API call
  /// - Local caching on success
  /// - Error handling (server, network, generic)
  /// - Offline queueing on network errors
  ///
  /// [operation] - The remote operation to execute
  /// [cacheResult] - Whether to cache the result (default: true)
  /// [queueOnFailure] - Operation data to queue if network fails (optional)
  /// [operationName] - Name for logging purposes
  Future<Either<Failure, T>> executeWithCaching<T>({
    required Future<T> Function() operation,
    required T Function(dynamic) mapToEntity,
    bool cacheResult = true,
    Map<String, dynamic>? queueOnFailure,
    required String operationName,
  }) async {
    try {
      logDebug('Starting: $operationName');

      final result = await operation();

      // Cache if enabled and result is a model
      if (cacheResult && result is MemoryVerseModel) {
        await _localDataSource.cacheVerse(result);
      }

      logSuccess('Completed: $operationName');

      return Right(mapToEntity(result));
    } on ServerException catch (e) {
      logError('Server error in $operationName: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      logError('Network error in $operationName: ${e.message}');

      // Queue for sync if specified
      if (queueOnFailure != null) {
        try {
          await _syncService.queueOperation(queueOnFailure);
        } catch (queueError, stackTrace) {
          logError(
            'Failed to queue operation after network error in $operationName: $queueError',
          );
          // Log stack trace in debug mode for troubleshooting
          Logger.debug('Stack trace: $stackTrace');
          // Continue to return NetworkFailure despite queueing error
        }
      }

      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      logError('Unexpected error in $operationName: $e');
      return Left(ServerFailure(
        message: 'Failed to complete $operationName: ${e.toString()}',
        code: 'UNEXPECTED_ERROR',
      ));
    }
  }

  /// Caches a list of verses locally.
  Future<void> cacheVerses(List<MemoryVerseModel> verses) async {
    await _localDataSource.cacheVerses(verses);
  }

  /// Updates a cached verse with new SM-2 algorithm state after review.
  Future<MemoryVerseModel?> updateVerseAfterReview({
    required String memoryVerseId,
    required Map<String, dynamic> reviewData,
  }) async {
    final cachedVerse =
        await _localDataSource.getCachedVerseById(memoryVerseId);

    if (cachedVerse == null) {
      return null;
    }

    final updatedVerse = cachedVerse.copyWith(
      easeFactor: reviewData['ease_factor'] as double,
      intervalDays: reviewData['interval_days'] as int,
      repetitions: reviewData['repetitions'] as int,
      nextReviewDate: DateTime.parse(reviewData['next_review_date'] as String),
      lastReviewed: DateTime.now(),
      totalReviews: reviewData['total_reviews'] as int,
    );

    await _localDataSource.cacheVerse(updatedVerse);
    return updatedVerse;
  }

  /// Gets a verse from cache by ID.
  Future<MemoryVerseModel?> getCachedVerseById(String id) async {
    return _localDataSource.getCachedVerseById(id);
  }

  /// Gets all cached verses from local storage.
  Future<List<MemoryVerseModel>> getAllCachedVerses() async {
    return _localDataSource.getAllCachedVerses();
  }

  /// Gets due verses from cache (offline fallback).
  Future<List<MemoryVerseModel>> getDueCachedVerses() async {
    return _localDataSource.getDueCachedVerses();
  }

  /// Removes a verse from local cache.
  Future<void> removeVerseFromCache(String id) async {
    await _localDataSource.removeVerse(id);
  }

  /// Clears all local cache.
  Future<void> clearCache() async {
    await _localDataSource.clearCache();
  }

  // ============================================================================
  // Logging Helpers
  // ============================================================================

  /// Logs a debug message.
  void logDebug(String message) {
    Logger.info('📖 [REPOSITORY] $message');
  }

  /// Logs a success message.
  void logSuccess(String message) {
    Logger.debug('✅ [REPOSITORY] $message');
  }

  /// Logs an error message.
  void logError(String message) {
    Logger.error('❌ [REPOSITORY] $message');
  }

  /// Logs a warning message.
  void logWarning(String message) {
    Logger.debug('⚠️ [REPOSITORY] $message');
  }

  /// Logs an info message.
  void logInfo(String message) {
    Logger.debug('🔍 [REPOSITORY] $message');
  }
}
