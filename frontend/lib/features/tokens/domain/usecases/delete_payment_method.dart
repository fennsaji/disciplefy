import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/payment_method_repository.dart';

class DeletePaymentMethod implements UseCase<void, DeletePaymentMethodParams> {
  final PaymentMethodRepository repository;

  DeletePaymentMethod(this.repository);

  @override
  Future<Either<Failure, void>> call(DeletePaymentMethodParams params) async {
    return await repository.deletePaymentMethod(params.paymentMethodId);
  }
}

class DeletePaymentMethodParams extends Equatable {
  final String paymentMethodId;

  const DeletePaymentMethodParams({required this.paymentMethodId});

  @override
  List<Object> get props => [paymentMethodId];
}
