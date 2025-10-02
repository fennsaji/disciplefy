import 'package:equatable/equatable.dart';

/// Purchase statistics entity for tracking user purchase patterns
class PurchaseStatistics extends Equatable {
  /// Total number of purchases made
  final int totalPurchases;

  /// Total tokens purchased across all transactions
  final int totalTokens;

  /// Total amount spent in rupees
  final double totalSpent;

  /// Average purchase amount in rupees
  final double averagePurchaseAmount;

  /// Date of first purchase
  final DateTime? firstPurchaseDate;

  /// Date of last purchase
  final DateTime? lastPurchaseDate;

  /// Most used payment method
  final String? mostUsedPaymentMethod;

  const PurchaseStatistics({
    required this.totalPurchases,
    required this.totalTokens,
    required this.totalSpent,
    required this.averagePurchaseAmount,
    this.firstPurchaseDate,
    this.lastPurchaseDate,
    this.mostUsedPaymentMethod,
  });

  @override
  List<Object?> get props => [
        totalPurchases,
        totalTokens,
        totalSpent,
        averagePurchaseAmount,
        firstPurchaseDate,
        lastPurchaseDate,
        mostUsedPaymentMethod,
      ];

  /// Create a copy with updated values
  PurchaseStatistics copyWith({
    int? totalPurchases,
    int? totalTokens,
    double? totalSpent,
    double? averagePurchaseAmount,
    DateTime? firstPurchaseDate,
    DateTime? lastPurchaseDate,
    String? mostUsedPaymentMethod,
  }) {
    return PurchaseStatistics(
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalTokens: totalTokens ?? this.totalTokens,
      totalSpent: totalSpent ?? this.totalSpent,
      averagePurchaseAmount:
          averagePurchaseAmount ?? this.averagePurchaseAmount,
      firstPurchaseDate: firstPurchaseDate ?? this.firstPurchaseDate,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      mostUsedPaymentMethod:
          mostUsedPaymentMethod ?? this.mostUsedPaymentMethod,
    );
  }

  /// Check if user has any purchase history
  bool get hasPurchaseHistory => totalPurchases > 0;

  /// Get formatted total amount spent
  String get formattedTotalSpent => '₹${totalSpent.toStringAsFixed(2)}';

  /// Get formatted average amount
  String get formattedAverageAmount =>
      '₹${averagePurchaseAmount.toStringAsFixed(2)}';
}
