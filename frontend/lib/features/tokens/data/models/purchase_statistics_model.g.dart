// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_statistics_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PurchaseStatisticsModel _$PurchaseStatisticsModelFromJson(
        Map<String, dynamic> json) =>
    PurchaseStatisticsModel(
      totalPurchases: (json['total_purchases'] as num?)?.toInt() ?? 0,
      totalAmountSpent:
          PurchaseStatisticsModel._parseAmountSpent(json['total_amount_spent']),
      totalTokensPurchased:
          (json['total_tokens_purchased'] as num?)?.toInt() ?? 0,
      averagePurchaseAmount: PurchaseStatisticsModel._parseAverageAmount(
          json['average_purchase_amount']),
      firstPurchaseDate: parseNullableDateTime(json['first_purchase_date']),
      lastPurchaseDate: parseNullableDateTime(json['last_purchase_date']),
      mostUsedPaymentMethod: json['most_used_payment_method'] as String?,
    );

Map<String, dynamic> _$PurchaseStatisticsModelToJson(
        PurchaseStatisticsModel instance) =>
    <String, dynamic>{
      'total_purchases': instance.totalPurchases,
      'total_amount_spent': instance.totalAmountSpent,
      'total_tokens_purchased': instance.totalTokensPurchased,
      'average_purchase_amount': instance.averagePurchaseAmount,
      'first_purchase_date': instance.firstPurchaseDate?.toIso8601String(),
      'last_purchase_date': instance.lastPurchaseDate?.toIso8601String(),
      'most_used_payment_method': instance.mostUsedPaymentMethod,
    };
