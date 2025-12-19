import 'package:equatable/equatable.dart';

/// Entry in the Memory Champions Leaderboard.
///
/// Ranked by:
/// - Primary: Master verses count
/// - Tiebreaker 1: Longest practice streak
/// - Tiebreaker 2: Total practice days
class MemoryChampionEntry extends Equatable {
  final String userId;
  final String displayName;
  final int rank;
  final int masterVerses;
  final int longestStreak;
  final int totalPracticeDays;
  final String? avatarUrl;
  final bool isCurrentUser;

  const MemoryChampionEntry({
    required this.userId,
    required this.displayName,
    required this.rank,
    required this.masterVerses,
    required this.longestStreak,
    required this.totalPracticeDays,
    this.avatarUrl,
    this.isCurrentUser = false,
  });

  /// Creates entry from backend JSON response
  factory MemoryChampionEntry.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final userId = json['user_id'] as String;
    return MemoryChampionEntry(
      userId: userId,
      displayName: json['display_name'] as String? ?? 'Anonymous',
      rank: (json['rank'] as num).toInt(),
      masterVerses: (json['master_verses'] as num).toInt(),
      longestStreak: (json['longest_streak'] as num).toInt(),
      totalPracticeDays: (json['total_practice_days'] as num).toInt(),
      avatarUrl: json['avatar_url'] as String?,
      isCurrentUser: currentUserId != null && userId == currentUserId,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        displayName,
        rank,
        masterVerses,
        longestStreak,
        totalPracticeDays,
        avatarUrl,
        isCurrentUser,
      ];
}

/// Current user's memory verse statistics and rank.
class UserMemoryStats extends Equatable {
  final int rank;
  final int masterVerses;
  final int currentStreak;
  final int longestStreak;
  final int totalPracticeDays;

  const UserMemoryStats({
    required this.rank,
    required this.masterVerses,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalPracticeDays,
  });

  /// Creates from backend JSON response
  factory UserMemoryStats.fromJson(Map<String, dynamic> json) {
    return UserMemoryStats(
      rank: (json['rank'] as num?)?.toInt() ?? 9999,
      masterVerses: (json['master_verses'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      totalPracticeDays: (json['total_practice_days'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object> get props => [
        rank,
        masterVerses,
        currentStreak,
        longestStreak,
        totalPracticeDays,
      ];
}
