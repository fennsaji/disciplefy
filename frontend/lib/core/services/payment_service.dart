import 'package:flutter/foundation.dart';
import '../constants/payment_constants.dart';
import '../models/payment_responses.dart';

// Conditional imports for web and mobile platforms
import 'payment_service_stub.dart'
    if (dart.library.html) 'payment_service_web.dart';
import 'payment_service_mobile_stub.dart'
    if (dart.library.io) 'payment_service_mobile.dart';
import '../utils/logger.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  bool _isWebPlatform = kIsWeb;
  PaymentServiceMobile? _mobileService;

  // Callbacks
  Function(PaymentSuccessResponse)? _onPaymentSuccess;
  Function(PaymentFailureResponse)? _onPaymentError;
  Function(ExternalWalletResponse)? _onExternalWallet;

  void initialize() {
    Logger.debug('[PaymentService] 🚀 INITIALIZING PAYMENT SERVICE');
    Logger.debug(
        '[PaymentService] Platform: ${_isWebPlatform ? "WEB" : "MOBILE"}');

    if (_isWebPlatform) {
      // Skip mobile service initialization on web
      Logger.debug(
          '[PaymentService] ✅ Web platform detected - skipping mobile plugin initialization');
      Logger.debug(
          '[PaymentService] Web payment flow will be used when needed');
      return;
    }

    try {
      _mobileService = PaymentServiceMobile();
      _mobileService!.initialize();
      Logger.debug(
          '[PaymentService] Mobile payment service initialized successfully');
    } catch (e) {
      Logger.debug('[PaymentService] Failed to initialize mobile service: $e');
      // Mark as web platform if initialization fails
      _isWebPlatform = true;
    }
  }

  void dispose() {
    _mobileService?.dispose();
  }

  Future<void> openCheckout({
    required String orderId,
    required double amount,
    required String description,
    required String userEmail,
    required String userPhone,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onError,
    Function(ExternalWalletResponse)? onExternalWallet,
    String? keyId, // Add keyId parameter to use from API response
  }) async {
    try {
      Logger.debug('[PaymentService] 🎯🎯🎯 OPEN CHECKOUT CALLED! 🎯🎯🎯');
      Logger.debug('[PaymentService] Order ID: $orderId');
      Logger.debug('[PaymentService] Amount: ₹$amount');
      Logger.debug('[PaymentService] Description: $description');
      Logger.debug('[PaymentService] User Email: $userEmail');
      Logger.debug(
          '[PaymentService] Key ID: ${keyId ?? PaymentConstants.razorpayKeyId}');
      Logger.debug(
          '[PaymentService] Platform: ${_isWebPlatform ? "WEB" : "MOBILE"}');

      // Store callbacks
      _onPaymentSuccess = onSuccess;
      _onPaymentError = onError;
      _onExternalWallet = onExternalWallet;

      final options = {
        'key': keyId ??
            PaymentConstants
                .razorpayKeyId, // Use provided keyId or fall back to constant
        'amount': (amount * 100).toInt(), // Amount in paise
        'order_id': orderId,
        'name': PaymentConstants.companyName,
        'description': description,
        'prefill': {
          'contact': userPhone,
          'email': userEmail,
        },
        'method': {
          'netbanking': true,
          'card': true,
          'upi': true,
          'wallet': true,
        },
        'theme': PaymentConstants.razorpayTheme,
      };

      Logger.debug('[PaymentService] 📋 PAYMENT OPTIONS CONFIGURED:');
      Logger.debug('[PaymentService] Key: ${options['key']}');
      Logger.debug('[PaymentService] Amount (paise): ${options['amount']}');
      Logger.debug('[PaymentService] Methods enabled: ${options['method']}');

      if (_isWebPlatform) {
        await _openWebCheckout(options);
      } else if (_mobileService != null) {
        _mobileService!.openCheckout(
          options: options,
          onSuccess: _handlePaymentSuccess,
          onError: _handlePaymentError,
          onExternalWallet:
              onExternalWallet != null ? _handleExternalWallet : null,
        );
      } else {
        throw Exception('Payment service not initialized');
      }
    } catch (e) {
      Logger.debug('[PaymentService] Error opening checkout: $e');
      if (_onPaymentError != null) {
        // Create a mock failure response for initialization errors
        final mockError = PaymentFailureResponse(
          1, // code
          'Failed to initialize payment: ${e.toString()}', // message
        );
        _onPaymentError!(mockError);
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    Logger.debug('[PaymentService] Payment successful: ${response.paymentId}');
    if (_onPaymentSuccess != null) {
      _onPaymentSuccess!(response);
    }
    _clearCallbacks();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    Logger.debug(
        '[PaymentService] Payment failed: ${response.code} - ${response.message}');
    if (_onPaymentError != null) {
      _onPaymentError!(response);
    }
    _clearCallbacks();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Logger.debug(
        '[PaymentService] External wallet selected: ${response.walletName}');
    if (_onExternalWallet != null) {
      _onExternalWallet!(response);
    }
    _clearCallbacks();
  }

  void _clearCallbacks() {
    _onPaymentSuccess = null;
    _onPaymentError = null;
    _onExternalWallet = null;
  }

  /// Web-specific Razorpay checkout using JavaScript integration
  Future<void> _openWebCheckout(Map<String, dynamic> options) async {
    try {
      Logger.debug(
          '[PaymentService] ===========================================');
      Logger.debug('[PaymentService] STARTING WEB CHECKOUT PROCESS');
      Logger.debug(
          '[PaymentService] ===========================================');
      Logger.debug(
          '[PaymentService] Opening web checkout with options: $options');
      Logger.debug(
          '[PaymentService] Browser platform: ${kIsWeb ? "Web" : "Mobile"}');

      // Load Razorpay script if not already loaded
      Logger.debug('[PaymentService] Step 1: Loading Razorpay script...');
      await _loadRazorpayScript();
      Logger.debug(
          '[PaymentService] Step 1: ✅ Razorpay script loaded successfully');

      // Create and open Razorpay checkout. All JS interop (option conversion,
      // callback wrapping, constructing and opening the checkout) lives in
      // PaymentServiceWeb so this file stays free of web-only types.
      Logger.debug('[PaymentService] Step 2: Opening Razorpay checkout...');
      Logger.debug(
          '[PaymentService] Checking if Razorpay exists: ${PaymentServiceWeb.hasProperty('Razorpay')}');

      await PaymentServiceWeb.openCheckout(
        options: options,
        onSuccess: (response) {
          Logger.debug('[PaymentService] Success response: $response');
          final paymentSuccessResponse = PaymentSuccessResponse(
            response['razorpay_payment_id'] as String?,
            response['razorpay_order_id'] as String?,
            response['razorpay_signature'] as String?,
            response,
          );
          Logger.debug('[PaymentService] Calling _handlePaymentSuccess...');
          _handlePaymentSuccess(paymentSuccessResponse);
        },
        onDismiss: () {
          final paymentFailureResponse = PaymentFailureResponse(
            0, // User cancelled
            'Payment was cancelled by user',
          );
          _handlePaymentError(paymentFailureResponse);
        },
        onFailed: (error) {
          final code = error['code'] ?? 'PAYMENT_FAILED';
          final description = error['description'] ?? 'Payment failed';
          _handlePaymentError(PaymentFailureResponse(
            1, // non-zero = hard failure, not user cancel
            '$code: $description',
          ));
        },
      );

      Logger.debug('[PaymentService] ✅ rzp.open() method called successfully');
      Logger.debug(
          '[PaymentService] ===========================================');
      Logger.debug('[PaymentService] RAZORPAY CHECKOUT SHOULD NOW BE VISIBLE!');
      Logger.debug(
          '[PaymentService] If you don\'t see the payment modal, check:');
      Logger.debug('[PaymentService] 1. Browser console for JavaScript errors');
      Logger.debug('[PaymentService] 2. Popup blockers');
      Logger.debug('[PaymentService] 3. Network requests to Razorpay');
      Logger.debug(
          '[PaymentService] ===========================================');
    } catch (e, stackTrace) {
      Logger.debug('[PaymentService] ❌❌❌ CRITICAL ERROR IN WEB CHECKOUT ❌❌❌');
      Logger.debug('[PaymentService] Error: $e');
      Logger.debug('[PaymentService] Stack trace: $stackTrace');
      Logger.debug('[PaymentService] ❌❌❌ END CRITICAL ERROR ❌❌❌');

      final paymentFailureResponse = PaymentFailureResponse(
        1,
        'Web checkout failed: ${e.toString()}',
      );
      _handlePaymentError(paymentFailureResponse);
    }
  }

  /// Load Razorpay JavaScript SDK for web
  Future<void> _loadRazorpayScript() async {
    await PaymentServiceWeb.loadRazorpayScript();
  }

  // Helper method to format amount for display
  static String formatAmount(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  // Helper method to calculate token amount based on price
  static int calculateTokenAmount(double price) {
    return (price * PaymentConstants.tokensPerRupee).round();
  }

  // Helper method to get payment package details
  static Map<String, dynamic> getPaymentPackage(String packageId) {
    return PaymentConstants.defaultPackages.firstWhere(
      (package) => package['id'] == packageId,
      orElse: () => PaymentConstants.defaultPackages.first,
    );
  }
}
