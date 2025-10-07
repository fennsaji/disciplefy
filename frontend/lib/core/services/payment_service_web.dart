// Web-specific implementation for Razorpay
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

class PaymentServiceWeb {
  /// Ensure Razorpay script is loaded and available
  static void ensureRazorpayLoaded() {
    if (kDebugMode) {
      final hasRazorpay = js.context.hasProperty('Razorpay');
      print('[PaymentService] Web: Checking if Razorpay exists: $hasRazorpay');
    }
  }

  /// Load Razorpay script dynamically
  static Future<void> loadRazorpayScript() async {
    // Check if Razorpay is already loaded
    if (js.context.hasProperty('Razorpay')) {
      if (kDebugMode) {
        print('[PaymentService] Web: Razorpay already loaded');
      }
      final razorpay = js.context['Razorpay'];
      if (kDebugMode) {
        print('[PaymentService] Web: Razorpay object: $razorpay');
      }
      return;
    }

    if (kDebugMode) {
      print('[PaymentService] Web: Loading Razorpay script...');
    }

    // Create and load Razorpay script
    final script = html.ScriptElement();
    script.src = 'https://checkout.razorpay.com/v1/checkout.js';
    script.async = true;

    // Add script to document first
    html.document.head!.children.add(script);

    // Wait for script to load
    await script.onLoad.first;
    if (kDebugMode) {
      print('[PaymentService] Web: Razorpay script loaded');
    }

    // Add delay to ensure script is fully initialized
    await Future.delayed(const Duration(milliseconds: 500));

    if (kDebugMode) {
      final hasRazorpay = js.context.hasProperty('Razorpay');
      print(
          '[PaymentService] Web: After loading - Razorpay exists: $hasRazorpay');
    }

    if (kDebugMode) {
      print('[PaymentService] Web: ✅ Razorpay script initialization complete');
    }
  }

  /// Check if Razorpay is available in browser
  static bool isRazorpayAvailable() {
    final hasRazorpay = js.context.hasProperty('Razorpay');
    if (kDebugMode) {
      print('[PaymentService] Web: Razorpay availability check: $hasRazorpay');
    }

    if (hasRazorpay) {
      final razorpayObj = js.context['Razorpay'];
      if (kDebugMode) {
        print('[PaymentService] Web: Razorpay object: $razorpayObj');
      }
    }

    return hasRazorpay;
  }

  /// Get JS interop utilities for Razorpay integration
  static js.JsObject jsify(Map<String, dynamic> options) {
    return js.JsObject.jsify(options);
  }

  /// Wrap callback function for JS interop
  static Function allowInterop(Function callback) {
    return js.allowInterop(callback);
  }

  /// Get Razorpay constructor from JS context
  static dynamic getRazorpayConstructor() {
    return js.context['Razorpay'];
  }

  /// Create Razorpay instance
  static dynamic createRazorpayInstance(
      dynamic constructor, js.JsObject options) {
    return js.JsObject(constructor, [options]);
  }

  /// Check if context has property
  static bool hasProperty(String property) {
    return js.context.hasProperty(property);
  }
}
