import 'package:equatable/equatable.dart';

/// Comprehensive user gamification stats from the database
class UserStats extends Equatable {
  // XP & Rank
  final int totalXp;
  final int? leaderboardRank;

  // Study Streak
  final int studyCurrentStreak;
  final int studyLongestStreak;
  final DateTime? studyLastDate;
  final int totalStudyDays;

  // Verse Streak
  final int verseCurrentStreak;
  final int verseLongestStreak;

  // Counts
  final int totalStudiesCompleted;
  final int totalTimeSpentSeconds;
  final int totalMemoryVerses;
  final int totalVoiceSessions;
  final int totalSavedGuides;

  // Achievements
  final int achievementsUnlocked;
  final int achievementsTotal;

  const UserStats({
    this.totalXp = 0,
    this.leaderboardRank,
    this.studyCurrentStreak = 0,
    this.studyLongestStreak = 0,
    this.studyLastDate,
    this.totalStudyDays = 0,
    this.verseCurrentStreak = 0,
    this.verseLongestStreak = 0,
    this.totalStudiesCompleted = 0,
    this.totalTimeSpentSeconds = 0,
    this.totalMemoryVerses = 0,
    this.totalVoiceSessions = 0,
    this.totalSavedGuides = 0,
    this.achievementsUnlocked = 0,
    this.achievementsTotal = 0,
  });

  /// Check if user is on leaderboard (200+ XP)
  bool get isOnLeaderboard => leaderboardRank != null;

  /// Get formatted time spent (e.g., "2h 30m")
  String get formattedTimeSpent {
    final hours = totalTimeSpentSeconds ~/ 3600;
    final minutes = (totalTimeSpentSeconds % 3600) ~/ 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '0m';
    }
  }

  /// Get achievement completion percentage
  double get achievementProgress {
    if (achievementsTotal == 0) return 0.0;
    return achievementsUnlocked / achievementsTotal;
  }

  /// Check if user has studied today
  bool get hasStudiedToday {
    if (studyLastDate == null) return false;
    final today = DateTime.now();
    return studyLastDate!.year == today.year &&
        studyLastDate!.month == today.month &&
        studyLastDate!.day == today.day;
  }

  UserStats copyWith({
    int? totalXp,
    int? leaderboardRank,
    int? studyCurrentStreak,
    int? studyLongestStreak,
    DateTime? studyLastDate,
    int? totalStudyDays,
    int? verseCurrentStreak,
    int? verseLongestStreak,
    int? totalStudiesCompleted,
    int? totalTimeSpentSeconds,
    int? totalMemoryVerses,
    int? totalVoiceSessions,
    int? totalSavedGuides,
    int? achievementsUnlocked,
    int? achievementsTotal,
  }) {
    return UserStats(
      totalXp: totalXp ?? this.totalXp,
      leaderboardRank: leaderboardRank ?? this.leaderboardRank,
      studyCurrentStreak: studyCurrentStreak ?? this.studyCurrentStreak,
      studyLongestStreak: studyLongestStreak ?? this.studyLongestStreak,
      studyLastDate: studyLastDate ?? this.studyLastDate,
      totalStudyDays: totalStudyDays ?? this.totalStudyDays,
      verseCurrentStreak: verseCurrentStreak ?? this.verseCurrentStreak,
      verseLongestStreak: verseLongestStreak ?? this.verseLongestStreak,
      totalStudiesCompleted:
          totalStudiesCompleted ?? this.totalStudiesCompleted,
      totalTimeSpentSeconds:
          totalTimeSpentSeconds ?? this.totalTimeSpentSeconds,
      totalMemoryVerses: totalMemoryVerses ?? this.totalMemoryVerses,
      totalVoiceSessions: totalVoiceSessions ?? this.totalVoiceSessions,
      totalSavedGuides: totalSavedGuides ?? this.totalSavedGuides,
      achievementsUnlocked: achievementsUnlocked ?? this.achievementsUnlocked,
      achievementsTotal: achievementsTotal ?? this.achievementsTotal,
    );
  }

  @override
  List<Object?> get props => [
        totalXp,
        leaderboardRank,
        studyCurrentStreak,
        studyLongestStreak,
        studyLastDate,
        totalStudyDays,
        verseCurrentStreak,
        verseLongestStreak,
        totalStudiesCompleted,
        totalTimeSpentSeconds,
        totalMemoryVerses,
        totalVoiceSessions,
        totalSavedGuides,
        achievementsUnlocked,
        achievementsTotal,
      ];
}
