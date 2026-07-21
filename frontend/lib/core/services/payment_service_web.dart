// Web-specific implementation for Razorpay
//
// All JavaScript interop for the Razorpay checkout lives in this file. The
// shared PaymentService talks to it through plain Dart types only, so the
// non-web stub (payment_service_stub.dart) can mirror the same signatures.
//
// Uses dart:js_interop rather than dart:js because `allowInterop` lives in
// dart:js_util, which is no longer resolvable on Dart 3.12+.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// The global `Razorpay` constructor injected by checkout.js.
@JS('Razorpay')
external JSFunction? get _razorpayConstructor;

class PaymentServiceWeb {
  /// Ensure Razorpay script is loaded and available
  static void ensureRazorpayLoaded() {
    if (kDebugMode) {
      final hasRazorpay = hasProperty('Razorpay');
      Logger.debug(
          '[PaymentService] Web: Checking if Razorpay exists: $hasRazorpay');
    }
  }

  /// Load Razorpay script dynamically
  static Future<void> loadRazorpayScript() async {
    // Check if Razorpay is already loaded
    if (hasProperty('Razorpay')) {
      Logger.debug('[PaymentService] Web: Razorpay already loaded');
      return;
    }

    Logger.debug('[PaymentService] Web: Loading Razorpay script...');

    // Create and load Razorpay script
    final script = html.ScriptElement();
    script.src = 'https://checkout.razorpay.com/v1/checkout.js';
    script.async = true;

    // Add script to document first
    html.document.head!.children.add(script);

    // Wait for script to load
    await script.onLoad.first;
    Logger.debug('[PaymentService] Web: Razorpay script loaded');

    // Add delay to ensure script is fully initialized
    await Future.delayed(const Duration(milliseconds: 500));

    if (kDebugMode) {
      Logger.info(
          '[PaymentService] Web: After loading - Razorpay exists: ${hasProperty('Razorpay')}');
    }

    Logger.debug(
        '[PaymentService] Web: ✅ Razorpay script initialization complete');
  }

  /// Check if Razorpay is available in browser
  static bool isRazorpayAvailable() {
    final hasRazorpay = hasProperty('Razorpay');
    Logger.debug(
        '[PaymentService] Web: Razorpay availability check: $hasRazorpay');
    return hasRazorpay;
  }

  /// Check if the JS global scope has a property
  static bool hasProperty(String property) {
    try {
      return globalContext.has(property);
    } catch (e) {
      return false;
    }
  }

  /// Build the Razorpay checkout, wire up its callbacks, and open it.
  ///
  /// [options] is the Razorpay options map (without handlers — those are
  /// supplied via the callbacks below and attached here).
  ///
  /// - [onSuccess] receives the Razorpay success response as a Dart map.
  /// - [onDismiss] fires when the user closes the checkout modal.
  /// - [onFailed] fires on a hard decline (`payment.failed`), receiving the
  ///   response's `error` object as a Dart map.
  static Future<void> openCheckout({
    required Map<String, dynamic> options,
    required void Function(Map<String, dynamic> response) onSuccess,
    required void Function() onDismiss,
    required void Function(Map<String, dynamic> error) onFailed,
  }) async {
    final constructor = _razorpayConstructor;
    if (constructor == null) {
      throw Exception('Razorpay object not available in window context');
    }

    final jsOptions = options.jsify() as JSObject;

    // Success handler — Razorpay invokes this with the payment response.
    jsOptions.setProperty(
      'handler'.toJS,
      ((JSObject response) {
        Logger.debug('[PaymentService] ✅ WEB PAYMENT SUCCESS CALLBACK');
        try {
          onSuccess(_toMap(response));
        } catch (e) {
          Logger.error('[PaymentService] ❌ Error in success handler: $e');
        }
      }).toJS,
    );

    // Razorpay calls ondismiss with one argument (null or an error object),
    // so the callback must accept it or the interop call throws.
    final modal = JSObject();
    modal.setProperty(
      'ondismiss'.toJS,
      ((JSAny? _) {
        Logger.debug('[PaymentService] ❌ WEB PAYMENT DISMISSED BY USER');
        onDismiss();
      }).toJS,
    );
    jsOptions.setProperty('modal'.toJS, modal);

    final rzp = constructor.callAsConstructor<JSObject>(jsOptions);
    Logger.debug('[PaymentService] ✅ Razorpay instance created');

    // Subscribe to hard-decline events (e.g. card declined by bank).
    // Without this, payment.failed fires ondismiss → reported as "cancelled".
    rzp.callMethod(
      'on'.toJS,
      'payment.failed'.toJS,
      ((JSObject response) {
        Logger.debug('[PaymentService] ❌ WEB PAYMENT FAILED EVENT');
        try {
          final error = response.getProperty<JSObject?>('error'.toJS);
          onFailed(error == null ? const {} : _toMap(error));
        } catch (e) {
          Logger.error(
              '[PaymentService] ❌ Error in payment.failed handler: $e');
          onFailed(const {});
        }
      }).toJS,
    );

    // Add a delay to ensure DOM is ready
    await Future.delayed(const Duration(milliseconds: 100));

    rzp.callMethod('open'.toJS);
    Logger.debug('[PaymentService] ✅ rzp.open() called');
  }

  /// Convert a plain JS object into a Dart map.
  static Map<String, dynamic> _toMap(JSObject object) {
    final dartified = object.dartify();
    if (dartified is Map) {
      return dartified.map((key, value) => MapEntry('$key', value));
    }
    return <String, dynamic>{};
  }
}
