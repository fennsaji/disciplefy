import '../../domain/entities/purchase_history.dart';

class PurchaseHistoryModel extends PurchaseHistory {
  const PurchaseHistoryModel({
    required super.id,
    required super.tokenAmount,
    required super.costRupees,
    required super.costPaise,
    required super.paymentId,
    required super.orderId,
    required super.paymentMethod,
    required super.status,
    super.receiptNumber,
    required super.purchasedAt,
  });

  factory PurchaseHistoryModel.fromJson(Map<String, dynamic> json) {
    return PurchaseHistoryModel(
      id: json['id'] as String,
      tokenAmount: json['token_amount'] as int,
      costRupees: (json['cost_rupees'] as num).toDouble(),
      costPaise: json['cost_paise'] as int,
      paymentId: json['payment_id'] as String,
      orderId: json['order_id'] as String,
      paymentMethod: json['payment_method'] as String,
      status: json['status'] as String,
      receiptNumber: json['receipt_number'] as String?,
      purchasedAt: DateTime.parse(json['purchased_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token_amount': tokenAmount,
      'cost_rupees': costRupees,
      'cost_paise': costPaise,
      'payment_id': paymentId,
      'order_id': orderId,
      'payment_method': paymentMethod,
      'status': status,
      'receipt_number': receiptNumber,
      'purchased_at': purchasedAt.toIso8601String(),
    };
  }
}

class PurchaseStatisticsModel extends PurchaseStatistics {
  const PurchaseStatisticsModel({
    required super.totalPurchases,
    required super.totalTokens,
    required super.totalSpent,
    super.firstPurchaseDate,
    super.lastPurchaseDate,
  });

  factory PurchaseStatisticsModel.fromJson(Map<String, dynamic> json) {
    return PurchaseStatisticsModel(
      totalPurchases: json['total_purchases'] as int,
      totalTokens: json['total_tokens'] as int,
      totalSpent: (json['total_spent'] as num).toDouble(),
      firstPurchaseDate: json['first_purchase_date'] != null
          ? DateTime.parse(json['first_purchase_date'] as String)
          : null,
      lastPurchaseDate: json['last_purchase_date'] != null
          ? DateTime.parse(json['last_purchase_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_purchases': totalPurchases,
      'total_tokens': totalTokens,
      'total_spent': totalSpent,
      'first_purchase_date': firstPurchaseDate?.toIso8601String(),
      'last_purchase_date': lastPurchaseDate?.toIso8601String(),
    };
  }
}
