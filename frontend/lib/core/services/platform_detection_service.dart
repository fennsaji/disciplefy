/// Platform Detection Service library.
///
/// Detects the current platform and returns the appropriate payment provider.
/// This service is used to automatically select the correct payment method
/// based on where the app is running:
/// - Web: Razorpay
/// - Android: Google Play In-App Purchases
/// - iOS: Apple App Store In-App Purchases
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Payment provider types
enum PaymentProvider {
  razorpay,
  googlePlay,
  appleAppStore,
}

/// Platform Detection Service
class PlatformDetectionService {
  /// Get the preferred payment provider for the current platform
  PaymentProvider getPreferredProvider() {
    if (kIsWeb) {
      return PaymentProvider.razorpay;
    }

    // Check for mobile platforms
    try {
      if (Platform.isAndroid) {
        return PaymentProvider.googlePlay;
      }
      if (Platform.isIOS) {
        return PaymentProvider.appleAppStore;
      }
    } catch (e) {
      // Platform class not available on web
      // This should never happen since we check kIsWeb first
    }

    // Default to Razorpay for desktop or unknown platforms
    return PaymentProvider.razorpay;
  }

  /// Convert PaymentProvider enum to API string
  String providerToString(PaymentProvider provider) {
    switch (provider) {
      case PaymentProvider.razorpay:
        return 'razorpay';
      case PaymentProvider.googlePlay:
        return 'google_play';
      case PaymentProvider.appleAppStore:
        return 'apple_appstore';
    }
  }

  /// Check if the current platform supports in-app purchases
  bool supportsInAppPurchases() {
    final provider = getPreferredProvider();
    return provider == PaymentProvider.googlePlay ||
        provider == PaymentProvider.appleAppStore;
  }

  /// Check if the current platform uses web-based checkout
  bool usesWebCheckout() {
    return getPreferredProvider() == PaymentProvider.razorpay;
  }

  /// Get a human-readable name for the current payment provider
  String getProviderDisplayName() {
    final provider = getPreferredProvider();
    switch (provider) {
      case PaymentProvider.razorpay:
        return 'Razorpay';
      case PaymentProvider.googlePlay:
        return 'Google Play';
      case PaymentProvider.appleAppStore:
        return 'Apple App Store';
    }
  }

  /// Get the current platform name
  String getPlatformName() {
    if (kIsWeb) {
      return 'Web';
    }

    try {
      if (Platform.isAndroid) {
        return 'Android';
      }
      if (Platform.isIOS) {
        return 'iOS';
      }
      if (Platform.isMacOS) {
        return 'macOS';
      }
      if (Platform.isWindows) {
        return 'Windows';
      }
      if (Platform.isLinux) {
        return 'Linux';
      }
    } catch (e) {
      // Platform class not available
    }

    return 'Unknown';
  }

  /// Check if running on mobile (Android or iOS)
  bool isMobile() {
    if (kIsWeb) {
      return false;
    }

    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  /// Check if running on desktop (Windows, macOS, Linux)
  bool isDesktop() {
    if (kIsWeb) {
      return false;
    }

    try {
      return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    } catch (e) {
      return false;
    }
  }
}
