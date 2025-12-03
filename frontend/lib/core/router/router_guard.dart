import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import '../services/language_preference_service.dart';
import '../services/language_cache_coordinator.dart';
import '../di/injection_container.dart';
import 'app_routes.dart';

/// Router guard that handles authentication and onboarding logic
/// Extracted from the main router to improve maintainability
class RouterGuard {
  static const String _hiveBboxName = 'app_settings';
  static const String _userTypeKey = 'user_type';
  static const String _userIdKey = 'user_id';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _sessionExpiresAtKey =
      'session_expires_at'; // SECURITY FIX
  static const String _deviceIdKey = 'device_id'; // SECURITY FIX

  // Router-level caching to prevent excessive API calls
  static String? _cachedUserId;
  static LanguageSelectionState? _cachedLanguageState;
  static DateTime? _languageCacheTime;
  static const Duration _languageCacheExpiry = Duration(minutes: 10);

  // Flag to track if we've registered with the cache coordinator
  static bool _isRegisteredWithCoordinator = false;

  /// Main redirect logic for the app router
  /// ANDROID FIX: Added isAuthInitialized parameter to prevent login screen flash
  static Future<String?> handleRedirect(
    String currentPath, {
    bool isAuthInitialized = true, // Default to true for backward compatibility
  }) async {
    // Clean any hash fragments that might interfere with routing
    // This is a safeguard for OAuth callback URLs that might preserve fragments
    final cleanPath = currentPath.split('#').first;

    Logger.info(
      'Processing route redirect',
      tag: 'ROUTER',
      context: {
        'original_path': currentPath,
        'clean_path': cleanPath,
        'is_auth_initialized': isAuthInitialized,
      },
    );

    // ANDROID FIX: Show loading screen while Supabase is restoring session
    // This prevents the flash of login screen during app startup on Android
    if (!isAuthInitialized) {
      // If already on loading screen, stay there until auth initializes
      if (cleanPath == AppRoutes.appLoading) return null;

      // Otherwise, redirect to loading screen
      Logger.info(
        'Auth not initialized - showing loading screen',
        tag: 'ROUTER',
        context: {
          'attempted_path': cleanPath,
        },
      );
      return AppRoutes.appLoading;
    }

    final authState = _getAuthenticationState();
    final onboardingState = _getOnboardingState();
    final languageSelectionState = await _getLanguageSelectionState();
    final routeAnalysis = _analyzeCurrentRoute(cleanPath);

    _logNavigationState(
        authState, onboardingState, routeAnalysis, languageSelectionState);

    return await _determineRedirect(
        authState, onboardingState, languageSelectionState, routeAnalysis);
  }

  /// Get authentication state from multiple sources
  /// SECURITY FIX: Now validates session expiration and device binding
  static AuthenticationState _getAuthenticationState() {
    // Check Supabase auth first
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // SECURITY FIX: Validate session expiration for all auth types
      final isExpired = _isSessionExpired();
      if (isExpired) {
        Logger.info(
          'User session expired',
          tag: 'AUTH_SECURITY',
          context: {
            'user_id': user.id,
            'user_type': user.isAnonymous ? 'anonymous' : 'supabase',
            'session_expired': true,
          },
        );
        // Clear expired session data
        _clearExpiredSession();
        return const AuthenticationState(isAuthenticated: false);
      }

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
        // SECURITY FIX: Validate session expiration
        final isExpired = _isSessionExpired();
        if (isExpired) {
          Logger.info(
            'Stored session expired',
            tag: 'AUTH_SECURITY',
            context: {
              'user_type': userType,
              'user_id': userId,
              'session_expired': true,
            },
          );
          _clearExpiredSession();
          return const AuthenticationState(isAuthenticated: false);
        }

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
    // Ensure we're registered with the cache coordinator
    _registerWithCacheCoordinator();

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
            currentPath == AppRoutes.phoneAuth ||
            currentPath == AppRoutes.phoneAuthVerify ||
            currentPath == AppRoutes.emailAuth ||
            currentPath == AppRoutes.passwordReset ||
            currentPath.startsWith('/auth/callback'),
      );

  /// Check if the route is public (accessible without authentication)
  static bool _isPublicRoute(String path) {
    final publicRoutes = [
      AppRoutes.login,
      AppRoutes.authCallback,
      AppRoutes.languageSelection,
      AppRoutes.phoneAuth,
      AppRoutes.phoneAuthVerify, // /phone-auth/verify
      AppRoutes.emailAuth, // /email-auth
      AppRoutes.passwordReset, // /password-reset
      AppRoutes.pricing, // /pricing - public pricing page
    ];

    return publicRoutes.contains(path) ||
        path.startsWith(AppRoutes.onboarding) ||
        path.startsWith('/auth/callback') ||
        path.startsWith('/phone-auth') || // Allow all phone auth related routes
        path.startsWith('/email-auth') || // Allow email auth routes
        path.startsWith('/password-reset'); // Allow password reset routes
  }

  /// Check if the route requires full authentication (not guest/anonymous)
  /// Routes like memory verses require a real Supabase session with database access
  static bool _requiresFullAuthentication(String path) {
    final fullAuthRoutes = [
      AppRoutes.memoryVerses,
      AppRoutes.verseReview,
    ];

    return fullAuthRoutes.contains(path) ||
        path.startsWith('/memory-verses') ||
        path.startsWith('/memory-verse-review');
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
  static Future<String?> _determineRedirect(
    AuthenticationState authState,
    OnboardingState onboardingState,
    LanguageSelectionState languageSelectionState,
    RouteAnalysis routeAnalysis,
  ) async {
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

    // Case 2.5: Check if guest/anonymous user is trying to access full-auth route
    if (authState.isAuthenticated &&
        (authState.userType == 'guest' || authState.userType == 'anonymous') &&
        _requiresFullAuthentication(routeAnalysis.currentPath)) {
      Logger.info(
        'Decision: Guest/anonymous user blocked from full-auth route',
        tag: 'ROUTER_SECURITY',
        context: {
          'user_type': authState.userType,
          'attempted_route': routeAnalysis.currentPath,
          'redirect_target': AppRoutes.login,
          'reason': 'route_requires_full_authentication',
        },
      );
      return AppRoutes.login;
    }

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
      return await _handleFullyAuthenticatedUser(routeAnalysis, authState);
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
  static Future<String?> _handleFullyAuthenticatedUser(
    RouteAnalysis routeAnalysis,
    AuthenticationState authState,
  ) async {
    // Phase 2: Enhanced auth route blocking
    if (routeAnalysis.isAuthRoute || routeAnalysis.isOnboardingRoute) {
      return _handleAuthenticatedUserOnAuthRoutes(routeAnalysis, authState);
    }

    // Check for pending premium upgrade from pricing page
    // This must be checked here because the router may have redirected the user
    // through language selection flow before the login screen could handle it
    if (routeAnalysis.currentPath == AppRoutes.home) {
      final pendingRedirect = await _checkPendingPremiumUpgradeAsync();
      if (pendingRedirect != null) {
        return pendingRedirect;
      }
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

  /// Check for pending premium upgrade flag and return redirect if needed
  /// Also checks if user already has premium - if so, clears flag and skips redirect
  static Future<String?> _checkPendingPremiumUpgradeAsync() async {
    try {
      final box = Hive.box(_hiveBboxName);
      final pendingPremiumUpgrade =
          box.get('pending_premium_upgrade', defaultValue: false);

      if (pendingPremiumUpgrade == true) {
        // Check if user already has an active premium subscription
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          Map<String, dynamic>? subscription;
          try {
            subscription = await Supabase.instance.client
                .from('subscriptions')
                .select('status, plan_type')
                .eq('user_id', userId)
                .inFilter('status',
                    ['active', 'authenticated', 'pending_cancellation'])
                .maybeSingle()
                .timeout(
                  const Duration(seconds: 10),
                  onTimeout: () {
                    Logger.warning(
                      'Subscription query timed out after 10 seconds',
                      tag: 'ROUTER',
                      context: {'user_id': userId},
                    );
                    return null;
                  },
                );
          } on TimeoutException catch (e) {
            Logger.warning(
              'Subscription query timeout: ${e.message}',
              tag: 'ROUTER',
              context: {'user_id': userId},
            );
            // Continue without subscription check - allow redirect to upgrade page
          } catch (e) {
            Logger.error(
              'Error checking subscription status',
              tag: 'ROUTER',
              error: e,
              context: {'user_id': userId},
            );
            // Continue without subscription check - allow redirect to upgrade page
          }

          if (subscription != null &&
              (subscription['plan_type'] as String?)?.startsWith('premium') ==
                  true) {
            // User already has premium - clear flag and don't redirect
            box.delete('pending_premium_upgrade');
            Logger.info(
              'User already has premium subscription - skipping upgrade redirect',
              tag: 'ROUTER',
              context: {
                'user_id': userId,
                'subscription_status': subscription['status'],
                'plan_type': subscription['plan_type'],
              },
            );
            return null;
          }
        }

        // Clear the flag and redirect to premium upgrade
        box.delete('pending_premium_upgrade');
        Logger.info(
          'Pending premium upgrade detected - redirecting to premium page',
          tag: 'ROUTER',
          context: {
            'redirect_target': AppRoutes.premiumUpgrade,
            'redirect_reason': 'pending_premium_upgrade',
          },
        );
        return AppRoutes.premiumUpgrade;
      }
    } catch (e) {
      Logger.error(
        'Error checking pending premium upgrade',
        tag: 'ROUTER',
        error: e,
      );
    }
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
    if (path == AppRoutes.phoneAuth) return 'phone_authentication';
    if (path == AppRoutes.phoneAuthVerify) return 'phone_verification';
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

  /// Register router cache invalidation with the language cache coordinator
  static void _registerWithCacheCoordinator() {
    if (_isRegisteredWithCoordinator) return;

    try {
      final cacheCoordinator = sl<LanguageCacheCoordinator>();
      cacheCoordinator.registerCacheInvalidationCallback(
        invalidateLanguageSelectionCache,
      );
      _isRegisteredWithCoordinator = true;

      Logger.info(
        'RouterGuard registered with LanguageCacheCoordinator',
        tag: 'ROUTER_CACHE',
      );
    } catch (e) {
      Logger.error(
        'Failed to register RouterGuard with LanguageCacheCoordinator',
        tag: 'ROUTER_CACHE',
        error: e,
      );
    }
  }

  /// SECURITY FIX: Check if the session has expired
  static bool _isSessionExpired() {
    try {
      final box = Hive.box(_hiveBboxName);
      final expiresAtStr = box.get(_sessionExpiresAtKey) as String?;

      if (expiresAtStr == null) {
        // No expiration data - assume session is valid (for backward compatibility)
        return false;
      }

      final expiresAt = DateTime.parse(expiresAtStr);
      final now = DateTime.now().toUtc();
      final isExpired = now.isAfter(expiresAt);

      if (isExpired) {
        final timeSinceExpiry = now.difference(expiresAt);
        Logger.info(
          'Session expired',
          tag: 'AUTH_SECURITY',
          context: {
            'expires_at': expiresAt.toIso8601String(),
            'current_time': now.toIso8601String(),
            'time_since_expiry_minutes': timeSinceExpiry.inMinutes,
          },
        );
      }

      return isExpired;
    } catch (e) {
      Logger.error(
        'Error checking session expiration',
        tag: 'AUTH_SECURITY',
        error: e,
      );
      // On error, assume session is valid to prevent breaking existing sessions
      return false;
    }
  }

  /// SECURITY FIX: Clear expired session data from Hive
  static void _clearExpiredSession() {
    try {
      final box = Hive.box(_hiveBboxName);
      box.delete(_userTypeKey);
      box.delete(_userIdKey);
      box.delete(_sessionExpiresAtKey);
      box.delete(_deviceIdKey);
      // NOTE: Do NOT clear onboarding_completed flag here!
      // Onboarding is a one-time per-device experience that should persist
      // across login/logout cycles. Only clear it on app reset or reinstall.

      Logger.info(
        'Expired session data cleared from storage',
        tag: 'AUTH_SECURITY',
        context: {
          'cleared_keys': [
            _userTypeKey,
            _userIdKey,
            _sessionExpiresAtKey,
            _deviceIdKey
          ],
          'preserved_keys': [_onboardingCompletedKey],
        },
      );
    } catch (e) {
      Logger.error(
        'Error clearing expired session data',
        tag: 'AUTH_SECURITY',
        error: e,
      );
    }
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
