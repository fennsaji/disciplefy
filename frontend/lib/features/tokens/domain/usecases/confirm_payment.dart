import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/token_status.dart';
import '../repositories/token_repository.dart';

/// Use case for confirming payment (step 2 of new payment flow)
///
/// Verifies Razorpay payment and updates token balance
class ConfirmPayment implements UseCase<TokenStatus, ConfirmPaymentParams> {
  final TokenRepository _repository;

  ConfirmPayment(this._repository);

  @override
  Future<Either<Failure, TokenStatus>> call(ConfirmPaymentParams params) async {
    return await _repository.confirmPayment(
      paymentId: params.paymentId,
      orderId: params.orderId,
      signature: params.signature,
      tokenAmount: params.tokenAmount,
    );
  }
}

/// Parameters for confirming a payment
class ConfirmPaymentParams extends Equatable {
  final String paymentId;
  final String orderId;
  final String signature;
  final int tokenAmount;

  const ConfirmPaymentParams({
    required this.paymentId,
    required this.orderId,
    required this.signature,
    required this.tokenAmount,
  });

  @override
  List<Object?> get props => [paymentId, orderId, signature, tokenAmount];
}
