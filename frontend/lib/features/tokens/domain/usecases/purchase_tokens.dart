import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/token_status.dart';
import '../repositories/token_repository.dart';

/// Parameters for purchasing tokens.
class PurchaseTokensParams extends Equatable {
  /// Number of tokens to purchase
  final int tokenAmount;

  /// Razorpay payment order ID
  final String paymentOrderId;

  /// Razorpay payment ID
  final String paymentId;

  /// Razorpay payment signature for verification
  final String signature;

  const PurchaseTokensParams({
    required this.tokenAmount,
    required this.paymentOrderId,
    required this.paymentId,
    required this.signature,
  });

  @override
  List<Object?> get props => [
        tokenAmount,
        paymentOrderId,
        paymentId,
        signature,
      ];

  @override
  String toString() => 'PurchaseTokensParams('
      'tokenAmount: $tokenAmount, '
      'paymentOrderId: $paymentOrderId, '
      'paymentId: $paymentId'
      ')';
}

/// Use case for purchasing additional tokens.
class PurchaseTokens implements UseCase<TokenStatus, PurchaseTokensParams> {
  final TokenRepository _repository;

  const PurchaseTokens(this._repository);

  @override
  Future<Either<Failure, TokenStatus>> call(PurchaseTokensParams params) async {
    print('🪙 [USE_CASE] Purchasing ${params.tokenAmount} tokens...');
    print('🪙 [USE_CASE] Payment Order ID: ${params.paymentOrderId}');
    print('🪙 [USE_CASE] Payment ID: ${params.paymentId}');

    // Validate parameters
    if (params.tokenAmount <= 0) {
      print('🚨 [USE_CASE] Invalid token amount: ${params.tokenAmount}');
      return const Left(ClientFailure(
        message: 'Token amount must be greater than zero',
        code: 'INVALID_TOKEN_AMOUNT',
      ));
    }

    if (params.paymentOrderId.isEmpty) {
      print('🚨 [USE_CASE] Missing payment order ID');
      return const Left(ClientFailure(
        message: 'Payment order ID is required',
        code: 'MISSING_PAYMENT_ORDER_ID',
      ));
    }

    if (params.paymentId.isEmpty) {
      print('🚨 [USE_CASE] Missing payment ID');
      return const Left(ClientFailure(
        message: 'Payment ID is required',
        code: 'MISSING_PAYMENT_ID',
      ));
    }

    if (params.signature.isEmpty) {
      print('🚨 [USE_CASE] Missing payment signature');
      return const Left(ClientFailure(
        message: 'Payment signature is required for verification',
        code: 'MISSING_PAYMENT_SIGNATURE',
      ));
    }

    final result = await _repository.purchaseTokens(
      tokenAmount: params.tokenAmount,
      paymentOrderId: params.paymentOrderId,
      paymentId: params.paymentId,
      signature: params.signature,
    );

    return result.fold(
      (failure) {
        print('🚨 [USE_CASE] Token purchase failed: ${failure.message}');
        return Left(failure);
      },
      (tokenStatus) {
        print('🪙 [USE_CASE] Token purchase successful!');
        print('🪙 [USE_CASE] New balance: ${tokenStatus.totalTokens} tokens');
        print('🪙 [USE_CASE] Available: ${tokenStatus.availableTokens}, '
            'Purchased: ${tokenStatus.purchasedTokens}');
        return Right(tokenStatus);
      },
    );
  }
}
