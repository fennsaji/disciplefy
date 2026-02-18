import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/device_keyboard_handler.dart';
import '../utils/keyboard_animation_sync.dart';
import '../utils/custom_viewport_handler.dart';
import '../utils/keyboard_performance_monitor.dart';
import '../utils/logger.dart';

/// Enhanced Scaffold with device-specific keyboard handling for problematic Android devices.
///
/// This widget automatically detects devices that need custom keyboard behavior
/// (Samsung, Xiaomi, OnePlus, etc.) and applies appropriate fixes to prevent
/// keyboard shadow issues and improve text input UX.
///
/// Usage:
/// ```dart
/// KeyboardAwareScaffold(
///   child: YourContentWidget(),
/// )
/// ```
class KeyboardAwareScaffold extends StatefulWidget {
  final Widget child;
  final bool? resizeToAvoidBottomInset;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final bool enableCustomKeyboardHandling;

  const KeyboardAwareScaffold({
    super.key,
    required this.child,
    this.resizeToAvoidBottomInset,
    this.backgroundColor,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.enableCustomKeyboardHandling = true,
  });

  @override
  State<KeyboardAwareScaffold> createState() => _KeyboardAwareScaffoldState();
}

class _KeyboardAwareScaffoldState extends State<KeyboardAwareScaffold>
    with WidgetsBindingObserver {
  double _keyboardHeight = 0;
  bool _isKeyboardVisible = false;
  bool _useCustomHandling = false;

  @override
  void initState() {
    super.initState();
    _setupKeyboardHandling();
    WidgetsBinding.instance.addObserver(this);

    // Phase 3: Initialize advanced keyboard handling
    if (_useCustomHandling) {
      KeyboardAnimationSync.instance.initialize();
      CustomViewportHandler.instance.initialize();
      KeyboardPerformanceMonitor.instance.startMonitoring();
    }
  }

  @override
  void dispose() {
    if (_useCustomHandling) {
      KeyboardPerformanceMonitor.instance.stopMonitoring();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupKeyboardHandling() {
    _useCustomHandling = widget.enableCustomKeyboardHandling &&
        DeviceKeyboardHandler.needsCustomKeyboardHandling;

    if (kDebugMode && _useCustomHandling) {
      Logger.debug(
          '🔧 [KEYBOARD AWARE SCAFFOLD] Custom handling enabled for: ${DeviceKeyboardHandler.deviceManufacturer}');
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    final newKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final newIsKeyboardVisible = newKeyboardHeight > 0;

    if (_keyboardHeight != newKeyboardHeight ||
        _isKeyboardVisible != newIsKeyboardVisible) {
      setState(() {
        _keyboardHeight = newKeyboardHeight;
        _isKeyboardVisible = newIsKeyboardVisible;
      });

      // Phase 3: Advanced keyboard handling
      if (_useCustomHandling) {
        KeyboardAnimationSync.instance
            .handleKeyboardChange(context, newKeyboardHeight);
        KeyboardPerformanceMonitor.instance
            .recordKeyboardChange(newKeyboardHeight);
      }

      Logger.debug(
          '🔧 [KEYBOARD AWARE SCAFFOLD] Keyboard height: $_keyboardHeight, visible: $_isKeyboardVisible');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_useCustomHandling) {
      // Use standard Scaffold for devices that don't need custom handling
      return Scaffold(
        backgroundColor: widget.backgroundColor,
        appBar: widget.appBar,
        body: widget.child,
        floatingActionButton: widget.floatingActionButton,
        floatingActionButtonLocation: widget.floatingActionButtonLocation,
        drawer: widget.drawer,
        endDrawer: widget.endDrawer,
        bottomNavigationBar: widget.bottomNavigationBar,
        bottomSheet: widget.bottomSheet,
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset ?? true,
      );
    }

    // Custom handling for problematic devices
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: widget.appBar,
      body: _buildCustomKeyboardHandling(),
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      drawer: widget.drawer,
      endDrawer: widget.endDrawer,
      bottomNavigationBar: widget.bottomNavigationBar,
      bottomSheet: widget.bottomSheet,
      resizeToAvoidBottomInset:
          false, // Disable default handling for custom implementation
    );
  }

  Widget _buildCustomKeyboardHandling() {
    return KeyboardAnimationBuilder(
      builder: (context, animationState) {
        final keyboardPadding = _isKeyboardVisible
            ? DeviceKeyboardHandler.getKeyboardPaddingAdjustment()
            : 0.0;

        final animationDuration =
            DeviceKeyboardHandler.getKeyboardAnimationDuration();

        // Adjust animation based on keyboard state
        final shouldAnimate = animationState != KeyboardAnimationState.stable;

        Widget child = _useCustomViewport()
            ? _buildCustomViewportHandling()
            : widget.child;

        // Add performance monitoring overlay in debug mode
        if (kDebugMode) {
          child = Stack(
            children: [
              child,
              const KeyboardPerformanceOverlay(),
            ],
          );
        }

        return AnimatedContainer(
          duration: shouldAnimate ? animationDuration : Duration.zero,
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(bottom: keyboardPadding),
          child: child,
        );
      },
    );
  }

  bool _useCustomViewport() {
    return (DeviceKeyboardHandler.shouldUseCustomViewport ||
            CustomViewportHandler.instance.needsCustomViewport) &&
        _isKeyboardVisible;
  }

  Widget _buildCustomViewportHandling() {
    // Phase 3: Use advanced custom viewport handler
    return CustomViewportProvider(
      child: widget.child,
    );
  }

  EdgeInsets _calculateCustomViewInsets(EdgeInsets original) {
    if (!_isKeyboardVisible) return original;

    final manufacturer = DeviceKeyboardHandler.deviceManufacturer.toLowerCase();

    // Samsung devices often have incorrect viewport calculations
    if (manufacturer.contains('samsung')) {
      return EdgeInsets.only(
        left: original.left,
        top: original.top,
        right: original.right,
        bottom: original.bottom > 0 ? original.bottom + 40 : 0,
      );
    }

    // Default custom calculation
    return EdgeInsets.only(
      left: original.left,
      top: original.top,
      right: original.right,
      bottom: original.bottom > 0 ? original.bottom + 20 : 0,
    );
  }
}

/// Mixin for widgets that need keyboard state awareness
mixin KeyboardAwareMixin on WidgetsBindingObserver {
  bool _keyboardVisible = false;

  bool get isKeyboardVisible => _keyboardVisible;

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    final newKeyboardVisible = WidgetsBinding
            .instance.platformDispatcher.views.first.viewInsets.bottom >
        0;

    if (_keyboardVisible != newKeyboardVisible) {
      _keyboardVisible = newKeyboardVisible;
      onKeyboardVisibilityChanged(newKeyboardVisible);
    }
  }

  /// Override this method to handle keyboard visibility changes
  void onKeyboardVisibilityChanged(bool isVisible) {}
}

/// Utility widget for keyboard state detection
class KeyboardVisibilityBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool isKeyboardVisible) builder;

  const KeyboardVisibilityBuilder({
    super.key,
    required this.builder,
  });

  @override
  State<KeyboardVisibilityBuilder> createState() =>
      _KeyboardVisibilityBuilderState();
}

class _KeyboardVisibilityBuilderState extends State<KeyboardVisibilityBuilder>
    with WidgetsBindingObserver {
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isVisible = keyboardHeight > 0;

    if (_isKeyboardVisible != isVisible) {
      setState(() {
        _isKeyboardVisible = isVisible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _isKeyboardVisible);
  }
}
