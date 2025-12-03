import 'package:flutter/material.dart';

/// App-wide animation constants and utilities
///
/// Provides consistent animation durations, curves, and reusable
/// animation builders for the Disciplefy app.
///
/// Style: Noticeable but smooth (250-350ms durations)
class AppAnimations {
  AppAnimations._();

  // ============================================================
  // DURATIONS
  // ============================================================

  /// Fast actions: button taps, micro-interactions (250ms)
  static const Duration fast = Duration(milliseconds: 250);

  /// Standard animations: fades, slides, most transitions (300ms)
  static const Duration medium = Duration(milliseconds: 300);

  /// Complex transitions: page transitions, large reveals (350ms)
  static const Duration slow = Duration(milliseconds: 350);

  /// Stagger delay between list items (50ms)
  static const Duration staggerDelay = Duration(milliseconds: 50);

  // ============================================================
  // CURVES
  // ============================================================

  /// Default curve for most animations
  static const Curve defaultCurve = Curves.easeOutCubic;

  /// Curve with slight overshoot for emphasis
  static const Curve bounceCurve = Curves.easeOutBack;

  /// Curve for entering elements (decelerate)
  static const Curve enterCurve = Curves.easeOut;

  /// Curve for exiting elements (accelerate)
  static const Curve exitCurve = Curves.easeIn;

  /// Curve for spring-like bounce
  static const Curve springCurve = Curves.elasticOut;

  // ============================================================
  // OFFSETS
  // ============================================================

  /// Standard slide distance for content reveal
  static const double slideDistance = 24.0;

  /// Small slide distance for subtle animations
  static const double smallSlideDistance = 12.0;

  /// Large slide distance for page transitions
  static const double largeSlideDistance = 40.0;

  // ============================================================
  // SCALE VALUES
  // ============================================================

  /// Scale factor for button press feedback
  static const double pressScale = 0.95;

  /// Scale factor for hover/focus states
  static const double hoverScale = 1.02;

  /// Initial scale for pop-in animations
  static const double popInStartScale = 0.8;

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Calculate stagger delay for a specific index in a list
  static Duration getStaggerDelay(int index, {int maxStagger = 10}) {
    // Cap the stagger to prevent long delays for large lists
    final effectiveIndex = index.clamp(0, maxStagger);
    return Duration(milliseconds: staggerDelay.inMilliseconds * effectiveIndex);
  }

  /// Check if animations should be reduced based on system settings
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get appropriate duration considering reduced motion settings
  static Duration getDuration(BuildContext context, Duration duration) {
    if (shouldReduceMotion(context)) {
      return Duration.zero;
    }
    return duration;
  }
}

/// Custom page transition that combines fade and slide
class FadeSlideTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final Offset beginOffset;

  const FadeSlideTransition({
    super.key,
    required this.animation,
    required this.child,
    this.beginOffset = const Offset(0.0, 0.1),
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: AppAnimations.defaultCurve,
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: AppAnimations.defaultCurve,
        )),
        child: child,
      ),
    );
  }
}

/// Animated scale wrapper for press feedback
class ScaleTapWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;
  final Duration duration;
  final bool enabled;

  const ScaleTapWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.pressScale = AppAnimations.pressScale,
    this.duration = AppAnimations.fast,
    this.enabled = true,
  });

  @override
  State<ScaleTapWrapper> createState() => _ScaleTapWrapperState();
}

class _ScaleTapWrapperState extends State<ScaleTapWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.duration.inMilliseconds ~/ 2),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressScale,
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
    if (widget.enabled) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    if (widget.enabled) {
      widget.onTap?.call();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
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

/// Fade-in widget that animates when first built
class FadeInWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Offset? slideOffset;

  const FadeInWidget({
    super.key,
    required this.child,
    this.duration = AppAnimations.medium,
    this.delay = Duration.zero,
    this.curve = AppAnimations.defaultCurve,
    this.slideOffset,
  });

  @override
  State<FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<FadeInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.slideOffset ?? Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect reduced motion settings
    if (AppAnimations.shouldReduceMotion(context)) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: widget.slideOffset != null
          ? SlideTransition(
              position: _slideAnimation,
              child: widget.child,
            )
          : widget.child,
    );
  }
}

/// Builder for staggered list animations
class StaggeredListBuilder extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Duration itemDuration;
  final Duration staggerDelay;
  final Offset? slideOffset;
  final ScrollPhysics? physics;
  final EdgeInsets? padding;
  final bool shrinkWrap;

  const StaggeredListBuilder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemDuration = AppAnimations.medium,
    this.staggerDelay = AppAnimations.staggerDelay,
    this.slideOffset,
    this.physics,
    this.padding,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return FadeInWidget(
          duration: itemDuration,
          delay: AppAnimations.getStaggerDelay(index),
          slideOffset: slideOffset ?? const Offset(0, 0.1),
          child: itemBuilder(context, index),
        );
      },
    );
  }
}
