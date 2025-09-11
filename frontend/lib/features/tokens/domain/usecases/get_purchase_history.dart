import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/purchase_history.dart';
import '../repositories/token_repository.dart';

class GetPurchaseHistory
    implements UseCase<List<PurchaseHistory>, GetPurchaseHistoryParams> {
  final TokenRepository _repository;

  GetPurchaseHistory(this._repository);

  @override
  Future<Either<Failure, List<PurchaseHistory>>> call(
      GetPurchaseHistoryParams params) async {
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
