import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/saved_payment_method.dart';
import '../entities/payment_preferences.dart';

/// Abstract repository for payment method management operations.
abstract class PaymentMethodRepository {
  /// Fetches all saved payment methods for the authenticated user.
  ///
  /// Returns list of [SavedPaymentMethod] on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, List<SavedPaymentMethod>>> getPaymentMethods();

  /// Saves a new payment method for the authenticated user.
  ///
  /// [methodType] - Type of payment method ('card', 'upi', 'netbanking', 'wallet')
  /// [provider] - Payment provider ('razorpay', etc.)
  /// [token] - Tokenized payment method from provider
  /// [lastFour] - Last 4 digits or identifier for display
  /// [brand] - Payment method brand ('visa', 'mastercard', etc.)
  /// [displayName] - User-friendly name for the method
  /// [isDefault] - Whether to set as default payment method
  /// [expiryMonth] - Expiry month for cards
  /// [expiryYear] - Expiry year for cards
  ///
  /// Returns saved payment method ID on success.
  /// Returns [Failure] on error (network, server, authentication, validation, etc.).
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
  });

  /// Sets a payment method as the default.
  ///
  /// [methodId] - ID of the payment method to set as default
  ///
  /// Returns true on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, bool>> setDefaultPaymentMethod(String methodId);

  /// Updates the last used timestamp for a payment method.
  ///
  /// [methodId] - ID of the payment method that was used
  ///
  /// Returns true on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, bool>> updatePaymentMethodUsage(String methodId);

  /// Records detailed payment method usage for analytics and tracking.
  ///
  /// This provides comprehensive usage data including transaction amount and type.
  ///
  /// [methodId] - ID of the payment method used
  /// [transactionAmount] - Amount of the transaction
  /// [transactionType] - Type of transaction ('token_purchase', 'subscription', etc.)
  /// [metadata] - Additional tracking data
  ///
  /// Returns true on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, bool>> recordPaymentMethodUsage({
    required String methodId,
    required double transactionAmount,
    required String transactionType,
    Map<String, dynamic>? metadata,
  });

  /// Deletes (deactivates) a payment method.
  ///
  /// [methodId] - ID of the payment method to delete
  ///
  /// Returns true on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, bool>> deletePaymentMethod(String methodId);

  /// Fetches payment preferences for the authenticated user.
  ///
  /// Returns [PaymentPreferences] on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, PaymentPreferences>> getPaymentPreferences();

  /// Updates payment preferences for the authenticated user.
  ///
  /// Only non-null parameters will be updated.
  ///
  /// Returns updated [PaymentPreferences] on success.
  /// Returns [Failure] on error (network, server, authentication, etc.).
  Future<Either<Failure, PaymentPreferences>> updatePaymentPreferences({
    bool? autoSavePaymentMethods,
    String? preferredWallet,
    bool? enableOneClickPurchase,
    String? defaultPaymentType,
  });
}
