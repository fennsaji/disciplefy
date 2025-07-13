import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'bottom_nav.dart' as bottom_nav;

/// Main App Shell with Bottom Navigation
/// 
/// Features:
/// - Persistent bottom navigation using IndexedStack
/// - Bottom navigation with Disciplefy branding
/// - Android back button handling
/// - No animations on bottom bar when switching tabs
/// - Memory-efficient screen management
/// - Accessibility support
class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  
  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        body: widget.navigationShell,
        bottomNavigationBar: bottom_nav.DisciplefyBottomNav(
          currentIndex: currentIndex,
          tabs: bottom_nav.DisciplefyBottomNav.defaultTabs,
          onTap: (index) {
            widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
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
  ) => child;

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