import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/achievement.dart';
import '../entities/study_streak.dart';
import '../entities/user_stats.dart';

/// Repository interface for gamification features
abstract class GamificationRepository {
  /// Get comprehensive user stats
  Future<Either<Failure, UserStats>> getUserStats(String userId);

  /// Get user achievements with unlock status
  Future<Either<Failure, List<Achievement>>> getUserAchievements(
    String userId,
    String language,
  );

  /// Get or create study streak
  Future<Either<Failure, StudyStreak>> getOrCreateStudyStreak(String userId);

  /// Update study streak (called when study guide is completed)
  Future<Either<Failure, StudyStreakUpdateResult>> updateStudyStreak(
      String userId);

  /// Check and award study count achievements
  Future<Either<Failure, List<AchievementUnlockResult>>> checkStudyAchievements(
      String userId);

  /// Check and award streak achievements
  Future<Either<Failure, List<AchievementUnlockResult>>>
      checkStreakAchievements(String userId);

  /// Check and award memory verse achievements
  Future<Either<Failure, List<AchievementUnlockResult>>>
      checkMemoryAchievements(String userId);

  /// Check and award voice session achievements
  Future<Either<Failure, List<AchievementUnlockResult>>> checkVoiceAchievements(
      String userId);

  /// Check and award saved guides achievements
  Future<Either<Failure, List<AchievementUnlockResult>>> checkSavedAchievements(
      String userId);

  /// Check all relevant achievements after study completion
  Future<Either<Failure, List<AchievementUnlockResult>>>
      checkAllStudyRelatedAchievements(
    String userId,
  );
}
