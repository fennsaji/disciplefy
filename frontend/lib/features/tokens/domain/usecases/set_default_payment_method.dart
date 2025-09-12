import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/payment_method_repository.dart';

/// Use case for setting a user's default payment method
///
/// Designates a specific saved payment method as the user's preferred choice
/// for future token purchases. The default payment method will be automatically
/// selected and highlighted in payment flows, providing a faster checkout experience.
///
/// **Purpose:**
/// - Sets the specified payment method as default for the current user
/// - Updates user preferences to reflect the new default selection
/// - Ensures only one payment method can be default at a time
/// - Removes default status from previously selected payment method
///
/// **Input:**
/// [SetDefaultPaymentMethodParams] containing:
/// - [paymentMethodId]: Unique identifier of the payment method to set as default
///
/// **Returns:**
/// [Future<Either<Failure, void>>] indicating operation result:
/// - [Right(void)]: Default payment method updated successfully
/// - [Left(Failure)]: Error occurred during update operation
///
/// **Possible Failure Scenarios:**
/// - [NotFoundFailure]: Payment method ID does not exist in user's saved methods
/// - [AuthorizationFailure]: User does not own the specified payment method
/// - [AuthenticationFailure]: User is not logged in or session expired
/// - [NetworkFailure]: Network connectivity issues during API call
/// - [ServerFailure]: Backend service error or payment provider API failure
/// - [ValidationFailure]: Invalid payment method ID format
///
/// **Usage:**
/// ```dart
/// final result = await setDefaultPaymentMethod(SetDefaultPaymentMethodParams(
///   paymentMethodId: 'pm_1234567890',
/// ));
///
/// result.fold(
///   (failure) => handleSetDefaultError(failure),
///   (_) => showDefaultSetSuccess(),
/// );
/// ```
///
/// **Behavior Notes:**
/// - Operation is idempotent - setting an already-default method succeeds
/// - Automatically clears previous default when setting a new one
/// - Changes take effect immediately for subsequent payment flows
class SetDefaultPaymentMethod
    implements UseCase<void, SetDefaultPaymentMethodParams> {
  final PaymentMethodRepository repository;

  SetDefaultPaymentMethod(this.repository);

  @override
  Future<Either<Failure, void>> call(
      SetDefaultPaymentMethodParams params) async {
    return await repository.setDefaultPaymentMethod(params.paymentMethodId);
  }
}

/// Parameters for setting a default payment method
///
/// Contains the unique identifier of the payment method to designate
/// as the user's preferred payment option for future purchases.
class SetDefaultPaymentMethodParams extends Equatable {
  /// Unique identifier of the payment method to set as default
  ///
  /// This must be a valid payment method ID that exists in the user's
  /// saved payment methods. Typically provided by the payment gateway
  /// when the method was initially saved.
  final String paymentMethodId;

  /// Creates parameters for setting a default payment method
  ///
  /// [paymentMethodId] Must be a valid, non-empty payment method identifier
  /// that belongs to the current user
  const SetDefaultPaymentMethodParams({required this.paymentMethodId});

  @override
  List<Object> get props => [paymentMethodId];
}
