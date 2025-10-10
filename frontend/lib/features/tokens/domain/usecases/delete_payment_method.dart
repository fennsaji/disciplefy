import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/payment_method_repository.dart';

/// Use case for deleting a stored payment method from user's account
///
/// Removes a previously saved payment method (card, UPI, etc.) from the
/// user's payment preferences, making it unavailable for future purchases.
///
/// **Failure Semantics:**
/// - [AuthenticationFailure]: User is not logged in or session expired
/// - [AuthorizationFailure]: User does not own the payment method being deleted
/// - [NotFoundFailure]: Payment method ID does not exist or was already deleted
/// - [NetworkFailure]: Network connectivity issues during deletion request
/// - [ServerFailure]: Backend service error or payment provider API failure
/// - [ValidationFailure]: Invalid payment method ID format
///
/// **Usage:**
/// ```dart
/// final result = await deletePaymentMethod(DeletePaymentMethodParams(
///   paymentMethodId: 'pm_1234567890',
/// ));
///
/// result.fold(
///   (failure) => handleDeletionError(failure),
///   (_) => showDeletionSuccess(),
/// );
/// ```
///
/// **Note**: Deletion is idempotent - calling delete on an already deleted
/// payment method returns success rather than an error.
class DeletePaymentMethod implements UseCase<void, DeletePaymentMethodParams> {
  /// Repository for payment method operations
  final PaymentMethodRepository repository;

  /// Creates a new DeletePaymentMethod use case
  ///
  /// [repository] The payment method repository to perform deletion operations
  DeletePaymentMethod(this.repository);

  /// Executes the payment method deletion
  ///
  /// [params] Contains the payment method ID to delete
  ///
  /// Returns [Right(void)] on successful deletion, [Left(Failure)] on error.
  /// See class documentation for detailed failure semantics.
  @override
  Future<Either<Failure, void>> call(DeletePaymentMethodParams params) async {
    return await repository.deletePaymentMethod(params.paymentMethodId);
  }
}

/// Parameters for deleting a payment method
///
/// Contains the unique identifier of the payment method to be removed
/// from the user's saved payment methods.
class DeletePaymentMethodParams extends Equatable {
  /// Unique identifier of the payment method to delete
  ///
  /// This is typically provided by the payment gateway (e.g., Razorpay)
  /// when the payment method was initially saved. Format varies by provider:
  /// - Razorpay: "pm_XXXXXXXXXX" or "card_XXXXXXXXXX"
  /// - Cards: May include last 4 digits for user identification
  final String paymentMethodId;

  /// Creates parameters for payment method deletion
  ///
  /// [paymentMethodId] Must be a valid, non-empty payment method identifier
  const DeletePaymentMethodParams({required this.paymentMethodId});

  @override
  List<Object> get props => [paymentMethodId];
}
