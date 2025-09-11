import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/payment_method_repository.dart';

class SetDefaultPaymentMethod
    implements UseCase<void, SetDefaultPaymentMethodParams> {
  final PaymentMethodRepository repository;

  SetDefaultPaymentMethod(this.repository);

  @override
  Future<Either<Failure, void>> call(
      SetDefaultPaymentMethodParams params) async {
    return await repository.setDefaultPaymentMethod(params.paymentMethodId);
  }
}

class SetDefaultPaymentMethodParams extends Equatable {
  final String paymentMethodId;

  const SetDefaultPaymentMethodParams({required this.paymentMethodId});

  @override
  List<Object> get props => [paymentMethodId];
}
