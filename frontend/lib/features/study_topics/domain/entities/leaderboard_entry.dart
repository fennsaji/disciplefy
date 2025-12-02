import 'package:equatable/equatable.dart';

/// Represents an entry in the XP leaderboard.
///
/// Can be either a real user entry (from database) or a placeholder entry
/// (fake data shown when there aren't enough real users with 200+ XP).
class LeaderboardEntry extends Equatable {
  /// Display name of the user (e.g., "John D.")
  final String displayName;

  /// Total XP earned by the user
  final int totalXp;

  /// Rank position (1 = first place)
  final int rank;

  /// Whether this is placeholder/fake data
  final bool isPlaceholder;

  /// User ID (null for placeholder entries)
  final String? userId;

  /// Whether this entry belongs to the current user
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.displayName,
    required this.totalXp,
    required this.rank,
    this.isPlaceholder = false,
    this.userId,
    this.isCurrentUser = false,
  });

  /// Creates a placeholder entry with fake data
  factory LeaderboardEntry.placeholder({
    required String displayName,
    required int totalXp,
    required int rank,
  }) {
    return LeaderboardEntry(
      displayName: displayName,
      totalXp: totalXp,
      rank: rank,
      isPlaceholder: true,
    );
  }

  /// Creates an entry from Supabase RPC response
  factory LeaderboardEntry.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final userId = json['user_id'] as String?;
    return LeaderboardEntry(
      displayName: json['display_name'] as String? ?? 'Anonymous',
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: userId,
      isCurrentUser: currentUserId != null && userId == currentUserId,
    );
  }

  @override
  List<Object?> get props => [
        displayName,
        totalXp,
        rank,
        isPlaceholder,
        userId,
        isCurrentUser,
      ];

  @override
  String toString() {
    return 'LeaderboardEntry(rank: $rank, name: $displayName, xp: $totalXp, placeholder: $isPlaceholder)';
  }
}

/// Represents the current user's XP and rank information.
class UserXpRank extends Equatable {
  /// Total XP earned by the current user
  final int totalXp;

  /// User's rank (null if user has less than 200 XP)
  final int? rank;

  const UserXpRank({
    required this.totalXp,
    this.rank,
  });

  /// Whether the user is ranked (has 200+ XP)
  bool get isRanked => rank != null;

  /// Creates from Supabase RPC response
  factory UserXpRank.fromJson(Map<String, dynamic> json) {
    return UserXpRank(
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [totalXp, rank];
}
