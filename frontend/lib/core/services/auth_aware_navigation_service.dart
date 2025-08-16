import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// Conditional import for web-specific functionality
import 'auth_aware_navigation_service_web.dart'
    if (dart.library.io) 'auth_aware_navigation_service_stub.dart' as web_utils;

import '../router/app_routes.dart';
import '../utils/logger.dart';

/// Navigation patterns for different scenarios
enum NavigationType {
  /// Normal navigation that maintains stack
  normal,

  /// Authentication transition that clears previous stack
  authTransition,

  /// Logout that completely resets navigation state
  logout,

  /// Replace current route without affecting stack depth
  replace,
}

/// Advanced navigation service that manages authentication-aware routing
/// and navigation stack management.
///
/// This service provides:
/// - Stack-aware navigation for authentication flows
/// - Browser history management for web platform
/// - Secure navigation patterns that prevent auth bypass
/// - Centralized navigation logic for consistency
class AuthAwareNavigationService {
  static final AuthAwareNavigationService _instance =
      AuthAwareNavigationService._internal();
  factory AuthAwareNavigationService() => _instance;
  AuthAwareNavigationService._internal();

  /// Navigates after successful authentication, clearing any pre-auth history
  static void navigateAfterAuth(BuildContext context, {String? route}) {
    final destination = route ?? AppRoutes.home;

    Logger.info(
      'Post-authentication navigation initiated',
      tag: 'AUTH_NAV',
      context: {
        'destination': destination,
        'navigation_type': 'auth_transition',
        'action': 'clear_stack_and_navigate'
      },
    );

    // Clear browser history for web platform
    _clearBrowserHistory(destination);

    // Use replace to clear navigation stack
    context.replace(destination);

    Logger.info(
      'Post-authentication navigation completed',
      tag: 'AUTH_NAV',
      context: {'new_route': destination},
    );
  }

  /// Handles logout navigation with complete state reset
  static void handleAuthLogout(BuildContext context) {
    Logger.info(
      'Logout navigation initiated',
      tag: 'AUTH_NAV',
      context: {
        'destination': AppRoutes.login,
        'navigation_type': 'logout',
        'action': 'complete_reset'
      },
    );

    // Clear browser history for web platform
    _clearBrowserHistory(AppRoutes.login);

    // Clear any cached auth data and navigate to login
    context.replace(AppRoutes.login);

    Logger.info(
      'Logout navigation completed',
      tag: 'AUTH_NAV',
      context: {'new_route': AppRoutes.login},
    );
  }

  /// Smart navigation that chooses appropriate method based on context
  static void navigateWithContext(
    BuildContext context,
    String route, {
    NavigationType type = NavigationType.normal,
    Object? extra,
  }) {
    Logger.info(
      'Context-aware navigation initiated',
      tag: 'AUTH_NAV',
      context: {
        'destination': route,
        'navigation_type': type.name,
        'has_extra': extra != null,
      },
    );

    switch (type) {
      case NavigationType.normal:
        context.go(route, extra: extra);
        break;
      case NavigationType.authTransition:
        _clearBrowserHistory(route);
        context.replace(route);
        break;
      case NavigationType.logout:
        _clearBrowserHistory(route);
        context.replace(route);
        break;
      case NavigationType.replace:
        context.replace(route);
        break;
    }

    Logger.info(
      'Context-aware navigation completed',
      tag: 'AUTH_NAV',
      context: {
        'new_route': route,
        'type': type.name,
      },
    );
  }

  /// Checks if navigation should be prevented based on auth state
  static bool shouldPreventNavigation(
    String currentRoute,
    String targetRoute,
    bool isAuthenticated,
  ) {
    // Prevent navigation to auth routes when authenticated
    if (isAuthenticated && _isAuthRoute(targetRoute)) {
      Logger.warning(
        'Navigation prevented: authenticated user trying to access auth route',
        tag: 'AUTH_NAV',
        context: {
          'current_route': currentRoute,
          'target_route': targetRoute,
          'is_authenticated': isAuthenticated,
          'action': 'prevent_navigation'
        },
      );
      return true;
    }

    // Prevent navigation to protected routes when not authenticated
    if (!isAuthenticated && _isProtectedRoute(targetRoute)) {
      Logger.warning(
        'Navigation prevented: unauthenticated user trying to access protected route',
        tag: 'AUTH_NAV',
        context: {
          'current_route': currentRoute,
          'target_route': targetRoute,
          'is_authenticated': isAuthenticated,
          'action': 'prevent_navigation'
        },
      );
      return true;
    }

    return false;
  }

  /// Gets the appropriate redirect route based on auth state
  static String? getRedirectRoute(String targetRoute, bool isAuthenticated) {
    if (isAuthenticated && _isAuthRoute(targetRoute)) {
      return AppRoutes.home;
    }

    if (!isAuthenticated && _isProtectedRoute(targetRoute)) {
      return AppRoutes.login;
    }

    return null;
  }

  /// Clears browser history for web platform (Phase 3 enhancement)
  static void _clearBrowserHistory(String newRoute) {
    if (kIsWeb) {
      try {
        // Use conditional import for web-specific functionality
        web_utils.clearBrowserHistory(newRoute);

        Logger.info(
          'Browser history cleared for web platform',
          tag: 'AUTH_NAV',
          context: {
            'new_route': newRoute,
            'platform': 'web',
            'action': 'history_replaced'
          },
        );
      } catch (e) {
        Logger.error(
          'Failed to clear browser history',
          tag: 'AUTH_NAV',
          context: {
            'error': e.toString(),
            'route': newRoute,
          },
        );
      }
    }
  }

  /// Checks if a route is an authentication route
  static bool _isAuthRoute(String route) {
    return route == AppRoutes.login ||
        route == AppRoutes.onboarding ||
        route.startsWith('/auth');
  }

  /// Checks if a route requires authentication
  static bool _isProtectedRoute(String route) {
    // Most routes are protected except auth and public routes
    return !_isAuthRoute(route) && route != '/' && !route.startsWith('/public');
  }

  /// Handles complex navigation scenarios with validation
  static Future<bool> navigateWithValidation(
    BuildContext context,
    String route, {
    bool isAuthenticated = false,
    NavigationType type = NavigationType.normal,
    Object? extra,
  }) async {
    // Validate navigation
    if (shouldPreventNavigation(
      GoRouterState.of(context).uri.path,
      route,
      isAuthenticated,
    )) {
      final redirectRoute = getRedirectRoute(route, isAuthenticated);
      if (redirectRoute != null) {
        navigateWithContext(
          context,
          redirectRoute,
          type: NavigationType.replace,
        );
      }
      return false;
    }

    // Proceed with navigation
    navigateWithContext(context, route, type: type, extra: extra);
    return true;
  }

  /// Gets navigation analytics for monitoring
  static Map<String, dynamic> getNavigationAnalytics() {
    return {
      'service_version': '1.0.0',
      'platform': kIsWeb ? 'web' : 'mobile',
      'features_enabled': [
        'auth_aware_routing',
        'stack_management',
        'browser_history_control',
        'navigation_validation',
      ],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// Extension on BuildContext for convenient access to AuthAwareNavigationService
extension AuthAwareNavigation on BuildContext {
  /// Navigate after authentication with stack clearing
  void navigateAfterAuth({String? route}) {
    AuthAwareNavigationService.navigateAfterAuth(this, route: route);
  }

  /// Handle logout with complete navigation reset
  void navigateAfterLogout() {
    AuthAwareNavigationService.handleAuthLogout(this);
  }

  /// Context-aware navigation with type specification
  void navigateWithType(
    String route, {
    NavigationType type = NavigationType.normal,
    Object? extra,
  }) {
    AuthAwareNavigationService.navigateWithContext(
      this,
      route,
      type: type,
      extra: extra,
    );
  }

  /// Validated navigation with auth state checking
  Future<bool> navigateWithAuthValidation(
    String route, {
    required bool isAuthenticated,
    NavigationType type = NavigationType.normal,
    Object? extra,
  }) {
    return AuthAwareNavigationService.navigateWithValidation(
      this,
      route,
      isAuthenticated: isAuthenticated,
      type: type,
      extra: extra,
    );
  }
}
