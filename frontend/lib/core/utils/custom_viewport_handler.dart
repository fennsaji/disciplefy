import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'device_keyboard_handler.dart';

/// Custom viewport handler for devices with problematic MediaQuery calculations.
///
/// This handles edge cases where the default Flutter viewport calculation
/// doesn't properly account for keyboard appearance, especially on devices
/// with custom keyboards, notches, or non-standard screen configurations.
class CustomViewportHandler {
  static CustomViewportHandler? _instance;
  static CustomViewportHandler get instance =>
      _instance ??= CustomViewportHandler._();

  CustomViewportHandler._();

  Map<String, ViewportConfiguration> _deviceConfigurations = {};
  ViewportConfiguration? _currentConfiguration;

  /// Initialize viewport handler with device-specific configurations
  void initialize() {
    _setupDeviceConfigurations();
    _currentConfiguration = _getConfigurationForCurrentDevice();

    if (kDebugMode) {
      print(
          '📐 [VIEWPORT HANDLER] Initialized with: ${_currentConfiguration?.name ?? "default"}');
    }
  }

  void _setupDeviceConfigurations() {
    _deviceConfigurations = {
      // Samsung Galaxy devices with One UI
      'samsung': ViewportConfiguration(
        name: 'Samsung One UI',
        keyboardHeightAdjustment: 40.0,
        bottomInsetMultiplier: 1.2,
        useCustomCalculation: true,
        statusBarHeightAdjustment: 0.0,
        navigationBarHeightAdjustment: 10.0,
        minimumKeyboardHeight: 250.0,
        keyboardDetectionThreshold: 100.0,
      ),

      // Xiaomi devices with MIUI
      'xiaomi': ViewportConfiguration(
        name: 'Xiaomi MIUI',
        keyboardHeightAdjustment: 25.0,
        bottomInsetMultiplier: 1.1,
        useCustomCalculation: true,
        statusBarHeightAdjustment: 0.0,
        navigationBarHeightAdjustment: 5.0,
        minimumKeyboardHeight: 200.0,
        keyboardDetectionThreshold: 80.0,
      ),

      // OnePlus devices with OxygenOS
      'oneplus': ViewportConfiguration(
        name: 'OnePlus OxygenOS',
        keyboardHeightAdjustment: 20.0,
        bottomInsetMultiplier: 1.05,
        useCustomCalculation: false,
        statusBarHeightAdjustment: 0.0,
        navigationBarHeightAdjustment: 0.0,
        minimumKeyboardHeight: 200.0,
        keyboardDetectionThreshold: 70.0,
      ),

      // Realme/OPPO devices
      'realme': ViewportConfiguration(
        name: 'Realme ColorOS',
        keyboardHeightAdjustment: 20.0,
        bottomInsetMultiplier: 1.1,
        useCustomCalculation: true,
        statusBarHeightAdjustment: 0.0,
        navigationBarHeightAdjustment: 8.0,
        minimumKeyboardHeight: 200.0,
        keyboardDetectionThreshold: 75.0,
      ),
    };
  }

  ViewportConfiguration? _getConfigurationForCurrentDevice() {
    if (!DeviceKeyboardHandler.needsCustomKeyboardHandling) {
      return null;
    }

    final manufacturer = DeviceKeyboardHandler.deviceManufacturer.toLowerCase();

    if (manufacturer.contains('samsung')) {
      return _deviceConfigurations['samsung'];
    } else if (manufacturer.contains('xiaomi') ||
        manufacturer.contains('redmi')) {
      return _deviceConfigurations['xiaomi'];
    } else if (manufacturer.contains('oneplus')) {
      return _deviceConfigurations['oneplus'];
    } else if (manufacturer.contains('realme') ||
        manufacturer.contains('oppo')) {
      return _deviceConfigurations['realme'];
    }

    return null;
  }

  /// Calculate custom MediaQueryData for problematic devices
  MediaQueryData calculateCustomMediaQuery(MediaQueryData originalData) {
    if (_currentConfiguration == null ||
        !_currentConfiguration!.useCustomCalculation) {
      return originalData;
    }

    final config = _currentConfiguration!;
    final originalViewInsets = originalData.viewInsets;

    // Custom keyboard height calculation
    EdgeInsets customViewInsets = originalViewInsets;

    if (originalViewInsets.bottom > config.keyboardDetectionThreshold) {
      // Keyboard is visible - apply custom calculation
      final adjustedKeyboardHeight = _calculateAdjustedKeyboardHeight(
        originalViewInsets.bottom,
        config,
      );

      customViewInsets = EdgeInsets.only(
        left: originalViewInsets.left,
        top: originalViewInsets.top,
        right: originalViewInsets.right,
        bottom: adjustedKeyboardHeight,
      );

      if (kDebugMode) {
        print('📐 [VIEWPORT HANDLER] Original: ${originalViewInsets.bottom}, '
            'Adjusted: $adjustedKeyboardHeight (${config.name})');
      }
    }

    return originalData.copyWith(
      viewInsets: customViewInsets,
      viewPadding:
          _calculateCustomViewPadding(originalData.viewPadding, config),
    );
  }

  double _calculateAdjustedKeyboardHeight(
      double originalHeight, ViewportConfiguration config) {
    // Apply device-specific adjustments
    double adjustedHeight = originalHeight * config.bottomInsetMultiplier;
    adjustedHeight += config.keyboardHeightAdjustment;

    // Ensure minimum keyboard height
    adjustedHeight =
        adjustedHeight.clamp(config.minimumKeyboardHeight, double.infinity);

    // Add navigation bar adjustment if needed
    adjustedHeight += config.navigationBarHeightAdjustment;

    return adjustedHeight;
  }

  EdgeInsets _calculateCustomViewPadding(
      EdgeInsets originalPadding, ViewportConfiguration config) {
    return EdgeInsets.only(
      left: originalPadding.left,
      top: originalPadding.top + config.statusBarHeightAdjustment,
      right: originalPadding.right,
      bottom: originalPadding.bottom + config.navigationBarHeightAdjustment,
    );
  }

  /// Check if current device needs custom viewport handling
  bool get needsCustomViewport =>
      _currentConfiguration?.useCustomCalculation ?? false;

  /// Get current viewport configuration
  ViewportConfiguration? get currentConfiguration => _currentConfiguration;
}

/// Configuration for device-specific viewport calculations
class ViewportConfiguration {
  final String name;
  final double keyboardHeightAdjustment;
  final double bottomInsetMultiplier;
  final bool useCustomCalculation;
  final double statusBarHeightAdjustment;
  final double navigationBarHeightAdjustment;
  final double minimumKeyboardHeight;
  final double keyboardDetectionThreshold;

  const ViewportConfiguration({
    required this.name,
    required this.keyboardHeightAdjustment,
    required this.bottomInsetMultiplier,
    required this.useCustomCalculation,
    required this.statusBarHeightAdjustment,
    required this.navigationBarHeightAdjustment,
    required this.minimumKeyboardHeight,
    required this.keyboardDetectionThreshold,
  });

  @override
  String toString() {
    return 'ViewportConfiguration($name: adjustment=$keyboardHeightAdjustment, '
        'multiplier=$bottomInsetMultiplier, custom=$useCustomCalculation)';
  }
}

/// Widget that provides custom MediaQuery for problematic devices
class CustomViewportProvider extends StatelessWidget {
  final Widget child;
  final bool forceCustomViewport;

  const CustomViewportProvider({
    super.key,
    required this.child,
    this.forceCustomViewport = false,
  });

  @override
  Widget build(BuildContext context) {
    final originalMediaQuery = MediaQuery.of(context);

    // Use custom viewport only for devices that need it
    if (!forceCustomViewport &&
        !CustomViewportHandler.instance.needsCustomViewport) {
      return child;
    }

    final customMediaQuery = CustomViewportHandler.instance
        .calculateCustomMediaQuery(originalMediaQuery);

    return MediaQuery(
      data: customMediaQuery,
      child: child,
    );
  }
}

/// Utility for debugging viewport calculations
class ViewportDebugger {
  static void logViewportInfo(BuildContext context, {String? tag}) {
    if (!kDebugMode) return;

    final mediaQuery = MediaQuery.of(context);
    final viewInsets = mediaQuery.viewInsets;
    final viewPadding = mediaQuery.viewPadding;
    final devicePixelRatio = mediaQuery.devicePixelRatio;
    final size = mediaQuery.size;

    final tagString = tag != null ? '[$tag] ' : '';

    print(
        '📐 [VIEWPORT DEBUG] ${tagString}Screen: ${size.width}x${size.height}');
    print(
        '📐 [VIEWPORT DEBUG] ${tagString}ViewInsets: ${viewInsets.toString()}');
    print(
        '📐 [VIEWPORT DEBUG] ${tagString}ViewPadding: ${viewPadding.toString()}');
    print(
        '📐 [VIEWPORT DEBUG] ${tagString}DevicePixelRatio: $devicePixelRatio');
    print(
        '📐 [VIEWPORT DEBUG] ${tagString}Keyboard height: ${viewInsets.bottom}');

    // Platform view information
    final platformDispatcher = WidgetsBinding.instance.platformDispatcher;
    if (platformDispatcher.views.isNotEmpty) {
      final view = platformDispatcher.views.first;
      print(
          '📐 [VIEWPORT DEBUG] ${tagString}Platform viewInsets: ${view.viewInsets.toString()}');
      print(
          '📐 [VIEWPORT DEBUG] ${tagString}Platform viewPadding: ${view.viewPadding.toString()}');
    }

    // Custom viewport handler info
    final config = CustomViewportHandler.instance.currentConfiguration;
    if (config != null) {
      print(
          '📐 [VIEWPORT DEBUG] ${tagString}Custom config: ${config.toString()}');
    }
  }

  /// Widget for runtime viewport debugging
  static Widget buildDebugOverlay(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Device: ${DeviceKeyboardHandler.deviceManufacturer}'),
              Text(
                  'Keyboard: ${MediaQuery.of(context).viewInsets.bottom.toStringAsFixed(1)}'),
              Text(
                  'Custom: ${CustomViewportHandler.instance.needsCustomViewport}'),
              if (CustomViewportHandler.instance.currentConfiguration != null)
                Text(
                    'Config: ${CustomViewportHandler.instance.currentConfiguration!.name}'),
            ],
          ),
        ),
      ),
    );
  }
}
