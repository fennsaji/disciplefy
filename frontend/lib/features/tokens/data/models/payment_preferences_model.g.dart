// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_preferences_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentPreferencesModel _$PaymentPreferencesModelFromJson(
        Map<String, dynamic> json) =>
    PaymentPreferencesModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      autoSavePaymentMethods: json['autoSavePaymentMethods'] as bool?,
      preferredWallet: json['preferredWallet'] as String?,
      enableOneClickPurchase: json['enableOneClickPurchase'] as bool?,
      defaultPaymentType: json['defaultPaymentType'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$PaymentPreferencesModelToJson(
        PaymentPreferencesModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'autoSavePaymentMethods': instance.autoSavePaymentMethods,
      'preferredWallet': instance.preferredWallet,
      'enableOneClickPurchase': instance.enableOneClickPurchase,
      'defaultPaymentType': instance.defaultPaymentType,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
