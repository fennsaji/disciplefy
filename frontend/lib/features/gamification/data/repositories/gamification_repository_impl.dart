import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/achievement.dart';
import '../../domain/entities/study_streak.dart';
import '../../domain/entities/user_stats.dart';
import '../../domain/repositories/gamification_repository.dart';
import '../datasources/gamification_remote_datasource.dart';

/// Implementation of GamificationRepository
class GamificationRepositoryImpl implements GamificationRepository {
  final GamificationRemoteDataSource _remoteDataSource;

  GamificationRepositoryImpl({
    required GamificationRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, UserStats>> getUserStats(String userId) async {
    try {
      final result = await _remoteDataSource.getUserStats(userId);
      return Right(result.toEntity());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load user stats: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Achievement>>> getUserAchievements(
    String userId,
    String language,
  ) async {
    try {
      final result =
          await _remoteDataSource.getUserAchievements(userId, language);
      return Right(result.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load achievements: $e'));
    }
  }

  @override
  Future<Either<Failure, StudyStreak>> getOrCreateStudyStreak(
      String userId) async {
    try {
      final result = await _remoteDataSource.getOrCreateStudyStreak(userId);
      return Right(result.toEntity());
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to get study streak: $e'));
    }
  }

  @override
  Future<Either<Failure, StudyStreakUpdateResult>> updateStudyStreak(
      String userId) async {
    try {
      final result = await _remoteDataSource.updateStudyStreak(userId);
      return Right(StudyStreakUpdateResult(
        currentStreak: result.currentStreak,
        longestStreak: result.longestStreak,
        streakIncreased: result.streakIncreased,
        isNewRecord: result.isNewRecord,
      ));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to update study streak: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AchievementUnlockResult>>> checkStudyAchievements(
    String userId,
  ) async {
    try {
      final result = await _remoteDataSource.checkStudyAchievements(userId);
      return Right(result
          .map((m) => AchievementUnlockResult(
                achievementId: m.achievementId,
                achievementName: m.achievementName,
                xpReward: m.xpReward,
                isNew: m.isNew,
              ))
          .toList());
    } catch (e) {
      return Left(
          ServerFailure(message: 'Failed to check study achievements: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AchievementUnlockResult>>>
      checkStreakAchievements(
    String userId,
  ) async {
    try {
      final result = await _remoteDataSource.checkStreakAchievements(userId);
      return Right(result
          .map((m) => AchievementUnlockResult(
                achievementId: m.achievementId,
                achievementName: m.achievementName,
                xpReward: m.xpReward,
                isNew: m.isNew,
              ))
          .toList());
    } catch (e) {
      return Left(
          ServerFailure(message: 'Failed to check streak achievements: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AchievementUnlockResult>>>
      checkMemoryAchievements(
    String userId,
  ) async {
    try {
      final result = await _remoteDataSource.checkMemoryAchievements(userId);
      return Right(result
          .map((m) => AchievementUnlockResult(
                achievementId: m.achievementId,
                achievementName: m.achievementName,
                xpReward: m.xpReward,
                isNew: m.isNew,
              ))
          .toList());
    } catch (e) {
      return Left(
          ServerFailure(message: 'Failed to check memory achievements: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AchievementUnlockResult>>> checkVoiceAchievements(
    String userId,
  ) async {
    try {
      final result = await _remoteDataSource.checkVoiceAchievements(userId);
      return Right(result
          .map((m) => AchievementUnlockResult(
                achievementId: m.achievementId,
                achievementName: m.achievementName,
                xpReward: m.xpReward,
                isNew: m.isNew,
              ))
          .toList());
    } catch (e) {
      return Left(
          ServerFailure(message: 'Failed to check voice achievements: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AchievementUnlockResult>>> checkSavedAchievements(
    String userId,
  ) async {
    try {
      final result = await _remoteDataSource.checkSavedAchievements(userId);
      return Right(result
          .map((m) => AchievementUnlockResult(
                achievementId: m.achievementId,
                achievementName: m.achievementName,
                xpReward: m.xpReward,
                isNew: m.isNew,
              ))
          .toList());
    } catch (e) {
      return Left(
          ServerFailure(message: 'Failed to check saved achievements: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AchievementUnlockResult>>>
      checkAllStudyRelatedAchievements(
    String userId,
  ) async {
    try {
      final List<AchievementUnlockResult> allUnlocked = [];

      // Check study count achievements
      final studyResults =
          await _remoteDataSource.checkStudyAchievements(userId);
      allUnlocked.addAll(studyResults.map((m) => AchievementUnlockResult(
            achievementId: m.achievementId,
            achievementName: m.achievementName,
            xpReward: m.xpReward,
            isNew: m.isNew,
          )));

      // Check streak achievements
      final streakResults =
          await _remoteDataSource.checkStreakAchievements(userId);
      allUnlocked.addAll(streakResults.map((m) => AchievementUnlockResult(
            achievementId: m.achievementId,
            achievementName: m.achievementName,
            xpReward: m.xpReward,
            isNew: m.isNew,
          )));

      return Right(allUnlocked);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to check achievements: $e'));
    }
  }
}
