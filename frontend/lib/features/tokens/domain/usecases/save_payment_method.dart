import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/saved_payment_method.dart';
import '../repositories/payment_method_repository.dart';

/// Use case for saving payment methods securely with tokenization.
///
/// This use case handles the secure storage of payment method information
/// by working with tokenized payment data rather than sensitive card details.
/// It supports multiple payment types including cards, UPI, net banking, and wallets.
///
/// **Security Features:**
/// - Works only with tokenized payment data (no raw card information)
/// - Validates payment method types and providers
/// - Supports secure storage with provider tokens
/// - Maintains user privacy with encrypted storage
///
/// **Supported Payment Types:**
/// - Credit/Debit Cards (Visa, Mastercard, Rupay, etc.)
/// - UPI (Google Pay, PhonePe, Paytm, etc.)
/// - Net Banking (SBI, HDFC, ICICI, etc.)
/// - Digital Wallets (Paytm, MobiKwik, etc.)
///
/// **Example Usage:**
/// ```dart
/// final usecase = SavePaymentMethod(repository);
/// final params = SavePaymentMethodParams(
///   methodType: 'card',
///   provider: 'razorpay',
///   token: 'card_token_xyz123',
///   lastFour: '1234',
///   brand: 'visa',
///   displayName: 'My Visa Card',
///   isDefault: true,
/// );
/// final result = await usecase(params);
/// ```
class SavePaymentMethod implements UseCase<String, SavePaymentMethodParams> {
  final PaymentMethodRepository repository;

  /// Creates a [SavePaymentMethod] use case.
  ///
  /// [repository] - The payment method repository for data operations
  SavePaymentMethod(this.repository);

  /// Executes the payment method saving operation.
  ///
  /// [params] - The payment method parameters containing all required and optional data
  ///
  /// Returns:
  /// - [Right<String>] - The saved payment method ID on success
  /// - [Left<Failure>] - A failure object containing error details
  ///
  /// **Possible Failures:**
  /// - [NetworkFailure] - No internet connection or network timeout
  /// - [ServerFailure] - Server error (500, 502, etc.)
  /// - [ClientFailure] - Invalid input data or validation errors
  /// - [AuthenticationFailure] - User not authenticated or session expired
  @override
  Future<Either<Failure, String>> call(SavePaymentMethodParams params) async {
    return await repository.savePaymentMethod(
      methodType: params.methodType,
      provider: params.provider,
      token: params.token,
      lastFour: params.lastFour,
      brand: params.brand,
      displayName: params.displayName,
      isDefault: params.isDefault,
      expiryMonth: params.expiryMonth,
      expiryYear: params.expiryYear,
    );
  }
}

/// Parameters for saving a payment method securely.
///
/// This class contains all the required and optional parameters for
/// saving payment method information in a secure, tokenized format.
/// It extends [Equatable] for value equality comparisons.
///
/// **Required Parameters:**
/// - [methodType] - Type of payment method ('card', 'upi', 'netbanking', 'wallet')
/// - [provider] - Payment service provider (typically 'razorpay')
/// - [token] - Tokenized payment method identifier (NEVER raw card data)
///
/// **Optional Parameters:**
/// - [lastFour] - Last 4 digits or identifier for user display
/// - [brand] - Payment method brand ('visa', 'mastercard', 'googlepay', etc.)
/// - [displayName] - User-friendly name for the payment method
/// - [isDefault] - Whether to set as the user's default payment method
/// - [expiryMonth] - Card expiry month (1-12, for cards only)
/// - [expiryYear] - Card expiry year (YYYY format, for cards only)
class SavePaymentMethodParams extends Equatable {
  final String methodType;
  final String provider;
  final String token;
  final String? lastFour;
  final String? brand;
  final String? displayName;
  final bool isDefault;
  final int? expiryMonth;
  final int? expiryYear;

  /// Creates parameters for saving a payment method.
  ///
  /// **Required Parameters:**
  /// - [methodType] - Payment type: 'card', 'upi', 'netbanking', 'wallet'
  /// - [provider] - Payment provider, typically 'razorpay'
  /// - [token] - Secure token from payment provider (NEVER store raw card data)
  ///
  /// **Optional Parameters:**
  /// - [lastFour] - Display identifier (e.g., '1234' for cards, 'user@upi' for UPI)
  /// - [brand] - Brand identifier ('visa', 'mastercard', 'googlepay', etc.)
  /// - [displayName] - User-friendly name ('My Credit Card', 'Work UPI', etc.)
  /// - [isDefault] - Set as default payment method (defaults to false)
  /// - [expiryMonth] - Card expiry month 1-12 (cards only)
  /// - [expiryYear] - Card expiry year YYYY format (cards only)
  ///
  /// **Security Notes:**
  /// - The [token] parameter must be a tokenized identifier from the payment provider
  /// - Never pass raw card numbers, CVV, or other sensitive data
  /// - Expiry dates are stored for card validation and user display only
  const SavePaymentMethodParams({
    required this.methodType,
    required this.provider,
    required this.token,
    this.lastFour,
    this.brand,
    this.displayName,
    this.isDefault = false,
    this.expiryMonth,
    this.expiryYear,
  });

  @override
  List<Object?> get props => [
        methodType,
        provider,
        // token excluded for security - prevents PII leakage in logs/debugging
        lastFour,
        brand,
        displayName,
        isDefault,
        expiryMonth,
        expiryYear,
      ];
}
