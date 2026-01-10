import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/token_usage_history.dart';
import '../repositories/token_repository.dart';

/// Use case for retrieving the user's token usage history
///
/// Fetches a paginated list of token consumption records with support for
/// limiting results, offset-based pagination, and date range filtering. The history
/// includes detailed usage information such as feature/operation, study mode, language,
/// content references, and token costs (daily vs purchased breakdown).
///
/// **Paging Semantics:**
/// - [limit]: Optional number of results to return (1-100, defaults to 20)
/// - [offset]: Number of records to skip (must be >= 0, defaults to 0)
/// - [startDate]: Optional start date for filtering records (inclusive)
/// - [endDate]: Optional end date for filtering records (inclusive)
/// - Results are ordered by created_at (most recent first)
///
/// **Returns:**
/// [Future<Either<Failure, List<TokenUsageHistory>>>] containing:
/// - [Right(List<TokenUsageHistory>)]: Paginated usage history records
/// - [Left(Failure)]: Error occurred during retrieval or invalid parameters
///
/// **Validation Rules:**
/// - If limit is provided, it must be between 1 and 100
/// - Offset must be >= 0
/// - If both startDate and endDate are provided, startDate must be before endDate
/// - Invalid parameters return [ValidationFailure] immediately
///
/// **Possible Failure Cases:**
/// - [ValidationFailure]: Invalid paging or date parameters
/// - [AuthenticationFailure]: User is not logged in or session expired
/// - [NetworkFailure]: Network connectivity issues during API call
/// - [ServerFailure]: Backend service error or database failure
///
/// **Usage:**
/// ```dart
/// // Get first 20 usage records
/// final result = await getUsageHistory(GetUsageHistoryParams(
///   limit: 20,
///   offset: 0,
/// ));
///
/// // Get usage history for specific date range
/// final result = await getUsageHistory(GetUsageHistoryParams(
///   startDate: DateTime(2024, 1, 1),
///   endDate: DateTime(2024, 12, 31),
/// ));
/// ```
class GetUsageHistory
    implements UseCase<List<TokenUsageHistory>, GetUsageHistoryParams> {
  final TokenRepository _repository;

  GetUsageHistory(this._repository);

  @override
  Future<Either<Failure, List<TokenUsageHistory>>> call(
      GetUsageHistoryParams params) async {
    // Validate limit parameter
    if (params.limit != null && (params.limit! < 1 || params.limit! > 100)) {
      return Left(ValidationFailure(
        message: 'Limit must be between 1 and 100',
        code: 'INVALID_LIMIT',
        context: {'limit': params.limit},
      ));
    }

    // Validate offset parameter
    if (params.offset != null && params.offset! < 0) {
      return Left(ValidationFailure(
        message: 'Offset must be greater than or equal to 0',
        code: 'INVALID_OFFSET',
        context: {'offset': params.offset},
      ));
    }

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

    return await _repository.getUsageHistory(
      limit: params.limit,
      offset: params.offset,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}

class GetUsageHistoryParams {
  final int? limit;
  final int? offset;
  final DateTime? startDate;
  final DateTime? endDate;

  const GetUsageHistoryParams({
    this.limit,
    this.offset,
    this.startDate,
    this.endDate,
  });
}
