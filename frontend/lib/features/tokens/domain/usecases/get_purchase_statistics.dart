import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/purchase_history.dart';
import '../repositories/token_repository.dart';

class GetPurchaseStatistics implements UseCase<PurchaseStatistics, NoParams> {
  final TokenRepository _repository;

  GetPurchaseStatistics(this._repository);

  @override
  Future<Either<Failure, PurchaseStatistics>> call(NoParams params) async {
    return await _repository.getPurchaseStatistics();
  }
}
