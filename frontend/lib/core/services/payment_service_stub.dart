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

  static Map<String, dynamic> jsify(Map<String, dynamic> options) {
    return options; // Return as-is on non-web platforms
  }

  static Function allowInterop(Function callback) {
    return callback; // Return as-is on non-web platforms
  }

  static dynamic getRazorpayConstructor() {
    return null; // Not available on non-web platforms
  }

  static dynamic createRazorpayInstance(dynamic constructor, dynamic options) {
    return null; // Not available on non-web platforms
  }

  static bool hasProperty(String property) {
    return false; // No JS context on non-web platforms
  }
}
