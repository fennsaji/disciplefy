import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/achievement_model.dart';
import '../models/study_streak_model.dart';
import '../models/user_stats_model.dart';

/// Remote data source for gamification features
abstract class GamificationRemoteDataSource {
  /// Get comprehensive user stats
  Future<UserStatsModel> getUserStats(String userId);

  /// Get user achievements with unlock status
  Future<List<AchievementModel>> getUserAchievements(
      String userId, String language);

  /// Get or create study streak
  Future<StudyStreakModel> getOrCreateStudyStreak(String userId);

  /// Update study streak (called when study guide is completed)
  Future<StudyStreakUpdateResultModel> updateStudyStreak(String userId);

  /// Check and award study count achievements
  Future<List<AchievementUnlockResultModel>> checkStudyAchievements(
      String userId);

  /// Check and award streak achievements
  Future<List<AchievementUnlockResultModel>> checkStreakAchievements(
      String userId);

  /// Check and award memory verse achievements
  Future<List<AchievementUnlockResultModel>> checkMemoryAchievements(
      String userId);

  /// Check and award voice session achievements
  Future<List<AchievementUnlockResultModel>> checkVoiceAchievements(
      String userId);

  /// Check and award saved guides achievements
  Future<List<AchievementUnlockResultModel>> checkSavedAchievements(
      String userId);
}

/// Implementation of GamificationRemoteDataSource using Supabase
class GamificationRemoteDataSourceImpl implements GamificationRemoteDataSource {
  final SupabaseClient _supabaseClient;

  GamificationRemoteDataSourceImpl({
    required SupabaseClient supabaseClient,
  }) : _supabaseClient = supabaseClient;

  @override
  Future<UserStatsModel> getUserStats(String userId) async {
    final response = await _supabaseClient.rpc('get_user_gamification_stats',
        params: {'p_user_id': userId}).single();

    return UserStatsModel.fromJson(response);
  }

  @override
  Future<List<AchievementModel>> getUserAchievements(
      String userId, String language) async {
    final response = await _supabaseClient.rpc(
      'get_user_achievements',
      params: {
        'p_user_id': userId,
        'p_language': language,
      },
    );

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map((json) => AchievementModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<StudyStreakModel> getOrCreateStudyStreak(String userId) async {
    final response = await _supabaseClient.rpc('get_or_create_study_streak',
        params: {'p_user_id': userId}).single();

    return StudyStreakModel.fromJson(response);
  }

  @override
  Future<StudyStreakUpdateResultModel> updateStudyStreak(String userId) async {
    final response = await _supabaseClient
        .rpc('update_study_streak', params: {'p_user_id': userId}).single();

    return StudyStreakUpdateResultModel.fromJson(response);
  }

  @override
  Future<List<AchievementUnlockResultModel>> checkStudyAchievements(
      String userId) async {
    final response = await _supabaseClient.rpc(
      'check_study_achievements',
      params: {'p_user_id': userId},
    );

    final List<dynamic> data = response as List<dynamic>? ?? [];
    return data
        .map((json) =>
            AchievementUnlockResultModel.fromJson(json as Map<String, dynamic>))
        .where((result) => result.isNew)
        .toList();
  }

  @override
  Future<List<AchievementUnlockResultModel>> checkStreakAchievements(
      String userId) async {
    final response = await _supabaseClient.rpc(
      'check_streak_achievements',
      params: {'p_user_id': userId},
    );

    final List<dynamic> data = response as List<dynamic>? ?? [];
    return data
        .map((json) =>
            AchievementUnlockResultModel.fromJson(json as Map<String, dynamic>))
        .where((result) => result.isNew)
        .toList();
  }

  @override
  Future<List<AchievementUnlockResultModel>> checkMemoryAchievements(
      String userId) async {
    final response = await _supabaseClient.rpc(
      'check_memory_achievements',
      params: {'p_user_id': userId},
    );

    final List<dynamic> data = response as List<dynamic>? ?? [];
    return data
        .map((json) =>
            AchievementUnlockResultModel.fromJson(json as Map<String, dynamic>))
        .where((result) => result.isNew)
        .toList();
  }

  @override
  Future<List<AchievementUnlockResultModel>> checkVoiceAchievements(
      String userId) async {
    final response = await _supabaseClient.rpc(
      'check_voice_achievements',
      params: {'p_user_id': userId},
    );

    final List<dynamic> data = response as List<dynamic>? ?? [];
    return data
        .map((json) =>
            AchievementUnlockResultModel.fromJson(json as Map<String, dynamic>))
        .where((result) => result.isNew)
        .toList();
  }

  @override
  Future<List<AchievementUnlockResultModel>> checkSavedAchievements(
      String userId) async {
    final response = await _supabaseClient.rpc(
      'check_saved_achievements',
      params: {'p_user_id': userId},
    );

    final List<dynamic> data = response as List<dynamic>? ?? [];
    return data
        .map((json) =>
            AchievementUnlockResultModel.fromJson(json as Map<String, dynamic>))
        .where((result) => result.isNew)
        .toList();
  }
}
