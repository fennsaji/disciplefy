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
  /// Real users with 200+ XP are shown first, remaining spots filled with
  /// placeholder data using fixed Indian names and XP values.
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

    // If we have 10 real entries, return them
    if (realEntries.length >= 10) {
      return realEntries;
    }

    // Fill remaining spots with placeholder data (fixed names and XP)
    final List<LeaderboardEntry> result = List.from(realEntries);
    final usedNames = <String>{};

    // Track names already used by real entries to avoid duplicates
    for (final entry in realEntries) {
      usedNames.add(entry.displayName);
    }

    // Add placeholder entries with fixed XP values
    int placeholderIndex = 0;
    while (result.length < 10 && placeholderIndex < _placeholderData.length) {
      final placeholder = _placeholderData[placeholderIndex];
      placeholderIndex++;

      // Skip if name is already used by a real entry
      if (usedNames.contains(placeholder.name)) {
        continue;
      }

      result.add(LeaderboardEntry.placeholder(
        displayName: placeholder.name,
        totalXp: placeholder.xp,
        rank: result.length + 1,
      ));

      usedNames.add(placeholder.name);
    }

    // Sort all entries by XP descending and reassign ranks
    result.sort((a, b) => b.totalXp.compareTo(a.totalXp));
    final sortedResult = <LeaderboardEntry>[];
    for (int i = 0; i < result.length; i++) {
      final entry = result[i];
      if (entry.isPlaceholder) {
        sortedResult.add(LeaderboardEntry.placeholder(
          displayName: entry.displayName,
          totalXp: entry.totalXp,
          rank: i + 1,
        ));
      } else {
        // Re-create real entry with updated rank if needed
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

  /// Gets the current user's XP and rank.
  ///
  /// Returns [UserXpRank] with total XP and rank (null if < 200 XP).
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

    return UserXpRank.fromJson(data.first as Map<String, dynamic>);
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
