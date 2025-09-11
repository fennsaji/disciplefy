import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/token_status.dart';
import '../../domain/entities/purchase_history.dart';
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

  @override
  Future<Either<Failure, TokenStatus>> getTokenStatus() async {
    if (await _networkInfo.isConnected) {
      try {
        print('🪙 [TOKEN_REPO] Fetching token status from remote...');

        final tokenStatusModel = await _remoteDataSource.getTokenStatus();
        final tokenStatus = tokenStatusModel.toEntity();

        print(
            '🪙 [TOKEN_REPO] Token status fetched successfully: ${tokenStatus.totalTokens} tokens');

        return Right(tokenStatus);
      } on ServerException catch (e) {
        print('🚨 [TOKEN_REPO] Server exception: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print('🚨 [TOKEN_REPO] Authentication exception: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print('🚨 [TOKEN_REPO] Client exception: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print('🚨 [TOKEN_REPO] Network exception: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print('🚨 [TOKEN_REPO] Unexpected exception: $e');
        return Left(ClientFailure(
          message: 'An unexpected error occurred while fetching token status',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [TOKEN_REPO] No internet connection');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, String>> createPaymentOrder({
    required int tokenAmount,
  }) async {
    if (await _networkInfo.isConnected) {
      try {
        print(
            '🪙 [TOKEN_REPO] Creating payment order for $tokenAmount tokens...');

        final orderId = await _remoteDataSource.createPaymentOrder(
          tokenAmount: tokenAmount,
        );

        print('🪙 [TOKEN_REPO] Payment order created successfully: $orderId');

        return Right(orderId);
      } on ServerException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Server exception during order creation: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Authentication exception during order creation: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Client exception during order creation: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Network exception during order creation: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print('🚨 [TOKEN_REPO] Unexpected exception during order creation: $e');
        return Left(ClientFailure(
          message: 'An unexpected error occurred during order creation',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [TOKEN_REPO] No internet connection for order creation');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, TokenStatus>> confirmPayment({
    required String paymentId,
    required String orderId,
    required String signature,
    required int tokenAmount,
  }) async {
    if (await _networkInfo.isConnected) {
      try {
        print('🪙 [TOKEN_REPO] Confirming payment: $paymentId');

        final tokenStatusModel = await _remoteDataSource.confirmPayment(
          paymentId: paymentId,
          orderId: orderId,
          signature: signature,
          tokenAmount: tokenAmount,
        );

        final tokenStatus = tokenStatusModel.toEntity();

        print(
            '🪙 [TOKEN_REPO] Payment confirmed successfully: ${tokenStatus.totalTokens} total tokens');

        return Right(tokenStatus);
      } on ServerException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Server exception during payment confirmation: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Authentication exception during payment confirmation: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Client exception during payment confirmation: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Network exception during payment confirmation: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print(
            '🚨 [TOKEN_REPO] Unexpected exception during payment confirmation: $e');
        return Left(ClientFailure(
          message: 'An unexpected error occurred during payment confirmation',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [TOKEN_REPO] No internet connection for payment confirmation');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, List<PurchaseHistory>>> getPurchaseHistory({
    int? limit,
    int? offset,
  }) async {
    if (await _networkInfo.isConnected) {
      try {
        print('🪙 [TOKEN_REPO] Fetching purchase history...');

        final purchaseHistoryModels =
            await _remoteDataSource.getPurchaseHistory(
          limit: limit,
          offset: offset,
        );

        final purchaseHistory = purchaseHistoryModels
            .map((model) => model as PurchaseHistory)
            .toList();

        print(
            '🪙 [TOKEN_REPO] Purchase history fetched successfully: ${purchaseHistory.length} records');

        return Right(purchaseHistory);
      } on ServerException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Server exception during purchase history fetch: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Authentication exception during purchase history fetch: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Client exception during purchase history fetch: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Network exception during purchase history fetch: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print(
            '🚨 [TOKEN_REPO] Unexpected exception during purchase history fetch: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while fetching purchase history',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [TOKEN_REPO] No internet connection for purchase history');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, PurchaseStatistics>> getPurchaseStatistics() async {
    if (await _networkInfo.isConnected) {
      try {
        print('🪙 [TOKEN_REPO] Fetching purchase statistics...');

        final purchaseStatisticsModel =
            await _remoteDataSource.getPurchaseStatistics();
        final purchaseStatistics =
            purchaseStatisticsModel as PurchaseStatistics;

        print('🪙 [TOKEN_REPO] Purchase statistics fetched successfully');

        return Right(purchaseStatistics);
      } on ServerException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Server exception during purchase statistics fetch: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Authentication exception during purchase statistics fetch: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Client exception during purchase statistics fetch: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Network exception during purchase statistics fetch: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print(
            '🚨 [TOKEN_REPO] Unexpected exception during purchase statistics fetch: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while fetching purchase statistics',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [TOKEN_REPO] No internet connection for purchase statistics');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }
}
