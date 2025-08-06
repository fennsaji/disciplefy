import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';
import 'app_routes.dart';

/// Router guard that handles authentication and onboarding logic
/// Extracted from the main router to improve maintainability
class RouterGuard {
  static const String _hiveBboxName = 'app_settings';
  static const String _userTypeKey = 'user_type';
  static const String _userIdKey = 'user_id';
  static const String _onboardingCompletedKey = 'onboarding_completed';

  /// Main redirect logic for the app router
  static String? handleRedirect(String currentPath) {
    // Clean any hash fragments that might interfere with routing
    // This is a safeguard for OAuth callback URLs that might preserve fragments
    final cleanPath = currentPath.split('#').first;

    Logger.info(
      'Processing route redirect',
      tag: 'ROUTER',
      context: {
        'original_path': currentPath,
        'clean_path': cleanPath,
      },
    );

    final authState = _getAuthenticationState();
    final onboardingState = _getOnboardingState();
    final routeAnalysis = _analyzeCurrentRoute(cleanPath);

    _logNavigationState(authState, onboardingState, routeAnalysis);

    return _determineRedirect(authState, onboardingState, routeAnalysis);
  }

  /// Get authentication state from multiple sources
  static AuthenticationState _getAuthenticationState() {
    // Check Supabase auth first
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      Logger.info(
        'User authenticated via Supabase',
        tag: 'AUTH',
        context: {
          'user_email': user.email ?? 'Anonymous',
          'is_anonymous': user.isAnonymous,
          'user_id': user.id,
        },
      );
      return AuthenticationState(
        isAuthenticated: true,
        userType: user.isAnonymous ? 'anonymous' : 'supabase',
        userId: user.id,
        userEmail: user.email,
      );
    }

    // Check Hive storage for guest/local auth
    try {
      final box = Hive.box(_hiveBboxName);
      final userType = box.get(_userTypeKey);
      final userId = box.get(_userIdKey);

      if (userType != null && (userType == 'guest' || userType == 'google')) {
        Logger.info(
          'User authenticated via local storage',
          tag: 'AUTH',
          context: {
            'user_type': userType,
            'user_id': userId,
          },
        );
        return AuthenticationState(
          isAuthenticated: true,
          userType: userType,
          userId: userId,
        );
      }
    } catch (e) {
      Logger.error(
        'Failed to read authentication from local storage',
        tag: 'ROUTER',
        error: e,
      );
    }

    Logger.info('No authentication found', tag: 'AUTH');
    return const AuthenticationState(isAuthenticated: false);
  }

  /// Get onboarding completion state
  static OnboardingState _getOnboardingState() {
    try {
      final box = Hive.box(_hiveBboxName);
      final isCompleted =
          box.get(_onboardingCompletedKey, defaultValue: false) as bool;

      // Log all relevant Hive data for debugging
      Logger.info(
        'Onboarding state retrieved',
        tag: 'ONBOARDING',
        context: {
          'onboarding_completed': isCompleted,
          'hive_keys': box.keys.toList(),
        },
      );

      return OnboardingState(isCompleted: isCompleted);
    } catch (e) {
      Logger.error(
        'Failed to read onboarding state from local storage',
        tag: 'ROUTER',
        error: e,
      );
      return const OnboardingState(isCompleted: false);
    }
  }

  /// Analyze the current route to determine its type
  static RouteAnalysis _analyzeCurrentRoute(String currentPath) =>
      RouteAnalysis(
        currentPath: currentPath,
        isPublicRoute: _isPublicRoute(currentPath),
        isOnboardingRoute: currentPath.startsWith(AppRoutes.onboarding),
        isAuthRoute: currentPath == AppRoutes.login ||
            currentPath.startsWith('/auth/callback'),
      );

  /// Check if the route is public (accessible without authentication)
  static bool _isPublicRoute(String path) {
    final publicRoutes = [
      AppRoutes.login,
      AppRoutes.authCallback,
    ];

    return publicRoutes.contains(path) ||
        path.startsWith(AppRoutes.onboarding) ||
        path.startsWith('/auth/callback');
  }

  /// Log the current navigation state for debugging
  static void _logNavigationState(
    AuthenticationState authState,
    OnboardingState onboardingState,
    RouteAnalysis routeAnalysis,
  ) {
    Logger.info(
      'Navigation state summary',
      tag: 'ROUTER',
      context: {
        'authenticated': authState.isAuthenticated,
        'onboarding_completed': onboardingState.isCompleted,
        'current_route': routeAnalysis.currentPath,
        'is_public_route': routeAnalysis.isPublicRoute,
        'is_onboarding_route': routeAnalysis.isOnboardingRoute,
        'is_auth_route': routeAnalysis.isAuthRoute,
        'user_type': authState.userType,
      },
    );
  }

  /// Determine the appropriate redirect based on state
  static String? _determineRedirect(
    AuthenticationState authState,
    OnboardingState onboardingState,
    RouteAnalysis routeAnalysis,
  ) {
    // Log detailed state for debugging logout issues
    Logger.info(
      'Router decision matrix',
      tag: 'ROUTER',
      context: {
        'is_authenticated': authState.isAuthenticated,
        'onboarding_completed': onboardingState.isCompleted,
        'current_path': routeAnalysis.currentPath,
        'user_type': authState.userType,
        'user_id': authState.userId,
      },
    );

    // Case 1: Not authenticated
    if (!authState.isAuthenticated) {
      Logger.info('Decision: User not authenticated', tag: 'ROUTER');
      return _handleUnauthenticatedUser(routeAnalysis);
    }

    // // Case 2: Authenticated but onboarding not completed
    // if (authState.isAuthenticated && !onboardingState.isCompleted) {
    //   Logger.info('Decision: User authenticated but onboarding incomplete',
    //       tag: 'ROUTER');
    //   return _handleAuthenticatedUserWithoutOnboarding(routeAnalysis);
    // }

    // Case 3: Authenticated and onboarding completed
    if (authState.isAuthenticated) {
      Logger.info('Decision: User fully authenticated and onboarded',
          tag: 'ROUTER');
      return _handleFullyAuthenticatedUser(routeAnalysis, authState);
    }

    // Fallback - no redirect needed
    Logger.info('Decision: No redirect needed (fallback)', tag: 'ROUTER');
    return null;
  }

  /// Handle redirect logic for unauthenticated users
  static String? _handleUnauthenticatedUser(RouteAnalysis routeAnalysis) {
    if (routeAnalysis.isPublicRoute) {
      // Public routes don't need logging for security reasons
      return null;
    }

    // Special handling for logout scenarios - ensure we go to login
    // even if there are temporary inconsistencies in storage
    if (routeAnalysis.currentPath == AppRoutes.settings ||
        routeAnalysis.currentPath == AppRoutes.generateStudy ||
        routeAnalysis.currentPath == AppRoutes.saved) {
      Logger.info(
        'Post-logout redirect to login from protected route',
        tag: 'ROUTER',
        context: {'attempted_route': routeAnalysis.currentPath},
      );
      return AppRoutes.login;
    }

    Logger.info(
      'Unauthenticated user redirected to login',
      tag: 'ROUTER',
      context: {'attempted_route': routeAnalysis.currentPath},
    );
    final onboardingState = _getOnboardingState();
    if (routeAnalysis.currentPath == AppRoutes.home) {
      if (onboardingState.isCompleted) {
        return AppRoutes.login; // Returning user
      }
    }
    if (routeAnalysis.isOnboardingRoute) {
      Logger.info(
        'Unauthenticated user redirected to onboarding',
        tag: 'ROUTER',
        context: {'attempted_route': routeAnalysis.currentPath},
      );
      return null; // New user
    }
    return AppRoutes.onboarding;
  }

  /// Handle redirect logic for authenticated users without completed onboarding
  static String? _handleAuthenticatedUserWithoutOnboarding(
      RouteAnalysis routeAnalysis) {
    if (routeAnalysis.isOnboardingRoute) {
      // User navigation logging handled by navigation system
      return null;
    }

    Logger.info(
      'Authenticated user without onboarding redirected to onboarding',
      tag: 'ROUTER',
      context: {'attempted_route': routeAnalysis.currentPath},
    );
    return AppRoutes.onboarding;
  }

  /// Handle redirect logic for fully authenticated and onboarded users
  static String? _handleFullyAuthenticatedUser(
    RouteAnalysis routeAnalysis,
    AuthenticationState authState,
  ) {
    if (routeAnalysis.isAuthRoute || routeAnalysis.isOnboardingRoute) {
      // Special case: Allow anonymous users to access login screen for account upgrade
      if (routeAnalysis.isAuthRoute && authState.userType == 'anonymous') {
        Logger.info(
          'Anonymous user allowed to access login screen for account upgrade',
          tag: 'ROUTER',
          context: {
            'attempted_route': routeAnalysis.currentPath,
            'user_type': authState.userType,
          },
        );
        return null; // Allow access to login screen
      }

      Logger.info(
        'Fully authenticated user redirected to home',
        tag: 'ROUTER',
        context: {
          'attempted_route': routeAnalysis.currentPath,
          'user_type': authState.userType,
        },
      );
      return AppRoutes.home;
    }

    Logger.info('Fully authenticated user, no redirect needed', tag: 'AUTH');
    return null;
  }
}

/// Data class for authentication state
class AuthenticationState {
  final bool isAuthenticated;
  final String? userType;
  final String? userId;
  final String? userEmail;

  const AuthenticationState({
    required this.isAuthenticated,
    this.userType,
    this.userId,
    this.userEmail,
  });
}

/// Data class for onboarding state
class OnboardingState {
  final bool isCompleted;

  const OnboardingState({required this.isCompleted});
}

/// Data class for route analysis
class RouteAnalysis {
  final String currentPath;
  final bool isPublicRoute;
  final bool isOnboardingRoute;
  final bool isAuthRoute;

  const RouteAnalysis({
    required this.currentPath,
    required this.isPublicRoute,
    required this.isOnboardingRoute,
    required this.isAuthRoute,
  });
}
