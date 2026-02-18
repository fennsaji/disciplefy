// Platform-Aware Payment Provider Service
//
// Automatically detects the current platform and returns the appropriate
// payment provider ('razorpay', 'google_play', 'apple_appstore').
//
// NO HARDCODING: Provider selection is based solely on runtime platform detection.

import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformPaymentProviderService {
  /// Get the payment provider for the current platform
  ///
  /// Returns:
  /// - 'razorpay' for web
  /// - 'google_play' for Android
  /// - 'apple_appstore' for iOS
  static String getProvider() {
    if (kIsWeb) {
      return 'razorpay';
    } else if (Platform.isAndroid) {
      return 'google_play';
    } else if (Platform.isIOS) {
      return 'apple_appstore';
    } else {
      // Fallback for unsupported platforms (e.g., desktop)
      return 'razorpay';
    }
  }

  /// Check if current platform uses In-App Purchases
  ///
  /// Returns true for Android and iOS, false for web and desktop
  static bool isIAPPlatform() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Check if current platform uses web payments
  ///
  /// Returns true for web, false for mobile and desktop
  static bool isWebPaymentPlatform() {
    return kIsWeb;
  }

  /// Get user-friendly provider name
  ///
  /// Returns a display-friendly name for the current payment provider:
  /// - 'Google Play' for Android
  /// - 'App Store' for iOS
  /// - 'Razorpay' for web
  static String getProviderDisplayName() {
    final provider = getProvider();
    switch (provider) {
      case 'google_play':
        return 'Google Play';
      case 'apple_appstore':
        return 'App Store';
      case 'razorpay':
        return 'Razorpay';
      default:
        return 'Payment Provider';
    }
  }

  /// Get platform-specific payment method description
  ///
  /// Returns a description of how payment will be processed on this platform
  static String getPaymentMethodDescription() {
    if (kIsWeb) {
      return 'Payment via Razorpay (Credit Card, Debit Card, UPI, Net Banking)';
    } else if (Platform.isAndroid) {
      return 'In-App Purchase via Google Play';
    } else if (Platform.isIOS) {
      return 'In-App Purchase via App Store';
    } else {
      return 'Online Payment';
    }
  }

  /// Check if the current platform supports subscription restoration
  ///
  /// Returns true for iOS and Android (IAP platforms), false for web
  static bool supportsRestorePurchases() {
    return isIAPPlatform();
  }

  /// Get the current platform name for logging/analytics
  static String getPlatformName() {
    if (kIsWeb) {
      return 'web';
    } else if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isMacOS) {
      return 'macos';
    } else if (Platform.isWindows) {
      return 'windows';
    } else if (Platform.isLinux) {
      return 'linux';
    } else {
      return 'unknown';
    }
  }
}
