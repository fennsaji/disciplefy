import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/memory_champion_entry.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for fetching Memory Champions Leaderboard.
///
/// Returns:
/// - List of top Memory Champions ranked by master verses
/// - Current user's statistics and rank
class GetMemoryChampionsLeaderboard
    implements
        UseCase<(List<MemoryChampionEntry>, UserMemoryStats),
            LeaderboardParams> {
  final MemoryVerseRepository repository;

  GetMemoryChampionsLeaderboard(this.repository);

  @override
  Future<Either<Failure, (List<MemoryChampionEntry>, UserMemoryStats)>> call(
    LeaderboardParams params,
  ) async {
    return repository.getMemoryChampionsLeaderboard(
      period: params.period,
      limit: params.limit,
    );
  }
}

/// Parameters for leaderboard query.
class LeaderboardParams {
  final String period; // 'weekly', 'monthly', 'all_time'
  final int limit;

  const LeaderboardParams({
    required this.period,
    this.limit = 100,
  });
}
