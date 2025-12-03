import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/leaderboard_entry.dart';

/// Repository interface for leaderboard operations.
///
/// Follows Clean Architecture - domain layer defines the contract,
/// data layer provides the implementation.
abstract class LeaderboardRepository {
  /// Gets the leaderboard with top 10 users.
  ///
  /// Real users with 200+ XP are shown first, remaining spots filled with
  /// placeholder data using fixed Indian names and XP values.
  Future<Either<Failure, List<LeaderboardEntry>>> getLeaderboard();

  /// Gets the current user's XP and rank.
  ///
  /// Returns [UserXpRank] with total XP and rank (null if < 200 XP).
  Future<Either<Failure, UserXpRank>> getCurrentUserXpRank();

  /// Gets both leaderboard entries and current user's rank.
  ///
  /// More efficient than calling both methods separately.
  Future<Either<Failure, LeaderboardData>> getLeaderboardWithUserRank();
}

/// Combined leaderboard data with user rank.
class LeaderboardData {
  final List<LeaderboardEntry> entries;
  final UserXpRank userRank;

  const LeaderboardData({
    required this.entries,
    required this.userRank,
  });
}
