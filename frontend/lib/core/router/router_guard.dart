import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import '../services/language_preference_service.dart';
import '../di/injection_container.dart';
import 'app_routes.dart';

/// Router guard that handles authentication and onboarding logic
/// Extracted from the main router to improve maintainability
class RouterGuard {
  static const String _hiveBboxName = 'app_settings';
  static const String _userTypeKey = 'user_type';
  static const String _userIdKey = 'user_id';
  static const String _onboardingCompletedKey = 'onboarding_completed';

  // Router-level caching to prevent excessive API calls
  static String? _cachedUserId;
  static LanguageSelectionState? _cachedLanguageState;
  static DateTime? _languageCacheTime;
  static const Duration _languageCacheExpiry = Duration(minutes: 10);

  /// Main redirect logic for the app router
  static Future<String?> handleRedirect(String currentPath) async {
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
    final languageSelectionState = await _getLanguageSelectionState();
    final routeAnalysis = _analyzeCurrentRoute(cleanPath);

    _logNavigationState(
        authState, onboardingState, routeAnalysis, languageSelectionState);

    return _determineRedirect(
        authState, onboardingState, languageSelectionState, routeAnalysis);
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

  /// Get language selection completion state with router-level caching
  /// This prevents excessive API calls on every navigation
  static Future<LanguageSelectionState> _getLanguageSelectionState() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      // Use cached result if available and fresh for the same user
      if (_isLanguageCacheFresh() &&
          _cachedUserId == currentUserId &&
          _cachedLanguageState != null) {
        Logger.info(
          'Using cached language selection state',
          tag: 'LANGUAGE_SELECTION_CACHE',
          context: {
            'cached_completion_status': _cachedLanguageState!.isCompleted,
            'user_id': currentUserId,
          },
        );
        return _cachedLanguageState!;
      }

      final languageService = sl<LanguagePreferenceService>();
      final isCompleted = await languageService.hasCompletedLanguageSelection();

      // Cache the result
      _cacheLanguageSelectionState(
          currentUserId, LanguageSelectionState(isCompleted: isCompleted));

      Logger.info(
        'Language selection state retrieved and cached',
        tag: 'LANGUAGE_SELECTION',
        context: {
          'language_selection_completed': isCompleted,
          'user_id': currentUserId,
        },
      );

      return LanguageSelectionState(isCompleted: isCompleted);
    } catch (e) {
      Logger.error(
        'Failed to check language selection status',
        tag: 'ROUTER',
        error: e,
      );
      return const LanguageSelectionState(isCompleted: false);
    }
  }

  /// Check if user has completed language selection (legacy method)
  static Future<bool> _hasCompletedLanguageSelection() async {
    final state = await _getLanguageSelectionState();
    return state.isCompleted;
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
      AppRoutes.languageSelection,
    ];

    return publicRoutes.contains(path) ||
        path.startsWith(AppRoutes.onboarding) ||
        path.startsWith('/auth/callback');
  }

  /// Log the current navigation state for debugging
  /// Phase 2 Enhancement: More detailed analytics and route classification
  static void _logNavigationState(
    AuthenticationState authState,
    OnboardingState onboardingState,
    RouteAnalysis routeAnalysis,
    LanguageSelectionState languageSelectionState,
  ) {
    Logger.info(
      'Navigation state summary',
      tag: 'ROUTER_ANALYTICS',
      context: {
        'authenticated': authState.isAuthenticated,
        'onboarding_completed': onboardingState.isCompleted,
        'language_selection_completed': languageSelectionState.isCompleted,
        'current_route': routeAnalysis.currentPath,
        'route_type': _getRouteType(routeAnalysis.currentPath),
        'is_public_route': routeAnalysis.isPublicRoute,
        'is_onboarding_route': routeAnalysis.isOnboardingRoute,
        'is_auth_route': routeAnalysis.isAuthRoute,
        'user_type': authState.userType ?? 'unauthenticated',
        'user_id': authState.userId,
        'session_state': _getSessionState(authState, onboardingState),
      },
    );
  }

  /// Phase 2: Get comprehensive session state for analytics
  static String _getSessionState(
    AuthenticationState authState,
    OnboardingState onboardingState,
  ) {
    if (!authState.isAuthenticated) {
      return onboardingState.isCompleted ? 'returning_visitor' : 'new_visitor';
    }

    switch (authState.userType) {
      case 'anonymous':
        return 'anonymous_session';
      case 'guest':
        return 'guest_session';
      case 'google':
      case 'supabase':
        return 'authenticated_session';
      default:
        return 'unknown_session';
    }
  }

  /// Determine the appropriate redirect based on state
  /// Phase 2 Enhancement: More comprehensive decision logging
  static String? _determineRedirect(
    AuthenticationState authState,
    OnboardingState onboardingState,
    LanguageSelectionState languageSelectionState,
    RouteAnalysis routeAnalysis,
  ) {
    // Phase 2: Enhanced decision matrix logging with more context
    Logger.info(
      'Router decision matrix',
      tag: 'ROUTER_DECISION',
      context: {
        'is_authenticated': authState.isAuthenticated,
        'onboarding_completed': onboardingState.isCompleted,
        'language_selection_completed': languageSelectionState.isCompleted,
        'current_path': routeAnalysis.currentPath,
        'route_type': _getRouteType(routeAnalysis.currentPath),
        'user_type': authState.userType ?? 'unauthenticated',
        'user_id': authState.userId,
        'session_state': _getSessionState(authState, onboardingState),
        'is_public_route': routeAnalysis.isPublicRoute,
        'is_auth_route': routeAnalysis.isAuthRoute,
        'is_onboarding_route': routeAnalysis.isOnboardingRoute,
        'decision_timestamp': DateTime.now().toIso8601String(),
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

    // Case 3: Authenticated but language selection not completed
    if (authState.isAuthenticated && !languageSelectionState.isCompleted) {
      Logger.info(
          'Decision: User authenticated but language selection incomplete',
          tag: 'ROUTER');
      return _handleAuthenticatedUserWithoutLanguageSelection(routeAnalysis);
    }

    // Case 4: Authenticated and language selection completed
    if (authState.isAuthenticated && languageSelectionState.isCompleted) {
      Logger.info(
          'Decision: User fully authenticated with language preference set',
          tag: 'ROUTER');
      return _handleFullyAuthenticatedUser(routeAnalysis, authState);
    }

    // Fallback - no redirect needed
    Logger.info('Decision: No redirect needed (fallback)', tag: 'ROUTER');
    return null;
  }

  /// Handle redirect logic for unauthenticated users
  /// Phase 2 Enhancement: Better analytics and edge case handling
  static String? _handleUnauthenticatedUser(RouteAnalysis routeAnalysis) {
    // Phase 2: Enhanced logging for public routes
    if (routeAnalysis.isPublicRoute) {
      Logger.info(
        'Unauthenticated user accessing public route',
        tag: 'ROUTER_ANALYTICS',
        context: {
          'current_route': routeAnalysis.currentPath,
          'route_type': _getRouteType(routeAnalysis.currentPath),
          'access_allowed': true,
          'user_type': 'unauthenticated',
        },
      );
      return null;
    }

    // Phase 2: Enhanced handling for protected routes
    final redirectTarget = _determineUnauthenticatedRedirect(routeAnalysis);
    final redirectReason =
        _getUnauthenticatedRedirectReason(routeAnalysis, redirectTarget);

    Logger.info(
      'Unauthenticated user redirected from protected route',
      tag: 'ROUTER_SECURITY',
      context: {
        'attempted_route': routeAnalysis.currentPath,
        'route_type': _getRouteType(routeAnalysis.currentPath),
        'redirect_target': redirectTarget,
        'redirect_reason': redirectReason,
        'user_type': 'unauthenticated',
        'security_action': 'access_denied',
      },
    );

    return redirectTarget;
  }

  /// Phase 2: Determine redirect target for unauthenticated users
  static String _determineUnauthenticatedRedirect(RouteAnalysis routeAnalysis) {
    final onboardingState = _getOnboardingState();

    // Special handling for logout scenarios - ensure we go to login
    // even if there are temporary inconsistencies in storage
    if (routeAnalysis.currentPath == AppRoutes.settings ||
        routeAnalysis.currentPath == AppRoutes.generateStudy ||
        routeAnalysis.currentPath == AppRoutes.saved) {
      return AppRoutes.login;
    }

    // Home page logic based on onboarding state
    if (routeAnalysis.currentPath == AppRoutes.home) {
      return onboardingState.isCompleted
          ? AppRoutes.login
          : AppRoutes.onboarding;
    }

    // Onboarding routes are allowed for new users
    if (routeAnalysis.isOnboardingRoute) {
      return routeAnalysis.currentPath; // Stay on onboarding route
    }

    // Default: new users to onboarding, others to login
    return onboardingState.isCompleted ? AppRoutes.login : AppRoutes.onboarding;
  }

  /// Phase 2: Get reason for unauthenticated user redirect
  static String _getUnauthenticatedRedirectReason(
      RouteAnalysis routeAnalysis, String redirectTarget) {
    if (redirectTarget == AppRoutes.login) {
      if (routeAnalysis.currentPath == AppRoutes.home) {
        return 'returning_user_needs_auth';
      }
      return 'protected_route_requires_auth';
    }

    if (redirectTarget == AppRoutes.onboarding) {
      return 'new_user_needs_onboarding';
    }

    return 'unknown_redirect_reason';
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

  /// Handle redirect logic for authenticated users without language selection
  static String? _handleAuthenticatedUserWithoutLanguageSelection(
      RouteAnalysis routeAnalysis) {
    // Allow access to language selection screen
    if (routeAnalysis.currentPath == AppRoutes.languageSelection) {
      return null;
    }

    // Allow access to auth routes (logout, etc.)
    if (routeAnalysis.isAuthRoute) {
      return null;
    }

    Logger.info(
      'Authenticated user without language selection redirected to language selection',
      tag: 'ROUTER',
      context: {'attempted_route': routeAnalysis.currentPath},
    );
    return AppRoutes.languageSelection;
  }

  /// Handle redirect logic for fully authenticated and onboarded users
  /// Phase 2 Enhancement: More aggressive blocking and better analytics
  static String? _handleFullyAuthenticatedUser(
    RouteAnalysis routeAnalysis,
    AuthenticationState authState,
  ) {
    // Phase 2: Enhanced auth route blocking
    if (routeAnalysis.isAuthRoute || routeAnalysis.isOnboardingRoute) {
      return _handleAuthenticatedUserOnAuthRoutes(routeAnalysis, authState);
    }

    // Phase 2: Enhanced logging for successful navigation
    Logger.info(
      'Authenticated user navigation allowed',
      tag: 'ROUTER',
      context: {
        'current_route': routeAnalysis.currentPath,
        'user_type': authState.userType,
        'user_id': authState.userId,
        'route_type': _getRouteType(routeAnalysis.currentPath),
        'navigation_source': 'direct_access',
      },
    );
    return null;
  }

  /// Phase 2: Handle authenticated users trying to access auth/onboarding routes
  /// Enhanced with more detailed analytics and stricter controls
  static String? _handleAuthenticatedUserOnAuthRoutes(
    RouteAnalysis routeAnalysis,
    AuthenticationState authState,
  ) {
    // Special case: Allow anonymous users to access login screen for account upgrade
    if (routeAnalysis.isAuthRoute &&
        authState.userType == 'anonymous' &&
        routeAnalysis.currentPath == AppRoutes.login) {
      Logger.info(
        'Anonymous user accessing login for account upgrade',
        tag: 'ROUTER_ANALYTICS',
        context: {
          'attempted_route': routeAnalysis.currentPath,
          'user_type': authState.userType,
          'user_id': authState.userId,
          'action': 'account_upgrade_attempt',
          'allowed': true,
        },
      );
      return null; // Allow access to login screen
    }

    // Phase 2: More aggressive blocking for all other cases
    final blockReason = _determineBlockReason(routeAnalysis, authState);

    Logger.info(
      'Authenticated user blocked from pre-auth route',
      tag: 'ROUTER_SECURITY',
      context: {
        'attempted_route': routeAnalysis.currentPath,
        'user_type': authState.userType,
        'user_id': authState.userId,
        'block_reason': blockReason,
        'redirect_target': AppRoutes.home,
        'security_action': 'force_redirect',
      },
    );

    return AppRoutes.home;
  }

  /// Phase 2: Determine specific reason for blocking authenticated user
  static String _determineBlockReason(
    RouteAnalysis routeAnalysis,
    AuthenticationState authState,
  ) {
    if (routeAnalysis.isOnboardingRoute) {
      return 'onboarding_already_completed';
    }

    if (routeAnalysis.currentPath == AppRoutes.login) {
      if (authState.userType == 'google' || authState.userType == 'supabase') {
        return 'already_authenticated_with_account';
      }
      if (authState.userType == 'guest') {
        return 'guest_user_blocked_from_login';
      }
    }

    if (routeAnalysis.currentPath.startsWith('/auth/callback')) {
      return 'oauth_callback_while_authenticated';
    }

    return 'authenticated_user_on_auth_route';
  }

  /// Phase 2: Classify route types for analytics
  static String _getRouteType(String path) {
    if (path == AppRoutes.home) return 'home';
    if (path == AppRoutes.generateStudy) return 'study_generation';
    if (path == AppRoutes.settings) return 'settings';
    if (path == AppRoutes.saved) return 'saved_guides';
    if (path.startsWith(AppRoutes.studyGuide)) return 'study_guide_view';
    if (path == AppRoutes.login) return 'authentication';
    if (path.startsWith(AppRoutes.onboarding)) return 'onboarding';
    if (path.startsWith('/auth/callback')) return 'oauth_callback';
    return 'unknown';
  }

  /// Cache language selection state to prevent repeated API calls
  static void _cacheLanguageSelectionState(
      String? userId, LanguageSelectionState state) {
    _cachedUserId = userId;
    _cachedLanguageState = state;
    _languageCacheTime = DateTime.now();
  }

  /// Check if cached language selection state is still fresh
  static bool _isLanguageCacheFresh() {
    if (_languageCacheTime == null) return false;
    final age = DateTime.now().difference(_languageCacheTime!);
    return age < _languageCacheExpiry;
  }

  /// Invalidate language selection cache (call when user logs in/out or changes language)
  static void invalidateLanguageSelectionCache() {
    _cachedUserId = null;
    _cachedLanguageState = null;
    _languageCacheTime = null;
    Logger.info('Router language selection cache invalidated',
        tag: 'ROUTER_CACHE');
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

/// Data class for language selection state
class LanguageSelectionState {
  final bool isCompleted;

  const LanguageSelectionState({required this.isCompleted});
}
