import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/saved_payment_method.dart';
import '../repositories/payment_method_repository.dart';

class GetPaymentPreferences implements UseCase<PaymentPreferences, NoParams> {
  final PaymentMethodRepository repository;

  GetPaymentPreferences(this.repository);

  @override
  Future<Either<Failure, PaymentPreferences>> call(NoParams params) async {
    return await repository.getPaymentPreferences();
  }
}
