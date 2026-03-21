import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/token_repository.dart';
import '../entities/payment_order_response.dart';

/// Use case for creating a payment order (step 1 of new payment flow)
///
/// Creates a Razorpay order and returns complete payment order response
class CreatePaymentOrder
    implements UseCase<PaymentOrderResponse, CreatePaymentOrderParams> {
  final TokenRepository _repository;

  CreatePaymentOrder(this._repository);

  @override
  Future<Either<Failure, PaymentOrderResponse>> call(
      CreatePaymentOrderParams params) async {
    // Validate tokenAmount is positive
    if (params.tokenAmount <= 0) {
      return Left(ValidationFailure(
        message: 'Token amount must be greater than 0',
        code: 'INVALID_TOKEN_AMOUNT',
        context: {
          'tokenAmount': params.tokenAmount,
        },
      ));
    }

    return await _repository.createPaymentOrder(
      tokenAmount: params.tokenAmount,
      rupeeAmount: params.rupeeAmount,
    );
  }
}

/// Parameters for creating a payment order
class CreatePaymentOrderParams extends Equatable {
  final int tokenAmount;

  /// Discounted rupee amount from the loaded pricing packages.
  final int rupeeAmount;

  const CreatePaymentOrderParams({
    required this.tokenAmount,
    required this.rupeeAmount,
  });

  @override
  List<Object?> get props => [tokenAmount, rupeeAmount];
}
