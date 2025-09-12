import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/purchase_history.dart';
import '../repositories/token_repository.dart';

/// Use case for retrieving the user's token purchase transaction history
///
/// Fetches a paginated list of completed token purchases with support for
/// limiting results and offset-based pagination. The history includes purchase
/// details, payment methods used, timestamps, and transaction amounts.
///
/// **Paging Semantics:**
/// - [limit]: Optional number of results to return (must be > 0 if provided)
/// - [offset]: Number of records to skip (must be >= 0, defaults to 0)
/// - Results are ordered by purchase date (most recent first)
/// - Maximum limit is typically 100 records per request
///
/// **Returns:**
/// [Future<Either<Failure, List<PurchaseHistory>>>] containing:
/// - [Right(List<PurchaseHistory>)]: Paginated purchase history records
/// - [Left(Failure)]: Error occurred during retrieval or invalid parameters
///
/// **Validation Rules:**
/// - If limit is provided, it must be > 0
/// - Offset must be >= 0
/// - Invalid paging parameters return [ValidationFailure] immediately
///
/// **Possible Failure Cases:**
/// - [ValidationFailure]: Invalid paging parameters (limit <= 0, offset < 0)
/// - [AuthenticationFailure]: User is not logged in or session expired
/// - [NetworkFailure]: Network connectivity issues during API call
/// - [ServerFailure]: Backend service error or database failure
///
/// **Usage:**
/// ```dart
/// // Get first 20 purchases
/// final result = await getPurchaseHistory(GetPurchaseHistoryParams(
///   limit: 20,
///   offset: 0,
/// ));
///
/// // Get all purchases (no pagination)
/// final result = await getPurchaseHistory(GetPurchaseHistoryParams());
/// ```
class GetPurchaseHistory
    implements UseCase<List<PurchaseHistory>, GetPurchaseHistoryParams> {
  final TokenRepository _repository;

  GetPurchaseHistory(this._repository);

  @override
  Future<Either<Failure, List<PurchaseHistory>>> call(
      GetPurchaseHistoryParams params) async {
    // Validate paging parameters before calling repository
    if (params.limit != null && params.limit! <= 0) {
      return Left(ValidationFailure(
        message: 'Limit must be greater than 0 when provided',
        code: 'INVALID_LIMIT',
        context: {'limit': params.limit},
      ));
    }

    if (params.offset != null && params.offset! < 0) {
      return Left(ValidationFailure(
        message: 'Offset must be greater than or equal to 0',
        code: 'INVALID_OFFSET',
        context: {'offset': params.offset},
      ));
    }

    return await _repository.getPurchaseHistory(
      limit: params.limit,
      offset: params.offset,
    );
  }
}

class GetPurchaseHistoryParams {
  final int? limit;
  final int? offset;

  const GetPurchaseHistoryParams({
    this.limit,
    this.offset,
  });
}
