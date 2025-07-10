# Authentication Module Summary

This document provides an overview of the authentication module within the Disciplefy Bible Study app's frontend, focusing on its architecture, key components, and authentication flows.

## 1. Architecture Overview

The authentication module adheres to a Clean Architecture-inspired structure, separating concerns into three main layers:

-   **Data Layer (`data/`)**: Handles external data sources and services, primarily interacting with Supabase for authentication and user profile management.
-   **Domain Layer (`domain/`)**: Contains core business logic and entities, such as the `UserEntity` which defines the application's user model.
-   **Presentation Layer (`presentation/`)**: Manages the UI and user interactions, utilizing the BLoC (Business Logic Component) pattern for state management.

## 2. Key Components

### 2.1. `AuthService` (`data/services/auth_service.dart`)

This is the central service for all authentication-related operations. It abstracts away the complexities of interacting with Supabase and external OAuth providers (Google, Apple).

**Key Responsibilities:**

-   **Supabase Integration**: Manages user sessions, listens to authentication state changes, and interacts with Supabase's `auth` and `from` APIs.
-   **Google Sign-In**:
    -   **Web**: Initiates the Google OAuth flow using Supabase's `signInWithOAuth` with a custom redirect URL.
    -   **Mobile**: Integrates with `google_sign_in` package to get Google tokens, then calls a custom backend callback (`/auth-google-callback`) to exchange these tokens for a Supabase session.
-   **Apple Sign-In**: Initiates Apple OAuth flow via Supabase's `signInWithOAuth`.
-   **Anonymous Sign-In**: Allows users to proceed without a registered account using Supabase's anonymous sign-in.
-   **User Profile Management**: Provides methods to `getUserProfile`, `upsertUserProfile` (for language and theme preferences), and `deleteAccount`.
-   **Session Management**: Provides `currentUser`, `isAuthenticated`, and `authStateChanges` stream for real-time authentication status.
-   **Guest Session Migration**: Includes logic to pass an anonymous session ID to the backend during Google OAuth callback, suggesting a potential mechanism for migrating guest data to a registered account.

### 2.2. `OAuthRedirectHandler` (`data/services/oauth_redirect_handler.dart`)

This class is responsible for handling OAuth redirect URLs and deep links, especially on mobile platforms.

**Key Responsibilities:**

-   **Deep Link Handling**: Sets up a `MethodChannel` to receive redirect URLs from native platforms.
-   **OAuth Callback Processing**: Parses the incoming URL to extract OAuth parameters (code, state, error) and delegates the processing to `AuthService`.
-   **URL Launching**: Provides a utility to launch OAuth URLs in external applications (e.g., browser).

### 2.3. `UserEntity` (`domain/entities/user_entity.dart`)

A simple immutable data class representing the application's user. It extends `Equatable` for value equality comparisons.

**Key Attributes:**

-   `id`: Unique user identifier.
-   `email`, `name`, `avatarUrl`: User details.
-   `authProvider`: The authentication method used (e.g., 'google', 'apple', 'anonymous').
-   `languagePreference`, `themePreference`: User-specific settings.
-   `isAnonymous`: Flag indicating if the user is anonymous.
-   `createdAt`, `lastSignInAt`: Timestamps.

### 2.4. `AuthBloc` (`presentation/bloc/auth_bloc.dart`)

The BLoC responsible for managing the authentication state and reacting to authentication events. It uses `AuthService` to perform actual authentication operations.

**Key Responsibilities:**

-   **State Management**: Emits different `AuthState`s (Initial, Loading, Unauthenticated, Authenticated, Error) based on authentication events and `AuthService` responses.
-   **Event Handling**: Processes `AuthEvent`s such as `AuthInitializeRequested`, `GoogleSignInRequested`, `AnonymousSignInRequested`, `SignOutRequested`, `GoogleOAuthCallbackRequested`, and `DeleteAccountRequested`.
-   **Supabase Auth State Listener**: Subscribes to `AuthService.authStateChanges` to automatically update its state when Supabase's authentication state changes (e.g., token refresh, sign-out from another device).
-   **User Profile Integration**: Fetches and updates user profile data (language, theme) via `AuthService` upon successful authentication or explicit requests.
-   **Error Handling**: Catches exceptions from `AuthService` and emits `AuthErrorState` with descriptive messages.

### 2.5. `AuthEvent` (`presentation/bloc/auth_event.dart`)

Defines the events that can be dispatched to the `AuthBloc` to trigger authentication actions.

**Examples:**

-   `AuthInitializeRequested`: To check initial authentication status.
-   `GoogleSignInRequested`: To initiate Google sign-in.
-   `GoogleOAuthCallbackRequested`: To process the OAuth redirect callback.
-   `SignOutRequested`: To sign out the user.

### 2.6. `AuthState` (`presentation/bloc/auth_state.dart`)

Defines the different states the authentication module can be in.

**Examples:**

-   `AuthInitialState`: Initial state.
-   `AuthLoadingState`: Authentication operation in progress.
-   `UnauthenticatedState`: User is not logged in.
-   `AuthenticatedState`: User is logged in, contains `User` object and profile data.
-   `AuthErrorState`: An error occurred during authentication.

### 2.7. UI Pages (`presentation/pages/`)

-   **`LoginScreen`**: The primary entry point for authentication. It presents options for Google Sign-In and "Continue as Guest" (anonymous sign-in). It uses `BlocListener` to react to `AuthBloc` state changes and navigate accordingly or display error messages.
-   **`AuthCallbackPage`**: A dedicated page to handle OAuth redirect callbacks. It receives authorization codes/errors from the URL and dispatches `GoogleOAuthCallbackRequested` to the `AuthBloc` for processing. It shows a loading indicator and redirects to the home screen on success or login screen on error.
-   **`AuthPage`**: (Seems to be an older or alternative login screen, as `LoginScreen` appears to be the main one. It directly uses `AuthService` instead of `AuthBloc` for sign-in, which might indicate a different flow or an incomplete refactoring.)

## 3. Authentication Flows

### 3.1. Google Sign-In (Web)

1.  User taps "Continue with Google" on `LoginScreen`.
2.  `LoginScreen` dispatches `GoogleSignInRequested` to `AuthBloc`.
3.  `AuthBloc` calls `AuthService.signInWithGoogle()`.
4.  `AuthService._signInWithGoogleWeb()` initiates Supabase's OAuth flow, redirecting the user to Google's authentication page.
5.  After successful Google authentication, Google redirects back to the app's configured `authRedirectUrl`.
6.  The `AuthCallbackPage` intercepts this redirect, extracts the `code` and `state` parameters.
7.  `AuthCallbackPage` dispatches `GoogleOAuthCallbackRequested` to `AuthBloc`.
8.  `AuthBloc` calls `AuthService.processGoogleOAuthCallback()`.
9.  `AuthService._callGoogleOAuthCallback()` makes an HTTP POST request to the custom backend endpoint (`/auth-google-callback`) with the authorization `code`.
10. The backend exchanges the code for a Supabase session and returns it.
11. `AuthService` recovers the Supabase session and then calls `upsertUserProfile` to create/update the user's profile in the database.
12. `AuthBloc` receives the `AuthStateChanged` event from `AuthService`'s stream, updates its state to `AuthenticatedState`, and `LoginScreen` (or `AuthCallbackPage`) navigates the user to the home screen.

### 3.2. Google Sign-In (Mobile)

1.  User taps "Continue with Google" on `LoginScreen`.
2.  `LoginScreen` dispatches `GoogleSignInRequested` to `AuthBloc`.
3.  `AuthBloc` calls `AuthService.signInWithGoogle()`.
4.  `AuthService._signInWithGoogleMobile()` initiates the `google_sign_in` flow, prompting the user to select a Google account.
5.  Upon successful Google sign-in, `google_sign_in` provides `accessToken` and `idToken`.
6.  `AuthService._callGoogleOAuthCallback()` is invoked with these tokens.
7.  Similar to the web flow, an HTTP POST request is made to the custom backend endpoint (`/auth-google-callback`).
8.  The backend processes the tokens, exchanges them for a Supabase session, and returns it.
9.  `AuthService` recovers the Supabase session and calls `upsertUserProfile`.
10. `AuthBloc` receives `AuthStateChanged`, updates its state to `AuthenticatedState`, and the UI navigates to the home screen.

### 3.3. Anonymous Sign-In

1.  User taps "Continue as Guest" on `LoginScreen`.
2.  `LoginScreen` dispatches `AnonymousSignInRequested` to `AuthBloc`.
3.  `AuthBloc` calls `AuthService.signInAnonymously()`.
4.  `AuthService` uses Supabase's `signInAnonymously()` method.
5.  `AuthBloc` receives `AuthStateChanged` (signed out event), updates its state to `AuthenticatedState` (with `isAnonymous: true`), and the UI navigates to the home screen.

### 3.4. Sign-Out

1.  User requests sign-out (e.g., from a settings page).
2.  `SignOutRequested` event is dispatched to `AuthBloc`.
3.  `AuthBloc` calls `AuthService.signOut()`.
4.  `AuthService` signs out from Google (if applicable) and then from Supabase.
5.  `AuthBloc` receives `AuthStateChanged` (signed out event), updates its state to `UnauthenticatedState`, and the UI navigates to the login screen.

### 3.5. Account Deletion

1.  User requests account deletion.
2.  `DeleteAccountRequested` event is dispatched to `AuthBloc`.
3.  `AuthBloc` calls `AuthService.deleteAccount()`.
4.  `AuthService` deletes the user's profile from the `user_profiles` table (which might trigger cascades for related data in Supabase) and then signs out the user.
5.  `AuthBloc` updates its state to `UnauthenticatedState`.

## 4. Error Handling

The module incorporates robust error handling at multiple levels:

-   **`AuthService`**: Catches exceptions during API calls and rethrows them, often with more descriptive messages. It handles specific backend error codes (e.g., `RATE_LIMITED`, `CSRF_VALIDATION_FAILED`).
-   **`AuthBloc`**: Catches errors from `AuthService` and emits `AuthErrorState` with user-friendly messages, distinguishing between user cancellations, network errors, and backend-specific issues.
-   **UI (`LoginScreen`, `AuthCallbackPage`)**: Uses `ScaffoldMessenger` to display `SnackBar` messages for errors, providing immediate feedback to the user. It also handles redirection to the login screen upon critical authentication errors.

## 5. User Profile and Preferences

Upon successful authentication (for non-anonymous users), the `AuthService` automatically calls `upsertUserProfile` to ensure a user profile exists in the Supabase `user_profiles` table. This profile stores preferences like `languagePreference` and `themePreference`. The `AuthBloc` also fetches this profile data and makes it available in the `AuthenticatedState`.

## 6. Potential Improvements/Considerations

-   **`AuthPage` vs. `LoginScreen`**: Clarify which page is the intended login entry point and remove redundancy if `AuthPage` is deprecated.
-   **Error Message Localization**: Currently, error messages are hardcoded strings. For a multi-language app, these should be localized.
-   **Test Coverage**: Ensure comprehensive unit and integration tests for `AuthService` and `AuthBloc` to cover all authentication flows and error scenarios.
-   **Security Best Practices**: Review `AppConfig` usage for sensitive keys and ensure they are handled securely (e.g., not committed directly to source control).
-   **Deep Link Configuration**: Document the necessary deep link configurations for iOS and Android to ensure OAuth redirects work correctly.
-   **Guest to Registered User Migration**: While the `X-Anonymous-Session-ID` header is passed, the actual backend logic for migrating anonymous user data to a newly registered account is not detailed here but is implied. This is a critical flow that needs to be robustly handled.
-   **Apple Sign-In Callback**: The current implementation for Apple Sign-In in `AuthService` only initiates the OAuth flow. It's not explicitly shown how the callback for Apple is handled, though it's likely similar to Google's, relying on `OAuthRedirectHandler`.

This summary provides a comprehensive understanding of the authentication module's design and functionality.