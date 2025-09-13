import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/token_status.dart';
import '../entities/purchase_history.dart';
import '../entities/purchase_statistics.dart';
import '../entities/payment_order_response.dart';

/// Abstract repository for token-related operations.
abstract class TokenRepository {
  /// Fetches current token status for the user.
  ///
  /// Returns [TokenStatus] on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, TokenStatus>> getTokenStatus();

  /// Creates a payment order for token purchase (step 1 of new flow)
  ///
  /// [tokenAmount] - Number of tokens to purchase (must be positive)
  ///
  /// Returns complete payment order response with order ID and key ID on success.
  /// Returns [Failure] on error (network, server, authentication, validation, etc.).
  Future<Either<Failure, PaymentOrderResponse>> createPaymentOrder({
    required int tokenAmount,
  });

  /// Confirms payment after successful Razorpay transaction (step 2 of new flow)
  ///
  /// [paymentId] - Razorpay payment ID
  /// [orderId] - Razorpay order ID
  /// [signature] - Razorpay payment signature
  /// [tokenAmount] - Number of tokens purchased
  ///
  /// Returns [TokenStatus] with updated balance on success.
  /// Returns [Failure] on error (network, server, authentication, validation, etc.).
  Future<Either<Failure, TokenStatus>> confirmPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required int tokenAmount,
  });

  /// Gets purchase history for the authenticated user.
  ///
  /// [limit] - Maximum number of purchases to return (optional)
  /// [offset] - Number of purchases to skip (optional)
  ///
  /// Returns list of [PurchaseHistory] records on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, List<PurchaseHistory>>> getPurchaseHistory({
    int? limit,
    int? offset,
  });

  /// Gets purchase statistics for the authenticated user.
  ///
  /// Returns [PurchaseStatistics] with aggregated data on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, PurchaseStatistics>> getPurchaseStatistics();
}
