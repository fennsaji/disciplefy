import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../constants/payment_constants.dart';

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
    if (_isWebPlatform) {
      // Skip Razorpay initialization on web - use web-based payment flow
      debugPrint(
          '[PaymentService] Web platform detected - skipping native plugin initialization');
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
  }) async {
    try {
      // Store callbacks
      _onPaymentSuccess = onSuccess;
      _onPaymentError = onError;
      _onExternalWallet = onExternalWallet;

      final options = {
        'key': PaymentConstants.razorpayKeyId,
        'amount': (amount * 100).toInt(), // Amount in paise
        'order_id': orderId,
        'name': PaymentConstants.companyName,
        'description': description,
        'prefill': {
          'contact': userPhone,
          'email': userEmail,
        },
        'external': {
          'wallets': ['paytm']
        },
        'theme': PaymentConstants.razorpayTheme,
      };

      if (_razorpay != null) {
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
