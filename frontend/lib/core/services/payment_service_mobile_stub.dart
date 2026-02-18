// Stub implementation for mobile payment service
// Used when not on mobile platform

import '../models/payment_responses.dart';

class PaymentServiceMobile {
  void initialize() {
    // No-op stub
  }

  void dispose() {
    // No-op stub
  }

  void openCheckout({
    required Map<String, dynamic> options,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onError,
    Function(ExternalWalletResponse)? onExternalWallet,
  }) {
    // No-op stub - should not be called
    throw UnsupportedError(
        'Mobile payment service not available on this platform');
  }
}
