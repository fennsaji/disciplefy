import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/leaderboard_entry.dart';

/// Remote data source for leaderboard functionality.
///
/// Fetches leaderboard data from Supabase and fills with placeholder data
/// when there aren't enough real users with 200+ XP.
class LeaderboardRemoteDataSource {
  final SupabaseClient _supabaseClient;

  LeaderboardRemoteDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  /// Placeholder entries for leaderboard with fixed names and XP values.
  /// XP values are above 200, multiples of 50, and well-spaced.
  static const List<({String name, int xp})> _placeholderData = [
    (name: 'Rahul Sharma', xp: 600),
    (name: 'Priya Nair', xp: 550),
    (name: 'Amit Patel', xp: 500),
    (name: 'Sneha Iyer', xp: 450),
    (name: 'Vikram Reddy', xp: 400),
    (name: 'Anjali Thomas', xp: 350),
    (name: 'Suresh Kumar', xp: 300),
    (name: 'Meera Menon', xp: 300),
    (name: 'Rajesh Gupta', xp: 250),
    (name: 'Divya Joseph', xp: 250),
  ];

  /// Gets the leaderboard with top 10 users.
  ///
  /// Combines all 10 placeholder accounts with real users (200+ XP),
  /// sorts by XP descending, and returns top 10. This ensures real users
  /// are ranked correctly among the placeholder community.
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;

    // Fetch real leaderboard data from Supabase
    final response = await _supabaseClient.rpc(
      'get_leaderboard',
      params: {'limit_count': 10},
    );

    final List<dynamic> data = response as List<dynamic>? ?? [];

    // Parse real entries
    final List<LeaderboardEntry> realEntries = data
        .map((json) => LeaderboardEntry.fromJson(
              json as Map<String, dynamic>,
              currentUserId: currentUserId,
            ))
        .toList();

    // If we have 10+ real entries, just return them (no placeholders needed)
    if (realEntries.length >= 10) {
      return realEntries;
    }

    // Combine ALL placeholders with real entries, then sort and take top 10
    final List<LeaderboardEntry> combined = List.from(realEntries);
    final usedNames = <String>{};

    // Track names already used by real entries to avoid duplicates
    for (final entry in realEntries) {
      usedNames.add(entry.displayName);
    }

    // Add ALL placeholder entries (not just enough to fill 10)
    for (final placeholder in _placeholderData) {
      // Skip if name is already used by a real entry
      if (usedNames.contains(placeholder.name)) {
        continue;
      }

      combined.add(LeaderboardEntry.placeholder(
        displayName: placeholder.name,
        totalXp: placeholder.xp,
        rank: 0, // Will be reassigned after sorting
      ));

      usedNames.add(placeholder.name);
    }

    // Sort all entries by XP descending
    combined.sort((a, b) => b.totalXp.compareTo(a.totalXp));

    // Take top 10 and reassign ranks
    final sortedResult = <LeaderboardEntry>[];
    for (int i = 0; i < combined.length && i < 10; i++) {
      final entry = combined[i];
      if (entry.isPlaceholder) {
        sortedResult.add(LeaderboardEntry.placeholder(
          displayName: entry.displayName,
          totalXp: entry.totalXp,
          rank: i + 1,
        ));
      } else {
        // Re-create real entry with updated rank
        sortedResult.add(LeaderboardEntry(
          displayName: entry.displayName,
          totalXp: entry.totalXp,
          rank: i + 1,
          userId: entry.userId,
          isCurrentUser: entry.isCurrentUser,
        ));
      }
    }

    return sortedResult;
  }

  /// Calculate rank considering placeholder accounts
  /// This ensures consistency across the app
  ///
  /// The rank is calculated by counting how many placeholders have MORE XP
  /// than the user, then adding 1. This matches how the leaderboard list
  /// is sorted and displayed.
  int _calculateRankWithPlaceholders(int userXp) {
    if (userXp < 200) return 0; // Not eligible

    // Count placeholders with STRICTLY greater XP
    int rank = 1;
    for (final placeholder in _placeholderData) {
      if (placeholder.xp > userXp) {
        rank++;
      }
    }
    return rank;
  }

  /// Gets the current user's XP and rank.
  ///
  /// Returns [UserXpRank] with total XP and rank (null if < 200 XP).
  /// Rank is calculated considering placeholder accounts for consistency.
  Future<UserXpRank> getCurrentUserXpRank() async {
    final userId = _supabaseClient.auth.currentUser?.id;

    if (userId == null) {
      return const UserXpRank(totalXp: 0);
    }

    final response = await _supabaseClient.rpc(
      'get_user_xp_rank',
      params: {'p_user_id': userId},
    );

    // RPC returns a list with single row
    final List<dynamic> data = response as List<dynamic>? ?? [];

    if (data.isEmpty) {
      return const UserXpRank(totalXp: 0);
    }

    final dbResult = UserXpRank.fromJson(data.first as Map<String, dynamic>);

    // Recalculate rank considering placeholder accounts
    final adjustedRank = _calculateRankWithPlaceholders(dbResult.totalXp);

    return UserXpRank(
      totalXp: dbResult.totalXp,
      rank: adjustedRank > 0 ? adjustedRank : null,
    );
  }

  /// Gets both leaderboard and current user's rank in a single call.
  Future<({List<LeaderboardEntry> entries, UserXpRank userRank})>
      getLeaderboardWithUserRank() async {
    // Fetch both in parallel
    final results = await Future.wait([
      getLeaderboard(),
      getCurrentUserXpRank(),
    ]);

    return (
      entries: results[0] as List<LeaderboardEntry>,
      userRank: results[1] as UserXpRank,
    );
  }
}
