import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/usage_stats.dart';
import '../../domain/repositories/usage_stats_repository.dart';
import '../datasources/usage_stats_remote_data_source.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/http_service.dart';
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
    } on FunctionException catch (e) {
      Logger.error(
        'Function error fetching usage stats',
        tag: 'USAGE_STATS_REPO',
        error: e,
      );
      // 401 means the session is invalid — sign the user out so the
      // router and AuthBloc return to a consistent unauthenticated state.
      if (e.status == 401) {
        Logger.warning(
          '401 from usage-stats function — signalling auth failure',
          tag: 'USAGE_STATS_REPO',
        );
        HttpService.signalAuthFailure('Session expired (401 from usage-stats)');
        return const Left(AuthenticationFailure(
          message: 'Session expired. Please sign in again.',
        ));
      }
      return const Left(ServerFailure(
        message: 'Failed to fetch usage statistics',
      ));
    } catch (e) {
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
