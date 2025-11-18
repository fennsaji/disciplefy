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
import '../helpers/memory_verse_repository_helper.dart';
import '../services/memory_verse_sync_service.dart';

/// Implementation of MemoryVerseRepository with offline-first strategy.
///
/// Handles data access from both remote (Supabase) and local (Hive) sources.
/// Implements offline-first pattern:
/// 1. Try remote first when online
/// 2. Cache successful responses locally
/// 3. Fall back to cache when offline
/// 4. Queue offline operations for later sync
class MemoryVerseRepositoryImpl implements MemoryVerseRepository {
  final MemoryVerseRemoteDataSource _remoteDataSource;
  final MemoryVerseRepositoryHelper _helper;
  final MemoryVerseSyncService _syncService;

  factory MemoryVerseRepositoryImpl({
    required MemoryVerseLocalDataSource localDataSource,
    required MemoryVerseRemoteDataSource remoteDataSource,
    MemoryVerseRepositoryHelper? helper,
    MemoryVerseSyncService? syncService,
  }) {
    final sync = syncService ??
        MemoryVerseSyncService(
          localDataSource: localDataSource,
          remoteDataSource: remoteDataSource,
        );
    return MemoryVerseRepositoryImpl._(
      remoteDataSource: remoteDataSource,
      syncService: sync,
      helper: helper ??
          MemoryVerseRepositoryHelper(
            localDataSource: localDataSource,
            syncService: sync,
          ),
    );
  }

  MemoryVerseRepositoryImpl._({
    required MemoryVerseRemoteDataSource remoteDataSource,
    required MemoryVerseSyncService syncService,
    required MemoryVerseRepositoryHelper helper,
  })  : _remoteDataSource = remoteDataSource,
        _syncService = syncService,
        _helper = helper;

  @override
  Future<Either<Failure, MemoryVerseEntity>> addVerseFromDaily({
    required String dailyVerseId,
  }) async {
    return _helper.executeWithCaching(
      operation: () => _remoteDataSource.addVerseFromDaily(dailyVerseId),
      mapToEntity: (model) => model.toEntity(),
      queueOnFailure: {
        'type': 'add_from_daily',
        'daily_verse_id': dailyVerseId,
      },
      operationName: 'Adding verse from daily: $dailyVerseId',
    );
  }

  @override
  Future<Either<Failure, MemoryVerseEntity>> addVerseManually({
    required String verseReference,
    required String verseText,
    String? language,
  }) async {
    return _helper.executeWithCaching(
      operation: () => _remoteDataSource.addVerseManually(
        verseReference: verseReference,
        verseText: verseText,
        language: language,
      ),
      mapToEntity: (model) => model.toEntity(),
      queueOnFailure: {
        'type': 'add_manual',
        'verse_reference': verseReference,
        'verse_text': verseText,
        if (language != null) 'language': language,
      },
      operationName: 'Adding manual verse: $verseReference',
    );
  }

  @override
  Future<Either<Failure, (List<MemoryVerseEntity>, ReviewStatisticsEntity)>>
      getDueVerses({int limit = 20, int offset = 0, String? language}) async {
    try {
      _helper.logDebug('Fetching due verses');
      final (versesModels, statsModel) = await _remoteDataSource.getDueVerses(
          limit: limit, offset: offset, language: language);
      await _helper.cacheVerses(versesModels);
      _helper.logSuccess('Fetched ${versesModels.length} verses');
      return Right((
        versesModels.map((m) => m.toEntity()).toList(),
        statsModel.toEntity()
      ));
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logWarning('Network error, using cache: ${e.message}');
      final cachedVerses = await _helper.getDueCachedVerses();
      if (cachedVerses.isEmpty) {
        return Left(NetworkFailure(
            message: 'No cached verses available offline',
            code: 'CACHE_EMPTY'));
      }
      return Right((
        cachedVerses.map((m) => m.toEntity()).toList(),
        ReviewStatisticsEntity(
          totalVerses: cachedVerses.length,
          dueVerses: cachedVerses.length,
          reviewedToday: 0,
          upcomingReviews: 0,
          masteredVerses: cachedVerses.where((v) => v.repetitions >= 5).length,
        )
      ));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ServerFailure(
          message: 'Failed to fetch verses: ${e.toString()}',
          code: 'UNEXPECTED_ERROR'));
    }
  }

  @override
  Future<Either<Failure, MemoryVerseEntity>> submitReview(
      {required String memoryVerseId,
      required int qualityRating,
      int? timeSpentSeconds}) async {
    try {
      _helper.logDebug('Submitting review for: $memoryVerseId');
      final reviewData = await _remoteDataSource.submitReview(
          memoryVerseId: memoryVerseId,
          qualityRating: qualityRating,
          timeSpentSeconds: timeSpentSeconds);
      final updatedVerse = await _helper.updateVerseAfterReview(
          memoryVerseId: memoryVerseId, reviewData: reviewData);
      if (updatedVerse != null) {
        _helper.logSuccess('Review submitted and cached');
        return Right(updatedVerse.toEntity());
      }
      return const Left(ServerFailure(
          message: 'Failed to update local cache',
          code: 'CACHE_UPDATE_FAILED'));
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      await _syncService.queueOperation({
        'type': 'submit_review',
        'memory_verse_id': memoryVerseId,
        'quality_rating': qualityRating,
        if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      });
      return const Left(NetworkFailure(
          message: 'Review queued for sync when online',
          code: 'OFFLINE_QUEUED'));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ServerFailure(
          message: 'Failed to submit review: ${e.toString()}',
          code: 'UNEXPECTED_ERROR'));
    }
  }

  @override
  Future<Either<Failure, ReviewStatisticsEntity>> getStatistics() async {
    try {
      _helper.logDebug('Fetching statistics');
      final result = await getDueVerses(limit: 1);
      return result.fold((failure) => Left(failure), (data) => Right(data.$2));
    } catch (e) {
      _helper.logError('Error fetching statistics: $e');
      return Left(ServerFailure(
          message: 'Failed to fetch statistics: ${e.toString()}',
          code: 'STATS_FETCH_FAILED'));
    }
  }

  @override
  Future<Either<Failure, MemoryVerseEntity>> getVerseById(String id) async {
    try {
      _helper.logInfo('Looking up verse by ID: $id');
      final cachedVerse = await _helper.getCachedVerseById(id);
      if (cachedVerse != null) {
        _helper.logSuccess('Found verse in cache');
        return Right(cachedVerse.toEntity());
      }
      _helper.logWarning('Verse not in cache, fetching from remote...');
      return _helper.executeWithCaching(
        operation: () => _remoteDataSource.getVerseById(id),
        mapToEntity: (model) => model.toEntity(),
        operationName: 'Fetching verse by ID from remote',
      );
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ServerFailure(
          message: 'Failed to get verse: ${e.toString()}',
          code: 'GET_VERSE_FAILED'));
    }
  }

  @override
  Future<Either<Failure, List<MemoryVerseEntity>>> getAllVerses() async {
    try {
      final cachedVerses = await _helper.getAllCachedVerses();
      final verses = cachedVerses.map((m) => m.toEntity()).toList();
      return Right(verses);
    } catch (e) {
      _helper.logError('Error getting all verses: $e');
      return Left(ServerFailure(
          message: 'Failed to get verses: ${e.toString()}',
          code: 'GET_VERSES_FAILED'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteVerse(String id) async {
    try {
      await _helper.removeVerseFromCache(id);

      // Queue for remote deletion
      await _syncService.queueOperation({
        'type': 'delete_verse',
        'verse_id': id,
      });

      return const Right(unit);
    } catch (e) {
      _helper.logError('Error deleting verse: $e');
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
    return _syncService.syncWithRemote();
  }

  @override
  Future<Either<Failure, Unit>> clearLocalCache() async {
    try {
      await _helper.clearCache();
      return const Right(unit);
    } catch (e) {
      _helper.logError('Failed to clear cache: $e');
      return Left(ServerFailure(
          message: 'Failed to clear cache: ${e.toString()}',
          code: 'CACHE_CLEAR_FAILED'));
    }
  }
}
