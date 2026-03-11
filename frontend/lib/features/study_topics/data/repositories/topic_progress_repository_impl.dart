import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/topic_progress.dart';
import '../../domain/repositories/learning_paths_repository.dart';
import '../../domain/repositories/topic_progress_repository.dart';
import '../datasources/topic_progress_remote_datasource.dart';
import '../services/learning_paths_cache_service.dart';

/// Implementation of [TopicProgressRepository].
///
/// Handles topic progress operations through the remote API
/// and maps exceptions to domain failures.
class TopicProgressRepositoryImpl implements TopicProgressRepository {
  final TopicProgressRemoteDataSource _remoteDataSource;
  final LearningPathsRepository _learningPathsRepository;
  final LearningPathsCacheService _learningPathsHiveCache;

  TopicProgressRepositoryImpl({
    required TopicProgressRemoteDataSource remoteDataSource,
    required LearningPathsRepository learningPathsRepository,
    required LearningPathsCacheService learningPathsHiveCache,
  })  : _remoteDataSource = remoteDataSource,
        _learningPathsRepository = learningPathsRepository,
        _learningPathsHiveCache = learningPathsHiveCache;

  @override
  Future<Either<Failure, void>> startTopic(String topicId) async {
    try {
      await _remoteDataSource.startTopic(topicId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TopicCompletionResult>> completeTopic(
    String topicId, {
    int timeSpentSeconds = 0,
    String? generationMode,
  }) async {
    try {
      final response = await _remoteDataSource.completeTopic(
        topicId,
        timeSpentSeconds: timeSpentSeconds,
        generationMode: generationMode,
      );

      // Invalidate learning paths cache (both in-memory and persistent Hive)
      // so progress % in the list refreshes silently on next load.
      _learningPathsRepository.clearCache();
      unawaited(_learningPathsHiveCache.clearCache());

      return Right(TopicCompletionResult(
        progressId: response.progressId,
        xpEarned: response.xpEarned ?? 0,
        isFirstCompletion: response.isFirstCompletion ?? false,
        topicTitle: response.topicTitle,
        fellowshipAdvanced: response.fellowshipAdvanced,
        fellowshipId: response.fellowshipId,
        newGuideIndex: response.newGuideIndex,
        studyCompleted: response.studyCompleted,
      ));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateTimeSpent(
    String topicId,
    int timeSpentSeconds,
  ) async {
    try {
      await _remoteDataSource.updateTimeSpent(topicId, timeSpentSeconds);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<InProgressTopic>>> getInProgressTopics({
    String language = 'en',
    int limit = 5,
  }) async {
    try {
      final response = await _remoteDataSource.getInProgressTopics(
        language: language,
        limit: limit,
      );

      return Right(response.toEntities());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(ClientFailure(message: e.toString()));
    }
  }
}
