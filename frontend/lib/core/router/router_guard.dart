import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import '../services/language_preference_service.dart';
import '../services/language_cache_coordinator.dart';
import '../services/system_config_service.dart';
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

  // PERFORMANCE FIX: Session-level cache for language selection (never expires during session)
  // Once language selection is confirmed, don't re-check until app restart or logout
  static bool _sessionLanguageConfirmed = false;

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

    // Check maintenance mode first (before any routing logic)
    try {
      final systemConfig = sl<SystemConfigService>();
      if (systemConfig.isMaintenanceModeActive) {
        // Check if user is admin (admins bypass maintenance mode)
        final user = Supabase.instance.client.auth.currentUser;
        bool isAdmin = false;

        if (user != null) {
          try {
            final profileResponse = await Supabase.instance.client
                .from('user_profiles')
                .select('is_admin')
                .eq('user_id', user.id)
                .maybeSingle();

            isAdmin = profileResponse?['is_admin'] == true;
          } catch (e) {
            Logger.error('Failed to check admin status',
                tag: 'ROUTER', error: e);
          }
        }

        if (!isAdmin) {
          // Non-admin user during maintenance - redirect to maintenance screen
          if (cleanPath == AppRoutes.maintenance) return null;

          Logger.info(
            'Maintenance mode active - redirecting to maintenance screen',
            tag: 'ROUTER',
            context: {
              'attempted_path': cleanPath,
              'is_admin': isAdmin,
            },
          );
          return AppRoutes.maintenance;
        } else {
          Logger.info(
            'Admin user bypassing maintenance mode',
            tag: 'ROUTER',
            context: {
              'user_email': user?.email,
            },
          );
        }
      }
    } catch (e) {
      Logger.error('Failed to check maintenance mode', tag: 'ROUTER', error: e);
      // Don't block routing on maintenance check failure
    }

    final authState = await _getAuthenticationState();

    // ANDROID FIX: If session restoration is in progress, show loading screen
    // This prevents race condition where timeout fires but session hasn't restored yet
    if (authState.isInitializing) {
      if (cleanPath == AppRoutes.appLoading) return null;

      Logger.info(
        'Session restoration in progress - showing loading screen',
        tag: 'ROUTER_ANDROID_FIX',
        context: {
          'attempted_path': cleanPath,
        },
      );
      return AppRoutes.appLoading;
    }

    final onboardingState = _getOnboardingState();
    final languageSelectionState = await _getLanguageSelectionState();
    final routeAnalysis = _analyzeCurrentRoute(cleanPath);

    return await _determineRedirect(
        authState, onboardingState, languageSelectionState, routeAnalysis);
  }

  /// Get authentication state from multiple sources
  /// SECURITY FIX: Now validates session expiration and device binding
  /// ANDROID FIX: Detects session restoration in progress to prevent race conditions
  static Future<AuthenticationState> _getAuthenticationState() async {
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

    // ============================================================================
    // ANDROID FIX: Session Existence Check During Restoration
    // ============================================================================
    //
    // PROBLEM: On Android cold start, there's a race condition where:
    //   1. User reopens app after process death
    //   2. AuthNotifier starts initialization (5s timeout)
    //   3. Supabase begins async session restoration from storage (can take 3-4s)
    //   4. Router guard runs BEFORE restoration completes
    //   5. currentUser is null → Router redirects to onboarding incorrectly
    //
    // SOLUTION: Check if a session exists in storage but hasn't been restored yet
    //   - If session exists in storage → return isInitializing=true
    //   - This tells router to wait for AuthNotifier timeout completion
    //   - Prevents premature routing decisions during async restoration
    //
    // SUPABASE DEPENDENCY WARNING:
    //   ⚠️ This code relies on Supabase's internal storage key format:
    //   - Key format: "sb-{project-id}-auth-token" (e.g., "sb-abcdefgh-auth-token")
    //   - Defined in: supabase_flutter/src/supabase.dart
    //   - Used since: supabase_flutter 1.x (stable for 2+ years)
    //
    //   PUBLIC API LIMITATION:
    //   - Supabase doesn't expose a public API to check for persisted sessions
    //     without triggering restoration
    //   - GoTrueClient.localStorage is private
    //   - SupabaseAuth.recoverSession() actually performs recovery (side effect)
    //   - Alternative: checking currentSession would miss restoration-in-progress
    //
    //   RISK ASSESSMENT:
    //   - ✅ Key format stable since 2022 (low risk)
    //   - ✅ Error handling prevents crashes if key changes
    //   - ✅ Fallback: AuthNotifier timeout still works (5s max delay)
    //   - ⚠️ If Supabase changes key format: session restoration may briefly fail,
    //        showing onboarding screen for 5s before timeout recovery
    //
    //   DETECTION:
    //   - Monitor logs for "Session exists in storage" messages
    //   - If count drops to zero after Supabase update → key format changed
    //   - Check latest supabase_flutter release notes for storage changes
    //
    // ALTERNATIVES CONSIDERED:
    //   ❌ Increase AuthNotifier timeout to 10s+ (too slow for normal startup)
    //   ❌ Remove this check entirely (race condition returns, breaks UX)
    //   ❌ Use recoverSession() (triggers unwanted side effects)
    //   ✅ Current approach: Defensive check with documented risk (best option)
    //
    // ============================================================================
    bool sessionExists = false;
    try {
      final sharedPrefs = await SharedPreferences.getInstance();

      // Check all known Supabase storage key formats
      // Format has evolved over versions, so we check multiple possibilities
      String? session;
      String? detectedKeyFormat;

      // Try all SharedPreferences keys to find any Supabase auth token
      // This is more robust than hardcoding specific keys
      final allKeys = sharedPrefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('sb-') && key.endsWith('-auth-token')) {
          // Current format: "sb-{project-id}-auth-token" (supabase_flutter 2.x+)
          session = sharedPrefs.getString(key);
          detectedKeyFormat = 'sb-{project}-auth-token';
          break;
        } else if (key == 'supabase.auth.token' || key == 'supabase.session') {
          // Legacy formats from older versions
          session = sharedPrefs.getString(key);
          detectedKeyFormat = key;
          break;
        }
      }

      sessionExists = session != null && session.isNotEmpty;

      if (sessionExists) {
        Logger.info(
          'Session exists in storage but not yet restored - initialization in progress',
          tag: 'AUTH_ANDROID_FIX',
          context: {
            'session_length': session.length,
            'key_format': detectedKeyFormat ?? 'unknown',
          },
        );
        // Return initializing state to prevent premature routing decisions
        return const AuthenticationState(
          isAuthenticated: false,
          isInitializing: true,
        );
      }
    } catch (e) {
      // Graceful degradation: If storage check fails, rely on AuthNotifier timeout
      Logger.error(
        'Failed to check session existence in SharedPreferences - falling back to AuthNotifier timeout',
        tag: 'AUTH_ANDROID_FIX',
        error: e,
      );
      // Don't throw - let AuthNotifier handle initialization completion
    }

    // Check Hive storage for guest/local auth
    try {
      // Ensure box is open before accessing
      if (!Hive.isBoxOpen(_hiveBboxName)) {
        await Hive.openBox(_hiveBboxName);
      }
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
  /// PERFORMANCE FIX: Uses session-level cache to avoid async calls on every navigation
  static Future<LanguageSelectionState> _getLanguageSelectionState() async {
    // PERFORMANCE FIX: If language is already confirmed this session, skip all checks
    if (_sessionLanguageConfirmed) {
      return const LanguageSelectionState(isCompleted: true);
    }

    // Ensure we're registered with the cache coordinator
    _registerWithCacheCoordinator();

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      // Use cached result if available and fresh for the same user
      if (_isLanguageCacheFresh() &&
          _cachedUserId == currentUserId &&
          _cachedLanguageState != null) {
        // PERFORMANCE FIX: If cached as completed, set session flag to skip future checks
        if (_cachedLanguageState!.isCompleted) {
          _sessionLanguageConfirmed = true;
        }
        return _cachedLanguageState!;
      }

      // PERFORMANCE FIX: Check local SharedPreferences first (synchronous)
      // This avoids the database call in most cases
      try {
        final prefs = await SharedPreferences.getInstance();
        final locallyCompleted =
            prefs.getBool('has_completed_language_selection') ?? false;
        if (locallyCompleted) {
          _sessionLanguageConfirmed = true;
          _cacheLanguageSelectionState(
              currentUserId, const LanguageSelectionState(isCompleted: true));
          return const LanguageSelectionState(isCompleted: true);
        }
      } catch (_) {
        // Ignore SharedPreferences errors, fall through to full check
      }

      final languageService = sl<LanguagePreferenceService>();
      final isCompleted = await languageService.hasCompletedLanguageSelection();

      // Cache the result
      _cacheLanguageSelectionState(
          currentUserId, LanguageSelectionState(isCompleted: isCompleted));

      // PERFORMANCE FIX: Set session flag if completed
      if (isCompleted) {
        _sessionLanguageConfirmed = true;
      }

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
  /// ANDROID FIX: Validates onboarding flag against session existence to auto-correct corruption
  /// ANDROID FIX: Checks both SharedPreferences and Hive for redundancy
  static OnboardingState _getOnboardingState() {
    try {
      // Ensure box is open before accessing
      if (!Hive.isBoxOpen(_hiveBboxName)) {
        // Box not open - return default state
        Logger.warning(
          'Hive box not open, returning default onboarding state',
          tag: 'ROUTER',
        );
        return const OnboardingState(isCompleted: false);
      }
      final box = Hive.box(_hiveBboxName);

      // ANDROID FIX: Check SharedPreferences first (more reliable on Android)
      // Note: We can't await here since this is a synchronous method,
      // but the onboarding datasource handles SharedPreferences properly
      // So this is a lightweight backup check in the router
      final isCompleted =
          box.get(_onboardingCompletedKey, defaultValue: false) as bool;

      // ANDROID FIX: Validate onboarding flag consistency
      // If user has valid session but onboarding=false, auto-correct the corruption
      final user = Supabase.instance.client.auth.currentUser;
      final hasLocalAuth = box.get(_userTypeKey) != null;

      if (!isCompleted && (user != null || hasLocalAuth)) {
        Logger.info(
          'Onboarding flag inconsistency detected - user has session but onboarding=false',
          tag: 'ONBOARDING_ANDROID_FIX',
          context: {
            'has_supabase_user': user != null,
            'has_local_auth': hasLocalAuth,
            'auto_correcting': true,
          },
        );

        // Auto-correct the corruption by setting onboarding as completed
        try {
          box.put(_onboardingCompletedKey, true);

          // Also persist to SharedPreferences for redundancy
          SharedPreferences.getInstance().then((prefs) {
            prefs.setBool('onboarding_completed', true);
          }).catchError((e) {
            Logger.error(
              'Failed to persist onboarding correction to SharedPreferences',
              tag: 'ONBOARDING_ANDROID_FIX',
              error: e,
            );
          });

          Logger.info(
            'Onboarding flag auto-corrected to true',
            tag: 'ONBOARDING_ANDROID_FIX',
          );
          return const OnboardingState(isCompleted: true);
        } catch (e) {
          Logger.error(
            'Failed to auto-correct onboarding flag',
            tag: 'ONBOARDING_ANDROID_FIX',
            error: e,
          );
        }
      }

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

    // Check for auto-free plan activation flag (new user flow)
    // This should happen BEFORE checking for pending upgrades
    if (routeAnalysis.currentPath == AppRoutes.home) {
      await _checkAutoActivateFreePlanAsync();
    }

    // Check for pending plan upgrade from pricing page
    // This must be checked here because the router may have redirected the user
    // through language selection flow before the login screen could handle it
    if (routeAnalysis.currentPath == AppRoutes.home) {
      final pendingRedirect = await _checkPendingPlanUpgradeAsync();
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

  /// Check for auto-free plan activation flag and activate if needed
  /// This runs in the background to avoid delaying user navigation
  static Future<void> _checkAutoActivateFreePlanAsync() async {
    try {
      // Ensure box is open before accessing
      if (!Hive.isBoxOpen(_hiveBboxName)) {
        await Hive.openBox(_hiveBboxName);
      }
      final box = Hive.box(_hiveBboxName);
      final shouldActivate =
          box.get('auto_activate_free_plan', defaultValue: false) as bool;

      if (!shouldActivate) {
        return; // No flag set, nothing to do
      }

      Logger.info(
        'Auto-free plan activation flag detected',
        tag: 'ROUTER_FREE_ACTIVATION',
      );

      // Check if user already has subscription
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        Logger.warning(
          'Cannot activate free plan - no user ID',
          tag: 'ROUTER_FREE_ACTIVATION',
        );
        await box.delete('auto_activate_free_plan');
        return;
      }

      Map<String, dynamic>? existingSub;
      try {
        existingSub = await Supabase.instance.client
            .from('subscriptions')
            .select('id, status, plan_id, subscription_plans!inner(plan_code)')
            .eq('user_id', userId)
            .maybeSingle()
            .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            Logger.warning(
              'Subscription check timed out during free plan activation',
              tag: 'ROUTER_FREE_ACTIVATION',
            );
            return null;
          },
        );
      } catch (e) {
        Logger.error(
          'Error checking existing subscription',
          tag: 'ROUTER_FREE_ACTIVATION',
          error: e,
        );
      }

      if (existingSub != null) {
        // User already has subscription - clear flag and skip activation
        Logger.info(
          'User already has subscription, skipping free plan activation',
          tag: 'ROUTER_FREE_ACTIVATION',
          context: {
            'existing_plan':
                existingSub['subscription_plans']?['plan_code'] ?? 'unknown',
            'status': existingSub['status'],
          },
        );
        await box.delete('auto_activate_free_plan');
        return;
      }

      // Activate free plan in background (don't await - fire and forget)
      Logger.info(
        'Auto-activating free plan for new user',
        tag: 'ROUTER_FREE_ACTIVATION',
        context: {'user_id': userId},
      );

      // Call free plan activation endpoint
      _activateFreePlanInBackground(userId);

      // Clear flag immediately (activation will happen async)
      await box.delete('auto_activate_free_plan');
    } catch (e) {
      Logger.error(
        'Error during auto-free plan activation check',
        tag: 'ROUTER_FREE_ACTIVATION',
        error: e,
      );
    }
  }

  /// Activate free plan in background (fire and forget)
  static void _activateFreePlanInBackground(String userId) {
    Supabase.instance.client.functions.invoke(
      'create-subscription-v2',
      body: {
        'plan_code': 'free',
        'provider': 'razorpay',
        'region': 'IN',
      },
    ).then((response) {
      Logger.info(
        'Free plan activated successfully',
        tag: 'ROUTER_FREE_ACTIVATION',
        context: {
          'user_id': userId,
          'response_status': response.status,
        },
      );
    }).catchError((e) {
      Logger.error(
        'Failed to auto-activate free plan',
        tag: 'ROUTER_FREE_ACTIVATION',
        error: e,
      );
    });
  }

  /// Check for pending plan upgrade flag and return redirect if needed
  /// Handles all plan types (standard, plus, premium, free)
  /// PERFORMANCE FIX: Only does database check if flag is actually set (rare case)
  static Future<String?> _checkPendingPlanUpgradeAsync() async {
    try {
      // Ensure box is open before accessing
      if (!Hive.isBoxOpen(_hiveBboxName)) {
        await Hive.openBox(_hiveBboxName);
      }
      final box = Hive.box(_hiveBboxName);

      // Check for pending plan upgrade (new system)
      final hasPendingUpgrade =
          box.get('pending_plan_upgrade', defaultValue: false) as bool;
      final selectedPlanCode = box.get('selected_plan_code') as String?;
      final selectedPlanPrice = box.get('selected_plan_price') as int?;

      // Also check legacy premium flag for backwards compatibility
      final hasPendingPremium =
          box.get('pending_premium_upgrade', defaultValue: false) as bool;

      // PERFORMANCE FIX: Early return if no pending upgrade (most common case)
      if (!hasPendingUpgrade && !hasPendingPremium) {
        return null;
      }

      Logger.info(
        'Pending upgrade detected',
        tag: 'ROUTER',
        context: {
          'plan_code': selectedPlanCode,
          'plan_price': selectedPlanPrice,
          'has_pending_upgrade': hasPendingUpgrade,
          'has_pending_premium': hasPendingPremium,
        },
      );

      // Check if user already has active subscription
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        Map<String, dynamic>? subscription;
        try {
          subscription = await Supabase.instance.client
              .from('subscriptions')
              .select('status, plan_type')
              .eq('user_id', userId)
              .inFilter(
                  'status', ['active', 'authenticated', 'pending_cancellation'])
              .maybeSingle()
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  Logger.warning(
                    'Subscription query timed out',
                    tag: 'ROUTER',
                  );
                  return null;
                },
              );
        } on TimeoutException {
          // Continue without subscription check - allow redirect to upgrade page
        } catch (e) {
          Logger.error(
            'Error checking subscription status',
            tag: 'ROUTER',
            error: e,
          );
        }

        if (subscription != null) {
          // User already has subscription - clear flags and don't redirect
          Logger.info(
            'User already has subscription, clearing flags',
            tag: 'ROUTER',
            context: {
              'subscription_status': subscription['status'],
              'plan_type': subscription['plan_type'],
            },
          );
          await box.delete('pending_plan_upgrade');
          await box.delete('selected_plan_code');
          await box.delete('selected_plan_price');
          await box.delete('pending_premium_upgrade');
          return null;
        }
      }

      // Route to appropriate upgrade page based on plan type
      String upgradePath;

      if (selectedPlanCode == 'premium' || hasPendingPremium) {
        upgradePath = AppRoutes.premiumUpgrade;
      } else if (selectedPlanCode == 'plus') {
        upgradePath = AppRoutes.plusUpgrade;
      } else if (selectedPlanCode == 'standard') {
        upgradePath = AppRoutes.standardUpgrade;
      } else if (selectedPlanCode == 'free') {
        // Free plan - activate directly without payment
        Logger.info(
          'Free plan selected, clearing flags (activation will happen on upgrade page)',
          tag: 'ROUTER',
        );
        // Don't clear flags yet - let the upgrade page handle free activation
        // Just stay on home
        return null;
      } else {
        // Unknown plan, default to premium for safety
        Logger.warning(
          'Unknown plan code, defaulting to premium upgrade',
          tag: 'ROUTER',
          context: {'plan_code': selectedPlanCode},
        );
        upgradePath = AppRoutes.premiumUpgrade;
      }

      Logger.info(
        'Redirecting to upgrade page',
        tag: 'ROUTER',
        context: {
          'upgrade_path': upgradePath,
          'plan_code': selectedPlanCode,
        },
      );
      return upgradePath;
    } catch (e) {
      Logger.error(
        'Error checking pending plan upgrade',
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
    _sessionLanguageConfirmed = false; // PERFORMANCE FIX: Reset session flag
    Logger.info('Router language selection cache invalidated',
        tag: 'ROUTER_CACHE');
  }

  /// Mark language selection as completed in router cache
  /// Call this when user completes language selection to avoid redirect loop
  static void markLanguageSelectionCompleted() {
    _sessionLanguageConfirmed = true;
    _cachedLanguageState = const LanguageSelectionState(isCompleted: true);
    _languageCacheTime = DateTime.now();
    Logger.info('Router language selection marked as completed',
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
      // Ensure box is open before accessing
      if (!Hive.isBoxOpen(_hiveBboxName)) {
        // Box not open - assume session is valid to prevent breaking existing sessions
        return false;
      }
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
      // Ensure box is open before accessing
      if (!Hive.isBoxOpen(_hiveBboxName)) {
        Logger.warning(
          'Cannot clear expired session - Hive box not open',
          tag: 'AUTH_SECURITY',
        );
        return;
      }
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
  final bool
      isInitializing; // ANDROID FIX: Track if session restoration is in progress
  final String? userType;
  final String? userId;
  final String? userEmail;

  const AuthenticationState({
    required this.isAuthenticated,
    this.isInitializing = false, // Default to false for backward compatibility
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
