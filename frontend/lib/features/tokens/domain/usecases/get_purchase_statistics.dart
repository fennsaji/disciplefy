import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/purchase_history.dart';
import '../entities/purchase_statistics.dart';
import '../repositories/token_repository.dart';

/// Use case for retrieving aggregated purchase statistics for the current user
///
/// Fetches comprehensive statistical data about the user's token purchase patterns
/// including total purchases, amounts spent, average purchase size, and time-based
/// aggregations. Statistics are computed in real-time from the purchase history
/// stored in the internal database.
///
/// **Statistics Returned:**
/// - Total number of purchases (lifetime)
/// - Total amount spent across all purchases
/// - Average purchase amount
/// - Most recent purchase date
/// - Purchase frequency metrics (daily/weekly/monthly averages)
/// - Payment method usage breakdown
///
/// **Data Source & Aggregation:**
/// - **Source**: Internal database purchase history records
/// - **Aggregation Period**: Real-time calculation from all historical data
/// - **Update Frequency**: Statistics reflect latest completed purchases immediately
/// - **Currency**: All monetary values in user's preferred currency (typically INR)
///
/// **Returns:**
/// [Future<Either<Failure, PurchaseStatistics>>] containing:
/// - [Right(PurchaseStatistics)]: Aggregated purchase statistics
/// - [Left(Failure)]: Error occurred during calculation or retrieval
///
/// **Typical Failure Reasons:**
/// - [AuthenticationFailure]: User is not logged in or session expired
/// - [NetworkFailure]: Network connectivity issues during API call
/// - [ServerFailure]: Database error or statistics calculation failure
/// - [NotFoundFailure]: User has no purchase history (returns empty statistics)
/// - [CacheFailure]: Local cache corruption requiring fresh data fetch
///
/// **Usage:**
/// ```dart
/// final result = await getPurchaseStatistics(NoParams());
///
/// result.fold(
///   (failure) => handleStatisticsError(failure),
///   (stats) => displayStatistics(stats),
/// );
/// ```
///
/// **Performance Notes:**
/// - Statistics are cached for 5 minutes to improve performance
/// - Large purchase histories (>1000 transactions) may take longer to calculate
/// - Consider pagination for users with extensive purchase records
class GetPurchaseStatistics implements UseCase<PurchaseStatistics, NoParams> {
  final TokenRepository _repository;

  GetPurchaseStatistics(this._repository);

  /// Retrieves aggregated purchase statistics for the current user
  ///
  /// [params] No parameters required (uses [NoParams])
  ///
  /// Returns [Right(PurchaseStatistics)] with aggregated data on success,
  /// or [Left(Failure)] if calculation fails. Empty statistics are returned
  /// for users with no purchase history rather than an error.
  @override
  Future<Either<Failure, PurchaseStatistics>> call(NoParams params) async {
    return await _repository.getPurchaseStatistics();
  }
}
