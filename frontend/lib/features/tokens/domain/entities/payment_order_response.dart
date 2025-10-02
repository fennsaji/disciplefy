import 'package:equatable/equatable.dart';

/// Payment Order Response Entity
///
/// Contains the complete response from payment order creation API
/// including both order ID and Razorpay key ID needed for payment processing
class PaymentOrderResponse extends Equatable {
  /// Razorpay order ID for payment processing
  final String orderId;

  /// Razorpay key ID that was used to create the order
  /// Must be used for opening the payment gateway
  final String keyId;

  /// Token amount for this order
  final int tokenAmount;

  /// Payment amount in paise
  final int amount;

  /// Currency (typically 'INR')
  final String currency;

  const PaymentOrderResponse({
    required this.orderId,
    required this.keyId,
    required this.tokenAmount,
    required this.amount,
    required this.currency,
  });

  @override
  List<Object?> get props => [orderId, keyId, tokenAmount, amount, currency];
}
