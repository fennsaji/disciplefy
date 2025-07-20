# Google OAuth Flow Analysis and Fix (v2)

**Date**: July 20, 2025

This document provides an updated and comprehensive analysis of the Google OAuth flow, identifying the root cause of the incorrect post-login redirect and detailing the architectural issues that contribute to it.

---

## 1. The Problem: Incorrect Post-Login Redirect

-   **Observed Behavior**: After a user successfully authenticates with Google, the app redirects them to `/#/onboarding` instead of the home screen (`/`).
-   **Expected Behavior**: A successfully authenticated user who has already completed onboarding should be directed straight to the home screen.
-   **Impact**: This creates a frustrating user experience, forcing users to re-enter the onboarding flow.

---

## 2. Deeper Flow Analysis: Tracing the Bug

The issue stems from a critical inconsistency in how the application's state (specifically the `onboarding_completed` flag) is managed across different parts of the codebase, combined with conflicting routing logic.

1.  **Authentication Trigger**: The user initiates Google login from `LoginScreen`, which dispatches a `GoogleSignInRequested` event to the `AuthBloc`.
2.  **OAuth Redirect & Callback**: The app correctly redirects to Google. After authentication, Google redirects back to `http://localhost:59641/auth/callback` with an authorization `code`.
3.  **Callback Handling**: The `AuthCallbackPage` receives the `code` and dispatches a `GoogleOAuthCallbackRequested` event to the `AuthBloc`.
4.  **Session Creation**: The `AuthBloc` calls `AuthService`, which successfully exchanges the code for a Supabase session. The `AuthService` then calls `CoreAuthService.AuthService.storeAuthData`.
5.  **The Root Cause - Inconsistent State Storage**:
    -   The `CoreAuthService.AuthService.storeAuthData` method writes `onboarding_completed: 'true'` to **`FlutterSecureStorage`** (see `frontend/lib/core/services/auth_service.dart`).
    -   However, the `AppRouter`'s redirect logic reads the `onboarding_completed` flag from **`Hive.box('app_settings')`** (see `frontend/lib/core/router/app_router.dart`).
    -   Because the flag is **never written to Hive** during the Google login flow, the router always assumes a new user has not completed onboarding.
6.  **Routing Conflict**: The `AuthCallbackPage` listener attempts to navigate to `/` upon success. However, the main `GoRouter`'s `redirect` logic intercepts this. It sees an authenticated user but, because the Hive value is `false`, it forces a redirect to `/onboarding`.

---

## 3. Architectural Issues Contributing to the Bug

-   **Dual Storage Mechanisms**: Using both `Hive` and `FlutterSecureStorage` for related flags (`onboarding_completed`, `user_type`) is an anti-pattern that directly caused this bug. There must be a single source of truth for application state.
-   **Conflicting Router Logic**: The routing logic is split between the `initialLocation` function and the `redirect` function in `AppRouter`. This creates confusion and potential race conditions. The `redirect` function should be the single source of truth for all routing decisions.
-   **Dual `AuthService` Implementations**: The presence of two `AuthService` files (`core/services/auth_service.dart` and `features/auth/data/services/auth_service.dart`) is a critical architectural flaw that leads to inconsistent behavior. The guest login flow in `OnboardingWelcomePage` uses the `core` service, which has a different implementation than the main `AuthService` used by the `AuthBloc`.

---

## 4. Comprehensive Solution

### Step 1: Unify State Storage (Primary Fix)

-   **Action**: Modify `CoreAuthService.AuthService.storeAuthData` to write the `onboarding_completed` flag to `Hive`, ensuring the router has access to the correct state.
-   **File to Update**: `frontend/lib/core/services/auth_service.dart`

    **Recommended Change:**
    ```dart
    // In CoreAuthService.AuthService.storeAuthData
    static Future<void> storeAuthData({
      required String accessToken,
      required String userType,
      String? userId,
    }) async {
      await _secureStorage.write(key: _authTokenKey, value: accessToken);
      await _secureStorage.write(key: _userTypeKey, value: userType);
      if (userId != null) {
        await _secureStorage.write(key: _userIdKey, value: userId);
      }
      await _secureStorage.write(key: _onboardingCompletedKey, value: 'true');

      // CRITICAL FIX: Also write to Hive for router consistency
      try {
        final box = await Hive.openBox('app_settings');
        await box.put('user_type', userType);
        if (userId != null) {
          await box.put('user_id', userId);
        }
        await box.put('onboarding_completed', true);
      } catch (e) {
        print('Warning: Failed to store auth data in Hive: $e');
      }
    }
    ```

### Step 2: Refactor and Simplify Router Logic

-   **Action**: Consolidate all routing decisions into the `redirect` function to create a single, clear, and robust guard for all navigation events.
-   **File to Update**: `frontend/lib/core/router/app_router.dart`

    **Recommended Change:**
    ```dart
    // In AppRouter
    static final GoRouter router = GoRouter(
      initialLocation: '/', // Let the redirect logic handle the initial route
      redirect: (context, state) {
        final box = Hive.box('app_settings');
        final onboardingCompleted = box.get('onboarding_completed', defaultValue: false) as bool;
        final user = Supabase.instance.client.auth.currentUser;
        final isAuthenticated = user != null;

        final isGoingToLogin = state.matchedLocation == AppRoutes.login;
        final isGoingToOnboarding = state.matchedLocation.startsWith(AppRoutes.onboarding);

        // Case 1: User is not authenticated
        if (!isAuthenticated) {
          return isGoingToLogin || isGoingToOnboarding ? null : AppRoutes.login;
        }

        // Case 2: User is authenticated but has not completed onboarding
        if (isAuthenticated && !onboardingCompleted) {
          return isGoingToOnboarding ? null : AppRoutes.onboarding;
        }

        // Case 3: User is authenticated and has completed onboarding
        if (isAuthenticated && onboardingCompleted) {
          return isGoingToLogin || isGoingToOnboarding ? AppRoutes.home : null;
        }

        return null; // No redirect needed
      },
      routes: [/* ... */],
    );
    ```

### Step 3: Deprecate and Remove Redundant Code

-   **Action**: To prevent future inconsistencies, the redundant `AuthService` in the `core` directory must be removed, and all UI components should interact exclusively with the `AuthBloc`.
    1.  Delete `frontend/lib/core/services/auth_service.dart`.
    2.  Refactor `OnboardingWelcomePage` to dispatch an `AnonymousSignInRequested` event to the `AuthBloc` instead of handling the guest login via direct HTTP calls.

By implementing these changes, the application will have a single source of truth for authentication and onboarding state, and a robust, centralized routing logic that correctly handles all user scenarios.