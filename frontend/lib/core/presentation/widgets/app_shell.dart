import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/navigation_cubit.dart';
import 'bottom_nav.dart' as bottom_nav;
import '../../../features/home/presentation/pages/home_screen.dart';
import '../../../features/study_generation/presentation/pages/generate_study_screen.dart';
import '../../../features/saved_guides/presentation/pages/saved_screen_api.dart';
import '../../../features/settings/presentation/pages/settings_screen.dart';

/// Main App Shell with Bottom Navigation
/// 
/// Features:
/// - Conditional rendering for lazy loading of screens and API optimization
/// - Bottom navigation with Disciplefy branding
/// - Android back button handling
/// - Smooth transitions and animations
/// - Memory-efficient screen management
/// - Accessibility support
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final NavigationCubit _navigationCubit;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _navigationCubit = NavigationCubit();
    // Initialize with default index, will be updated in didChangeDependencies
    _navigationCubit.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only initialize once when dependencies are available
    if (!_isInitialized) {
      _isInitialized = true;
      
      // Now it's safe to access GoRouterState since the widget tree is built
      if (mounted) {
        final currentRoute = GoRouterState.of(context).matchedLocation;
        final initialIndex = _navigationCubit.getTabIndexForRoute(currentRoute) ?? 0;
        
        // Only update if different from current
        if (initialIndex != _navigationCubit.selectedIndex) {
          _navigationCubit.initialize(initialIndex: initialIndex);
        }
      }
    }
  }

  @override
  void dispose() {
    _navigationCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
      value: _navigationCubit,
      child: const _AppShellContent(),
    );
}

class _AppShellContent extends StatelessWidget {
  const _AppShellContent();

  @override
  Widget build(BuildContext context) => BlocBuilder<NavigationCubit, NavigationState>(
      builder: (context, state) {
        int selectedIndex = 0;
        
        if (state is NavigationInitial) {
          selectedIndex = state.selectedIndex;
        } else if (state is NavigationTabChanged) {
          selectedIndex = state.selectedIndex;
        }

        return PopScope(
          canPop: false, // Handle back navigation manually
          onPopInvoked: (didPop) {
            if (!didPop) {
              _handleBackNavigation(context);
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF1E1E1E), // Match bottom nav background
            body: _buildCurrentScreen(selectedIndex),
            bottomNavigationBar: bottom_nav.DisciplefyBottomNav(
              currentIndex: selectedIndex,
              tabs: bottom_nav.DisciplefyBottomNav.defaultTabs,
              onTap: (index) {
                // Navigate to the corresponding route
                final navigationCubit = context.read<NavigationCubit>();
                final route = navigationCubit.getRouteForTabIndex(index);
                if (route != null) {
                  context.go(route);
                  navigationCubit.selectTab(index);
                }
              },
            ),
          ),
        );
      },
    );

  Widget _buildCurrentScreen(int selectedIndex) {
    switch (selectedIndex) {
      case 0:
        return const _HomeScreenWrapper();
      case 1:
        return const _GenerateStudyScreenWrapper();
      case 2:
        return const _SavedScreenWrapper();
      case 3:
        return const _SettingsScreenWrapper();
      default:
        return const _HomeScreenWrapper();
    }
  }

  void _handleBackNavigation(BuildContext context) {
    final navigationCubit = context.read<NavigationCubit>();
    
    // Try to handle back navigation within the app
    final handled = navigationCubit.handleBackNavigation();
    
    if (!handled) {
      // If not handled by navigation, exit the app
      SystemNavigator.pop();
    }
  }

}

/// Wrapper for Home Screen without app bar
class _HomeScreenWrapper extends StatelessWidget {
  const _HomeScreenWrapper();

  @override
  Widget build(BuildContext context) {
    // Note: HomeScreen already handles its own layout
    // We may need to modify it to remove the bottom navigation
    return const HomeScreen();
  }
}

/// Wrapper for Study Generation Screen without app bar
class _GenerateStudyScreenWrapper extends StatelessWidget {
  const _GenerateStudyScreenWrapper();

  @override
  Widget build(BuildContext context) => const GenerateStudyScreen();
}

/// Wrapper for Saved Guides Screen without app bar
class _SavedScreenWrapper extends StatelessWidget {
  const _SavedScreenWrapper();

  @override
  Widget build(BuildContext context) {
    // Using API-integrated version for saved guides
    return const SavedScreenApi();
  }
}

/// Wrapper for Settings Screen without app bar  
class _SettingsScreenWrapper extends StatelessWidget {
  const _SettingsScreenWrapper();

  @override
  Widget build(BuildContext context) {
    // Note: We'll need to create a version without app bar
    return const SettingsScreen();
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