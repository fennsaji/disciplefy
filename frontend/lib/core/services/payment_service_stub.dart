// Stub implementation for non-web platforms (used during testing)
// This file provides empty implementations that satisfy the interface

class PaymentServiceWeb {
  static void ensureRazorpayLoaded() {
    // No-op on non-web platforms
  }

  static Future<void> loadRazorpayScript() async {
    // No-op on non-web platforms
  }

  static bool isRazorpayAvailable() {
    return false; // Razorpay not available on non-web platforms
  }

  static bool hasProperty(String property) {
    return false; // No JS context on non-web platforms
  }

  static Future<void> openCheckout({
    required Map<String, dynamic> options,
    required void Function(Map<String, dynamic> response) onSuccess,
    required void Function() onDismiss,
    required void Function(Map<String, dynamic> error) onFailed,
  }) async {
    // Non-web platforms use the native Razorpay SDK, not the JS checkout.
    throw UnsupportedError('Web checkout is not available on this platform');
  }
}
