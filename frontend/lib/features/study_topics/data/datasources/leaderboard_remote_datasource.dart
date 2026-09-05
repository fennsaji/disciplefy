import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/leaderboard_ranking.dart';

/// Remote data source for leaderboard functionality.
///
/// Fetches leaderboard data from Supabase and pads it with placeholder
/// accounts (see [LeaderboardRanking]) while fewer than ten real users have
/// 200+ XP.
class LeaderboardRemoteDataSource {
  final SupabaseClient _supabaseClient;

  LeaderboardRemoteDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  /// Real ranked users (200+ XP), top [LeaderboardRanking.visibleEntries],
  /// ordered by rank as the database reports it.
  Future<List<LeaderboardEntry>> _fetchRealEntries() async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;

    final response = await _supabaseClient.rpc(
      'get_leaderboard',
      params: {'limit_count': LeaderboardRanking.visibleEntries},
    );

    final List<dynamic> data = response as List<dynamic>? ?? [];
    return data
        .map((json) => LeaderboardEntry.fromJson(
              json as Map<String, dynamic>,
              currentUserId: currentUserId,
            ))
        .toList();
  }

  /// The current user's XP and database rank among real ranked users, before
  /// any placeholder adjustment.
  Future<UserXpRank> _fetchUserDbRank() async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) return const UserXpRank(totalXp: 0);

    final response = await _supabaseClient.rpc(
      'get_user_xp_rank',
      params: {'p_user_id': userId},
    );

    // RPC returns a list with single row
    final List<dynamic> data = response as List<dynamic>? ?? [];
    if (data.isEmpty) return const UserXpRank(totalXp: 0);
    return UserXpRank.fromJson(data.first as Map<String, dynamic>);
  }

  UserXpRank _adjustForPlaceholders(UserXpRank dbResult, int realCount) =>
      UserXpRank(
        totalXp: dbResult.totalXp,
        rank: LeaderboardRanking.rankWithPlaceholders(
          dbRank: dbResult.rank,
          userXp: dbResult.totalXp,
          realRankedUserCount: realCount,
        ),
      );

  /// Gets the leaderboard with top 10 users, padded with placeholders while
  /// fewer than 10 real users are ranked.
  Future<List<LeaderboardEntry>> getLeaderboard() async =>
      LeaderboardRanking.merge(await _fetchRealEntries());

  /// How many real users are currently ranked (capped at 10). Lets other
  /// surfaces decide whether placeholders are in play.
  Future<int> getRealRankedUserCount() async =>
      (await _fetchRealEntries()).length;

  /// Gets the current user's XP and rank on the padded board.
  ///
  /// Returns [UserXpRank] with total XP and rank (null if < 200 XP).
  Future<UserXpRank> getCurrentUserXpRank() async {
    final results = await Future.wait([
      _fetchUserDbRank(),
      _fetchRealEntries(),
    ]);
    return _adjustForPlaceholders(
      results[0] as UserXpRank,
      (results[1] as List<LeaderboardEntry>).length,
    );
  }

  /// Gets both leaderboard and current user's rank in a single call, derived
  /// from the same set of real entries so the two cannot disagree.
  Future<({List<LeaderboardEntry> entries, UserXpRank userRank})>
      getLeaderboardWithUserRank() async {
    final results = await Future.wait([
      _fetchRealEntries(),
      _fetchUserDbRank(),
    ]);
    final realEntries = results[0] as List<LeaderboardEntry>;

    return (
      entries: LeaderboardRanking.merge(realEntries),
      userRank:
          _adjustForPlaceholders(results[1] as UserXpRank, realEntries.length),
    );
  }
}
