import 'package:dartz/dartz.dart';
import '../entities/usage_stats.dart';
import '../../../../core/error/failures.dart';

/// Repository interface for usage statistics
abstract class UsageStatsRepository {
  /// Get current usage statistics for authenticated user
  ///
  /// Returns [UsageStats] on success, [Failure] on error
  Future<Either<Failure, UsageStats>> getUserUsageStats();
}
