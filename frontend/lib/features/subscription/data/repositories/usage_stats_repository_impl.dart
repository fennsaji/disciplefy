import 'package:dartz/dartz.dart';
import '../../domain/entities/usage_stats.dart';
import '../../domain/repositories/usage_stats_repository.dart';
import '../datasources/usage_stats_remote_data_source.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/logger.dart';

/// Implementation of usage stats repository
class UsageStatsRepositoryImpl implements UsageStatsRepository {
  final UsageStatsRemoteDataSource remoteDataSource;

  UsageStatsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, UsageStats>> getUserUsageStats() async {
    try {
      final model = await remoteDataSource.getUserUsageStats();
      return Right(model.toEntity());
    } on Exception catch (e) {
      Logger.error(
        'Repository error fetching usage stats',
        tag: 'USAGE_STATS_REPO',
        error: e,
      );
      return const Left(ServerFailure(
        message: 'Failed to fetch usage statistics',
      ));
    }
  }
}
