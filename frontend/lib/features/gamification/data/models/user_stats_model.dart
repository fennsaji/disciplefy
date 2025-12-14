import '../../domain/entities/user_stats.dart';

/// Data model for UserStats from Supabase
class UserStatsModel extends UserStats {
  const UserStatsModel({
    super.totalXp,
    super.leaderboardRank,
    super.studyCurrentStreak,
    super.studyLongestStreak,
    super.studyLastDate,
    super.totalStudyDays,
    super.verseCurrentStreak,
    super.verseLongestStreak,
    super.totalStudiesCompleted,
    super.totalTimeSpentSeconds,
    super.totalMemoryVerses,
    super.totalVoiceSessions,
    super.totalSavedGuides,
    super.achievementsUnlocked,
    super.achievementsTotal,
  });

  /// Create from Supabase RPC response
  factory UserStatsModel.fromJson(Map<String, dynamic> json) {
    return UserStatsModel(
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      leaderboardRank: (json['leaderboard_rank'] as num?)?.toInt(),
      studyCurrentStreak: (json['study_current_streak'] as num?)?.toInt() ?? 0,
      studyLongestStreak: (json['study_longest_streak'] as num?)?.toInt() ?? 0,
      studyLastDate: json['study_last_date'] != null
          ? DateTime.tryParse(json['study_last_date'].toString())
          : null,
      totalStudyDays: (json['total_study_days'] as num?)?.toInt() ?? 0,
      verseCurrentStreak: (json['verse_current_streak'] as num?)?.toInt() ?? 0,
      verseLongestStreak: (json['verse_longest_streak'] as num?)?.toInt() ?? 0,
      totalStudiesCompleted:
          (json['total_studies_completed'] as num?)?.toInt() ?? 0,
      totalTimeSpentSeconds:
          (json['total_time_spent_seconds'] as num?)?.toInt() ?? 0,
      totalMemoryVerses: (json['total_memory_verses'] as num?)?.toInt() ?? 0,
      totalVoiceSessions: (json['total_voice_sessions'] as num?)?.toInt() ?? 0,
      totalSavedGuides: (json['total_saved_guides'] as num?)?.toInt() ?? 0,
      achievementsUnlocked:
          (json['achievements_unlocked'] as num?)?.toInt() ?? 0,
      achievementsTotal: (json['achievements_total'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert to JSON (for debugging/logging)
  Map<String, dynamic> toJson() {
    return {
      'total_xp': totalXp,
      'leaderboard_rank': leaderboardRank,
      'study_current_streak': studyCurrentStreak,
      'study_longest_streak': studyLongestStreak,
      'study_last_date': studyLastDate?.toIso8601String(),
      'total_study_days': totalStudyDays,
      'verse_current_streak': verseCurrentStreak,
      'verse_longest_streak': verseLongestStreak,
      'total_studies_completed': totalStudiesCompleted,
      'total_time_spent_seconds': totalTimeSpentSeconds,
      'total_memory_verses': totalMemoryVerses,
      'total_voice_sessions': totalVoiceSessions,
      'total_saved_guides': totalSavedGuides,
      'achievements_unlocked': achievementsUnlocked,
      'achievements_total': achievementsTotal,
    };
  }

  /// Convert to domain entity
  UserStats toEntity() {
    return UserStats(
      totalXp: totalXp,
      leaderboardRank: leaderboardRank,
      studyCurrentStreak: studyCurrentStreak,
      studyLongestStreak: studyLongestStreak,
      studyLastDate: studyLastDate,
      totalStudyDays: totalStudyDays,
      verseCurrentStreak: verseCurrentStreak,
      verseLongestStreak: verseLongestStreak,
      totalStudiesCompleted: totalStudiesCompleted,
      totalTimeSpentSeconds: totalTimeSpentSeconds,
      totalMemoryVerses: totalMemoryVerses,
      totalVoiceSessions: totalVoiceSessions,
      totalSavedGuides: totalSavedGuides,
      achievementsUnlocked: achievementsUnlocked,
      achievementsTotal: achievementsTotal,
    );
  }
}
