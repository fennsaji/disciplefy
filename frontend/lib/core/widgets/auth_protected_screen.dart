import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/logger.dart';
import '../router/app_routes.dart';
import '../services/auth_aware_navigation_service.dart';

/// A wrapper widget that provides authentication-aware navigation protection
/// for screens that should not be accessible via back navigation after auth.
///
/// This widget integrates PopScope to handle back navigation attempts and
/// provides customizable behavior for different authentication scenarios.
class AuthProtectedScreen extends StatefulWidget {
  /// The child widget to display
  final Widget child;

  /// Whether this screen is accessed post-authentication
  final bool isPostAuthScreen;

  /// Whether to allow back navigation (defaults to dynamic based on auth state)
  final bool? canPop;

  /// Custom handler for back navigation attempts
  final VoidCallback? onBackPressed;

  /// Whether to show exit confirmation on back press
  final bool showExitConfirmation;

  /// Custom exit confirmation message
  final String? exitConfirmationMessage;

  /// Whether to log navigation events for debugging
  final bool enableLogging;

  const AuthProtectedScreen({
    super.key,
    required this.child,
    this.isPostAuthScreen = true,
    this.canPop,
    this.onBackPressed,
    this.showExitConfirmation = false,
    this.exitConfirmationMessage,
    this.enableLogging = true,
  });

  @override
  State<AuthProtectedScreen> createState() => _AuthProtectedScreenState();
}

class _AuthProtectedScreenState extends State<AuthProtectedScreen> {
  bool _isExiting = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _determineCanPop(),
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        _handlePopInvoked(didPop, result);
      },
      child: widget.child,
    );
  }

  /// Determines whether back navigation should be allowed
  bool _determineCanPop() {
    // Use explicit canPop if provided
    if (widget.canPop != null) {
      return widget.canPop!;
    }

    // For post-auth screens, prevent back navigation by default
    if (widget.isPostAuthScreen) {
      return false;
    }

    // Allow back navigation for non-auth-protected screens
    return true;
  }

  /// Handles the pop invocation with custom logic
  void _handlePopInvoked(bool didPop, dynamic result) {
    if (widget.enableLogging) {
      Logger.info(
        'Pop invocation handled',
        tag: 'AUTH_PROTECTION',
        context: {
          'did_pop': didPop,
          'is_post_auth_screen': widget.isPostAuthScreen,
          'can_pop': _determineCanPop(),
          'show_exit_confirmation': widget.showExitConfirmation,
        },
      );
    }

    // If pop already happened, nothing to do
    if (didPop) {
      return;
    }

    // Handle custom back press logic
    if (widget.onBackPressed != null) {
      widget.onBackPressed!();
      return;
    }

    // Handle exit confirmation
    if (widget.showExitConfirmation && !_isExiting) {
      _showExitConfirmation();
      return;
    }

    // Default behavior for post-auth screens
    if (widget.isPostAuthScreen) {
      _handlePostAuthBackPress();
    }
  }

  /// Handles back press for post-authentication screens
  void _handlePostAuthBackPress() {
    if (widget.enableLogging) {
      Logger.warning(
        'Back navigation attempted on post-auth screen',
        tag: 'AUTH_PROTECTION',
        context: {
          'screen_type': 'post_auth',
          'action': 'prevented',
          'fallback': 'exit_app_or_stay',
        },
      );
    }

    // For post-auth screens, we can either:
    // 1. Do nothing (stay on current screen)
    // 2. Exit the app (for root screens)
    // 3. Navigate to a specific route

    // Check if this is likely a root screen (home, main, etc.)
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';

    if (_isRootScreen(currentRoute)) {
      // Show exit app confirmation for root screens
      _showExitAppConfirmation();
    } else {
      // For non-root screens, navigate to home
      AuthAwareNavigationService.navigateWithContext(
        context,
        AppRoutes.home,
        type: NavigationType.replace,
      );
    }
  }

  /// Shows exit confirmation dialog
  Future<void> _showExitConfirmation() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit App'),
          content: Text(widget.exitConfirmationMessage ??
              'Are you sure you want to exit the app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true && mounted) {
      _exitApp();
    }
  }

  /// Shows exit app confirmation for root screens
  Future<void> _showExitAppConfirmation() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit App'),
          content: const Text('Are you sure you want to exit the app?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true && mounted) {
      _exitApp();
    }
  }

  /// Exits the application
  void _exitApp() {
    _isExiting = true;

    if (widget.enableLogging) {
      Logger.info(
        'Application exit initiated',
        tag: 'AUTH_PROTECTION',
        context: {
          'trigger': 'back_press_on_protected_screen',
          'user_confirmed': true,
        },
      );
    }

    SystemNavigator.pop();
  }

  /// Checks if the current route is a root screen
  bool _isRootScreen(String route) {
    const rootScreens = [
      AppRoutes.home,
      '/',
      '/home',
      '/main',
      '/dashboard',
    ];

    return rootScreens.contains(route) || route.isEmpty;
  }
}

/// A specialized version for the home screen with app exit behavior
class HomeScreenProtection extends StatelessWidget {
  final Widget child;
  final bool enableLogging;

  const HomeScreenProtection({
    super.key,
    required this.child,
    this.enableLogging = true,
  });

  @override
  Widget build(BuildContext context) {
    return AuthProtectedScreen(
      showExitConfirmation: true,
      exitConfirmationMessage: 'Are you sure you want to exit Disciplefy?',
      enableLogging: enableLogging,
      child: child,
    );
  }
}

/// A specialized version for critical authenticated screens
class CriticalAuthScreen extends StatelessWidget {
  final Widget child;
  final VoidCallback? onUnauthorizedAccess;
  final bool enableLogging;

  const CriticalAuthScreen({
    super.key,
    required this.child,
    this.onUnauthorizedAccess,
    this.enableLogging = true,
  });

  @override
  Widget build(BuildContext context) {
    return AuthProtectedScreen(
      canPop: false, // Never allow back navigation
      onBackPressed: () {
        if (enableLogging) {
          Logger.warning(
            'Unauthorized back navigation attempt on critical screen',
            tag: 'SECURITY',
            context: {
              'screen_type': 'critical_auth',
              'action': 'blocked',
            },
          );
        }

        if (onUnauthorizedAccess != null) {
          onUnauthorizedAccess!();
        } else {
          // Default: show warning and stay on screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Navigation restricted for security'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      enableLogging: enableLogging,
      child: child,
    );
  }
}

/// Extension to easily wrap widgets with auth protection
extension AuthProtectionExtension on Widget {
  /// Wraps the widget with basic auth protection
  Widget withAuthProtection({
    bool isPostAuthScreen = true,
    bool? canPop,
    VoidCallback? onBackPressed,
    bool enableLogging = true,
  }) {
    return AuthProtectedScreen(
      isPostAuthScreen: isPostAuthScreen,
      canPop: canPop,
      onBackPressed: onBackPressed,
      enableLogging: enableLogging,
      child: this,
    );
  }

  /// Wraps the widget with home screen protection (exit confirmation)
  Widget withHomeProtection({bool enableLogging = true}) {
    return HomeScreenProtection(
      enableLogging: enableLogging,
      child: this,
    );
  }

  /// Wraps the widget with critical auth screen protection
  Widget withCriticalAuthProtection({
    VoidCallback? onUnauthorizedAccess,
    bool enableLogging = true,
  }) {
    return CriticalAuthScreen(
      onUnauthorizedAccess: onUnauthorizedAccess,
      enableLogging: enableLogging,
      child: this,
    );
  }
}
