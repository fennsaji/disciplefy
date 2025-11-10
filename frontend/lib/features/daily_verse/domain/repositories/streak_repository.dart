import '../entities/daily_verse_streak.dart';

/// Repository interface for daily verse streak operations
abstract class StreakRepository {
  /// Get the current user's streak data
  /// Returns null if user is not authenticated
  Future<DailyVerseStreak?> getStreak();

  /// Update the streak when user views daily verse
  /// Handles streak increment/reset logic based on last viewed date
  Future<DailyVerseStreak> markVerseAsViewed();

  /// Get streak for specific user (admin/testing purposes)
  Future<DailyVerseStreak?> getStreakForUser(String userId);

  /// Send streak notification via backend Edge Function
  ///
  /// [notificationType] - Either 'milestone' or 'streak_lost'
  /// [streakCount] - The streak count (milestone number or lost streak count)
  /// [language] - User's preferred language code (en, hi, ml)
  ///
  /// Returns true if notification was sent successfully
  Future<bool> sendStreakNotification({
    required String notificationType,
    required int streakCount,
    required String language,
  });
}
