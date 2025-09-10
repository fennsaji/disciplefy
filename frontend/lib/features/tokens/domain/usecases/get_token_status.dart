import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/token_status.dart';
import '../repositories/token_repository.dart';

/// Use case for fetching current token status.
class GetTokenStatus implements UseCase<TokenStatus, NoParams> {
  final TokenRepository _repository;

  const GetTokenStatus(this._repository);

  @override
  Future<Either<Failure, TokenStatus>> call(NoParams params) async {
    print('🪙 [USE_CASE] Getting token status...');

    final result = await _repository.getTokenStatus();

    return result.fold(
      (failure) {
        print('🚨 [USE_CASE] Get token status failed: ${failure.message}');
        return Left(failure);
      },
      (tokenStatus) {
        print('🪙 [USE_CASE] Token status retrieved successfully');
        print('🪙 [USE_CASE] Available: ${tokenStatus.availableTokens}, '
            'Purchased: ${tokenStatus.purchasedTokens}, '
            'Total: ${tokenStatus.totalTokens}, '
            'Plan: ${tokenStatus.userPlan.displayName}');
        return Right(tokenStatus);
      },
    );
  }
}
