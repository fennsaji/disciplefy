import 'package:equatable/equatable.dart';

class SavedPaymentMethod extends Equatable {
  final String id;
  final String methodType; // 'card', 'upi', 'netbanking', 'wallet'
  final String provider; // 'razorpay', 'paytm', 'googlepay', etc.
  // NOTE: No token field - tokens are encrypted and stored securely on backend only
  final String? lastFour; // Last 4 digits or identifier
  final String? brand; // 'visa', 'mastercard', 'upi', etc.
  final String? displayName; // User-friendly name
  final bool isDefault;
  final bool isActive;
  final int? expiryMonth;
  final int? expiryYear;
  final DateTime createdAt;
  final DateTime? lastUsed; // Changed from lastUsedAt to match backend
  final int usageCount; // Track usage frequency
  final bool isExpiredCard; // Computed field from backend

  const SavedPaymentMethod({
    required this.id,
    required this.methodType,
    required this.provider,
    // No token parameter - kept secure on backend
    this.lastFour,
    this.brand,
    this.displayName,
    required this.isDefault,
    required this.isActive,
    this.expiryMonth,
    this.expiryYear,
    required this.createdAt,
    this.lastUsed,
    this.usageCount = 0,
    this.isExpiredCard = false,
  });

  @override
  List<Object?> get props => [
        id,
        methodType,
        provider,
        // No token in props for security
        lastFour,
        brand,
        displayName,
        isDefault,
        isActive,
        expiryMonth,
        expiryYear,
        createdAt,
        lastUsed,
        usageCount,
        isExpiredCard,
      ];

  /// Get user-friendly method type label
  String get methodTypeLabel {
    switch (methodType.toLowerCase()) {
      case 'card':
        return 'Card';
      case 'upi':
        return 'UPI';
      case 'netbanking':
        return 'Net Banking';
      case 'wallet':
        return 'Wallet';
      default:
        return methodType.toUpperCase();
    }
  }

  /// Get formatted display text
  String get formattedDisplay {
    if (displayName?.isNotEmpty == true) {
      return displayName!;
    }

    switch (methodType.toLowerCase()) {
      case 'card':
        final brandText = brand?.toUpperCase() ?? 'CARD';
        final lastFourText = lastFour != null ? ' •••• $lastFour' : '';
        return '$brandText$lastFourText';
      case 'upi':
        return lastFour ?? 'UPI';
      case 'netbanking':
        return brand?.toUpperCase() ?? 'Net Banking';
      case 'wallet':
        return brand?.toUpperCase() ?? 'Wallet';
      default:
        return methodType.toUpperCase();
    }
  }

  /// Check if card is expired (uses backend-computed value for accuracy)
  bool get isExpired {
    // Use backend-computed expiry status for security and accuracy
    return isExpiredCard;
  }

  /// Get expiry text for display
  String? get expiryText {
    if (expiryMonth == null || expiryYear == null) return null;
    return '${expiryMonth.toString().padLeft(2, '0')}/${expiryYear! % 100}';
  }

  /// Compatibility getter for widgets that expect lastUsedAt
  DateTime? get lastUsedAt => lastUsed;

  SavedPaymentMethod copyWith({
    String? id,
    String? methodType,
    String? provider,
    // No token parameter for security
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
    return SavedPaymentMethod(
      id: id ?? this.id,
      methodType: methodType ?? this.methodType,
      provider: provider ?? this.provider,
      // No token copying for security
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

class PaymentPreferences extends Equatable {
  final String id;
  final bool autoSavePaymentMethods;
  final String? preferredWallet;
  final bool enableOneClickPurchase;
  final String? defaultPaymentType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentPreferences({
    required this.id,
    required this.autoSavePaymentMethods,
    this.preferredWallet,
    required this.enableOneClickPurchase,
    this.defaultPaymentType,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        autoSavePaymentMethods,
        preferredWallet,
        enableOneClickPurchase,
        defaultPaymentType,
        createdAt,
        updatedAt,
      ];

  PaymentPreferences copyWith({
    String? id,
    bool? autoSavePaymentMethods,
    String? preferredWallet,
    bool? enableOneClickPurchase,
    String? defaultPaymentType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentPreferences(
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
