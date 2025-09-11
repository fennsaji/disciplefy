import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/saved_payment_method.dart';
import '../../domain/repositories/payment_method_repository.dart';
import '../datasources/token_remote_data_source.dart';

/// Implementation of PaymentMethodRepository that handles payment method operations.
class PaymentMethodRepositoryImpl implements PaymentMethodRepository {
  final TokenRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  const PaymentMethodRepositoryImpl({
    required TokenRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, List<SavedPaymentMethod>>> getPaymentMethods() async {
    if (await _networkInfo.isConnected) {
      try {
        print('💳 [PAYMENT_REPO] Fetching payment methods from remote...');

        final paymentMethodModels = await _remoteDataSource.getPaymentMethods();
        final paymentMethods = paymentMethodModels
            .map((model) => model as SavedPaymentMethod)
            .toList();

        print(
            '💳 [PAYMENT_REPO] Payment methods fetched successfully: ${paymentMethods.length} methods');

        return Right(paymentMethods);
      } on ServerException catch (e) {
        print('🚨 [PAYMENT_REPO] Server exception: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print('🚨 [PAYMENT_REPO] Authentication exception: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print('🚨 [PAYMENT_REPO] Client exception: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print('🚨 [PAYMENT_REPO] Network exception: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print('🚨 [PAYMENT_REPO] Unexpected exception: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while fetching payment methods',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [PAYMENT_REPO] No internet connection');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, String>> savePaymentMethod({
    required String methodType,
    required String provider,
    required String token,
    String? lastFour,
    String? brand,
    String? displayName,
    bool isDefault = false,
    int? expiryMonth,
    int? expiryYear,
  }) async {
    if (await _networkInfo.isConnected) {
      try {
        print('💳 [PAYMENT_REPO] Saving payment method: $methodType');

        final methodId = await _remoteDataSource.savePaymentMethod(
          methodType: methodType,
          provider: provider,
          token: token,
          lastFour: lastFour,
          brand: brand,
          displayName: displayName,
          isDefault: isDefault,
          expiryMonth: expiryMonth,
          expiryYear: expiryYear,
        );

        print('💳 [PAYMENT_REPO] Payment method saved successfully: $methodId');

        return Right(methodId);
      } on ServerException catch (e) {
        print('🚨 [PAYMENT_REPO] Server exception during save: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Authentication exception during save: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print('🚨 [PAYMENT_REPO] Client exception during save: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print('🚨 [PAYMENT_REPO] Network exception during save: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print('🚨 [PAYMENT_REPO] Unexpected exception during save: $e');
        return Left(ClientFailure(
          message: 'An unexpected error occurred while saving payment method',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [PAYMENT_REPO] No internet connection for save');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, bool>> setDefaultPaymentMethod(String methodId) async {
    if (await _networkInfo.isConnected) {
      try {
        print('💳 [PAYMENT_REPO] Setting default payment method: $methodId');

        final success =
            await _remoteDataSource.setDefaultPaymentMethod(methodId);

        print('💳 [PAYMENT_REPO] Default payment method set: $success');

        return Right(success);
      } on ServerException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Server exception during set default: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Authentication exception during set default: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Client exception during set default: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Network exception during set default: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print('🚨 [PAYMENT_REPO] Unexpected exception during set default: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while setting default payment method',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [PAYMENT_REPO] No internet connection for set default');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, bool>> updatePaymentMethodUsage(
      String methodId) async {
    if (await _networkInfo.isConnected) {
      try {
        print('💳 [PAYMENT_REPO] Updating payment method usage: $methodId');

        final success =
            await _remoteDataSource.updatePaymentMethodUsage(methodId);

        print('💳 [PAYMENT_REPO] Payment method usage updated: $success');

        return Right(success);
      } on ServerException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Server exception during usage update: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Authentication exception during usage update: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Client exception during usage update: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Network exception during usage update: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print('🚨 [PAYMENT_REPO] Unexpected exception during usage update: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while updating payment method usage',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [PAYMENT_REPO] No internet connection for usage update');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, bool>> recordPaymentMethodUsage({
    required String methodId,
    required double transactionAmount,
    required String transactionType,
    Map<String, dynamic>? metadata,
  }) async {
    if (await _networkInfo.isConnected) {
      try {
        print(
            '💳 [PAYMENT_REPO] Recording payment method usage: $methodId for $transactionType');

        final success = await _remoteDataSource.recordPaymentMethodUsage(
          methodId: methodId,
          transactionAmount: transactionAmount,
          transactionType: transactionType,
          metadata: metadata,
        );

        print('💳 [PAYMENT_REPO] Payment method usage recorded: $success');

        return Right(success);
      } on ServerException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Server exception during usage recording: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Authentication exception during usage recording: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Client exception during usage recording: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Network exception during usage recording: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Unexpected exception during usage recording: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while recording payment method usage',
          code: 'RECORD_USAGE_FAILED',
        ));
      }
    } else {
      print('🚨 [PAYMENT_REPO] No internet connection for usage recording');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, bool>> deletePaymentMethod(String methodId) async {
    if (await _networkInfo.isConnected) {
      try {
        print('💳 [PAYMENT_REPO] Deleting payment method: $methodId');

        final success = await _remoteDataSource.deletePaymentMethod(methodId);

        print('💳 [PAYMENT_REPO] Payment method deleted: $success');

        return Right(success);
      } on ServerException catch (e) {
        print('🚨 [PAYMENT_REPO] Server exception during delete: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Authentication exception during delete: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print('🚨 [PAYMENT_REPO] Client exception during delete: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Network exception during delete: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print('🚨 [PAYMENT_REPO] Unexpected exception during delete: $e');
        return Left(ClientFailure(
          message: 'An unexpected error occurred while deleting payment method',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [PAYMENT_REPO] No internet connection for delete');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, PaymentPreferences>> getPaymentPreferences() async {
    if (await _networkInfo.isConnected) {
      try {
        print('💳 [PAYMENT_REPO] Fetching payment preferences from remote...');

        final preferencesModel =
            await _remoteDataSource.getPaymentPreferences();
        final preferences = preferencesModel as PaymentPreferences;

        print('💳 [PAYMENT_REPO] Payment preferences fetched successfully');

        return Right(preferences);
      } on ServerException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Server exception during preferences fetch: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Authentication exception during preferences fetch: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Client exception during preferences fetch: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Network exception during preferences fetch: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Unexpected exception during preferences fetch: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while fetching payment preferences',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [PAYMENT_REPO] No internet connection for preferences fetch');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  @override
  Future<Either<Failure, PaymentPreferences>> updatePaymentPreferences({
    bool? autoSavePaymentMethods,
    String? preferredWallet,
    bool? enableOneClickPurchase,
    String? defaultPaymentType,
  }) async {
    if (await _networkInfo.isConnected) {
      try {
        print('💳 [PAYMENT_REPO] Updating payment preferences...');

        final preferencesModel =
            await _remoteDataSource.updatePaymentPreferences(
          autoSavePaymentMethods: autoSavePaymentMethods,
          preferredWallet: preferredWallet,
          enableOneClickPurchase: enableOneClickPurchase,
          defaultPaymentType: defaultPaymentType,
        );
        final preferences = preferencesModel as PaymentPreferences;

        print('💳 [PAYMENT_REPO] Payment preferences updated successfully');

        return Right(preferences);
      } on ServerException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Server exception during preferences update: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Authentication exception during preferences update: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Client exception during preferences update: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Network exception during preferences update: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        print(
            '🚨 [PAYMENT_REPO] Unexpected exception during preferences update: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while updating payment preferences',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      print('🚨 [PAYMENT_REPO] No internet connection for preferences update');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }
}
