import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/validation/payment_validators.dart';
import '../../domain/entities/saved_payment_method.dart';
import '../../domain/entities/payment_preferences.dart';
import '../../domain/repositories/payment_method_repository.dart';
import '../datasources/token_remote_data_source.dart';
import '../../../../core/utils/logger.dart';

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
        Logger.debug(
            '💳 [PAYMENT_REPO] Fetching payment methods from remote...');

        final paymentMethodModels = await _remoteDataSource.getPaymentMethods();
        final paymentMethods = paymentMethodModels;

        Logger.debug(
            '💳 [PAYMENT_REPO] Payment methods fetched successfully: ${paymentMethods.length} methods');

        return Right(paymentMethods);
      } on ServerException catch (e) {
        Logger.debug('🚨 [PAYMENT_REPO] Server exception: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Authentication exception: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        Logger.debug('🚨 [PAYMENT_REPO] Client exception: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        Logger.debug('🚨 [PAYMENT_REPO] Network exception: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        Logger.error('🚨 [PAYMENT_REPO] Unexpected exception: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while fetching payment methods',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      Logger.debug('🚨 [PAYMENT_REPO] No internet connection');
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
    // Validate inputs before making network call
    final validationResult = _validateSavePaymentMethodInputs(
      methodType: methodType,
      provider: provider,
      token: token,
      lastFour: lastFour,
      brand: brand,
      displayName: displayName,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
    );

    if (!validationResult.isValid) {
      Logger.error(
          '🚨 [PAYMENT_REPO] Input validation failed: ${validationResult.errorMessage}');
      return Left(ClientFailure(
        message: validationResult.errorMessage ?? 'Invalid input data',
        code: validationResult.errorCode ?? 'VALIDATION_FAILED',
      ));
    }

    if (await _networkInfo.isConnected) {
      try {
        Logger.debug('💳 [PAYMENT_REPO] Saving payment method: $methodType');

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

        Logger.debug(
            '💳 [PAYMENT_REPO] Payment method saved successfully: $methodId');

        return Right(methodId);
      } on ServerException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Server exception during save: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Authentication exception during save: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Client exception during save: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Network exception during save: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        Logger.error('🚨 [PAYMENT_REPO] Unexpected exception during save: $e');
        return Left(ClientFailure(
          message: 'An unexpected error occurred while saving payment method',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      Logger.debug('🚨 [PAYMENT_REPO] No internet connection for save');
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
        Logger.debug(
            '💳 [PAYMENT_REPO] Setting default payment method: $methodId');

        final success =
            await _remoteDataSource.setDefaultPaymentMethod(methodId);

        Logger.debug('💳 [PAYMENT_REPO] Default payment method set: $success');

        return Right(success);
      } on ServerException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Server exception during set default: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Authentication exception during set default: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Client exception during set default: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Network exception during set default: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        Logger.error(
            '🚨 [PAYMENT_REPO] Unexpected exception during set default: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while setting default payment method',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      Logger.debug('🚨 [PAYMENT_REPO] No internet connection for set default');
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
        Logger.debug(
            '💳 [PAYMENT_REPO] Updating payment method usage: $methodId');

        final success =
            await _remoteDataSource.updatePaymentMethodUsage(methodId);

        Logger.debug(
            '💳 [PAYMENT_REPO] Payment method usage updated: $success');

        return Right(success);
      } on ServerException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Server exception during usage update: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Authentication exception during usage update: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Client exception during usage update: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Network exception during usage update: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        Logger.error(
            '🚨 [PAYMENT_REPO] Unexpected exception during usage update: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while updating payment method usage',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      Logger.debug('🚨 [PAYMENT_REPO] No internet connection for usage update');
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
        Logger.debug(
            '💳 [PAYMENT_REPO] Recording payment method usage: $methodId for $transactionType');

        final success = await _remoteDataSource.recordPaymentMethodUsage(
          methodId: methodId,
          transactionAmount: transactionAmount,
          transactionType: transactionType,
          metadata: metadata,
        );

        Logger.debug(
            '💳 [PAYMENT_REPO] Payment method usage recorded: $success');

        return Right(success);
      } on ServerException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Server exception during usage recording: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Authentication exception during usage recording: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Client exception during usage recording: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Network exception during usage recording: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        Logger.error(
            '🚨 [PAYMENT_REPO] Unexpected exception during usage recording: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while recording payment method usage',
          code: 'RECORD_USAGE_FAILED',
        ));
      }
    } else {
      Logger.debug(
          '🚨 [PAYMENT_REPO] No internet connection for usage recording');
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
        Logger.debug('💳 [PAYMENT_REPO] Deleting payment method: $methodId');

        final success = await _remoteDataSource.deletePaymentMethod(methodId);

        Logger.debug('💳 [PAYMENT_REPO] Payment method deleted: $success');

        return Right(success);
      } on ServerException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Server exception during delete: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Authentication exception during delete: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Client exception during delete: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Network exception during delete: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        Logger.error(
            '🚨 [PAYMENT_REPO] Unexpected exception during delete: $e');
        return Left(ClientFailure(
          message: 'An unexpected error occurred while deleting payment method',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      Logger.debug('🚨 [PAYMENT_REPO] No internet connection for delete');
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
        Logger.debug(
            '💳 [PAYMENT_REPO] Fetching payment preferences from remote...');

        final preferencesModel =
            await _remoteDataSource.getPaymentPreferences();
        final preferences = preferencesModel;

        Logger.debug(
            '💳 [PAYMENT_REPO] Payment preferences fetched successfully');

        return Right(preferences);
      } on ServerException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Server exception during preferences fetch: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Authentication exception during preferences fetch: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Client exception during preferences fetch: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Network exception during preferences fetch: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        Logger.error(
            '🚨 [PAYMENT_REPO] Unexpected exception during preferences fetch: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while fetching payment preferences',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      Logger.debug(
          '🚨 [PAYMENT_REPO] No internet connection for preferences fetch');
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
        Logger.debug('💳 [PAYMENT_REPO] Updating payment preferences...');

        final preferencesModel =
            await _remoteDataSource.updatePaymentPreferences(
          autoSavePaymentMethods: autoSavePaymentMethods,
          preferredWallet: preferredWallet,
          enableOneClickPurchase: enableOneClickPurchase,
          defaultPaymentType: defaultPaymentType,
        );
        final preferences = preferencesModel;

        Logger.debug(
            '💳 [PAYMENT_REPO] Payment preferences updated successfully');

        return Right(preferences);
      } on ServerException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Server exception during preferences update: ${e.message}');
        return Left(ServerFailure(
          message: e.message,
          code: e.code,
        ));
      } on AuthenticationException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Authentication exception during preferences update: ${e.message}');
        return Left(AuthenticationFailure(
          message: e.message,
          code: e.code,
        ));
      } on ClientException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Client exception during preferences update: ${e.message}');
        return Left(ClientFailure(
          message: e.message,
          code: e.code,
        ));
      } on NetworkException catch (e) {
        Logger.debug(
            '🚨 [PAYMENT_REPO] Network exception during preferences update: ${e.message}');
        return Left(NetworkFailure(
          message: e.message,
          code: e.code,
        ));
      } catch (e) {
        Logger.error(
            '🚨 [PAYMENT_REPO] Unexpected exception during preferences update: $e');
        return Left(ClientFailure(
          message:
              'An unexpected error occurred while updating payment preferences',
          code: 'UNEXPECTED_ERROR',
        ));
      }
    } else {
      Logger.debug(
          '🚨 [PAYMENT_REPO] No internet connection for preferences update');
      return const Left(NetworkFailure(
        message:
            'No internet connection. Please check your network and try again.',
        code: 'NO_INTERNET',
      ));
    }
  }

  /// Validates inputs for savePaymentMethod before making remote calls
  ValidationResult _validateSavePaymentMethodInputs({
    required String methodType,
    required String provider,
    required String token,
    String? lastFour,
    String? brand,
    String? displayName,
    int? expiryMonth,
    int? expiryYear,
  }) {
    // Validate required fields are non-empty
    if (methodType.trim().isEmpty) {
      return const ValidationResult.invalid(
        errorMessage: 'Payment method type is required',
        errorCode: 'MISSING_METHOD_TYPE',
      );
    }

    if (provider.trim().isEmpty) {
      return const ValidationResult.invalid(
        errorMessage: 'Payment provider is required',
        errorCode: 'MISSING_PROVIDER',
      );
    }

    if (token.trim().isEmpty) {
      return const ValidationResult.invalid(
        errorMessage: 'Payment token is required',
        errorCode: 'MISSING_TOKEN',
      );
    }

    // Validate lastFour format if provided
    if (lastFour != null && lastFour.isNotEmpty) {
      final trimmedLastFour = lastFour.trim();
      if (methodType.toLowerCase() == 'card' &&
          !RegExp(r'^\d{4}$').hasMatch(trimmedLastFour)) {
        return const ValidationResult.invalid(
          errorMessage:
              'Last four digits must be exactly 4 numbers for card payments',
          errorCode: 'INVALID_LAST_FOUR_FORMAT',
        );
      }
    }

    // Validate expiry fields for cards
    if (methodType.toLowerCase() == 'card') {
      if (expiryMonth != null) {
        if (expiryMonth < 1 || expiryMonth > 12) {
          return ValidationResult.invalid(
            errorMessage: 'Expiry month must be between 1 and 12',
            errorCode: 'INVALID_EXPIRY_MONTH',
          );
        }
      }

      if (expiryYear != null) {
        final currentYear = DateTime.now().year;
        if (expiryYear < currentYear || expiryYear > currentYear + 20) {
          return ValidationResult.invalid(
            errorMessage:
                'Expiry year must be between $currentYear and ${currentYear + 20}',
            errorCode: 'INVALID_EXPIRY_YEAR',
          );
        }
      }
    }

    // Validate display name length if provided
    if (displayName != null && displayName.trim().length > 100) {
      return const ValidationResult.invalid(
        errorMessage: 'Display name must be 100 characters or less',
        errorCode: 'DISPLAY_NAME_TOO_LONG',
      );
    }

    // Use comprehensive payment method validation
    return PaymentMethodValidator.validatePaymentMethod(
      methodType: methodType.trim(),
      provider: provider.trim(),
      lastFour: lastFour?.trim(),
      brand: brand?.trim(),
      displayName: displayName?.trim(),
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
    );
  }
}
