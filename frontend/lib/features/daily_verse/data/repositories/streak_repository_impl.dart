import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/daily_verse_streak.dart';
import '../../domain/repositories/streak_repository.dart';
import '../models/daily_verse_streak_model.dart';

/// Implementation of StreakRepository using Supabase
class StreakRepositoryImpl implements StreakRepository {
  final SupabaseClient _supabaseClient;

  StreakRepositoryImpl(this._supabaseClient);

  @override
  Future<DailyVerseStreak?> getStreak() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return null;

      return await getStreakForUser(userId);
    } catch (e) {
      throw Exception('Failed to get streak: $e');
    }
  }

  @override
  Future<DailyVerseStreak?> getStreakForUser(String userId) async {
    try {
      final response = await _supabaseClient
          .from('daily_verse_streaks')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Create initial streak for new user
        final initialStreak = await _createInitialStreak(userId);
        return initialStreak;
      }

      final model = DailyVerseStreakModel.fromJson(response);
      return model.toEntity();
    } catch (e) {
      throw Exception('Failed to get streak for user: $e');
    }
  }

  @override
  Future<DailyVerseStreak> markVerseAsViewed() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get current streak or create if doesn't exist
      final currentStreak = await getStreakForUser(userId);
      if (currentStreak == null) {
        throw Exception('Failed to get or create streak');
      }

      // If already viewed today, return current streak unchanged
      if (currentStreak.hasViewedToday) {
        return currentStreak;
      }

      // Calculate new streak values
      final now = DateTime.now();
      int newCurrentStreak;
      int newLongestStreak = currentStreak.longestStreak;

      if (currentStreak.lastViewedAt == null ||
          currentStreak.currentStreak == 0) {
        // First time viewing
        newCurrentStreak = 1;
      } else if (currentStreak.canContinueStreak) {
        // Viewed yesterday, continue streak
        newCurrentStreak = currentStreak.currentStreak + 1;
      } else if (currentStreak.shouldResetStreak) {
        // Missed a day, reset streak
        newCurrentStreak = 1;
      } else {
        // Shouldn't happen, but handle gracefully
        newCurrentStreak = currentStreak.currentStreak;
      }

      // Update longest streak if current streak is higher
      if (newCurrentStreak > newLongestStreak) {
        newLongestStreak = newCurrentStreak;
      }

      // Update in database
      final response = await _supabaseClient
          .from('daily_verse_streaks')
          .update({
            'current_streak': newCurrentStreak,
            'longest_streak': newLongestStreak,
            'last_viewed_at': now.toIso8601String(),
            'total_views': currentStreak.totalViews + 1,
            'updated_at': now.toIso8601String(),
          })
          .eq('user_id', userId)
          .select()
          .single();

      final model = DailyVerseStreakModel.fromJson(response);
      return model.toEntity();
    } catch (e) {
      throw Exception('Failed to mark verse as viewed: $e');
    }
  }

  /// Create initial streak record for new user
  Future<DailyVerseStreak> _createInitialStreak(String userId) async {
    try {
      final now = DateTime.now();
      final response = await _supabaseClient
          .from('daily_verse_streaks')
          .insert({
            'user_id': userId,
            'current_streak': 0,
            'longest_streak': 0,
            'total_views': 0,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .select()
          .single();

      final model = DailyVerseStreakModel.fromJson(response);
      return model.toEntity();
    } catch (e) {
      throw Exception('Failed to create initial streak: $e');
    }
  }
}
