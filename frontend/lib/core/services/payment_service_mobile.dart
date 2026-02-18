// Mobile-specific Razorpay implementation
import 'package:razorpay_flutter/razorpay_flutter.dart' as rzp;
import '../models/payment_responses.dart';
import '../utils/logger.dart';

class PaymentServiceMobile {
  rzp.Razorpay? _razorpay;

  // Callbacks
  Function(PaymentSuccessResponse)? _onPaymentSuccess;
  Function(PaymentFailureResponse)? _onPaymentError;
  Function(ExternalWalletResponse)? _onExternalWallet;

  void initialize() {
    try {
      _razorpay = rzp.Razorpay();
      _razorpay?.on(rzp.Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay?.on(rzp.Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay?.on(rzp.Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      Logger.debug('[PaymentServiceMobile] Razorpay initialized successfully');
    } catch (e) {
      Logger.debug('[PaymentServiceMobile] Failed to initialize Razorpay: $e');
      rethrow;
    }
  }

  void dispose() {
    _razorpay?.clear();
  }

  void openCheckout({
    required Map<String, dynamic> options,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onError,
    Function(ExternalWalletResponse)? onExternalWallet,
  }) {
    try {
      Logger.debug(
          '[PaymentServiceMobile] Opening Razorpay checkout with options: $options');

      // Store callbacks
      _onPaymentSuccess = onSuccess;
      _onPaymentError = onError;
      _onExternalWallet = onExternalWallet;

      if (_razorpay != null) {
        _razorpay!.open(options);
      } else {
        throw Exception('Razorpay not initialized');
      }
    } catch (e) {
      Logger.debug('[PaymentServiceMobile] Error opening checkout: $e');
      final mockError = PaymentFailureResponse(
        1,
        'Failed to initialize payment: ${e.toString()}',
      );
      onError(mockError);
    }
  }

  void _handlePaymentSuccess(rzp.PaymentSuccessResponse response) {
    Logger.debug(
        '[PaymentServiceMobile] Payment successful: ${response.paymentId}');
    if (_onPaymentSuccess != null) {
      // Convert Razorpay response to our custom response
      final customResponse = PaymentSuccessResponse(
        response.paymentId,
        response.orderId,
        response.signature,
      );
      _onPaymentSuccess!(customResponse);
    }
    _clearCallbacks();
  }

  void _handlePaymentError(rzp.PaymentFailureResponse response) {
    Logger.debug(
        '[PaymentServiceMobile] Payment failed: ${response.code} - ${response.message}');
    if (_onPaymentError != null) {
      // Convert Razorpay response to our custom response
      final customResponse = PaymentFailureResponse(
        response.code,
        response.message,
      );
      _onPaymentError!(customResponse);
    }
    _clearCallbacks();
  }

  void _handleExternalWallet(rzp.ExternalWalletResponse response) {
    Logger.debug(
        '[PaymentServiceMobile] External wallet selected: ${response.walletName}');
    if (_onExternalWallet != null) {
      // Convert Razorpay response to our custom response
      final customResponse = ExternalWalletResponse(
        response.walletName,
      );
      _onExternalWallet!(customResponse);
    }
    _clearCallbacks();
  }

  void _clearCallbacks() {
    _onPaymentSuccess = null;
    _onPaymentError = null;
    _onExternalWallet = null;
  }
}
