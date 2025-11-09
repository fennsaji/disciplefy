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
}
