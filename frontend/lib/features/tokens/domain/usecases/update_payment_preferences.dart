import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/payment_preferences.dart';
import '../repositories/payment_method_repository.dart';

/// Use case for updating user's payment preferences and settings
///
/// Modifies the user's payment configuration including auto-save behavior,
/// preferred wallet selection, one-click purchase enablement, and default
/// payment type preferences. Only non-null parameters are updated, allowing
/// for partial preference modifications.
///
/// **Parameter Semantics:**
/// - [autoSavePaymentMethods]: Whether to automatically save payment methods for future use
/// - [preferredWallet]: Default wallet provider (e.g., "paytm", "phonepe", "googlepay")
/// - [enableOneClickPurchase]: Enable faster checkout with saved payment methods
/// - [defaultPaymentType]: Preferred payment type (e.g., "card", "upi", "wallet")
///
/// **Validation:**
/// - At least one parameter must be non-null to prevent no-op updates
/// - Empty updates return [ValidationFailure] without calling repository
/// - All provided values are validated before applying changes
///
/// **Returns:**
/// [Future<Either<Failure, PaymentPreferences>>] containing:
/// - [Right(PaymentPreferences)]: Updated payment preferences
/// - [Left(Failure)]: Error occurred during update or validation failure
///
/// **Possible Failure Cases:**
/// - [ValidationFailure]: No parameters provided or invalid parameter values
/// - [AuthenticationFailure]: User is not logged in or session expired
/// - [NetworkFailure]: Network connectivity issues during API call
/// - [ServerFailure]: Backend service error or payment provider API failure
///
/// **Usage:**
/// ```dart
/// // Update only auto-save preference
/// final result = await updatePaymentPreferences(UpdatePaymentPreferencesParams(
///   autoSavePaymentMethods: true,
/// ));
///
/// // Update multiple preferences
/// final result = await updatePaymentPreferences(UpdatePaymentPreferencesParams(
///   autoSavePaymentMethods: false,
///   preferredWallet: 'googlepay',
///   enableOneClickPurchase: true,
/// ));
/// ```
class UpdatePaymentPreferences
    implements UseCase<PaymentPreferences, UpdatePaymentPreferencesParams> {
  final PaymentMethodRepository repository;

  UpdatePaymentPreferences(this.repository);

  @override
  Future<Either<Failure, PaymentPreferences>> call(
      UpdatePaymentPreferencesParams params) async {
    // Validate that at least one field is provided for update
    if (params.autoSavePaymentMethods == null &&
        params.preferredWallet == null &&
        params.enableOneClickPurchase == null &&
        params.defaultPaymentType == null) {
      return const Left(ValidationFailure(
        message: 'At least one payment preference must be provided for update',
        code: 'NO_UPDATE_FIELDS',
        context: {
          'providedFields': 0,
          'availableFields': [
            'autoSavePaymentMethods',
            'preferredWallet',
            'enableOneClickPurchase',
            'defaultPaymentType'
          ],
        },
      ));
    }

    // Comprehensive payload validation with business rules
    final validationResult = _validatePaymentPreferencesPayload(params);
    if (validationResult != null) {
      return Left(validationResult);
    }

    return await repository.updatePaymentPreferences(
      autoSavePaymentMethods: params.autoSavePaymentMethods,
      preferredWallet: params.preferredWallet,
      enableOneClickPurchase: params.enableOneClickPurchase,
      defaultPaymentType: params.defaultPaymentType,
    );
  }

  /// Validates payment preferences payload against business rules
  ///
  /// Returns [ValidationFailure] if validation fails, null if valid
  ValidationFailure? _validatePaymentPreferencesPayload(
      UpdatePaymentPreferencesParams params) {
    // Validate preferred wallet if provided
    if (params.preferredWallet != null) {
      final wallet = params.preferredWallet!.trim().toLowerCase();

      if (wallet.isEmpty) {
        return const ValidationFailure(
          message: 'Preferred wallet cannot be empty',
          code: 'EMPTY_PREFERRED_WALLET',
          context: {'field': 'preferredWallet'},
        );
      }

      // Validate against supported wallet providers
      const supportedWallets = {
        'paytm',
        'phonepe',
        'googlepay',
        'amazonpay',
        'mobikwik',
        'freecharge',
        'jiopay',
        'olamoney',
        'payumoney',
        'airtelwallet'
      };

      if (!supportedWallets.contains(wallet)) {
        return ValidationFailure(
          message: 'Unsupported wallet provider: ${params.preferredWallet}',
          code: 'UNSUPPORTED_WALLET_PROVIDER',
          context: {
            'providedWallet': params.preferredWallet,
            'supportedWallets': supportedWallets.toList(),
          },
        );
      }
    }

    // Validate default payment type if provided
    if (params.defaultPaymentType != null) {
      final paymentType = params.defaultPaymentType!.trim().toLowerCase();

      if (paymentType.isEmpty) {
        return const ValidationFailure(
          message: 'Default payment type cannot be empty',
          code: 'EMPTY_PAYMENT_TYPE',
          context: {'field': 'defaultPaymentType'},
        );
      }

      // Validate against supported payment types
      const supportedPaymentTypes = {'card', 'upi', 'netbanking', 'wallet'};

      if (!supportedPaymentTypes.contains(paymentType)) {
        return ValidationFailure(
          message: 'Unsupported payment type: ${params.defaultPaymentType}',
          code: 'UNSUPPORTED_PAYMENT_TYPE',
          context: {
            'providedPaymentType': params.defaultPaymentType,
            'supportedPaymentTypes': supportedPaymentTypes.toList(),
          },
        );
      }
    }

    // Business rule: One-click purchase requires auto-save to be enabled
    if (params.enableOneClickPurchase == true &&
        params.autoSavePaymentMethods == false) {
      return const ValidationFailure(
        message:
            'One-click purchase requires auto-save payment methods to be enabled',
        code: 'ONECLICK_REQUIRES_AUTOSAVE',
        context: {
          'enableOneClickPurchase': true,
          'autoSavePaymentMethods': false,
          'businessRule': 'One-click purchase depends on saved payment methods',
        },
      );
    }

    return null; // All validations passed
  }
}

/// Parameters for updating payment preferences
///
/// Contains optional fields for modifying user's payment configuration.
/// At least one field must be non-null to perform a meaningful update.
class UpdatePaymentPreferencesParams extends Equatable {
  /// Whether to automatically save payment methods for future use
  final bool? autoSavePaymentMethods;

  /// Preferred wallet provider (e.g., "paytm", "phonepe", "googlepay")
  final String? preferredWallet;

  /// Enable faster checkout with saved payment methods
  final bool? enableOneClickPurchase;

  /// Preferred payment type (e.g., "card", "upi", "wallet")
  final String? defaultPaymentType;

  /// Creates parameters for updating payment preferences
  ///
  /// At least one parameter must be non-null to prevent no-op updates.
  /// Throws [ArgumentError] if all parameters are null.
  ///
  /// [autoSavePaymentMethods] Whether to save payment methods automatically
  /// [preferredWallet] Default wallet provider preference
  /// [enableOneClickPurchase] Enable one-click purchase feature
  /// [defaultPaymentType] Default payment method type
  const UpdatePaymentPreferencesParams({
    this.autoSavePaymentMethods,
    this.preferredWallet,
    this.enableOneClickPurchase,
    this.defaultPaymentType,
  }) : assert(
          autoSavePaymentMethods != null ||
              preferredWallet != null ||
              enableOneClickPurchase != null ||
              defaultPaymentType != null,
          'At least one payment preference must be provided for update',
        );

  @override
  List<Object?> get props => [
        autoSavePaymentMethods,
        preferredWallet,
        enableOneClickPurchase,
        defaultPaymentType,
      ];
}
