import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/token_status.dart';
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
  Future<Either<Failure, TokenStatus>> purchaseTokens({
    required int tokenAmount,
    required String paymentOrderId,
    required String paymentId,
    required String signature,
  }) async {
    if (await _networkInfo.isConnected) {
      try {
        print('🪙 [TOKEN_REPO] Purchasing $tokenAmount tokens...');

        final tokenStatusModel = await _remoteDataSource.purchaseTokens(
          tokenAmount: tokenAmount,
          paymentOrderId: paymentOrderId,
          paymentId: paymentId,
          signature: signature,
        );

        final tokenStatus = tokenStatusModel.toEntity();

        print(
            '🪙 [TOKEN_REPO] Token purchase successful: ${tokenStatus.totalTokens} total tokens');

        return Right(tokenStatus);
      } on ServerException catch (e) {
        print('🚨 [TOKEN_REPO] Server exception during purchase: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Authentication exception during purchase: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print('🚨 [TOKEN_REPO] Client exception during purchase: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print(
            '🚨 [TOKEN_REPO] Network exception during purchase: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print('🚨 [TOKEN_REPO] Unexpected exception during purchase: $e');
        return Left(ClientFailure(
          message: 'An unexpected error occurred during token purchase',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [TOKEN_REPO] No internet connection for purchase');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }
}
