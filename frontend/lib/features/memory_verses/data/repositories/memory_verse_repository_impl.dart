import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/fetched_verse_entity.dart';
import '../../domain/entities/memory_verse_entity.dart';
import '../../domain/entities/review_session_entity.dart';
import '../../domain/entities/review_statistics_entity.dart';
import '../../domain/entities/practice_mode_entity.dart';
import '../../domain/entities/memory_streak_entity.dart';
import '../../domain/entities/mastery_progress_entity.dart';
import '../../domain/entities/daily_goal_entity.dart';
import '../../domain/entities/memory_challenge_entity.dart';
import '../../domain/entities/memory_champion_entry.dart';
import '../../domain/entities/suggested_verse_entity.dart';
import '../../domain/repositories/memory_verse_repository.dart';
import '../../domain/usecases/submit_practice_session.dart';
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
    String? language,
  }) async {
    return _helper.executeWithCaching(
      operation: () => _remoteDataSource.addVerseFromDaily(
        dailyVerseId,
        language: language,
      ),
      mapToEntity: (model) => model.toEntity(),
      queueOnFailure: {
        'type': 'add_from_daily',
        'daily_verse_id': dailyVerseId,
        if (language != null) 'language': language,
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
      _helper.logDebug('Deleting verse: $id');

      // Try to delete from remote first
      await _remoteDataSource.deleteVerse(id);

      // Remove from local cache after successful remote deletion
      await _helper.removeVerseFromCache(id);

      _helper.logSuccess('Verse deleted successfully');
      return const Right(unit);
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');

      // Remove from cache immediately for better UX
      await _helper.removeVerseFromCache(id);

      // Queue for remote deletion when back online
      await _syncService.queueOperation({
        'type': 'delete_verse',
        'verse_id': id,
      });

      return const Left(NetworkFailure(
          message: 'Verse removed locally, will sync when online',
          code: 'OFFLINE_QUEUED'));
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

  @override
  Future<Either<Failure, FetchedVerseEntity>> fetchVerseText({
    required String book,
    required int chapter,
    required int verseStart,
    int? verseEnd,
    required String language,
  }) async {
    try {
      _helper.logDebug(
          'Fetching verse text: $book $chapter:$verseStart${verseEnd != null ? '-$verseEnd' : ''}');

      final result = await _remoteDataSource.fetchVerseText(
        book: book,
        chapter: chapter,
        verseStart: verseStart,
        verseEnd: verseEnd,
        language: language,
      );

      _helper.logSuccess('Verse text fetched successfully');

      return Right(FetchedVerseEntity(
        text: result['text']!,
        localizedReference: result['localizedReference']!,
      ));
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ServerFailure(
          message: 'Failed to fetch verse text: ${e.toString()}',
          code: 'FETCH_VERSE_TEXT_FAILED'));
    }
  }

  // ==========================================================================
  // PRACTICE MODE METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  @override
  Future<Either<Failure, PracticeModeEntity>> selectPracticeMode({
    required String verseId,
    required PracticeModeType practiceMode,
  }) async {
    try {
      _helper
          .logDebug('Selecting practice mode $practiceMode for verse $verseId');

      // For now, return a default entity since backend doesn't track selection
      // Backend will handle this when submitting practice session
      final entity = PracticeModeEntity(
        modeType: practiceMode,
        timesPracticed: 0,
        successRate: 0.0,
        isFavorite: false,
      );

      _helper.logSuccess('Practice mode selected');
      return Right(entity);
    } catch (e) {
      _helper.logError('Error selecting practice mode: $e');
      return Left(ClientFailure(
        message: 'Failed to select practice mode: ${e.toString()}',
        code: 'SELECT_MODE_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, SubmitPracticeSessionResponse>> submitPracticeSession(
    SubmitPracticeSessionParams params,
  ) async {
    try {
      _helper.logDebug(
          'Submitting practice session: ${params.practiceMode.name} for verse ${params.memoryVerseId}');

      // Call backend edge function
      // Use toJson() to get snake_case format expected by backend
      final response = await _remoteDataSource.submitPracticeSession(
        memoryVerseId: params.memoryVerseId,
        practiceMode: params.practiceMode.toJson(),
        qualityRating: params.qualityRating,
        confidenceRating: params.confidenceRating,
        accuracyPercentage: params.accuracyPercentage,
        timeSpentSeconds: params.timeSpentSeconds,
        hintsUsed: params.hintsUsed,
      );

      // Parse response - backend returns stats, not the full verse
      // Extract achievement names from the response
      final rawAchievements =
          response['new_achievements'] as List<dynamic>? ?? [];
      final newAchievements = rawAchievements
          .map((a) => a is Map
              ? (a['achievement_name'] as String? ?? '')
              : a.toString())
          .where((name) => name.isNotEmpty)
          .toList();

      final xpEarned = response['xp_earned'] as int? ?? 0;
      final dailyGoalProgress =
          response['daily_goal_progress'] as Map<String, dynamic>?;
      final challengeProgress = response['challenge_updates'] as List<dynamic>?;

      _helper.logSuccess('Practice session submitted successfully');

      return Right(SubmitPracticeSessionResponse(
        newAchievements: newAchievements,
        xpEarned: xpEarned,
        dailyGoalProgress: dailyGoalProgress,
        challengeProgress:
            challengeProgress != null ? {'updates': challengeProgress} : null,
      ));
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');

      // Queue for sync when back online
      await _syncService.queueOperation({
        'type': 'submit_practice',
        ...params.toJson(),
      });

      return const Left(NetworkFailure(
        message: 'Practice session queued, will sync when online',
        code: 'OFFLINE_QUEUED',
      ));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to submit practice session: ${e.toString()}',
        code: 'SUBMIT_PRACTICE_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, List<PracticeModeEntity>>>
      getPracticeModeStatistics() async {
    try {
      _helper.logDebug('Fetching practice mode statistics');

      final response = await _remoteDataSource.getPracticeModeStatistics();
      final modes = response.map((mode) {
        return PracticeModeEntity(
          modeType: PracticeModeType.values.firstWhere(
            (e) => e.name == mode['mode_type'],
          ),
          timesPracticed: mode['times_practiced'] as int,
          successRate: (mode['success_rate'] as num).toDouble(),
          averageTimeSeconds: mode['average_time_seconds'] as int?,
          isFavorite: mode['is_favorite'] as bool,
        );
      }).toList();

      _helper.logSuccess('Practice mode statistics fetched');
      return Right(modes);
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to fetch practice mode statistics: ${e.toString()}',
        code: 'GET_PRACTICE_STATS_FAILED',
      ));
    }
  }

  // ==========================================================================
  // STREAK METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  @override
  Future<Either<Failure, MemoryStreakEntity>> getMemoryStreak() async {
    try {
      _helper.logDebug('Fetching memory streak');

      final response = await _remoteDataSource.getMemoryStreak();

      final entity = MemoryStreakEntity(
        currentStreak: response['current_streak'] as int,
        longestStreak: response['longest_streak'] as int,
        lastPracticeDate: response['last_practice_date'] != null
            ? DateTime.parse(response['last_practice_date'] as String)
            : null,
        totalPracticeDays: response['total_practice_days'] as int,
        freezeDaysAvailable: response['freeze_days_available'] as int,
        freezeDaysUsed: response['freeze_days_used'] as int,
        milestones: _parseMilestones(response['milestones']),
      );

      _helper.logSuccess('Memory streak fetched');
      return Right(entity);
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to fetch memory streak: ${e.toString()}',
        code: 'GET_STREAK_FAILED',
      ));
    }
  }

  Map<int, DateTime?> _parseMilestones(dynamic milestones) {
    final result = <int, DateTime?>{};
    if (milestones is Map) {
      milestones.forEach((key, value) {
        final dayKey = int.tryParse(key.toString());
        if (dayKey != null) {
          result[dayKey] =
              value != null ? DateTime.parse(value as String) : null;
        }
      });
    }
    return result;
  }

  @override
  Future<Either<Failure, MemoryStreakEntity>> useStreakFreeze({
    required DateTime freezeDate,
  }) async {
    try {
      _helper.logDebug('Using streak freeze for date: $freezeDate');

      final response = await _remoteDataSource.useStreakFreeze(
        freezeDate:
            freezeDate.toIso8601String().split('T')[0], // Format as YYYY-MM-DD
      );

      final entity = MemoryStreakEntity(
        currentStreak: response['current_streak'] as int,
        longestStreak: response['longest_streak'] as int,
        lastPracticeDate: response['last_practice_date'] != null
            ? DateTime.parse(response['last_practice_date'] as String)
            : null,
        totalPracticeDays: response['total_practice_days'] as int,
        freezeDaysAvailable: response['freeze_days_available'] as int,
        freezeDaysUsed: response['freeze_days_used'] as int,
        milestones: _parseMilestones(response['milestones']),
      );

      _helper.logSuccess('Streak freeze applied');
      return Right(entity);
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to use streak freeze: ${e.toString()}',
        code: 'USE_FREEZE_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, (bool, int?)>> checkStreakMilestone() async {
    try {
      _helper.logDebug('Checking streak milestone');

      final response = await _remoteDataSource.checkStreakMilestone();

      final milestoneReached = response['milestone_reached'] as bool;
      final milestoneNumber = response['milestone_number'] as int?;

      _helper.logSuccess('Streak milestone checked');
      return Right((milestoneReached, milestoneNumber));
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to check streak milestone: ${e.toString()}',
        code: 'CHECK_MILESTONE_FAILED',
      ));
    }
  }

  // ==========================================================================
  // MASTERY METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  @override
  Future<Either<Failure, MasteryProgressEntity>> getMasteryProgress({
    required String verseId,
  }) async {
    try {
      _helper.logDebug('Fetching mastery progress for verse: $verseId');

      final response =
          await _remoteDataSource.getMasteryProgress(verseId: verseId);

      final entity = MasteryProgressEntity(
        masteryLevel:
            MasteryLevelExtension.fromJson(response['mastery_level'] as String),
        masteryPercentage: (response['mastery_percentage'] as num).toDouble(),
        modesMastered: response['modes_mastered'] as int,
        perfectRecalls: response['perfect_recalls'] as int,
        confidenceRating: response['confidence_rating'] != null
            ? (response['confidence_rating'] as num).toDouble()
            : null,
      );

      _helper.logSuccess('Mastery progress fetched');
      return Right(entity);
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to fetch mastery progress: ${e.toString()}',
        code: 'GET_MASTERY_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, MasteryProgressEntity>> updateMasteryLevel({
    required String verseId,
    required MasteryLevel newMasteryLevel,
  }) async {
    try {
      _helper.logDebug(
          'Updating mastery level for verse: $verseId to $newMasteryLevel');

      final response = await _remoteDataSource.updateMasteryLevel(
        verseId: verseId,
        masteryLevel: newMasteryLevel.toJson(),
      );

      final entity = MasteryProgressEntity(
        masteryLevel:
            MasteryLevelExtension.fromJson(response['mastery_level'] as String),
        masteryPercentage: (response['mastery_percentage'] as num).toDouble(),
        modesMastered: response['modes_mastered'] as int,
        perfectRecalls: response['perfect_recalls'] as int,
        confidenceRating: response['confidence_rating'] != null
            ? (response['confidence_rating'] as num).toDouble()
            : null,
      );

      _helper.logSuccess('Mastery level updated');
      return Right(entity);
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to update mastery level: ${e.toString()}',
        code: 'UPDATE_MASTERY_FAILED',
      ));
    }
  }

  // ==========================================================================
  // DAILY GOAL METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  @override
  Future<Either<Failure, DailyGoalEntity>> getDailyGoal() async {
    try {
      _helper.logDebug('Fetching daily goal');

      final response = await _remoteDataSource.getDailyGoal();

      final entity = DailyGoalEntity(
        targetReviews: response['target_reviews'] as int,
        completedReviews: response['completed_reviews'] as int,
        targetNewVerses: response['target_new_verses'] as int,
        addedNewVerses: response['added_new_verses'] as int,
        goalAchieved: response['goal_achieved'] as bool,
        bonusXpAwarded: response['bonus_xp_awarded'] as int,
      );

      _helper.logSuccess('Daily goal fetched');
      return Right(entity);
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to fetch daily goal: ${e.toString()}',
        code: 'GET_DAILY_GOAL_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, DailyGoalEntity>> updateDailyGoalProgress({
    required bool isNewVerse,
  }) async {
    try {
      _helper.logDebug('Updating daily goal progress: isNewVerse=$isNewVerse');

      final response = await _remoteDataSource.updateDailyGoalProgress(
        isNewVerse: isNewVerse,
      );

      final entity = DailyGoalEntity(
        targetReviews: response['target_reviews'] as int,
        completedReviews: response['completed_reviews'] as int,
        targetNewVerses: response['target_new_verses'] as int,
        addedNewVerses: response['added_new_verses'] as int,
        goalAchieved: response['goal_achieved'] as bool,
        bonusXpAwarded: response['bonus_xp_awarded'] as int,
      );

      _helper.logSuccess('Daily goal progress updated');
      return Right(entity);
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');

      // Queue for sync when back online
      await _syncService.queueOperation({
        'type': 'update_daily_goal',
        'is_new_verse': isNewVerse,
      });

      return const Left(NetworkFailure(
        message: 'Daily goal update queued, will sync when online',
        code: 'OFFLINE_QUEUED',
      ));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to update daily goal progress: ${e.toString()}',
        code: 'UPDATE_DAILY_GOAL_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, DailyGoalEntity>> setDailyGoalTargets({
    required int targetReviews,
    required int targetNewVerses,
  }) async {
    try {
      _helper.logDebug(
          'Setting daily goal targets: reviews=$targetReviews, newVerses=$targetNewVerses');

      final response = await _remoteDataSource.setDailyGoalTargets(
        targetReviews: targetReviews,
        targetNewVerses: targetNewVerses,
      );

      final entity = DailyGoalEntity(
        targetReviews: response['target_reviews'] as int,
        completedReviews: response['completed_reviews'] as int,
        targetNewVerses: response['target_new_verses'] as int,
        addedNewVerses: response['added_new_verses'] as int,
        goalAchieved: response['goal_achieved'] as bool,
        bonusXpAwarded: response['bonus_xp_awarded'] as int,
      );

      _helper.logSuccess('Daily goal targets set');
      return Right(entity);
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to set daily goal targets: ${e.toString()}',
        code: 'SET_DAILY_GOAL_TARGETS_FAILED',
      ));
    }
  }

  // ==========================================================================
  // CHALLENGE METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  @override
  Future<Either<Failure, List<MemoryChallengeEntity>>>
      getActiveChallenges() async {
    try {
      _helper.logDebug('Fetching active challenges');

      final response = await _remoteDataSource.getActiveChallenges();
      final challenges = response.map((challenge) {
        return MemoryChallengeEntity(
          id: challenge['id'] as String,
          challengeType: ChallengeType.values.firstWhere(
            (e) => e.name == challenge['challenge_type'],
          ),
          targetType: ChallengeTargetType.values.firstWhere(
            (e) => e.name == challenge['target_type'],
          ),
          targetValue: challenge['target_value'] as int,
          currentProgress: challenge['current_progress'] as int,
          xpReward: challenge['xp_reward'] as int,
          badgeIcon: challenge['badge_icon'] as String,
          startDate: DateTime.parse(challenge['start_date'] as String),
          endDate: DateTime.parse(challenge['end_date'] as String),
          isCompleted: challenge['is_completed'] as bool,
        );
      }).toList();

      _helper.logSuccess('Active challenges fetched');
      return Right(challenges);
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to fetch active challenges: ${e.toString()}',
        code: 'GET_CHALLENGES_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, (MemoryChallengeEntity, int)>> claimChallengeReward({
    required String challengeId,
  }) async {
    try {
      _helper.logDebug('Claiming challenge reward: $challengeId');

      final response = await _remoteDataSource.claimChallengeReward(
        challengeId: challengeId,
      );

      final challenge = response['challenge'];
      final xpEarned = response['xp_earned'] as int;

      final entity = MemoryChallengeEntity(
        id: challenge['id'] as String,
        challengeType: ChallengeType.values.firstWhere(
          (e) => e.name == challenge['challenge_type'],
        ),
        targetType: ChallengeTargetType.values.firstWhere(
          (e) => e.name == challenge['target_type'],
        ),
        targetValue: challenge['target_value'] as int,
        currentProgress: challenge['current_progress'] as int,
        xpReward: challenge['xp_reward'] as int,
        badgeIcon: challenge['badge_icon'] as String,
        startDate: DateTime.parse(challenge['start_date'] as String),
        endDate: DateTime.parse(challenge['end_date'] as String),
        isCompleted: challenge['is_completed'] as bool,
      );

      _helper.logSuccess('Challenge reward claimed');
      return Right((entity, xpEarned));
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to claim challenge reward: ${e.toString()}',
        code: 'CLAIM_REWARD_FAILED',
      ));
    }
  }

  // ==========================================================================
  // LEADERBOARD AND STATISTICS METHODS
  // ==========================================================================

  @override
  Future<Either<Failure, (List<MemoryChampionEntry>, UserMemoryStats)>>
      getMemoryChampionsLeaderboard({
    required String period,
    int limit = 100,
  }) async {
    try {
      _helper
          .logDebug('Fetching Memory Champions leaderboard (period: $period)');

      final (leaderboardData, userStatsData) =
          await _remoteDataSource.getMemoryChampionsLeaderboard(
        period: period,
        limit: limit,
      );

      // Get current user ID for marking current user in leaderboard
      final currentUserId = await _getCurrentUserId();

      // Parse leaderboard entries
      final leaderboard = leaderboardData
          .map((json) => MemoryChampionEntry.fromJson(
                json,
                currentUserId: currentUserId,
              ))
          .toList();

      // Parse user stats
      final userStats = UserMemoryStats.fromJson(userStatsData);

      _helper.logSuccess('Fetched ${leaderboard.length} leaderboard entries');
      return Right((leaderboard, userStats));
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message:
            'Failed to fetch Memory Champions leaderboard: ${e.toString()}',
        code: 'GET_LEADERBOARD_FAILED',
      ));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMemoryStatistics() async {
    try {
      _helper.logDebug('Fetching memory statistics');

      final stats = await _remoteDataSource.getMemoryStatistics();

      _helper.logSuccess('Memory statistics fetched successfully');
      return Right(stats);
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to fetch memory statistics: ${e.toString()}',
        code: 'GET_MEMORY_STATS_FAILED',
      ));
    }
  }

  /// Gets current user ID from authentication service
  Future<String?> _getCurrentUserId() async {
    try {
      // TODO: Get user ID from auth service
      // For now, this is a placeholder - actual implementation will use auth service
      return null;
    } catch (e) {
      _helper.logWarning('Failed to get current user ID: $e');
      return null;
    }
  }

  // ==========================================================================
  // SUGGESTED VERSES METHODS (Sprint 2 - Memory Verses Enhancement)
  // ==========================================================================

  @override
  Future<Either<Failure, SuggestedVersesResponse>> getSuggestedVerses({
    SuggestedVerseCategory? category,
    String language = 'en',
  }) async {
    try {
      _helper.logDebug(
          'Fetching suggested verses (category: ${category?.name ?? 'all'}, language: $language)');

      final response = await _remoteDataSource.getSuggestedVerses(
        category: category?.name,
        language: language,
      );

      _helper.logSuccess('Fetched ${response.total} suggested verses');
      return Right(response.toEntity());
    } on ServerException catch (e) {
      _helper.logError('Server error: ${e.message}');
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      _helper.logError('Network error: ${e.message}');
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      _helper.logError('Unexpected error: $e');
      return Left(ClientFailure(
        message: 'Failed to fetch suggested verses: ${e.toString()}',
        code: 'GET_SUGGESTED_VERSES_FAILED',
      ));
    }
  }
}
