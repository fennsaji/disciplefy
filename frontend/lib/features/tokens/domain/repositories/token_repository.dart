import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/token_status.dart';

/// Abstract repository for token-related operations.
abstract class TokenRepository {
  /// Fetches current token status for the user.
  ///
  /// Returns [TokenStatus] on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, TokenStatus>> getTokenStatus();

  /// Purchases additional tokens for standard plan users.
  ///
  /// [tokenAmount] - Number of tokens to purchase (must be positive)
  /// [paymentOrderId] - Razorpay payment order ID
  /// [paymentId] - Razorpay payment ID
  /// [signature] - Razorpay payment signature
  ///
  /// Returns [TokenStatus] with updated balance on success.
  /// Returns [Failure] on error (network, server, authentication, validation, etc.).
  Future<Either<Failure, TokenStatus>> purchaseTokens({
    required int tokenAmount,
    required String paymentOrderId,
    required String paymentId,
    required String signature,
  });
}
