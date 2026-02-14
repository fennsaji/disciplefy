import 'package:flutter/foundation.dart';
import '../constants/payment_constants.dart';
import '../models/payment_responses.dart';

// Conditional imports for web and mobile platforms
import 'payment_service_stub.dart'
    if (dart.library.html) 'payment_service_web.dart';
import 'payment_service_mobile_stub.dart'
    if (dart.library.io) 'payment_service_mobile.dart';

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
    debugPrint('[PaymentService] 🚀 INITIALIZING PAYMENT SERVICE');
    debugPrint(
        '[PaymentService] Platform: ${_isWebPlatform ? "WEB" : "MOBILE"}');

    if (_isWebPlatform) {
      // Skip mobile service initialization on web
      debugPrint(
          '[PaymentService] ✅ Web platform detected - skipping mobile plugin initialization');
      debugPrint('[PaymentService] Web payment flow will be used when needed');
      return;
    }

    try {
      _mobileService = PaymentServiceMobile();
      _mobileService!.initialize();
      debugPrint(
          '[PaymentService] Mobile payment service initialized successfully');
    } catch (e) {
      debugPrint('[PaymentService] Failed to initialize mobile service: $e');
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
      debugPrint('[PaymentService] 🎯🎯🎯 OPEN CHECKOUT CALLED! 🎯🎯🎯');
      debugPrint('[PaymentService] Order ID: $orderId');
      debugPrint('[PaymentService] Amount: ₹$amount');
      debugPrint('[PaymentService] Description: $description');
      debugPrint('[PaymentService] User Email: $userEmail');
      debugPrint(
          '[PaymentService] Key ID: ${keyId ?? PaymentConstants.razorpayKeyId}');
      debugPrint(
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

      debugPrint('[PaymentService] 📋 PAYMENT OPTIONS CONFIGURED:');
      debugPrint('[PaymentService] Key: ${options['key']}');
      debugPrint('[PaymentService] Amount (paise): ${options['amount']}');
      debugPrint('[PaymentService] Methods enabled: ${options['method']}');

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
      debugPrint('[PaymentService] Error opening checkout: $e');
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
    debugPrint('[PaymentService] Payment successful: ${response.paymentId}');
    if (_onPaymentSuccess != null) {
      _onPaymentSuccess!(response);
    }
    _clearCallbacks();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint(
        '[PaymentService] Payment failed: ${response.code} - ${response.message}');
    if (_onPaymentError != null) {
      _onPaymentError!(response);
    }
    _clearCallbacks();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint(
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
      debugPrint(
          '[PaymentService] ===========================================');
      debugPrint('[PaymentService] STARTING WEB CHECKOUT PROCESS');
      debugPrint(
          '[PaymentService] ===========================================');
      debugPrint(
          '[PaymentService] Opening web checkout with options: $options');
      debugPrint(
          '[PaymentService] Browser platform: ${kIsWeb ? "Web" : "Mobile"}');

      // Load Razorpay script if not already loaded
      debugPrint('[PaymentService] Step 1: Loading Razorpay script...');
      await _loadRazorpayScript();
      debugPrint(
          '[PaymentService] Step 1: ✅ Razorpay script loaded successfully');

      // Add web-specific handlers
      debugPrint('[PaymentService] Step 2: Setting up payment handlers...');
      options['handler'] = PaymentServiceWeb.allowInterop((response) {
        debugPrint(
            '[PaymentService] ✅ WEB PAYMENT SUCCESS CALLBACK TRIGGERED!');
        debugPrint('[PaymentService] Success response: $response');
        try {
          // Convert JsObject to Map for proper access
          final responseMap = {
            'razorpay_payment_id': response['razorpay_payment_id'],
            'razorpay_order_id': response['razorpay_order_id'],
            'razorpay_signature': response['razorpay_signature'],
          };
          debugPrint('[PaymentService] Converted response map: $responseMap');

          // Create PaymentSuccessResponse with extracted values
          final paymentSuccessResponse = PaymentSuccessResponse(
            responseMap['razorpay_payment_id'],
            responseMap['razorpay_order_id'],
            responseMap['razorpay_signature'],
            responseMap, // Pass the converted map
          );
          debugPrint('[PaymentService] Calling _handlePaymentSuccess...');
          _handlePaymentSuccess(paymentSuccessResponse);
        } catch (handlerError) {
          debugPrint(
              '[PaymentService] ❌ Error in success handler: $handlerError');
        }
      });

      options['modal'] = {
        'ondismiss': PaymentServiceWeb.allowInterop(() {
          debugPrint('[PaymentService] ❌ WEB PAYMENT DISMISSED BY USER');
          final paymentFailureResponse = PaymentFailureResponse(
            0, // User cancelled
            'Payment was cancelled by user',
          );
          _handlePaymentError(paymentFailureResponse);
        })
      };
      debugPrint('[PaymentService] Step 2: ✅ Payment handlers configured');

      // Create and open Razorpay checkout
      debugPrint('[PaymentService] Step 3: Creating Razorpay checkout...');
      debugPrint('[PaymentService] Converting options to JS object...');
      final jsOptions = PaymentServiceWeb.jsify(options);
      debugPrint(
          '[PaymentService] ✅ Options converted to JS object successfully');

      debugPrint('[PaymentService] Step 4: Creating Razorpay instance...');
      debugPrint(
          '[PaymentService] Checking if Razorpay exists: ${PaymentServiceWeb.hasProperty('Razorpay')}');

      if (!PaymentServiceWeb.hasProperty('Razorpay')) {
        throw Exception('Razorpay object not available in window context');
      }

      final razorpayConstructor = PaymentServiceWeb.getRazorpayConstructor();
      debugPrint(
          '[PaymentService] Razorpay constructor type: ${razorpayConstructor.runtimeType}');
      debugPrint(
          '[PaymentService] Creating Razorpay instance with jsOptions...');

      final rzp = PaymentServiceWeb.createRazorpayInstance(
          razorpayConstructor, jsOptions);
      debugPrint(
          '[PaymentService] ✅ Razorpay instance created successfully: $rzp');

      debugPrint('[PaymentService] Step 5: Opening Razorpay checkout...');
      debugPrint('[PaymentService] Calling rzp.open()...');

      // Add a delay to ensure DOM is ready
      await Future.delayed(const Duration(milliseconds: 100));

      rzp.callMethod('open');
      debugPrint('[PaymentService] ✅ rzp.open() method called successfully');
      debugPrint(
          '[PaymentService] ===========================================');
      debugPrint('[PaymentService] RAZORPAY CHECKOUT SHOULD NOW BE VISIBLE!');
      debugPrint(
          '[PaymentService] If you don\'t see the payment modal, check:');
      debugPrint('[PaymentService] 1. Browser console for JavaScript errors');
      debugPrint('[PaymentService] 2. Popup blockers');
      debugPrint('[PaymentService] 3. Network requests to Razorpay');
      debugPrint(
          '[PaymentService] ===========================================');
    } catch (e, stackTrace) {
      debugPrint('[PaymentService] ❌❌❌ CRITICAL ERROR IN WEB CHECKOUT ❌❌❌');
      debugPrint('[PaymentService] Error: $e');
      debugPrint('[PaymentService] Stack trace: $stackTrace');
      debugPrint('[PaymentService] ❌❌❌ END CRITICAL ERROR ❌❌❌');

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
