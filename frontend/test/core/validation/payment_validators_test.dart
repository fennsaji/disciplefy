import 'package:flutter_test/flutter_test.dart';
import 'package:disciplefy_bible_study/core/validation/payment_validators.dart';

void main() {
  group('ValidationResult', () {
    test('should create valid result', () {
      const result = ValidationResult.valid();

      expect(result.isValid, true);
      expect(result.errorMessage, null);
      expect(result.errorCode, null);
      expect(result.errorDetails, null);
    });

    test('should create invalid result with error details', () {
      const result = ValidationResult.invalid(
        errorMessage: 'Test error',
        errorCode: 'TEST_ERROR',
        errorDetails: {'key': 'value'},
      );

      expect(result.isValid, false);
      expect(result.errorMessage, 'Test error');
      expect(result.errorCode, 'TEST_ERROR');
      expect(result.errorDetails, {'key': 'value'});
    });

    test('should implement equality correctly', () {
      const result1 = ValidationResult.valid();
      const result2 = ValidationResult.valid();
      const result3 = ValidationResult.invalid(errorMessage: 'Error');

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });
  });

  group('PaymentMethodValidator', () {
    group('validateMethodType', () {
      test('should validate supported method types', () {
        expect(PaymentMethodValidator.validateMethodType('card').isValid, true);
        expect(PaymentMethodValidator.validateMethodType('upi').isValid, true);
        expect(PaymentMethodValidator.validateMethodType('netbanking').isValid,
            true);
        expect(
            PaymentMethodValidator.validateMethodType('wallet').isValid, true);

        // Case insensitive
        expect(PaymentMethodValidator.validateMethodType('CARD').isValid, true);
        expect(PaymentMethodValidator.validateMethodType('Card').isValid, true);
      });

      test('should reject null or empty method type', () {
        var result = PaymentMethodValidator.validateMethodType(null);
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_METHOD_TYPE');

        result = PaymentMethodValidator.validateMethodType('');
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_METHOD_TYPE');

        result = PaymentMethodValidator.validateMethodType('   ');
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_METHOD_TYPE');
      });

      test('should reject unsupported method types', () {
        final result = PaymentMethodValidator.validateMethodType('crypto');
        expect(result.isValid, false);
        expect(result.errorCode, 'UNSUPPORTED_METHOD_TYPE');
        expect(result.errorDetails!['provided_type'], 'crypto');
        expect(result.errorDetails!['supported_types'], contains('card'));
      });
    });

    group('validateProvider', () {
      test('should accept valid provider names', () {
        expect(
            PaymentMethodValidator.validateProvider('razorpay').isValid, true);
        expect(PaymentMethodValidator.validateProvider('stripe').isValid, true);
        expect(PaymentMethodValidator.validateProvider('payu').isValid, true);
      });

      test('should reject null or empty provider', () {
        var result = PaymentMethodValidator.validateProvider(null);
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_PROVIDER');

        result = PaymentMethodValidator.validateProvider('');
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_PROVIDER');
      });

      test('should reject provider names that are too long', () {
        final longProvider = 'a' * 51;
        final result = PaymentMethodValidator.validateProvider(longProvider);
        expect(result.isValid, false);
        expect(result.errorCode, 'PROVIDER_TOO_LONG');
      });
    });

    group('validateCardExpiry', () {
      final currentYear = DateTime.now().year;
      final currentMonth = DateTime.now().month;

      test('should accept valid future dates', () {
        expect(
            PaymentMethodValidator.validateCardExpiry(12, currentYear + 1)
                .isValid,
            true);
        expect(
            PaymentMethodValidator.validateCardExpiry(1, currentYear + 5)
                .isValid,
            true);
      });

      test('should accept current month and year', () {
        if (currentMonth <= 12) {
          expect(
              PaymentMethodValidator.validateCardExpiry(
                      currentMonth, currentYear)
                  .isValid,
              true);
        }
      });

      test('should reject null values', () {
        var result =
            PaymentMethodValidator.validateCardExpiry(null, currentYear);
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_EXPIRY');

        result = PaymentMethodValidator.validateCardExpiry(12, null);
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_EXPIRY');
      });

      test('should reject invalid month values', () {
        var result = PaymentMethodValidator.validateCardExpiry(0, currentYear);
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_EXPIRY_MONTH');

        result = PaymentMethodValidator.validateCardExpiry(13, currentYear);
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_EXPIRY_MONTH');
      });

      test('should reject invalid year values', () {
        var result =
            PaymentMethodValidator.validateCardExpiry(12, currentYear - 1);
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_EXPIRY_YEAR');

        result =
            PaymentMethodValidator.validateCardExpiry(12, currentYear + 25);
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_EXPIRY_YEAR');
      });

      test('should reject expired cards', () {
        // Test with a clearly expired date - but first year range validation will trigger
        final result =
            PaymentMethodValidator.validateCardExpiry(1, currentYear - 1);
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_EXPIRY_YEAR');
      });

      test('should reject cards expired this year', () {
        // Test with a past month in current year to trigger CARD_EXPIRED
        if (currentMonth > 1) {
          final result = PaymentMethodValidator.validateCardExpiry(
              currentMonth - 1, currentYear);
          expect(result.isValid, false);
          expect(result.errorCode, 'CARD_EXPIRED');
        }
      });
    });

    group('validateLastFour', () {
      test('should validate card last four digits', () {
        expect(PaymentMethodValidator.validateLastFour('1234', 'card').isValid,
            true);
        expect(PaymentMethodValidator.validateLastFour('0000', 'card').isValid,
            true);
      });

      test('should require last four for card payments', () {
        var result = PaymentMethodValidator.validateLastFour(null, 'card');
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_LAST_FOUR');

        result = PaymentMethodValidator.validateLastFour('', 'card');
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_LAST_FOUR');
      });

      test('should reject invalid card last four format', () {
        var result = PaymentMethodValidator.validateLastFour('123', 'card');
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_CARD_LAST_FOUR');

        result = PaymentMethodValidator.validateLastFour('12345', 'card');
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_CARD_LAST_FOUR');

        result = PaymentMethodValidator.validateLastFour('abcd', 'card');
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_CARD_LAST_FOUR');
      });

      test('should allow null last four for non-card payments', () {
        expect(
            PaymentMethodValidator.validateLastFour(null, 'upi').isValid, true);
        expect(PaymentMethodValidator.validateLastFour(null, 'wallet').isValid,
            true);
      });

      test('should validate UPI identifier length', () {
        expect(
            PaymentMethodValidator.validateLastFour('test@upi', 'upi').isValid,
            true);

        final longUpi = 'a' * 15;
        final result = PaymentMethodValidator.validateLastFour(longUpi, 'upi');
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_UPI_IDENTIFIER');
      });
    });

    group('validateCardBrand', () {
      test('should validate supported card brands', () {
        expect(PaymentMethodValidator.validateCardBrand('visa', 'card').isValid,
            true);
        expect(
            PaymentMethodValidator.validateCardBrand('mastercard', 'card')
                .isValid,
            true);
        expect(
            PaymentMethodValidator.validateCardBrand('rupay', 'card').isValid,
            true);

        // Case insensitive
        expect(PaymentMethodValidator.validateCardBrand('VISA', 'card').isValid,
            true);
      });

      test('should require brand for card payments', () {
        var result = PaymentMethodValidator.validateCardBrand(null, 'card');
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_CARD_BRAND');

        result = PaymentMethodValidator.validateCardBrand('', 'card');
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_CARD_BRAND');
      });

      test('should reject unsupported card brands', () {
        final result =
            PaymentMethodValidator.validateCardBrand('unknown', 'card');
        expect(result.isValid, false);
        expect(result.errorCode, 'UNSUPPORTED_CARD_BRAND');
        expect(result.errorDetails!['provided_brand'], 'unknown');
      });

      test('should skip validation for non-card payments', () {
        expect(PaymentMethodValidator.validateCardBrand(null, 'upi').isValid,
            true);
        expect(
            PaymentMethodValidator.validateCardBrand('unknown', 'wallet')
                .isValid,
            true);
      });
    });

    group('validateWalletProvider', () {
      test('should validate supported wallet providers', () {
        expect(
            PaymentMethodValidator.validateWalletProvider('paytm', 'wallet')
                .isValid,
            true);
        expect(
            PaymentMethodValidator.validateWalletProvider('googlepay', 'wallet')
                .isValid,
            true);
        expect(
            PaymentMethodValidator.validateWalletProvider('phonepe', 'wallet')
                .isValid,
            true);

        // Case insensitive
        expect(
            PaymentMethodValidator.validateWalletProvider('PAYTM', 'wallet')
                .isValid,
            true);
      });

      test('should require provider for wallet payments', () {
        var result =
            PaymentMethodValidator.validateWalletProvider(null, 'wallet');
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_WALLET_PROVIDER');

        result = PaymentMethodValidator.validateWalletProvider('', 'wallet');
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_WALLET_PROVIDER');
      });

      test('should reject unsupported wallet providers', () {
        final result =
            PaymentMethodValidator.validateWalletProvider('unknown', 'wallet');
        expect(result.isValid, false);
        expect(result.errorCode, 'UNSUPPORTED_WALLET_PROVIDER');
        expect(result.errorDetails!['provided_provider'], 'unknown');
      });

      test('should skip validation for non-wallet payments', () {
        expect(
            PaymentMethodValidator.validateWalletProvider(null, 'card').isValid,
            true);
        expect(
            PaymentMethodValidator.validateWalletProvider('unknown', 'upi')
                .isValid,
            true);
      });
    });

    group('validateDisplayName', () {
      test('should allow valid display names', () {
        expect(PaymentMethodValidator.validateDisplayName('My Card').isValid,
            true);
        expect(PaymentMethodValidator.validateDisplayName('Work UPI').isValid,
            true);
        expect(PaymentMethodValidator.validateDisplayName(null).isValid,
            true); // Optional
        expect(PaymentMethodValidator.validateDisplayName('').isValid,
            true); // Optional
      });

      test('should reject display names that are too long', () {
        final longName = 'a' * 101;
        final result = PaymentMethodValidator.validateDisplayName(longName);
        expect(result.isValid, false);
        expect(result.errorCode, 'DISPLAY_NAME_TOO_LONG');
      });

      test('should reject display names with invalid characters', () {
        var result = PaymentMethodValidator.validateDisplayName('My<Card>');
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_DISPLAY_NAME_CHARACTERS');

        result = PaymentMethodValidator.validateDisplayName('My"Card"');
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_DISPLAY_NAME_CHARACTERS');

        result = PaymentMethodValidator.validateDisplayName("My'Card'");
        expect(result.isValid, false);
        expect(result.errorCode, 'INVALID_DISPLAY_NAME_CHARACTERS');
      });
    });

    group('validatePaymentMethod', () {
      test('should validate complete card payment method', () {
        final result = PaymentMethodValidator.validatePaymentMethod(
          methodType: 'card',
          provider: 'razorpay',
          lastFour: '1234',
          brand: 'visa',
          displayName: 'My Visa Card',
          expiryMonth: 12,
          expiryYear: DateTime.now().year + 2,
        );

        expect(result.isValid, true);
      });

      test('should validate complete wallet payment method', () {
        final result = PaymentMethodValidator.validatePaymentMethod(
          methodType: 'wallet',
          provider: 'paytm',
          displayName: 'My Paytm Wallet',
        );

        expect(result.isValid, true);
      });

      test('should validate UPI payment method', () {
        final result = PaymentMethodValidator.validatePaymentMethod(
          methodType: 'upi',
          provider: 'googlepay',
          lastFour: 'test@upi',
          displayName: 'My UPI',
        );

        expect(result.isValid, true);
      });

      test('should fail validation if any required field is invalid', () {
        var result = PaymentMethodValidator.validatePaymentMethod(
          methodType: 'invalid',
          provider: 'razorpay',
        );
        expect(result.isValid, false);
        expect(result.errorCode, 'UNSUPPORTED_METHOD_TYPE');

        result = PaymentMethodValidator.validatePaymentMethod(
          methodType: 'card',
          provider: 'razorpay',
          // Missing required fields for card (expiry checked first)
        );
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_EXPIRY');
      });
    });
  });

  group('TokenPurchaseValidator', () {
    group('validateTokenAmount', () {
      test('should accept valid token amounts', () {
        expect(TokenPurchaseValidator.validateTokenAmount(10).isValid, true);
        expect(TokenPurchaseValidator.validateTokenAmount(100).isValid, true);
        expect(TokenPurchaseValidator.validateTokenAmount(9999).isValid, true);
      });

      test('should reject null token amount', () {
        final result = TokenPurchaseValidator.validateTokenAmount(null);
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_TOKEN_AMOUNT');
      });

      test('should reject token amounts that are too low', () {
        final result = TokenPurchaseValidator.validateTokenAmount(5);
        expect(result.isValid, false);
        expect(result.errorCode, 'TOKEN_AMOUNT_TOO_LOW');
        expect(result.errorDetails!['provided'], 5);
        expect(result.errorDetails!['minimum'], 10);
      });

      test('should reject token amounts that are too high', () {
        final result = TokenPurchaseValidator.validateTokenAmount(10000);
        expect(result.isValid, false);
        expect(result.errorCode, 'TOKEN_AMOUNT_TOO_HIGH');
        expect(result.errorDetails!['provided'], 10000);
        expect(result.errorDetails!['maximum'], 9999);
      });
    });

    group('validatePaymentAmount', () {
      test('should accept valid payment amounts', () {
        expect(TokenPurchaseValidator.validatePaymentAmount(1.0).isValid, true);
        expect(
            TokenPurchaseValidator.validatePaymentAmount(50.50).isValid, true);
        expect(
            TokenPurchaseValidator.validatePaymentAmount(999.90).isValid, true);
      });

      test('should reject null payment amount', () {
        final result = TokenPurchaseValidator.validatePaymentAmount(null);
        expect(result.isValid, false);
        expect(result.errorCode, 'MISSING_PAYMENT_AMOUNT');
      });

      test('should reject payment amounts that are too low', () {
        final result = TokenPurchaseValidator.validatePaymentAmount(0.50);
        expect(result.isValid, false);
        expect(result.errorCode, 'PAYMENT_AMOUNT_TOO_LOW');
        expect(result.errorDetails!['provided'], 0.50);
        expect(result.errorDetails!['minimum'], 1.0);
      });

      test('should reject payment amounts that are too high', () {
        final result = TokenPurchaseValidator.validatePaymentAmount(1000.0);
        expect(result.isValid, false);
        expect(result.errorCode, 'PAYMENT_AMOUNT_TOO_HIGH');
        expect(result.errorDetails!['provided'], 1000.0);
        expect(result.errorDetails!['maximum'], 999.90);
      });
    });

    group('validateTokenAmountConversion', () {
      test('should validate correct token to amount conversion', () {
        // 10 tokens = ₹1, so 100 tokens = ₹10
        expect(
            TokenPurchaseValidator.validateTokenAmountConversion(100, 10.0)
                .isValid,
            true);
        expect(
            TokenPurchaseValidator.validateTokenAmountConversion(50, 5.0)
                .isValid,
            true);
        expect(
            TokenPurchaseValidator.validateTokenAmountConversion(10, 1.0)
                .isValid,
            true);
      });

      test('should allow small floating point differences', () {
        // Should accept tiny differences due to floating point arithmetic
        expect(
            TokenPurchaseValidator.validateTokenAmountConversion(100, 10.001)
                .isValid,
            true);
        expect(
            TokenPurchaseValidator.validateTokenAmountConversion(100, 9.999)
                .isValid,
            true);
      });

      test('should reject incorrect conversions', () {
        final result =
            TokenPurchaseValidator.validateTokenAmountConversion(100, 15.0);
        expect(result.isValid, false);
        expect(result.errorCode, 'AMOUNT_MISMATCH');
        expect(result.errorDetails!['token_amount'], 100);
        expect(result.errorDetails!['provided_amount'], 15.0);
        expect(result.errorDetails!['expected_amount'], 10.0);
      });

      test('should handle edge cases correctly', () {
        // Test minimum token purchase (10 tokens = ₹1)
        expect(
            TokenPurchaseValidator.validateTokenAmountConversion(10, 1.0)
                .isValid,
            true);

        // Test maximum token purchase (9999 tokens = ₹999.90)
        expect(
            TokenPurchaseValidator.validateTokenAmountConversion(9999, 999.90)
                .isValid,
            true);
      });
    });
  });

  group('PaymentPreferenceValidator', () {
    group('validateDefaultPaymentType', () {
      test('should accept valid default payment types', () {
        expect(
            PaymentPreferenceValidator.validateDefaultPaymentType('card')
                .isValid,
            true);
        expect(
            PaymentPreferenceValidator.validateDefaultPaymentType('upi')
                .isValid,
            true);
        expect(
            PaymentPreferenceValidator.validateDefaultPaymentType('wallet')
                .isValid,
            true);
        expect(
            PaymentPreferenceValidator.validateDefaultPaymentType(null).isValid,
            true); // Optional
      });

      test('should reject unsupported payment types', () {
        final result =
            PaymentPreferenceValidator.validateDefaultPaymentType('crypto');
        expect(result.isValid, false);
        expect(result.errorCode, 'UNSUPPORTED_DEFAULT_PAYMENT_TYPE');
        expect(result.errorDetails!['provided_type'], 'crypto');
      });
    });

    group('validatePreferredWallet', () {
      test('should accept supported wallets', () {
        expect(
            PaymentPreferenceValidator.validatePreferredWallet('paytm').isValid,
            true);
        expect(
            PaymentPreferenceValidator.validatePreferredWallet('googlepay')
                .isValid,
            true);
        expect(
            PaymentPreferenceValidator.validatePreferredWallet('phonepe')
                .isValid,
            true);
        expect(PaymentPreferenceValidator.validatePreferredWallet(null).isValid,
            true); // Optional
      });

      test('should reject unsupported wallets', () {
        final result =
            PaymentPreferenceValidator.validatePreferredWallet('unknown');
        expect(result.isValid, false);
        expect(result.errorCode, 'UNSUPPORTED_PREFERRED_WALLET');
        expect(result.errorDetails!['provided_wallet'], 'unknown');
      });
    });

    group('validatePaymentPreferences', () {
      test('should accept valid preference combinations', () {
        var result = PaymentPreferenceValidator.validatePaymentPreferences(
          autoSavePaymentMethods: true,
          preferredWallet: 'paytm',
          enableOneClickPurchase: true,
          defaultPaymentType: 'card',
        );
        expect(result.isValid, true);

        result = PaymentPreferenceValidator.validatePaymentPreferences(
          autoSavePaymentMethods: false,
          enableOneClickPurchase: false,
        );
        expect(result.isValid, true);
      });

      test('should reject incompatible preferences', () {
        final result = PaymentPreferenceValidator.validatePaymentPreferences(
          autoSavePaymentMethods: false,
          enableOneClickPurchase: true, // Incompatible combination
        );
        expect(result.isValid, false);
        expect(result.errorCode, 'INCOMPATIBLE_PREFERENCES');
      });

      test('should validate individual preference fields', () {
        var result = PaymentPreferenceValidator.validatePaymentPreferences(
          defaultPaymentType: 'invalid',
        );
        expect(result.isValid, false);
        expect(result.errorCode, 'UNSUPPORTED_DEFAULT_PAYMENT_TYPE');

        result = PaymentPreferenceValidator.validatePaymentPreferences(
          preferredWallet: 'invalid',
        );
        expect(result.isValid, false);
        expect(result.errorCode, 'UNSUPPORTED_PREFERRED_WALLET');
      });

      test('should allow null values for optional fields', () {
        final result = PaymentPreferenceValidator.validatePaymentPreferences();
        expect(result.isValid, true);
      });
    });
  });
}
