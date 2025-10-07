import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../constants/payment_constants.dart';

// Conditional imports for web platform
import 'payment_service_stub.dart'
    if (dart.library.html) 'payment_service_web.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  Razorpay? _razorpay;
  bool _isWebPlatform = kIsWeb;

  // Callbacks
  Function(PaymentSuccessResponse)? _onPaymentSuccess;
  Function(PaymentFailureResponse)? _onPaymentError;
  Function(ExternalWalletResponse)? _onExternalWallet;

  void initialize() {
    debugPrint('[PaymentService] 🚀 INITIALIZING PAYMENT SERVICE');
    debugPrint(
        '[PaymentService] Platform: ${_isWebPlatform ? "WEB" : "MOBILE"}');

    if (_isWebPlatform) {
      // Skip Razorpay initialization on web - use web-based payment flow
      debugPrint(
          '[PaymentService] ✅ Web platform detected - skipping native plugin initialization');
      debugPrint('[PaymentService] Web payment flow will be used when needed');
      return;
    }

    try {
      _razorpay = Razorpay();
      _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay?.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      debugPrint('[PaymentService] Razorpay initialized successfully');
    } catch (e) {
      debugPrint('[PaymentService] Failed to initialize Razorpay: $e');
      // Mark as web platform if initialization fails (common on web)
      _isWebPlatform = true;
    }
  }

  void dispose() {
    _razorpay?.clear();
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
      debugPrint('[PaymentService] External wallets: ${options['external']}');
      debugPrint('[PaymentService] Config: ${options['config']}');

      if (_isWebPlatform) {
        await _openWebCheckout(options);
      } else if (_razorpay != null) {
        _razorpay!.open(options);
      } else {
        throw Exception('Razorpay not initialized');
      }
    } catch (e) {
      debugPrint('Error opening Razorpay checkout: $e');
      if (_onPaymentError != null) {
        // Create a mock failure response for initialization errors
        final mockError = PaymentFailureResponse(
          1, // code
          'Failed to initialize payment: ${e.toString()}', // message
          null, // data
        );
        _onPaymentError!(mockError);
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Payment successful: ${response.paymentId}');
    if (_onPaymentSuccess != null) {
      _onPaymentSuccess!(response);
    }
    _clearCallbacks();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment failed: ${response.code} - ${response.message}');
    if (_onPaymentError != null) {
      _onPaymentError!(response);
    }
    _clearCallbacks();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet selected: ${response.walletName}');
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
            null,
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
      await Future.delayed(Duration(milliseconds: 100));

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
        null,
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
