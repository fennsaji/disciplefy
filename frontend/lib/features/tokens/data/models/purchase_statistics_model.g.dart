// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_statistics_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PurchaseStatisticsModel _$PurchaseStatisticsModelFromJson(
        Map<String, dynamic> json) =>
    PurchaseStatisticsModel(
      totalPurchases: (json['total_purchases'] as num).toInt(),
      totalAmountSpent: (json['total_amount_spent'] as num).toDouble(),
      totalTokensPurchased: (json['total_tokens_purchased'] as num).toInt(),
      averagePurchaseAmount:
          (json['average_purchase_amount'] as num).toDouble(),
      firstPurchaseDate: json['first_purchase_date'] == null
          ? null
          : DateTime.parse(json['first_purchase_date'] as String),
      lastPurchaseDate: json['last_purchase_date'] == null
          ? null
          : DateTime.parse(json['last_purchase_date'] as String),
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
