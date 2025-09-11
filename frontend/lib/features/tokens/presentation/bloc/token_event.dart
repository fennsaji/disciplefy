import 'package:equatable/equatable.dart';

/// Token BLoC Events
///
/// Defines all possible events that can occur in the token management system
abstract class TokenEvent extends Equatable {
  const TokenEvent();

  @override
  List<Object?> get props => [];
}

/// Event to fetch the current token status for the authenticated user
///
/// Triggers API call to get:
/// - Available tokens (daily + purchased)
/// - User plan (free/standard/premium)
/// - Daily limit and reset time
/// - Purchase history
class GetTokenStatus extends TokenEvent {
  const GetTokenStatus();
}

/// Event to refresh token status from the server
///
/// Forces a fresh API call even if cached data exists
/// Used after token consumption or purchase
class RefreshTokenStatus extends TokenEvent {
  const RefreshTokenStatus();
}

/// Event triggered when tokens are consumed by an operation
///
/// Updates the local token count without making API calls
/// Used to provide immediate UI feedback
class ConsumeTokens extends TokenEvent {
  final int tokensConsumed;
  final String operationType; // 'study_generation', 'verse_lookup', etc.

  const ConsumeTokens({
    required this.tokensConsumed,
    required this.operationType,
  });

  @override
  List<Object?> get props => [tokensConsumed, operationType];
}

/// Event to simulate token consumption for testing
///
/// Used in development/testing to verify token deduction logic
class SimulateTokenConsumption extends TokenEvent {
  final int tokensToConsume;

  const SimulateTokenConsumption({
    required this.tokensToConsume,
  });

  @override
  List<Object?> get props => [tokensToConsume];
}

/// Event to reset daily tokens (typically handled by backend scheduler)
///
/// Manually triggered for testing or admin operations
class ResetDailyTokens extends TokenEvent {
  const ResetDailyTokens();
}

/// Event to upgrade user plan
///
/// Initiates plan upgrade process which affects token limits and permissions
class UpgradeUserPlan extends TokenEvent {
  final String targetPlan; // 'standard' or 'premium'
  final String? paymentMethodId;

  const UpgradeUserPlan({
    required this.targetPlan,
    this.paymentMethodId,
  });

  @override
  List<Object?> get props => [targetPlan, paymentMethodId];
}

/// Event to clear any error states and reset to initial state
///
/// Used when user dismisses error messages or retries operations
class ClearTokenError extends TokenEvent {
  const ClearTokenError();
}

/// Event to validate if user has sufficient tokens for an operation
///
/// Checks token availability before allowing operations to proceed
class ValidateTokenSufficiency extends TokenEvent {
  final int requiredTokens;
  final String operationType;

  const ValidateTokenSufficiency({
    required this.requiredTokens,
    required this.operationType,
  });

  @override
  List<Object?> get props => [requiredTokens, operationType];
}

/// Event to handle payment success callback from Razorpay
///
/// Updates token balance after successful payment
class PaymentSuccess extends TokenEvent {
  final String paymentId;
  final String orderId;
  final String signature;
  final int tokensPurchased;

  const PaymentSuccess({
    required this.paymentId,
    required this.orderId,
    required this.signature,
    required this.tokensPurchased,
  });

  @override
  List<Object?> get props => [paymentId, orderId, signature, tokensPurchased];
}

/// Event to handle payment failure callback from Razorpay
///
/// Provides error feedback and cleanup after failed payment attempts
class PaymentFailure extends TokenEvent {
  final String error;
  final String? errorDescription;

  const PaymentFailure({
    required this.error,
    this.errorDescription,
  });

  @override
  List<Object?> get props => [error, errorDescription];
}

/// Event to schedule local notifications for token reset
///
/// Sets up notifications to remind users when their daily tokens reset
class ScheduleTokenResetNotification extends TokenEvent {
  final DateTime resetTime;

  const ScheduleTokenResetNotification({
    required this.resetTime,
  });

  @override
  List<Object?> get props => [resetTime];
}

/// Event to prefetch token status for performance
///
/// Proactively loads token data in background for faster UI responses
class PrefetchTokenStatus extends TokenEvent {
  const PrefetchTokenStatus();
}

/// Event to create a payment order (step 1 of new payment flow)
///
/// Creates Razorpay order and returns order ID for payment gateway
class CreatePaymentOrder extends TokenEvent {
  final int tokenAmount;

  const CreatePaymentOrder({
    required this.tokenAmount,
  });

  @override
  List<Object?> get props => [tokenAmount];
}

/// Event to confirm payment with signature verification
///
/// Called after successful Razorpay payment to verify and complete purchase
class ConfirmPayment extends TokenEvent {
  final String paymentId;
  final String orderId;
  final String signature;
  final int tokenAmount;

  const ConfirmPayment({
    required this.paymentId,
    required this.orderId,
    required this.signature,
    required this.tokenAmount,
  });

  @override
  List<Object?> get props => [paymentId, orderId, signature, tokenAmount];
}

/// Event to fetch purchase history for the authenticated user
///
/// Loads transaction history with optional pagination
class GetPurchaseHistory extends TokenEvent {
  final int? limit;
  final int? offset;

  const GetPurchaseHistory({
    this.limit,
    this.offset,
  });

  @override
  List<Object?> get props => [limit, offset];
}

/// Event to fetch purchase statistics for the authenticated user
///
/// Loads aggregated purchase data (total spent, purchases count, etc.)
class GetPurchaseStatistics extends TokenEvent {
  const GetPurchaseStatistics();
}

/// Event to refresh purchase history from the server
///
/// Forces a fresh API call for latest purchase data
class RefreshPurchaseHistory extends TokenEvent {
  const RefreshPurchaseHistory();
}
