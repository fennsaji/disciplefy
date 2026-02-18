import 'package:equatable/equatable.dart';

/// Comprehensive payment validation utilities
///
/// Provides client-side validation for payment-related data to improve UX
/// and catch errors early before sending to backend.

/// Validation result with detailed error information
class ValidationResult extends Equatable {
  final bool isValid;
  final String? errorMessage;
  final String? errorCode;
  final Map<String, dynamic>? errorDetails;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.errorCode,
    this.errorDetails,
  });

  const ValidationResult.valid() : this(isValid: true);

  const ValidationResult.invalid({
    required String errorMessage,
    String? errorCode,
    Map<String, dynamic>? errorDetails,
  }) : this(
          isValid: false,
          errorMessage: errorMessage,
          errorCode: errorCode,
          errorDetails: errorDetails,
        );

  @override
  List<Object?> get props => [isValid, errorMessage, errorCode, errorDetails];
}

/// Comprehensive payment method validation
class PaymentMethodValidator {
  static const Set<String> _supportedMethodTypes = {
    'card',
    'upi',
    'netbanking',
    'wallet',
  };

  static const Set<String> _supportedCardBrands = {
    'visa',
    'mastercard',
    'amex',
    'discover',
    'diners',
    'jcb',
    'rupay',
  };

  static const Set<String> _supportedWallets = {
    'paytm',
    'googlepay',
    'phonepe',
    'amazonpay',
    'freecharge',
    'mobikwik',
    'airtel',
    'jio',
  };

  /// Validate payment method type
  static ValidationResult validateMethodType(String? methodType) {
    if (methodType == null || methodType.trim().isEmpty) {
      return const ValidationResult.invalid(
        errorMessage: 'Payment method type is required',
        errorCode: 'MISSING_METHOD_TYPE',
      );
    }

    final normalizedType = methodType.toLowerCase().trim();
    if (!_supportedMethodTypes.contains(normalizedType)) {
      return ValidationResult.invalid(
        errorMessage: 'Unsupported payment method type: $methodType',
        errorCode: 'UNSUPPORTED_METHOD_TYPE',
        errorDetails: {
          'provided_type': methodType,
          'supported_types': _supportedMethodTypes.toList(),
        },
      );
    }

    return const ValidationResult.valid();
  }

  /// Validate payment provider
  static ValidationResult validateProvider(String? provider) {
    if (provider == null || provider.trim().isEmpty) {
      return const ValidationResult.invalid(
        errorMessage: 'Payment provider is required',
        errorCode: 'MISSING_PROVIDER',
      );
    }

    // Basic provider validation - non-empty and reasonable length
    if (provider.length > 50) {
      return const ValidationResult.invalid(
        errorMessage: 'Provider name is too long (max 50 characters)',
        errorCode: 'PROVIDER_TOO_LONG',
      );
    }

    return const ValidationResult.valid();
  }

  /// Validate card expiry date
  static ValidationResult validateCardExpiry(int? month, int? year) {
    if (month == null || year == null) {
      return const ValidationResult.invalid(
        errorMessage: 'Card expiry month and year are required',
        errorCode: 'MISSING_EXPIRY',
      );
    }

    // Validate month range
    if (month < 1 || month > 12) {
      return ValidationResult.invalid(
        errorMessage: 'Invalid expiry month: $month',
        errorCode: 'INVALID_EXPIRY_MONTH',
        errorDetails: {'provided_month': month},
      );
    }

    // Validate year range (current year to 20 years in the future)
    final currentYear = DateTime.now().year;
    if (year < currentYear || year > currentYear + 20) {
      return ValidationResult.invalid(
        errorMessage: 'Invalid expiry year: $year',
        errorCode: 'INVALID_EXPIRY_YEAR',
        errorDetails: {
          'provided_year': year,
          'min_year': currentYear,
          'max_year': currentYear + 20,
        },
      );
    }

    // Check if card is expired
    final now = DateTime.now();
    final expiryDate = DateTime(year, month + 1, 0); // Last day of expiry month
    if (now.isAfter(expiryDate)) {
      return ValidationResult.invalid(
        errorMessage: 'Card has already expired',
        errorCode: 'CARD_EXPIRED',
        errorDetails: {
          'expiry_month': month,
          'expiry_year': year,
          'current_date': now.toIso8601String(),
        },
      );
    }

    return const ValidationResult.valid();
  }

  /// Validate last four digits
  static ValidationResult validateLastFour(
      String? lastFour, String methodType) {
    if (lastFour == null || lastFour.trim().isEmpty) {
      // Last four is optional for some methods
      if (methodType.toLowerCase() == 'card') {
        return const ValidationResult.invalid(
          errorMessage: 'Last four digits are required for card payments',
          errorCode: 'MISSING_LAST_FOUR',
        );
      }
      return const ValidationResult.valid();
    }

    final trimmed = lastFour.trim();

    // Validate format based on payment method type
    switch (methodType.toLowerCase()) {
      case 'card':
        if (!RegExp(r'^\d{4}$').hasMatch(trimmed)) {
          return ValidationResult.invalid(
            errorMessage: 'Card last four digits must be exactly 4 numbers',
            errorCode: 'INVALID_CARD_LAST_FOUR',
            errorDetails: {'provided': lastFour},
          );
        }
        break;
      case 'upi':
        // For UPI, last four might be part of VPA
        if (trimmed.length > 10) {
          return ValidationResult.invalid(
            errorMessage: 'UPI identifier is too long',
            errorCode: 'INVALID_UPI_IDENTIFIER',
            errorDetails: {'provided': lastFour},
          );
        }
        break;
    }

    return const ValidationResult.valid();
  }

  /// Validate card brand
  static ValidationResult validateCardBrand(String? brand, String methodType) {
    if (methodType.toLowerCase() != 'card') {
      return const ValidationResult.valid(); // Brand validation only for cards
    }

    if (brand == null || brand.trim().isEmpty) {
      return const ValidationResult.invalid(
        errorMessage: 'Card brand is required for card payments',
        errorCode: 'MISSING_CARD_BRAND',
      );
    }

    final normalizedBrand = brand.toLowerCase().trim();
    if (!_supportedCardBrands.contains(normalizedBrand)) {
      return ValidationResult.invalid(
        errorMessage: 'Unsupported card brand: $brand',
        errorCode: 'UNSUPPORTED_CARD_BRAND',
        errorDetails: {
          'provided_brand': brand,
          'supported_brands': _supportedCardBrands.toList(),
        },
      );
    }

    return const ValidationResult.valid();
  }

  /// Validate wallet provider
  static ValidationResult validateWalletProvider(
      String? provider, String methodType) {
    if (methodType.toLowerCase() != 'wallet') {
      return const ValidationResult
          .valid(); // Only validate for wallet payments
    }

    if (provider == null || provider.trim().isEmpty) {
      return const ValidationResult.invalid(
        errorMessage: 'Wallet provider is required for wallet payments',
        errorCode: 'MISSING_WALLET_PROVIDER',
      );
    }

    final normalizedProvider = provider.toLowerCase().trim();
    if (!_supportedWallets.contains(normalizedProvider)) {
      return ValidationResult.invalid(
        errorMessage: 'Unsupported wallet provider: $provider',
        errorCode: 'UNSUPPORTED_WALLET_PROVIDER',
        errorDetails: {
          'provided_provider': provider,
          'supported_wallets': _supportedWallets.toList(),
        },
      );
    }

    return const ValidationResult.valid();
  }

  /// Validate display name
  static ValidationResult validateDisplayName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) {
      return const ValidationResult.valid(); // Display name is optional
    }

    final trimmed = displayName.trim();
    if (trimmed.length > 100) {
      return ValidationResult.invalid(
        errorMessage: 'Display name is too long (max 100 characters)',
        errorCode: 'DISPLAY_NAME_TOO_LONG',
        errorDetails: {'provided_length': trimmed.length},
      );
    }

    // Check for potentially harmful content
    if (trimmed.contains('<') ||
        trimmed.contains('>') ||
        trimmed.contains('"') ||
        trimmed.contains("'")) {
      return const ValidationResult.invalid(
        errorMessage: 'Display name contains invalid characters',
        errorCode: 'INVALID_DISPLAY_NAME_CHARACTERS',
      );
    }

    return const ValidationResult.valid();
  }

  /// Comprehensive payment method validation
  static ValidationResult validatePaymentMethod({
    required String methodType,
    required String provider,
    String? lastFour,
    String? brand,
    String? displayName,
    int? expiryMonth,
    int? expiryYear,
  }) {
    // Validate method type
    final methodTypeResult = validateMethodType(methodType);
    if (!methodTypeResult.isValid) return methodTypeResult;

    // Validate provider
    final providerResult = validateProvider(provider);
    if (!providerResult.isValid) return providerResult;

    // Validate card-specific fields
    if (methodType.toLowerCase() == 'card') {
      final expiryResult = validateCardExpiry(expiryMonth, expiryYear);
      if (!expiryResult.isValid) return expiryResult;

      final brandResult = validateCardBrand(brand, methodType);
      if (!brandResult.isValid) return brandResult;
    }

    // Validate wallet-specific fields
    if (methodType.toLowerCase() == 'wallet') {
      final walletResult = validateWalletProvider(provider, methodType);
      if (!walletResult.isValid) return walletResult;
    }

    // Validate last four digits
    final lastFourResult = validateLastFour(lastFour, methodType);
    if (!lastFourResult.isValid) return lastFourResult;

    // Validate display name
    final displayNameResult = validateDisplayName(displayName);
    if (!displayNameResult.isValid) return displayNameResult;

    return const ValidationResult.valid();
  }
}

/// Token purchase validation
class TokenPurchaseValidator {
  static const int minTokens = 10;
  static const int maxTokens = 9999;
  static const double minAmount = 1.0;
  static const double maxAmount = 999.90;

  /// Validate token amount
  static ValidationResult validateTokenAmount(int? tokenAmount) {
    if (tokenAmount == null) {
      return const ValidationResult.invalid(
        errorMessage: 'Token amount is required',
        errorCode: 'MISSING_TOKEN_AMOUNT',
      );
    }

    if (tokenAmount < minTokens) {
      return ValidationResult.invalid(
        errorMessage: 'Minimum token purchase is $minTokens tokens',
        errorCode: 'TOKEN_AMOUNT_TOO_LOW',
        errorDetails: {
          'provided': tokenAmount,
          'minimum': minTokens,
        },
      );
    }

    if (tokenAmount > maxTokens) {
      return ValidationResult.invalid(
        errorMessage: 'Maximum token purchase is $maxTokens tokens',
        errorCode: 'TOKEN_AMOUNT_TOO_HIGH',
        errorDetails: {
          'provided': tokenAmount,
          'maximum': maxTokens,
        },
      );
    }

    return const ValidationResult.valid();
  }

  /// Validate payment amount
  static ValidationResult validatePaymentAmount(double? amount) {
    if (amount == null) {
      return const ValidationResult.invalid(
        errorMessage: 'Payment amount is required',
        errorCode: 'MISSING_PAYMENT_AMOUNT',
      );
    }

    if (amount < minAmount) {
      return ValidationResult.invalid(
        errorMessage:
            'Minimum payment amount is ₹${minAmount.toStringAsFixed(2)}',
        errorCode: 'PAYMENT_AMOUNT_TOO_LOW',
        errorDetails: {
          'provided': amount,
          'minimum': minAmount,
        },
      );
    }

    if (amount > maxAmount) {
      return ValidationResult.invalid(
        errorMessage:
            'Maximum payment amount is ₹${maxAmount.toStringAsFixed(2)}',
        errorCode: 'PAYMENT_AMOUNT_TOO_HIGH',
        errorDetails: {
          'provided': amount,
          'maximum': maxAmount,
        },
      );
    }

    return const ValidationResult.valid();
  }

  /// Token pricing configuration
  static const int tokensPerRupee = 4; // 4 tokens = ₹1
  static const int paisePerRupee = 100; // 100 paise = ₹1

  /// Validate token to amount conversion with precise pricing calculation
  static ValidationResult validateTokenAmountConversion(
      int tokenAmount, double amount) {
    // Calculate expected amount using precise arithmetic
    // Price per token in paise: 100 paise / 4 tokens = 25 paise per token
    const pricePerTokenPaise = paisePerRupee ~/ tokensPerRupee;

    // Calculate total cost in paise, then convert to rupees
    final totalPaise = tokenAmount * pricePerTokenPaise;
    final expectedAmount =
        totalPaise / paisePerRupee; // Convert paise to rupees

    const tolerance = 0.01; // Allow for small floating point differences

    if ((amount - expectedAmount).abs() > tolerance) {
      return ValidationResult.invalid(
        errorMessage: 'Payment amount does not match token amount',
        errorCode: 'AMOUNT_MISMATCH',
        errorDetails: {
          'token_amount': tokenAmount,
          'provided_amount': amount,
          'expected_amount': expectedAmount,
          'price_per_token_paise': pricePerTokenPaise,
          'total_paise': totalPaise,
        },
      );
    }

    return const ValidationResult.valid();
  }
}

/// Payment preference validation
class PaymentPreferenceValidator {
  static const Set<String> _supportedPaymentTypes = {
    'card',
    'upi',
    'netbanking',
    'wallet',
  };

  static const Set<String> _supportedWallets = {
    'paytm',
    'googlepay',
    'phonepe',
    'amazonpay',
  };

  /// Validate default payment type
  static ValidationResult validateDefaultPaymentType(String? paymentType) {
    if (paymentType == null) {
      return const ValidationResult.valid(); // Optional field
    }

    final normalizedType = paymentType.toLowerCase().trim();
    if (!_supportedPaymentTypes.contains(normalizedType)) {
      return ValidationResult.invalid(
        errorMessage: 'Unsupported default payment type: $paymentType',
        errorCode: 'UNSUPPORTED_DEFAULT_PAYMENT_TYPE',
        errorDetails: {
          'provided_type': paymentType,
          'supported_types': _supportedPaymentTypes.toList(),
        },
      );
    }

    return const ValidationResult.valid();
  }

  /// Validate preferred wallet
  static ValidationResult validatePreferredWallet(String? wallet) {
    if (wallet == null) {
      return const ValidationResult.valid(); // Optional field
    }

    final normalizedWallet = wallet.toLowerCase().trim();
    if (!_supportedWallets.contains(normalizedWallet)) {
      return ValidationResult.invalid(
        errorMessage: 'Unsupported preferred wallet: $wallet',
        errorCode: 'UNSUPPORTED_PREFERRED_WALLET',
        errorDetails: {
          'provided_wallet': wallet,
          'supported_wallets': _supportedWallets.toList(),
        },
      );
    }

    return const ValidationResult.valid();
  }

  /// Comprehensive payment preferences validation
  static ValidationResult validatePaymentPreferences({
    bool? autoSavePaymentMethods,
    String? preferredWallet,
    bool? enableOneClickPurchase,
    String? defaultPaymentType,
  }) {
    // Validate default payment type
    final defaultTypeResult = validateDefaultPaymentType(defaultPaymentType);
    if (!defaultTypeResult.isValid) return defaultTypeResult;

    // Validate preferred wallet
    final walletResult = validatePreferredWallet(preferredWallet);
    if (!walletResult.isValid) return walletResult;

    // Logical validation: if one-click purchase is enabled, ensure we have supporting preferences
    if (enableOneClickPurchase == true) {
      if (autoSavePaymentMethods == false) {
        return const ValidationResult.invalid(
          errorMessage:
              'One-click purchase requires auto-save payment methods to be enabled',
          errorCode: 'INCOMPATIBLE_PREFERENCES',
        );
      }
    }

    return const ValidationResult.valid();
  }
}
