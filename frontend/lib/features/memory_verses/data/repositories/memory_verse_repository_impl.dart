import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../../domain/entities/review_session_entity.dart';
import '../../domain/entities/review_statistics_entity.dart';
import '../../domain/repositories/memory_verse_repository.dart';
import '../datasources/memory_verse_local_datasource.dart';
import '../datasources/memory_verse_remote_datasource.dart';

/// Implementation of MemoryVerseRepository with offline-first strategy.
///
/// Handles data access from both remote (Supabase) and local (Hive) sources.
/// Implements offline-first pattern:
/// 1. Try remote first when online
/// 2. Cache successful responses locally
/// 3. Fall back to cache when offline
/// 4. Queue offline operations for later sync
class MemoryVerseRepositoryImpl implements MemoryVerseRepository {
  final MemoryVerseLocalDataSource localDataSource;
  final MemoryVerseRemoteDataSource remoteDataSource;

  MemoryVerseRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, MemoryVerseEntity>> addVerseFromDaily({
    required String dailyVerseId,
  }) async {
    try {
      if (kDebugMode) {
        print('📖 [REPOSITORY] Adding verse from daily: $dailyVerseId');
      }

      // Try remote API
      final verseModel = await remoteDataSource.addVerseFromDaily(dailyVerseId);

      // Cache locally
      await localDataSource.cacheVerse(verseModel);

      if (kDebugMode) {
        print('✅ [REPOSITORY] Verse added and cached');
      }

      return Right(verseModel.toEntity());
    } on ServerException catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Server error: ${e.message}');
      }
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Network error: ${e.message}');
      }

      // Queue for sync when online
      await localDataSource.addToSyncQueue({
        'type': 'add_from_daily',
        'daily_verse_id': dailyVerseId,
      });

      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Unexpected error: $e');
      }
      return Left(ServerFailure(
          message: 'Failed to add verse: ${e.toString()}',
          code: 'UNEXPECTED_ERROR'));
    }
  }

  @override
  Future<Either<Failure, MemoryVerseEntity>> addVerseManually({
    required String verseReference,
    required String verseText,
    String? language,
  }) async {
    try {
      if (kDebugMode) {
        print('📖 [REPOSITORY] Adding manual verse: $verseReference');
      }

      // Try remote API
      final verseModel = await remoteDataSource.addVerseManually(
        verseReference: verseReference,
        verseText: verseText,
        language: language,
      );

      // Cache locally
      await localDataSource.cacheVerse(verseModel);

      if (kDebugMode) {
        print('✅ [REPOSITORY] Manual verse added and cached');
      }

      return Right(verseModel.toEntity());
    } on ServerException catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Server error: ${e.message}');
      }
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Network error: ${e.message}');
      }

      // Queue for sync when online
      await localDataSource.addToSyncQueue({
        'type': 'add_manual',
        'verse_reference': verseReference,
        'verse_text': verseText,
        if (language != null) 'language': language,
      });

      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Unexpected error: $e');
      }
      return Left(ServerFailure(
          message: 'Failed to add verse: ${e.toString()}',
          code: 'UNEXPECTED_ERROR'));
    }
  }

  @override
  Future<Either<Failure, (List<MemoryVerseEntity>, ReviewStatisticsEntity)>>
      getDueVerses({
    int limit = 20,
    int offset = 0,
    String? language,
  }) async {
    try {
      if (kDebugMode) {
        print('📖 [REPOSITORY] Fetching due verses');
      }

      // Try remote first
      final (versesModels, statsModel) = await remoteDataSource.getDueVerses(
        limit: limit,
        offset: offset,
        language: language,
      );

      // Cache verses locally
      await localDataSource.cacheVerses(versesModels);

      if (kDebugMode) {
        print('✅ [REPOSITORY] Fetched ${versesModels.length} verses');
      }

      final verses = versesModels.map((m) => m.toEntity()).toList();
      final stats = statsModel.toEntity();

      return Right((verses, stats));
    } on ServerException catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Server error: ${e.message}');
      }
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      if (kDebugMode) {
        print('⚠️ [REPOSITORY] Network error, using cache: ${e.message}');
      }

      // Fall back to local cache
      final cachedVerses = await localDataSource.getDueCachedVerses();

      if (cachedVerses.isEmpty) {
        return Left(NetworkFailure(
            message: 'No cached verses available offline',
            code: 'CACHE_EMPTY'));
      }

      final verses = cachedVerses.map((m) => m.toEntity()).toList();

      // Create basic statistics from cache
      final stats = ReviewStatisticsEntity(
        totalVerses: cachedVerses.length,
        dueVerses: cachedVerses.length,
        reviewedToday: 0,
        upcomingReviews: 0,
        masteredVerses: cachedVerses.where((v) => v.repetitions >= 5).length,
      );

      return Right((verses, stats));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Unexpected error: $e');
      }
      return Left(ServerFailure(
          message: 'Failed to fetch verses: ${e.toString()}',
          code: 'UNEXPECTED_ERROR'));
    }
  }

  @override
  Future<Either<Failure, MemoryVerseEntity>> submitReview({
    required String memoryVerseId,
    required int qualityRating,
    int? timeSpentSeconds,
  }) async {
    try {
      if (kDebugMode) {
        print('📖 [REPOSITORY] Submitting review for: $memoryVerseId');
      }

      // Try remote API
      final reviewData = await remoteDataSource.submitReview(
        memoryVerseId: memoryVerseId,
        qualityRating: qualityRating,
        timeSpentSeconds: timeSpentSeconds,
      );

      // Update local cache with new SM-2 state
      final cachedVerse =
          await localDataSource.getCachedVerseById(memoryVerseId);
      if (cachedVerse != null) {
        final updatedVerse = cachedVerse.copyWith(
          easeFactor: reviewData['ease_factor'] as double,
          intervalDays: reviewData['interval_days'] as int,
          repetitions: reviewData['repetitions'] as int,
          nextReviewDate:
              DateTime.parse(reviewData['next_review_date'] as String),
          lastReviewed: DateTime.now(),
          totalReviews: reviewData['total_reviews'] as int,
        );

        await localDataSource.cacheVerse(updatedVerse);

        if (kDebugMode) {
          print('✅ [REPOSITORY] Review submitted and cached');
        }

        return Right(updatedVerse.toEntity());
      }

      return const Left(ServerFailure(
          message: 'Failed to update local cache',
          code: 'CACHE_UPDATE_FAILED'));
    } on ServerException catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Server error: ${e.message}');
      }
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Network error: ${e.message}');
      }

      // Queue review for sync when online
      await localDataSource.addToSyncQueue({
        'type': 'submit_review',
        'memory_verse_id': memoryVerseId,
        'quality_rating': qualityRating,
        if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      });

      return const Left(NetworkFailure(
          message: 'Review queued for sync when online',
          code: 'OFFLINE_QUEUED'));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Unexpected error: $e');
      }
      return Left(ServerFailure(
          message: 'Failed to submit review: ${e.toString()}',
          code: 'UNEXPECTED_ERROR'));
    }
  }

  @override
  Future<Either<Failure, ReviewStatisticsEntity>> getStatistics() async {
    try {
      if (kDebugMode) {
        print('📖 [REPOSITORY] Fetching statistics');
      }

      // Fetch due verses which includes statistics
      final result = await getDueVerses(limit: 1);

      return result.fold(
        (failure) => Left(failure),
        (data) {
          final (_, stats) = data;
          return Right(stats);
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Error fetching statistics: $e');
      }
      return Left(ServerFailure(
          message: 'Failed to fetch statistics: ${e.toString()}',
          code: 'STATS_FETCH_FAILED'));
    }
  }

  @override
  Future<Either<Failure, MemoryVerseEntity>> getVerseById(String id) async {
    try {
      if (kDebugMode) {
        print('🔍 [REPOSITORY] Looking up verse by ID: $id');
      }

      // Try cache first for single verse lookup
      final cachedVerse = await localDataSource.getCachedVerseById(id);

      if (cachedVerse != null) {
        if (kDebugMode) {
          print('✅ [REPOSITORY] Found verse in cache');
        }
        return Right(cachedVerse.toEntity());
      }

      if (kDebugMode) {
        print('⚠️ [REPOSITORY] Verse not in cache, fetching from remote...');
      }

      // If not in cache, fetch from remote
      final verseModel = await remoteDataSource.getVerseById(id);

      if (kDebugMode) {
        print('📥 [REPOSITORY] Caching verse from remote...');
      }

      // Cache the fetched verse for future lookups
      await localDataSource.cacheVerse(verseModel);

      if (kDebugMode) {
        print('✅ [REPOSITORY] Verse fetched and cached successfully');
      }

      return Right(verseModel.toEntity());
    } on ServerException catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Server error getting verse by ID: ${e.message}');
      }
      return Left(ServerFailure(
        message: e.message,
        code: e.code,
      ));
    } on NetworkException catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Network error getting verse by ID: ${e.message}');
      }
      return Left(NetworkFailure(
        message: e.message,
        code: e.code,
      ));
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Unexpected error getting verse by ID: $e');
      }
      return Left(ServerFailure(
        message: 'Failed to get verse: ${e.toString()}',
        code: 'GET_VERSE_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, List<MemoryVerseEntity>>> getAllVerses() async {
    try {
      final cachedVerses = await localDataSource.getAllCachedVerses();
      final verses = cachedVerses.map((m) => m.toEntity()).toList();
      return Right(verses);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Error getting all verses: $e');
      }
      return Left(ServerFailure(
          message: 'Failed to get verses: ${e.toString()}',
          code: 'GET_VERSES_FAILED'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteVerse(String id) async {
    try {
      await localDataSource.removeVerse(id);

      // Queue for remote deletion
      await localDataSource.addToSyncQueue({
        'type': 'delete_verse',
        'verse_id': id,
      });

      return const Right(unit);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Error deleting verse: $e');
      }
      return Left(ServerFailure(
          message: 'Failed to delete verse: ${e.toString()}',
          code: 'DELETE_FAILED'));
    }
  }

  @override
  Future<Either<Failure, List<ReviewSessionEntity>>> getReviewHistory({
    required String memoryVerseId,
    int limit = 50,
  }) async {
    // Note: Review history would need additional API endpoint and local storage
    // For now, return empty list
    return const Right([]);
  }

  @override
  Future<Either<Failure, Unit>> syncWithRemote() async {
    try {
      if (kDebugMode) {
        print('🔄 [REPOSITORY] Starting sync...');
      }

      final syncQueue = await localDataSource.getSyncQueue();

      if (syncQueue.isEmpty) {
        if (kDebugMode) {
          print('✅ [REPOSITORY] Nothing to sync');
        }
        return const Right(unit);
      }

      // Process each queued operation
      bool hadFailure = false;

      for (final operation in syncQueue) {
        try {
          final type = operation['type'] as String;

          switch (type) {
            case 'add_from_daily':
              await remoteDataSource.addVerseFromDaily(
                operation['daily_verse_id'] as String,
              );
              break;

            case 'add_manual':
              await remoteDataSource.addVerseManually(
                verseReference: operation['verse_reference'] as String,
                verseText: operation['verse_text'] as String,
                language: operation['language'] as String?,
              );
              break;

            case 'submit_review':
              await remoteDataSource.submitReview(
                memoryVerseId: operation['memory_verse_id'] as String,
                qualityRating: operation['quality_rating'] as int,
                timeSpentSeconds: operation['time_spent_seconds'] as int?,
              );
              break;

            case 'delete_verse':
              await remoteDataSource.deleteVerse(
                operation['verse_id'] as String,
              );
              break;

            default:
              if (kDebugMode) {
                print('⚠️ [REPOSITORY] Unknown sync operation: $type');
              }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ [REPOSITORY] Failed to sync operation: $e');
            print(
                '⏸️ [REPOSITORY] Stopping sync to preserve failed operations');
          }
          hadFailure = true;
          break; // Stop processing further operations
        }
      }

      // Only clear sync queue and update timestamp if all operations succeeded
      if (!hadFailure) {
        await localDataSource.clearSyncQueue();
        await localDataSource.updateLastSyncTime();

        if (kDebugMode) {
          print(
              '✅ [REPOSITORY] Sync completed - all operations synced successfully');
        }

        return const Right(unit);
      } else {
        if (kDebugMode) {
          print(
              '⚠️ [REPOSITORY] Sync incomplete - failed operations remain queued for retry');
        }

        // Return failure to indicate sync was not fully successful
        return const Left(
          ServerFailure(
            message: 'Sync failed - some operations could not be completed',
            code: 'SYNC_INCOMPLETE',
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Sync failed: $e');
      }
      return Left(ServerFailure(
          message: 'Sync failed: ${e.toString()}', code: 'SYNC_FAILED'));
    }
  }

  @override
  Future<Either<Failure, Unit>> clearLocalCache() async {
    try {
      await localDataSource.clearCache();
      return const Right(unit);
    } catch (e) {
      if (kDebugMode) {
        print('❌ [REPOSITORY] Failed to clear cache: $e');
      }
      return Left(ServerFailure(
          message: 'Failed to clear cache: ${e.toString()}',
          code: 'CACHE_CLEAR_FAILED'));
    }
  }
}
