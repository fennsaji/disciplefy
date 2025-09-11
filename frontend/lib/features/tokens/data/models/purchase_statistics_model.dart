import 'package:json_annotation/json_annotation.dart';

part 'purchase_statistics_model.g.dart';

/// Model for purchase statistics
@JsonSerializable()
class PurchaseStatisticsModel {
  /// Total number of purchases made
  @JsonKey(name: 'total_purchases')
  final int totalPurchases;

  /// Total amount spent
  @JsonKey(name: 'total_amount_spent')
  final double totalAmountSpent;

  /// Total tokens purchased
  @JsonKey(name: 'total_tokens_purchased')
  final int totalTokensPurchased;

  /// Average purchase amount
  @JsonKey(name: 'average_purchase_amount')
  final double averagePurchaseAmount;

  /// Date of first purchase
  @JsonKey(name: 'first_purchase_date')
  final DateTime? firstPurchaseDate;

  /// Date of last purchase
  @JsonKey(name: 'last_purchase_date')
  final DateTime? lastPurchaseDate;

  /// Most used payment method
  @JsonKey(name: 'most_used_payment_method')
  final String? mostUsedPaymentMethod;

  const PurchaseStatisticsModel({
    required this.totalPurchases,
    required this.totalAmountSpent,
    required this.totalTokensPurchased,
    required this.averagePurchaseAmount,
    this.firstPurchaseDate,
    this.lastPurchaseDate,
    this.mostUsedPaymentMethod,
  });

  factory PurchaseStatisticsModel.fromJson(Map<String, dynamic> json) =>
      _$PurchaseStatisticsModelFromJson(json);

  Map<String, dynamic> toJson() => _$PurchaseStatisticsModelToJson(this);

  /// Create a copy with updated values
  PurchaseStatisticsModel copyWith({
    int? totalPurchases,
    double? totalAmountSpent,
    int? totalTokensPurchased,
    double? averagePurchaseAmount,
    DateTime? firstPurchaseDate,
    DateTime? lastPurchaseDate,
    String? mostUsedPaymentMethod,
  }) {
    return PurchaseStatisticsModel(
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalAmountSpent: totalAmountSpent ?? this.totalAmountSpent,
      totalTokensPurchased: totalTokensPurchased ?? this.totalTokensPurchased,
      averagePurchaseAmount:
          averagePurchaseAmount ?? this.averagePurchaseAmount,
      firstPurchaseDate: firstPurchaseDate ?? this.firstPurchaseDate,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      mostUsedPaymentMethod:
          mostUsedPaymentMethod ?? this.mostUsedPaymentMethod,
    );
  }
}
