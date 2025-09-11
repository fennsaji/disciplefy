import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/saved_payment_method.dart';
import '../repositories/payment_method_repository.dart';

class GetPaymentMethods implements UseCase<List<SavedPaymentMethod>, NoParams> {
  final PaymentMethodRepository repository;

  GetPaymentMethods(this.repository);

  @override
  Future<Either<Failure, List<SavedPaymentMethod>>> call(
      NoParams params) async {
    return await repository.getPaymentMethods();
  }
}
