import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/payment_preferences.dart';

part 'payment_preferences_model.g.dart';

@JsonSerializable()
class PaymentPreferencesModel extends PaymentPreferences {
  const PaymentPreferencesModel({
    required super.id,
    required super.userId,
    super.autoSavePaymentMethods,
    super.preferredWallet,
    super.enableOneClickPurchase,
    super.defaultPaymentType,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PaymentPreferencesModel.fromJson(Map<String, dynamic> json) =>
      _$PaymentPreferencesModelFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentPreferencesModelToJson(this);

  factory PaymentPreferencesModel.fromEntity(PaymentPreferences entity) {
    return PaymentPreferencesModel(
      id: entity.id,
      userId: entity.userId,
      autoSavePaymentMethods: entity.autoSavePaymentMethods,
      preferredWallet: entity.preferredWallet,
      enableOneClickPurchase: entity.enableOneClickPurchase,
      defaultPaymentType: entity.defaultPaymentType,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  @override
  PaymentPreferencesModel copyWith({
    String? id,
    String? userId,
    bool? autoSavePaymentMethods,
    String? preferredWallet,
    bool? enableOneClickPurchase,
    String? defaultPaymentType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentPreferencesModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      autoSavePaymentMethods:
          autoSavePaymentMethods ?? this.autoSavePaymentMethods,
      preferredWallet: preferredWallet ?? this.preferredWallet,
      enableOneClickPurchase:
          enableOneClickPurchase ?? this.enableOneClickPurchase,
      defaultPaymentType: defaultPaymentType ?? this.defaultPaymentType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
