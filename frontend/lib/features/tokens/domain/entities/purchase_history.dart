import 'package:equatable/equatable.dart';

class PurchaseHistory extends Equatable {
  final String id;
  final int tokenAmount;
  final double costRupees;
  final int costPaise;
  final String paymentId;
  final String orderId;
  final String paymentMethod;
  final String status;
  final String? receiptNumber;
  final DateTime purchasedAt;

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

class PurchaseStatistics extends Equatable {
  final int totalPurchases;
  final int totalTokens;
  final double totalSpent;
  final DateTime? firstPurchaseDate;
  final DateTime? lastPurchaseDate;

  const PurchaseStatistics({
    required this.totalPurchases,
    required this.totalTokens,
    required this.totalSpent,
    this.firstPurchaseDate,
    this.lastPurchaseDate,
  });

  @override
  List<Object?> get props => [
        totalPurchases,
        totalTokens,
        totalSpent,
        firstPurchaseDate,
        lastPurchaseDate,
      ];
}
