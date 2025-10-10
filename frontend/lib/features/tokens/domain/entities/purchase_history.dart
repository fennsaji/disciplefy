import 'package:equatable/equatable.dart';

/// Represents a completed token purchase transaction record
///
/// Contains all the details of a user's token purchase including
/// payment information, costs, and transaction metadata.
class PurchaseHistory extends Equatable {
  /// Unique identifier for this purchase transaction
  final String id;

  /// Number of tokens purchased in this transaction
  final int tokenAmount;

  /// Total cost in Indian Rupees (INR)
  final double costRupees;

  /// Total cost in paise (1 rupee = 100 paise)
  final int costPaise;

  /// Payment gateway transaction ID (e.g., Razorpay payment ID)
  final String paymentId;

  /// Payment gateway order ID used to initiate the payment
  final String orderId;

  /// Payment method used (e.g., 'card', 'upi', 'netbanking')
  final String paymentMethod;

  /// Current status of the purchase (e.g., 'completed', 'failed', 'pending')
  final String status;

  /// Optional receipt number for the transaction, can be null
  final String? receiptNumber;

  /// Timestamp when the purchase was completed
  final DateTime purchasedAt;

  /// Creates a PurchaseHistory instance with the specified transaction details
  ///
  /// All fields except [receiptNumber] are required.
  /// [costRupees] and [costPaise] should represent the same amount in different units.
  const PurchaseHistory({
    required this.id,
    required this.tokenAmount,
    required this.costRupees,
    required this.costPaise,
    required this.paymentId,
    required this.orderId,
    required this.paymentMethod,
    required this.status,
    this.receiptNumber,
    required this.purchasedAt,
  });

  @override
  List<Object?> get props => [
        id,
        tokenAmount,
        costRupees,
        costPaise,
        paymentId,
        orderId,
        paymentMethod,
        status,
        receiptNumber,
        purchasedAt,
      ];
}
