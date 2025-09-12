import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/saved_payment_method.dart';
import '../repositories/payment_method_repository.dart';

/// Use case for retrieving all saved payment methods for the current user
///
/// Fetches a list of previously stored payment methods (cards, UPI, wallets)
/// that the user has opted to save for future purchases. This includes
/// payment methods from various providers like Razorpay, credit/debit cards,
/// and digital wallet configurations.
///
/// **Return Value:**
/// Returns a [List<SavedPaymentMethod>] containing:
/// - Payment method ID and display name
/// - Card details (last 4 digits, brand, expiry) for cards
/// - UPI ID or VPA for UPI methods
/// - Wallet provider information for digital wallets
/// - Default payment method indicators
/// - Creation and last used timestamps
///
/// **Failure Types:**
/// - [AuthenticationFailure]: User is not logged in or session expired
/// - [NetworkFailure]: Network connectivity issues during API call
/// - [ServerFailure]: Backend service error or payment provider API failure
/// - [CacheFailure]: Local storage error when caching payment methods
///
/// **Usage:**
/// ```dart
/// final result = await getPaymentMethods(NoParams());
///
/// result.fold(
///   (failure) => handlePaymentMethodsError(failure),
///   (paymentMethods) => displayPaymentMethods(paymentMethods),
/// );
/// ```
///
/// **Data Freshness:**
/// The use case may return cached data for performance, but will attempt
/// to refresh from the server periodically or when explicitly requested.
class GetPaymentMethods implements UseCase<List<SavedPaymentMethod>, NoParams> {
  /// Repository for payment method operations
  final PaymentMethodRepository repository;

  /// Creates a new GetPaymentMethods use case
  ///
  /// [repository] The payment method repository for data retrieval
  GetPaymentMethods(this.repository);

  /// Retrieves all saved payment methods for the current user
  ///
  /// [params] No parameters required (uses [NoParams])
  ///
  /// Returns [Right(List<SavedPaymentMethod>)] on success with payment methods,
  /// or [Left(Failure)] if an error occurs. An empty list indicates the user
  /// has no saved payment methods.
  ///
  /// **Note**: The returned list is sorted by:
  /// 1. Default payment method first (if any)
  /// 2. Most recently used methods
  /// 3. Alphabetically by display name
  @override
  Future<Either<Failure, List<SavedPaymentMethod>>> call(
      NoParams params) async {
    return await repository.getPaymentMethods();
  }
}
