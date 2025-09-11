import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/token_repository.dart';

/// Use case for creating a payment order (step 1 of new payment flow)
///
/// Creates a Razorpay order and returns order ID for payment gateway
class CreatePaymentOrder implements UseCase<String, CreatePaymentOrderParams> {
  final TokenRepository _repository;

  CreatePaymentOrder(this._repository);

  @override
  Future<Either<Failure, String>> call(CreatePaymentOrderParams params) async {
    return await _repository.createPaymentOrder(
      tokenAmount: params.tokenAmount,
    );
  }
}

/// Parameters for creating a payment order
class CreatePaymentOrderParams extends Equatable {
  final int tokenAmount;

  const CreatePaymentOrderParams({
    required this.tokenAmount,
  });

  @override
  List<Object?> get props => [tokenAmount];
}
