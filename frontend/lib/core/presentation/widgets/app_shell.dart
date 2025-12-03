import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/app_animations.dart';
import 'bottom_nav.dart' as bottom_nav;

/// Main App Shell with Bottom Navigation
///
/// Features:
/// - Persistent bottom navigation using IndexedStack
/// - Bottom navigation with Disciplefy branding
/// - Android back button handling
/// - Smooth fade animation when switching tabs
/// - Memory-efficient screen management
/// - Accessibility support
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  int _previousIndex = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    // Quick cross-fade for snappy tab transitions
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _setupAnimations();
    _animController.value = 1.0; // Start at end position (visible)
  }

  void _setupAnimations() {
    // Fade through: cross-fade animation (Material Design recommended)
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    ));

    // Subtle scale: 92% → 100% for incoming content (Material Motion)
    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTabChange(int index) {
    if (index == widget.navigationShell.currentIndex || _isAnimating) return;

    _isAnimating = true;

    // Fade through: fade out current content
    _animController.reverse().then((_) {
      // Switch to new tab
      widget.navigationShell.goBranch(index);

      // Fade in new content with scale
      _animController.forward().then((_) {
        _isAnimating = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    // Detect tab change from external navigation (e.g., back button)
    if (currentIndex != _previousIndex && !_isAnimating) {
      _previousIndex = currentIndex;

      // Quick fade in when tab changes externally
      _animController.value = 0.0;
      _animController.forward();
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        // Material Design: Cross-fade with subtle scale (no lateral motion)
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: widget.navigationShell,
          ),
        ),
        bottomNavigationBar: bottom_nav.DisciplefyBottomNav(
          currentIndex: currentIndex,
          tabs: bottom_nav.DisciplefyBottomNav.defaultTabs,
          onTap: _onTabChange,
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    if (widget.navigationShell.currentIndex > 0) {
      // Go back to home tab if not already there
      widget.navigationShell.goBranch(0);
    } else {
      // Exit the app if already on home tab
      SystemNavigator.pop();
    }
  }
}

/// Custom page transition for smooth navigation
class SlidePageRoute<T> extends PageRoute<T> {
  final Widget child;
  final AxisDirection direction;

  SlidePageRoute({
    required this.child,
    this.direction = AxisDirection.left,
    super.settings,
  });

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    Offset begin;
    const Offset end = Offset.zero;

    switch (direction) {
      case AxisDirection.up:
        begin = const Offset(0.0, 1.0);
        break;
      case AxisDirection.down:
        begin = const Offset(0.0, -1.0);
        break;
      case AxisDirection.right:
        begin = const Offset(-1.0, 0.0);
        break;
      case AxisDirection.left:
      default:
        begin = const Offset(1.0, 0.0);
        break;
    }

    final tween = Tween(begin: begin, end: end);
    final offsetAnimation = animation.drive(tween);

    return SlideTransition(
      position: offsetAnimation,
      child: child,
    );
  }

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
}
