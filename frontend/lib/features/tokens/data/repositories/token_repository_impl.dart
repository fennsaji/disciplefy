import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/validation/payment_validators.dart';
import '../../domain/entities/token_status.dart';
import '../../domain/entities/purchase_history.dart';
import '../../domain/entities/purchase_statistics.dart';
import '../../domain/repositories/token_repository.dart';
import '../datasources/token_remote_data_source.dart';

/// Implementation of TokenRepository that handles data operations.
class TokenRepositoryImpl implements TokenRepository {
  final TokenRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  const TokenRepositoryImpl({
    required TokenRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  /// Generic error handler that converts exceptions to failures
  Future<Either<Failure, T>> _execute<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    if (await _networkInfo.isConnected) {
      try {
        final result = await operation();
        return Right(result);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, code: e.code));
      } on AuthenticationException catch (e) {
        return Left(AuthenticationFailure(message: e.message, code: e.code));
      } on ClientException catch (e) {
        return Left(ClientFailure(message: e.message, code: e.code));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message, code: e.code));
      } catch (e) {
        return Left(ClientFailure(
          message: 'An unexpected error occurred during $operationName',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, TokenStatus>> getTokenStatus() async {
    return _execute<TokenStatus>(
      () async {
        final tokenStatusModel = await _remoteDataSource.getTokenStatus();
        return tokenStatusModel.toEntity();
      },
      'token status fetch',
    );
  }

  @override
  Future<Either<Failure, String>> createPaymentOrder({
    required int tokenAmount,
  }) async {
    // Comprehensive input validation using TokenPurchaseValidator
    final validationResult =
        TokenPurchaseValidator.validateTokenAmount(tokenAmount);

    if (!validationResult.isValid) {
      return Left(ClientFailure(
        message: validationResult.errorMessage ?? 'Invalid token amount',
        code: validationResult.errorCode ?? 'INVALID_TOKEN_AMOUNT',
      ));
    }

    // Additional business rule validation
    if (tokenAmount < 50) {
      return const Left(ClientFailure(
        message: 'Minimum token purchase is 50 tokens',
        code: 'TOKEN_AMOUNT_BELOW_MINIMUM',
      ));
    }

    if (tokenAmount > 9999) {
      return const Left(ClientFailure(
        message: 'Maximum token purchase is 9,999 tokens per transaction',
        code: 'TOKEN_AMOUNT_EXCEEDS_MAXIMUM',
      ));
    }

    return _execute<String>(
      () async {
        return await _remoteDataSource.createPaymentOrder(
          tokenAmount: tokenAmount,
        );
      },
      'payment order creation',
    );
  }

  @override
  Future<Either<Failure, TokenStatus>> confirmPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required int tokenAmount,
  }) async {
    // Comprehensive input validation before network calls

    // Validate paymentId - non-null, non-empty, expected format
    if (paymentId.trim().isEmpty) {
      return const Left(ClientFailure(
        message: 'Payment ID is required',
        code: 'MISSING_PAYMENT_ID',
      ));
    }

    // Basic format validation for Razorpay payment IDs
    if (!RegExp(r'^pay_[A-Za-z0-9]{14}$').hasMatch(paymentId.trim())) {
      return const Left(ClientFailure(
        message: 'Invalid payment ID format',
        code: 'INVALID_PAYMENT_ID_FORMAT',
      ));
    }

    // Validate orderId - non-null, non-empty, expected format
    if (orderId.trim().isEmpty) {
      return const Left(ClientFailure(
        message: 'Order ID is required',
        code: 'MISSING_ORDER_ID',
      ));
    }

    // Basic format validation for Razorpay order IDs
    if (!RegExp(r'^order_[A-Za-z0-9]{14}$').hasMatch(orderId.trim())) {
      return const Left(ClientFailure(
        message: 'Invalid order ID format',
        code: 'INVALID_ORDER_ID_FORMAT',
      ));
    }

    // Validate signature - non-null, non-empty, hex format
    if (signature.trim().isEmpty) {
      return const Left(ClientFailure(
        message: 'Payment signature is required',
        code: 'MISSING_SIGNATURE',
      ));
    }

    // Basic validation for signature format (hex string)
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(signature.trim())) {
      return const Left(ClientFailure(
        message: 'Invalid payment signature format',
        code: 'INVALID_SIGNATURE_FORMAT',
      ));
    }

    // Comprehensive token amount validation
    final tokenValidationResult =
        TokenPurchaseValidator.validateTokenAmount(tokenAmount);

    if (!tokenValidationResult.isValid) {
      return Left(ClientFailure(
        message: tokenValidationResult.errorMessage ?? 'Invalid token amount',
        code: tokenValidationResult.errorCode ?? 'INVALID_TOKEN_AMOUNT',
      ));
    }

    return _execute<TokenStatus>(
      () async {
        final tokenStatusModel = await _remoteDataSource.confirmPayment(
          paymentId: paymentId,
          orderId: orderId,
          signature: signature,
          tokenAmount: tokenAmount,
        );
        return tokenStatusModel.toEntity();
      },
      'payment confirmation',
    );
  }

  @override
  Future<Either<Failure, List<PurchaseHistory>>> getPurchaseHistory({
    int? limit,
    int? offset,
  }) async {
    return _execute<List<PurchaseHistory>>(
      () async {
        final purchaseHistoryModels =
            await _remoteDataSource.getPurchaseHistory(
          limit: limit,
          offset: offset,
        );
        return purchaseHistoryModels;
      },
      'purchase history fetch',
    );
  }

  @override
  Future<Either<Failure, PurchaseStatistics>> getPurchaseStatistics() async {
    return _execute<PurchaseStatistics>(
      () async {
        final purchaseStatisticsModel =
            await _remoteDataSource.getPurchaseStatistics();
        return purchaseStatisticsModel.toEntity();
      },
      'purchase statistics fetch',
    );
  }
}
