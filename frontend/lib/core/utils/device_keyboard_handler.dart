import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Utility class for detecting devices that need custom keyboard handling
/// to resolve keyboard shadow issues on specific Android OEMs.
///
/// Targets problematic devices:
/// - Samsung Galaxy series (One UI keyboard behavior)
/// - Xiaomi/Redmi devices (MIUI keyboard handling)
/// - OnePlus devices (OxygenOS-specific issues)
/// - High pixel density screens with non-standard aspect ratios
class DeviceKeyboardHandler {
  static DeviceInfoPlugin? _deviceInfoPlugin;
  static AndroidDeviceInfo? _androidInfo;
  static bool? _needsCustomHandling;

  /// Initialize device info detection (call once at app startup)
  static Future<void> initialize() async {
    // Skip initialization on web platform
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      _deviceInfoPlugin = DeviceInfoPlugin();
      _androidInfo = await _deviceInfoPlugin!.androidInfo;
      _needsCustomHandling = await _determineCustomHandlingNeeded();

      if (kDebugMode) {
        print(
            '🔧 [DEVICE KEYBOARD] Initialized for ${_androidInfo!.manufacturer} ${_androidInfo!.model}');
        print(
            '🔧 [DEVICE KEYBOARD] Custom handling needed: $_needsCustomHandling');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🚨 [DEVICE KEYBOARD] Failed to initialize: $e');
      }
      _needsCustomHandling = false;
    }
  }

  /// Check if current device needs custom keyboard handling
  static bool get needsCustomKeyboardHandling {
    // Skip on web platform
    if (kIsWeb) return false;
    // Default to false if not initialized or not Android
    if (defaultTargetPlatform != TargetPlatform.android ||
        _needsCustomHandling == null) {
      return false;
    }
    return _needsCustomHandling!;
  }

  /// Get device manufacturer for debugging
  static String get deviceManufacturer {
    if (kIsWeb) return 'Web';
    return _androidInfo?.manufacturer ?? 'Unknown';
  }

  /// Get device model for debugging
  static String get deviceModel {
    if (kIsWeb) return 'Web Browser';
    return _androidInfo?.model ?? 'Unknown';
  }

  /// Get Android version for debugging
  static String get androidVersion {
    if (kIsWeb) return 'N/A (Web)';
    return _androidInfo?.version.release ?? 'Unknown';
  }

  /// Get detailed device info for debugging
  static String get debugInfo {
    if (kIsWeb) return 'Platform: Web Browser, Custom handling: false';
    if (_androidInfo == null) return 'Device info not available';

    return 'Manufacturer: ${_androidInfo!.manufacturer}, '
        'Model: ${_androidInfo!.model}, '
        'Android: ${_androidInfo!.version.release}, '
        'SDK: ${_androidInfo!.version.sdkInt}, '
        'Custom handling: $_needsCustomHandling';
  }

  /// Determine if device needs custom keyboard handling based on manufacturer and model
  static Future<bool> _determineCustomHandlingNeeded() async {
    if (_androidInfo == null) return false;

    final manufacturer = _androidInfo!.manufacturer.toLowerCase();
    final model = _androidInfo!.model.toLowerCase();
    final sdkInt = _androidInfo!.version.sdkInt;

    // Samsung devices with One UI (especially problematic)
    if (manufacturer.contains('samsung')) {
      // Galaxy S series, Note series, A series are most affected
      if (model.contains('galaxy') || model.contains('sm-')) {
        if (kDebugMode) {
          print('🔧 [DEVICE KEYBOARD] Samsung Galaxy device detected: $model');
        }
        return true;
      }
    }

    // Xiaomi/Redmi devices with MIUI
    if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi')) {
      // Most Xiaomi devices with MIUI have keyboard issues
      if (kDebugMode) {
        print('🔧 [DEVICE KEYBOARD] Xiaomi/Redmi device detected: $model');
      }
      return true;
    }

    // OnePlus devices with OxygenOS
    if (manufacturer.contains('oneplus')) {
      // OnePlus 8, 9, 10 series have reported issues
      if (model.contains('oneplus') ||
          model.contains('op') ||
          model.contains('cph')) {
        if (kDebugMode) {
          print('🔧 [DEVICE KEYBOARD] OnePlus device detected: $model');
        }
        return true;
      }
    }

    // Realme devices (similar to OnePlus/OPPO issues)
    if (manufacturer.contains('realme') || manufacturer.contains('oppo')) {
      if (kDebugMode) {
        print('🔧 [DEVICE KEYBOARD] Realme/OPPO device detected: $model');
      }
      return true;
    }

    // Vivo devices (similar keyboard handling issues)
    if (manufacturer.contains('vivo')) {
      if (kDebugMode) {
        print('🔧 [DEVICE KEYBOARD] Vivo device detected: $model');
      }
      return true;
    }

    // Honor devices (Huawei-based)
    if (manufacturer.contains('honor') || manufacturer.contains('huawei')) {
      if (kDebugMode) {
        print('🔧 [DEVICE KEYBOARD] Honor/Huawei device detected: $model');
      }
      return true;
    }

    // Additional checks for high-risk devices based on Android version and screen characteristics
    if (sdkInt >= 29) {
      // Android 10+
      // Check for specific model patterns that commonly have issues
      final problematicPatterns = [
        'sm-', // Samsung internal model codes
        'mi ', // Xiaomi Mi series
        'redmi', // Redmi series
        'poco', // Poco series (Xiaomi sub-brand)
        'cph', // OnePlus internal model codes
        'rmx', // Realme internal model codes
      ];

      for (final pattern in problematicPatterns) {
        if (model.contains(pattern)) {
          if (kDebugMode) {
            print(
                '🔧 [DEVICE KEYBOARD] Problematic model pattern detected: $pattern in $model');
          }
          return true;
        }
      }
    }

    if (kDebugMode) {
      print(
          '🔧 [DEVICE KEYBOARD] No custom handling needed for: $manufacturer $model');
    }
    return false;
  }

  /// Get recommended keyboard padding adjustment for device
  static double getKeyboardPaddingAdjustment() {
    if (!needsCustomKeyboardHandling) return 0.0;

    final manufacturer = _androidInfo?.manufacturer.toLowerCase() ?? '';

    // Samsung devices often need more padding due to One UI keyboard behavior
    if (manufacturer.contains('samsung')) {
      return 30.0;
    }

    // Xiaomi devices with MIUI need moderate adjustment
    if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi')) {
      return 25.0;
    }

    // OnePlus devices need minimal adjustment
    if (manufacturer.contains('oneplus')) {
      return 20.0;
    }

    // Default adjustment for other problematic devices
    return 20.0;
  }

  /// Get recommended animation duration for keyboard transitions
  static Duration getKeyboardAnimationDuration() {
    if (!needsCustomKeyboardHandling) {
      return const Duration(milliseconds: 200);
    }

    final manufacturer = _androidInfo?.manufacturer.toLowerCase() ?? '';

    // Samsung devices often have slower keyboard animations
    if (manufacturer.contains('samsung')) {
      return const Duration(milliseconds: 300);
    }

    // Xiaomi devices need standard duration
    if (manufacturer.contains('xiaomi') || manufacturer.contains('redmi')) {
      return const Duration(milliseconds: 250);
    }

    // Default for other devices
    return const Duration(milliseconds: 250);
  }

  /// Check if device should use alternative viewport calculation
  static bool get shouldUseCustomViewport {
    if (!needsCustomKeyboardHandling) return false;

    final manufacturer = _androidInfo?.manufacturer.toLowerCase() ?? '';

    // Samsung devices with One UI often need custom viewport handling
    if (manufacturer.contains('samsung')) {
      return true;
    }

    return false;
  }
}
