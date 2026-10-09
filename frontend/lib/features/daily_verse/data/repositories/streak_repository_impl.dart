import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/daily_verse_streak.dart';
import '../../domain/repositories/streak_repository.dart';
import '../models/daily_verse_streak_model.dart';
import '../../../../core/utils/logger.dart';

/// `p_local_date` for `touch_daily_streak`: the local calendar day of [now]
/// as yyyy-MM-dd, always in ASCII digits whatever the app locale.
String streakLocalDate(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year.toString().padLeft(4, '0')}-${two(now.month)}-${two(now.day)}';
}

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
  Future<DailyVerseStreak> markVerseAsViewed() => markActivityToday();

  @override
  Future<DailyVerseStreak> markActivityToday() async {
    try {
      if (_supabaseClient.auth.currentUser == null) {
        throw Exception('User not authenticated');
      }

      // The day is decided by the device's clock, the same calendar the
      // streak is shown in; the server only compares it with the last one
      // it stored (same day: no change, the day after: +1, later: reset).
      final response = await _supabaseClient.rpc(
        'touch_daily_streak',
        params: {'p_local_date': streakLocalDate(DateTime.now())},
      );

      final model = DailyVerseStreakModel.fromJson(
          Map<String, dynamic>.from(response as Map));
      return model.toEntity();
    } catch (e) {
      throw Exception('Failed to mark streak activity: $e');
    }
  }

  @override
  Future<bool> sendStreakNotification({
    required String notificationType,
    required int streakCount,
    required String language,
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Call the secured Edge Function
      final response = await _supabaseClient.functions.invoke(
        'send-streak-notification',
        body: {
          'userId': userId,
          'notificationType': notificationType,
          'streakCount': streakCount,
          'language': language,
        },
      );

      // Check for errors in response
      if (response.status != 200) {
        throw Exception(
            'Notification failed with status ${response.status}: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>?;
      return data?['sent'] == true;
    } catch (e) {
      // Log error but don't throw - notifications are optional
      Logger.debug('Failed to send streak notification: $e');
      return false;
    }
  }

  /// Create initial streak record for new user
  Future<DailyVerseStreak> _createInitialStreak(String userId) async {
    try {
      final now = DateTime.now();
      // Concurrent calls can both see no existing row and race here — upsert
      // on the unique user_id constraint so the loser updates instead of
      // hitting 23505 (unique_user_daily_verse_streak).
      final response = await _supabaseClient
          .from('daily_verse_streaks')
          .upsert({
            'user_id': userId,
            'current_streak': 0,
            'longest_streak': 0,
            'total_views': 0,
            'created_at': now.toUtc().toIso8601String(),
            'updated_at': now.toUtc().toIso8601String(),
          }, onConflict: 'user_id')
          .select()
          .single();

      final model = DailyVerseStreakModel.fromJson(response);
      return model.toEntity();
    } catch (e) {
      throw Exception('Failed to create initial streak: $e');
    }
  }
}
