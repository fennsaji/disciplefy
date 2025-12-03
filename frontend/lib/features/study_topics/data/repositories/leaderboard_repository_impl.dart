import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_remote_datasource.dart';

/// Implementation of [LeaderboardRepository].
///
/// Delegates to [LeaderboardRemoteDataSource] and wraps results in Either.
class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardRemoteDataSource _remoteDataSource;

  LeaderboardRepositoryImpl({
    required LeaderboardRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, List<LeaderboardEntry>>> getLeaderboard() async {
    try {
      final entries = await _remoteDataSource.getLeaderboard();
      return Right(entries);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to load leaderboard: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Either<Failure, UserXpRank>> getCurrentUserXpRank() async {
    try {
      final userRank = await _remoteDataSource.getCurrentUserXpRank();
      return Right(userRank);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to load user rank: ${e.toString()}',
      ));
    }
  }

  @override
  Future<Either<Failure, LeaderboardData>> getLeaderboardWithUserRank() async {
    try {
      final result = await _remoteDataSource.getLeaderboardWithUserRank();
      return Right(LeaderboardData(
        entries: result.entries,
        userRank: result.userRank,
      ));
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to load leaderboard data: ${e.toString()}',
      ));
    }
  }
}
