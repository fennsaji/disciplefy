import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'device_keyboard_handler.dart';

/// Advanced keyboard animation synchronization for eliminating timing-related
/// keyboard shadow issues on problematic Android devices.
///
/// This utility ensures keyboard appearance/disappearance animations are
/// perfectly synchronized with Flutter's rebuild cycle to prevent visual
/// artifacts and shadow issues.
class KeyboardAnimationSync {
  static KeyboardAnimationSync? _instance;
  static KeyboardAnimationSync get instance =>
      _instance ??= KeyboardAnimationSync._();

  KeyboardAnimationSync._();

  Timer? _debounceTimer;
  StreamController<KeyboardAnimationState>? _stateController;
  KeyboardAnimationState _currentState = KeyboardAnimationState.stable;
  double _lastKeyboardHeight = 0;
  bool _isTransitioning = false;

  /// Stream of keyboard animation states for widgets to listen to
  Stream<KeyboardAnimationState> get stateStream =>
      _stateController?.stream ?? const Stream.empty();

  /// Initialize the animation synchronizer
  void initialize() {
    _stateController ??= StreamController<KeyboardAnimationState>.broadcast();

    if (kDebugMode) {
      print('🎬 [KEYBOARD ANIMATION SYNC] Initialized');
    }
  }

  /// Clean up resources
  void dispose() {
    _debounceTimer?.cancel();
    _stateController?.close();
    _stateController = null;

    if (kDebugMode) {
      print('🎬 [KEYBOARD ANIMATION SYNC] Disposed');
    }
  }

  /// Handle keyboard metrics change with advanced synchronization
  void handleKeyboardChange(BuildContext context, double newKeyboardHeight) {
    final wasKeyboardVisible = _lastKeyboardHeight > 0;
    final isKeyboardVisible = newKeyboardHeight > 0;

    // Detect state transitions
    if (!wasKeyboardVisible && isKeyboardVisible) {
      _handleKeyboardAppearing(context, newKeyboardHeight);
    } else if (wasKeyboardVisible && !isKeyboardVisible) {
      _handleKeyboardDisappearing(context);
    } else if (wasKeyboardVisible &&
        isKeyboardVisible &&
        (_lastKeyboardHeight - newKeyboardHeight).abs() > 10) {
      _handleKeyboardResizing(context, newKeyboardHeight);
    }

    _lastKeyboardHeight = newKeyboardHeight;
  }

  void _handleKeyboardAppearing(BuildContext context, double keyboardHeight) {
    if (kDebugMode) {
      print(
          '🎬 [KEYBOARD ANIMATION SYNC] Keyboard appearing: ${keyboardHeight}px');
    }

    _updateState(KeyboardAnimationState.appearing);
    _isTransitioning = true;

    // Use device-specific timing for optimal synchronization
    final duration = DeviceKeyboardHandler.getKeyboardAnimationDuration();

    // Cancel any existing debounce
    _debounceTimer?.cancel();

    // Wait for keyboard animation to complete before marking as stable
    _debounceTimer = Timer(duration + const Duration(milliseconds: 50), () {
      _handleAnimationComplete(KeyboardAnimationState.visible);
    });

    // Force a frame callback to ensure UI updates are synchronized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerFrameSync();
    });
  }

  void _handleKeyboardDisappearing(BuildContext context) {
    if (kDebugMode) {
      print('🎬 [KEYBOARD ANIMATION SYNC] Keyboard disappearing');
    }

    _updateState(KeyboardAnimationState.disappearing);
    _isTransitioning = true;

    final duration = DeviceKeyboardHandler.getKeyboardAnimationDuration();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration + const Duration(milliseconds: 100), () {
      _handleAnimationComplete(KeyboardAnimationState.hidden);
    });

    // Critical: Force frame synchronization for disappearing animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerFrameSync();
    });
  }

  void _handleKeyboardResizing(BuildContext context, double newHeight) {
    if (kDebugMode) {
      print('🎬 [KEYBOARD ANIMATION SYNC] Keyboard resizing: ${newHeight}px');
    }

    _updateState(KeyboardAnimationState.resizing);

    final duration = DeviceKeyboardHandler.getKeyboardAnimationDuration();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, () {
      _handleAnimationComplete(KeyboardAnimationState.visible);
    });
  }

  void _handleAnimationComplete(KeyboardAnimationState finalState) {
    if (kDebugMode) {
      print('🎬 [KEYBOARD ANIMATION SYNC] Animation complete: $finalState');
    }

    _updateState(finalState);
    _isTransitioning = false;
  }

  void _updateState(KeyboardAnimationState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController?.add(newState);
    }
  }

  void _triggerFrameSync() {
    // Force frame synchronization for problematic devices
    if (DeviceKeyboardHandler.needsCustomKeyboardHandling) {
      SchedulerBinding.instance.scheduleFrame();
    }
  }

  /// Get current keyboard animation state
  KeyboardAnimationState get currentState => _currentState;

  /// Check if keyboard is currently transitioning
  bool get isTransitioning => _isTransitioning;

  /// Get last recorded keyboard height
  double get lastKeyboardHeight => _lastKeyboardHeight;
}

/// Enumeration of keyboard animation states
enum KeyboardAnimationState {
  hidden, // Keyboard is completely hidden
  appearing, // Keyboard is animating in
  visible, // Keyboard is fully visible and stable
  resizing, // Keyboard is changing size (e.g., suggestion bar)
  disappearing, // Keyboard is animating out
  stable, // Initial state - unknown keyboard status
}

/// Widget that rebuilds based on keyboard animation state
class KeyboardAnimationBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, KeyboardAnimationState state)
      builder;
  final KeyboardAnimationState? initialState;

  const KeyboardAnimationBuilder({
    super.key,
    required this.builder,
    this.initialState,
  });

  @override
  State<KeyboardAnimationBuilder> createState() =>
      _KeyboardAnimationBuilderState();
}

class _KeyboardAnimationBuilderState extends State<KeyboardAnimationBuilder>
    with WidgetsBindingObserver {
  late StreamSubscription<KeyboardAnimationState> _stateSubscription;
  KeyboardAnimationState _currentState = KeyboardAnimationState.stable;

  @override
  void initState() {
    super.initState();

    _currentState =
        widget.initialState ?? KeyboardAnimationSync.instance.currentState;

    // Listen to keyboard animation state changes
    _stateSubscription =
        KeyboardAnimationSync.instance.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _stateSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    // Notify animation sync of metrics change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        KeyboardAnimationSync.instance
            .handleKeyboardChange(context, keyboardHeight);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentState);
  }
}

/// Mixin for widgets that need keyboard animation state awareness
mixin KeyboardAnimationMixin<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  StreamSubscription<KeyboardAnimationState>? _animationSubscription;
  KeyboardAnimationState _animationState = KeyboardAnimationState.stable;

  KeyboardAnimationState get keyboardAnimationState => _animationState;
  bool get isKeyboardTransitioning =>
      KeyboardAnimationSync.instance.isTransitioning;

  @override
  void initState() {
    super.initState();

    // Listen to animation state changes
    _animationSubscription =
        KeyboardAnimationSync.instance.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _animationState = state;
        });
        onKeyboardAnimationStateChanged(state);
      }
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _animationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        KeyboardAnimationSync.instance
            .handleKeyboardChange(context, keyboardHeight);
      }
    });
  }

  /// Override this method to handle keyboard animation state changes
  void onKeyboardAnimationStateChanged(KeyboardAnimationState state) {}
}

/// Utility for creating smooth keyboard-aware animations
class KeyboardAwareAnimatedContainer extends StatelessWidget {
  final Widget child;
  final Duration? duration;
  final Curve curve;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final Decoration? decoration;
  final double? height;
  final double? width;

  const KeyboardAwareAnimatedContainer({
    super.key,
    required this.child,
    this.duration,
    this.curve = Curves.easeInOut,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardAnimationBuilder(
      builder: (context, state) {
        final animationDuration =
            duration ?? DeviceKeyboardHandler.getKeyboardAnimationDuration();

        // Adjust properties based on keyboard animation state
        EdgeInsets? adjustedPadding = padding;
        final EdgeInsets? adjustedMargin = margin;

        if (state == KeyboardAnimationState.appearing ||
            state == KeyboardAnimationState.visible) {
          final keyboardPadding =
              DeviceKeyboardHandler.getKeyboardPaddingAdjustment();
          adjustedPadding = (padding ?? EdgeInsets.zero).copyWith(
            bottom: (padding?.bottom ?? 0) + keyboardPadding,
          );
        }

        // Ensure only one of color or decoration is provided to AnimatedContainer
        Color? containerColor;
        Decoration? containerDecoration;

        if (decoration != null) {
          // If decoration is provided, use it and set color to null
          containerDecoration = decoration;
          containerColor = null;
        } else if (color != null) {
          // If only color is provided, create BoxDecoration with the color
          containerDecoration = BoxDecoration(color: color);
          containerColor = null;
        } else {
          // Neither color nor decoration provided
          containerColor = null;
          containerDecoration = null;
        }

        return AnimatedContainer(
          duration: animationDuration,
          curve: curve,
          padding: adjustedPadding,
          margin: adjustedMargin,
          color: containerColor,
          decoration: containerDecoration,
          height: height,
          width: width,
          child: child,
        );
      },
    );
  }
}
