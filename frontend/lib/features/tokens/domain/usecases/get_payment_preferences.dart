import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/payment_preferences.dart';
import '../repositories/payment_method_repository.dart';

/// Use case for retrieving the user's payment preferences and settings
///
/// Fetches the current user's payment configuration including auto-save settings,
/// preferred payment methods, wallet preferences, and one-click purchase options.
/// These preferences control the behavior of payment flows and default selections
/// in the payment gateway.
///
/// **Returns:**
/// [Future<Either<Failure, PaymentPreferences>>] containing:
/// - [Right(PaymentPreferences)]: User's current payment preferences
/// - [Left(Failure)]: Error occurred during retrieval
///
/// **Possible Failure Cases:**
/// - [AuthenticationFailure]: User is not logged in or session expired
/// - [NetworkFailure]: Network connectivity issues during API call
/// - [ServerFailure]: Backend service error or payment provider API failure
/// - [CacheFailure]: Local storage error when caching preferences
/// - [NotFoundFailure]: User has no payment preferences configured
///
/// **Usage:**
/// ```dart
/// final result = await getPaymentPreferences(NoParams());
///
/// result.fold(
///   (failure) => handlePreferencesError(failure),
///   (preferences) => displayPreferences(preferences),
/// );
/// ```
class GetPaymentPreferences implements UseCase<PaymentPreferences, NoParams> {
  /// Repository for payment method and preferences operations
  ///
  /// Used to fetch payment preferences data from the backend service
  /// or local cache depending on availability and freshness requirements.
  final PaymentMethodRepository repository;

  /// Creates a new GetPaymentPreferences use case
  ///
  /// [repository] The PaymentMethodRepository used to fetch preferences data
  GetPaymentPreferences(this.repository);

  /// Retrieves the user's current payment preferences
  ///
  /// [params] No parameters required (uses [NoParams])
  ///
  /// Returns [Right(PaymentPreferences)] on success with the user's preferences,
  /// or [Left(Failure)] if an error occurs. If the user has no preferences
  /// configured, returns default preference values.
  @override
  Future<Either<Failure, PaymentPreferences>> call(NoParams params) async {
    return await repository.getPaymentPreferences();
  }
}
