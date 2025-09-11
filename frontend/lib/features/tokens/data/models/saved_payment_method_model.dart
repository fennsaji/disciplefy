import '../../domain/entities/saved_payment_method.dart';

class SavedPaymentMethodModel extends SavedPaymentMethod {
  const SavedPaymentMethodModel({
    required super.id,
    required super.methodType,
    required super.provider,
    // No token parameter - security enhancement
    super.lastFour,
    super.brand,
    super.displayName,
    required super.isDefault,
    required super.isActive,
    super.expiryMonth,
    super.expiryYear,
    required super.createdAt,
    super.lastUsed,
    super.usageCount = 0,
    super.isExpiredCard = false,
  });

  factory SavedPaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return SavedPaymentMethodModel(
      id: json['id'] as String,
      methodType: json['method_type'] as String,
      provider: json['provider'] as String,
      // No token from JSON - security enhancement
      lastFour: json['last_four'] as String?,
      brand: json['brand'] as String?,
      displayName: json['display_name'] as String?,
      isDefault: json['is_default'] as bool,
      isActive: json['is_active'] ?? true, // Default to true if not specified
      expiryMonth: json['expiry_month'] as int?,
      expiryYear: json['expiry_year'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastUsed: json['last_used'] != null
          ? DateTime.parse(json['last_used'] as String)
          : null,
      usageCount: json['usage_count'] as int? ?? 0,
      isExpiredCard: json['is_expired'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method_type': methodType,
      'provider': provider,
      // No token in JSON - security enhancement
      'last_four': lastFour,
      'brand': brand,
      'display_name': displayName,
      'is_default': isDefault,
      'is_active': isActive,
      'expiry_month': expiryMonth,
      'expiry_year': expiryYear,
      'created_at': createdAt.toIso8601String(),
      'last_used': lastUsed?.toIso8601String(),
      'usage_count': usageCount,
      'is_expired': isExpiredCard,
    };
  }

  @override
  SavedPaymentMethodModel copyWith({
    String? id,
    String? methodType,
    String? provider,
    // No token parameter - security enhancement
    String? lastFour,
    String? brand,
    String? displayName,
    bool? isDefault,
    bool? isActive,
    int? expiryMonth,
    int? expiryYear,
    DateTime? createdAt,
    DateTime? lastUsed,
    int? usageCount,
    bool? isExpiredCard,
  }) {
    return SavedPaymentMethodModel(
      id: id ?? this.id,
      methodType: methodType ?? this.methodType,
      provider: provider ?? this.provider,
      // No token copying - security enhancement
      lastFour: lastFour ?? this.lastFour,
      brand: brand ?? this.brand,
      displayName: displayName ?? this.displayName,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      usageCount: usageCount ?? this.usageCount,
      isExpiredCard: isExpiredCard ?? this.isExpiredCard,
    );
  }
}

class PaymentPreferencesModel extends PaymentPreferences {
  const PaymentPreferencesModel({
    required super.id,
    required super.autoSavePaymentMethods,
    super.preferredWallet,
    required super.enableOneClickPurchase,
    super.defaultPaymentType,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PaymentPreferencesModel.fromJson(Map<String, dynamic> json) {
    return PaymentPreferencesModel(
      id: json['id'] as String,
      autoSavePaymentMethods: json['auto_save_payment_methods'] as bool,
      preferredWallet: json['preferred_wallet'] as String?,
      enableOneClickPurchase: json['enable_one_click_purchase'] as bool,
      defaultPaymentType: json['default_payment_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auto_save_payment_methods': autoSavePaymentMethods,
      'preferred_wallet': preferredWallet,
      'enable_one_click_purchase': enableOneClickPurchase,
      'default_payment_type': defaultPaymentType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  PaymentPreferencesModel copyWith({
    String? id,
    bool? autoSavePaymentMethods,
    String? preferredWallet,
    bool? enableOneClickPurchase,
    String? defaultPaymentType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentPreferencesModel(
      id: id ?? this.id,
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
