import 'package:equatable/equatable.dart';

/// Payment preferences entity for user configuration
class PaymentPreferences extends Equatable {
  /// Unique identifier
  final String id;

  /// User ID this preference belongs to
  final String userId;

  /// Whether to automatically save payment methods
  final bool? autoSavePaymentMethods;

  /// Preferred wallet provider
  final String? preferredWallet;

  /// Whether to enable one-click purchase
  final bool? enableOneClickPurchase;

  /// Default payment type
  final String? defaultPaymentType;

  /// Creation timestamp
  final DateTime createdAt;

  /// Last update timestamp
  final DateTime updatedAt;

  const PaymentPreferences({
    required this.id,
    required this.userId,
    this.autoSavePaymentMethods,
    this.preferredWallet,
    this.enableOneClickPurchase,
    this.defaultPaymentType,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        autoSavePaymentMethods,
        preferredWallet,
        enableOneClickPurchase,
        defaultPaymentType,
        createdAt,
        updatedAt,
      ];

  /// Create a copy with updated values
  PaymentPreferences copyWith({
    String? id,
    String? userId,
    bool? autoSavePaymentMethods,
    String? preferredWallet,
    bool? enableOneClickPurchase,
    String? defaultPaymentType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentPreferences(
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
