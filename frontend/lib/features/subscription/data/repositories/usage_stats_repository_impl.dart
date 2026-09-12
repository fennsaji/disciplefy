import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    } on FunctionException catch (e) {
      Logger.error(
        'Function error fetching usage stats',
        tag: 'USAGE_STATS_REPO',
        error: e,
      );
      // A 401 here is reported, not acted on. It used to sign the user out
      // immediately, with no refresh attempted — so a single stale-token
      // response from one non-essential stats call could end the session,
      // including moments after a resume when the session had simply not
      // finished restoring. Usage statistics are not worth a logout.
      //
      // The refresh-or-keep decision belongs to HttpService and the router,
      // which both distinguish "refused by the server" from "could not
      // confirm". This returns the failure and lets them decide.
      if (e.status == 401) {
        Logger.warning(
          '401 from usage-stats function — reporting without ending the session',
          tag: 'USAGE_STATS_REPO',
        );
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
