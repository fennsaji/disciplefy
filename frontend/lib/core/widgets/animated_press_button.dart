import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../animations/app_animations.dart';

/// Animated Press Button - Adds scale animation and haptic feedback to any button
///
/// This widget wraps any child widget (typically a button) and adds:
/// - Scale down animation on press (0.95 scale)
/// - Haptic feedback on tap
/// - Smooth animation transitions
///
/// Usage:
/// ```dart
/// AnimatedPressButton(
///   onPressed: () => doSomething(),
///   child: ElevatedButton(...),
/// )
/// ```
class AnimatedPressButton extends StatefulWidget {
  /// The child widget to animate (typically a button)
  final Widget child;

  /// Callback when the button is pressed
  final VoidCallback? onPressed;

  /// Scale factor when pressed (default: 0.95)
  final double pressedScale;

  /// Whether to provide haptic feedback on press
  final bool enableHaptics;

  /// Whether the button is disabled
  final bool isDisabled;

  const AnimatedPressButton({
    super.key,
    required this.child,
    this.onPressed,
    this.pressedScale = 0.95,
    this.enableHaptics = true,
    this.isDisabled = false,
  });

  @override
  State<AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.defaultCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isDisabled && widget.onPressed != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    if (!widget.isDisabled && widget.onPressed != null) {
      if (widget.enableHaptics) {
        HapticFeedback.lightImpact();
      }
      widget.onPressed!();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Check for reduced motion preference
    if (AppAnimations.shouldReduceMotion(context)) {
      return GestureDetector(
        onTap: widget.isDisabled ? null : widget.onPressed,
        child: widget.child,
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Animated Icon Button - A simple animated icon button with scale effect
///
/// Provides a consistent animated icon button throughout the app.
class AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final String? tooltip;
  final bool isDisabled;

  const AnimatedIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 44,
    this.iconSize = 24,
    this.tooltip,
    this.isDisabled = false,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.defaultCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isDisabled && widget.onPressed != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    if (!widget.isDisabled && widget.onPressed != null) {
      HapticFeedback.lightImpact();
      widget.onPressed!();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = widget.isDisabled
        ? theme.colorScheme.onSurface.withOpacity(0.38)
        : widget.color ?? theme.colorScheme.primary;
    final bgColor = widget.backgroundColor ?? iconColor.withOpacity(0.1);

    // Check for reduced motion preference
    final reduceMotion = AppAnimations.shouldReduceMotion(context);

    // Static button content (used for both animated and non-animated paths)
    final buttonContent = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.size / 4),
      ),
      child: Center(
        child: Icon(
          widget.icon,
          color: iconColor,
          size: widget.iconSize,
        ),
      ),
    );

    Widget button;
    if (reduceMotion) {
      // Reduced motion: static button without scale animation
      button = GestureDetector(
        onTap: widget.isDisabled
            ? null
            : () {
                if (widget.onPressed != null) {
                  HapticFeedback.lightImpact();
                  widget.onPressed!();
                }
              },
        child: buttonContent,
      );
    } else {
      // Normal: animated button with scale effect
      button = GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: buttonContent,
        ),
      );
    }

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return Semantics(
      button: true,
      enabled: !widget.isDisabled,
      label: widget.tooltip,
      child: button,
    );
  }
}

/// Gradient Button with press animation
///
/// A premium-looking button with gradient background and scale animation.
class AnimatedGradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final double height;
  final double borderRadius;
  final TextStyle? textStyle;
  final Widget? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AnimatedGradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.gradient,
    this.height = 56,
    this.borderRadius = 12,
    this.textStyle,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  State<AnimatedGradientButton> createState() => _AnimatedGradientButtonState();
}

class _AnimatedGradientButtonState extends State<AnimatedGradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.defaultCurve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.onPressed != null && !widget.isLoading) {
      HapticFeedback.mediumImpact();
      widget.onPressed!();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultGradient = LinearGradient(
      colors: [
        theme.colorScheme.primary,
        theme.colorScheme.primary.withOpacity(0.8),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final isEnabled = widget.onPressed != null && !widget.isLoading;

    // Check for reduced motion preference
    final reduceMotion = AppAnimations.shouldReduceMotion(context);

    // Static button content
    final buttonContent = AnimatedOpacity(
      duration: reduceMotion ? Duration.zero : AppAnimations.fast,
      opacity: isEnabled ? 1.0 : 0.6,
      child: Container(
        width: widget.isFullWidth ? double.infinity : null,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: widget.gradient ?? defaultGradient,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          widget.icon!,
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.text,
                          style: widget.textStyle ??
                              TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    if (reduceMotion) {
      // Reduced motion: static button without scale animation
      return GestureDetector(
        onTap: isEnabled
            ? () {
                HapticFeedback.mediumImpact();
                widget.onPressed!();
              }
            : null,
        child: buttonContent,
      );
    }

    // Normal: animated button with scale effect
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: buttonContent,
      ),
    );
  }
}
