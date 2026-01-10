import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/usage_statistics.dart';
import '../repositories/token_repository.dart';

/// Use case for retrieving aggregated token usage statistics for the current user
///
/// Fetches comprehensive statistical data about the user's token consumption patterns
/// including total usage, operation counts, feature/language/mode breakdowns, and
/// daily vs purchased token distribution. Statistics can be filtered by date range
/// for period-specific analysis.
///
/// **Statistics Returned:**
/// - Total tokens consumed (lifetime or within date range)
/// - Total number of operations performed
/// - Daily tokens consumed vs purchased tokens consumed
/// - Most used feature, language, and study mode
/// - Detailed breakdowns by feature, language, and study mode
/// - Average tokens per operation
/// - First and last usage dates
///
/// **Data Source & Aggregation:**
/// - **Source**: Internal database token usage history records
/// - **Aggregation Period**: Real-time calculation from all historical data
/// - **Update Frequency**: Statistics reflect latest token consumption immediately
/// - **Filtering**: Supports optional date range filtering
///
/// **Returns:**
/// [Future<Either<Failure, UsageStatistics>>] containing:
/// - [Right(UsageStatistics)]: Aggregated usage statistics
/// - [Left(Failure)]: Error occurred during calculation or retrieval
///
/// **Validation Rules:**
/// - If both startDate and endDate are provided, startDate must be before endDate
/// - Invalid date range returns [ValidationFailure] immediately
///
/// **Typical Failure Reasons:**
/// - [ValidationFailure]: Invalid date range parameters
/// - [AuthenticationFailure]: User is not logged in or session expired
/// - [NetworkFailure]: Network connectivity issues during API call
/// - [ServerFailure]: Database error or statistics calculation failure
///
/// **Usage:**
/// ```dart
/// // Get lifetime statistics
/// final result = await getUsageStatistics(GetUsageStatisticsParams());
///
/// // Get statistics for specific date range
/// final result = await getUsageStatistics(GetUsageStatisticsParams(
///   startDate: DateTime(2024, 1, 1),
///   endDate: DateTime(2024, 12, 31),
/// ));
/// ```
///
/// **Performance Notes:**
/// - Statistics are calculated on-demand from usage history
/// - Large usage histories (>10,000 records) may take longer to aggregate
/// - Empty statistics are returned for users with no usage history
class GetUsageStatistics
    implements UseCase<UsageStatistics, GetUsageStatisticsParams> {
  final TokenRepository _repository;

  GetUsageStatistics(this._repository);

  @override
  Future<Either<Failure, UsageStatistics>> call(
      GetUsageStatisticsParams params) async {
    // Validate date range
    if (params.startDate != null &&
        params.endDate != null &&
        params.startDate!.isAfter(params.endDate!)) {
      return Left(ValidationFailure(
        message: 'Start date must be before or equal to end date',
        code: 'INVALID_DATE_RANGE',
        context: {
          'startDate': params.startDate!.toIso8601String(),
          'endDate': params.endDate!.toIso8601String(),
        },
      ));
    }

    return await _repository.getUsageStatistics(
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}

class GetUsageStatisticsParams {
  final DateTime? startDate;
  final DateTime? endDate;

  const GetUsageStatisticsParams({
    this.startDate,
    this.endDate,
  });
}
