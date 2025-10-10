import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/token_status.dart';
import '../repositories/token_repository.dart';

/// Use case for fetching current token status from the remote data source.
///
/// This use case retrieves the user's token balance, including:
/// - Available tokens from daily allocation
/// - Purchased tokens from token purchases
/// - Total token count
/// - User's current plan information
///
/// Returns either a [Failure] if the operation fails, or a [TokenStatus] entity
/// containing the complete token information for the authenticated user.
class GetTokenStatus implements UseCase<TokenStatus, NoParams> {
  final TokenRepository _repository;

  const GetTokenStatus(this._repository);

  /// Executes the use case to retrieve current token status.
  ///
  /// Returns [Either<Failure, TokenStatus>] where:
  /// - [Left] contains a [Failure] if the operation fails
  /// - [Right] contains [TokenStatus] with current token information
  @override
  Future<Either<Failure, TokenStatus>> call(NoParams params) async {
    return await _repository.getTokenStatus();
  }
}
