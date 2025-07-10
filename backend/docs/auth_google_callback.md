# Google OAuth Callback Edge Function (`auth-google-callback`)

This document provides an analysis of the `auth-google-callback` Supabase Edge Function, detailing its purpose, implementation flows, and key functionalities.

## 1. Purpose

The `auth-google-callback` Edge Function serves as the backend endpoint for handling the callback from Google's OAuth 2.0 authorization flow. After a user successfully authenticates with Google, Google redirects back to this function with an authorization code. This function's primary role is to exchange that code for a Supabase user session, manage user data, perform security checks, and facilitate the migration of anonymous user data to the newly authenticated account.

## 2. Key Imports and Dependencies

The function relies on several modules and services:

-   **`serve` (Deno HTTP Server)**: For handling incoming HTTP requests.
-   **`createClient` (Supabase JS SDK)**: To interact with the Supabase API (authentication, database, functions).
-   **`corsHeaders` (from `_shared/cors.ts`)**: For handling Cross-Origin Resource Sharing.
-   **`ErrorHandler`, `AppError` (from `_shared/error-handler.ts`)**: For centralized error management and custom application errors.
-   **`SecurityValidator` (from `_shared/security-validator.ts`)**: For implementing various security checks like rate limiting and referer validation.
-   **`AnalyticsLogger` (from `_shared/analytics-logger.ts`)**: For logging analytics events.
-   **Deno Environment Variables**: Accesses `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

## 3. Execution Flow

The function processes incoming requests through the following steps:

1.  **CORS Preflight Handling**: Responds to `OPTIONS` requests with appropriate CORS headers.
2.  **Method Validation**: Ensures the request method is `POST` for security reasons; otherwise, it throws a `METHOD_NOT_ALLOWED` error.
3.  **Supabase Client Initialization**: Initializes a Supabase client using environment variables, configured not to auto-refresh or persist sessions.
4.  **Request Body Parsing**: Parses the incoming JSON request body, expecting a `code` (authorization code) or an `error` parameter from Google.
5.  **OAuth Error Handling**: If the request contains an `error` parameter (indicating an OAuth failure from Google), it logs the OAuth error and throws an `OAUTH_ERROR`.
6.  **Authorization Code Validation**: Checks if the `code` parameter is present and is a valid string.
7.  **Security Validation**:
    *   Calls `SecurityValidator.validateRequest` to perform checks such as rate limiting (max 30 requests per hour) and referer validation (allowing Google, localhost, and `disciplefy.com`).
    *   If security validation fails, it logs a `SECURITY_VIOLATION` event and throws an `AppError`.
8.  **CSRF Protection (State Parameter Validation)**:
    *   If a `state` parameter is present in the request, it calls `validateStateParameter` to ensure it's a valid UUID format.
    *   (Note: The current `validateStateParameter` only checks format and does not fully implement state persistence/lookup, which is crucial for robust CSRF protection in a production environment.)
    *   If state validation fails, it logs a `CSRF_INVALID_STATE` security event and throws a `CSRF_VALIDATION_FAILED` error.
9.  **Exchange Authorization Code for Session**: Uses `supabaseClient.auth.exchangeCodeForSession(code)` to get a Supabase user session.
    *   Handles potential errors during the exchange, logging them as `OAUTH_EXCHANGE_FAILED`.
    *   Ensures a valid session and user object are returned; otherwise, it throws an `OAUTH_SESSION_FAILED` error.
10. **Log Successful Authentication**: Records the successful authentication event in the `analytics_events` table, including user details and metadata.
11. **Anonymous Session Migration**:
    *   Calls `handleAnonymousSessionMigration` to check if the user was previously anonymous (identified by an `x-anonymous-session-id` header).
    *   If an anonymous session with associated study guides is found, it attempts to migrate these guides to the newly authenticated user's account in the `study_guides` table.
    *   Marks the anonymous session as migrated.
12. **Prepare Response**: Constructs a `GoogleCallbackResponse` object containing the new Supabase session details (access token, refresh token, user info) and a `redirect_url`.
13. **Analytics Logging**: Logs an `oauth_login_success` event using `AnalyticsLogger`, including details about the provider, email verification status, and whether anonymous migration occurred.
14. **Send Response**: Returns the JSON response with appropriate headers and a 200 status code.
15. **General Error Handling**: A `try-catch` block wraps the entire process, using `ErrorHandler.handleError` to catch any exceptions and return a standardized error response.

## 4. Helper Functions

-   **`validateStateParameter(supabaseClient, state)`**:
    *   Currently, it primarily validates if the `state` parameter is in a UUID format using a regex.
    *   **Important**: For full CSRF protection, this function should also verify that the `state` parameter matches a value previously generated by the server and stored (e.g., in a temporary database or cache) for the specific user's session. The current implementation is a basic placeholder.
-   **`logOAuthError(supabaseClient, errorData, req)`**:
    *   Logs details of OAuth-related errors (e.g., Google denying access) to the `llm_security_events` table.
    *   Records `event_type` as `oauth_callback_error`, `input_text`, `risk_score`, `action_taken`, `detection_details`, and `ip_address`.
-   **`logSecurityEvent(supabaseClient, eventType, req, details)`**:
    *   Logs general security-related events (e.g., CSRF failures, rate limit breaches) to the `llm_security_events` table.
    *   Records `event_type`, `input_text`, `risk_score`, `action_taken` (typically 'blocked'), `detection_details`, and `ip_address`.
-   **`logSuccessfulAuth(supabaseClient, user, req)`**:
    *   Logs successful authentication events to the `analytics_events` table.
    *   Records `user_id`, `event_type` (`oauth_login_success`), `event_data` (provider, email, user metadata), `ip_address`, `user_agent`, and `created_at`.
-   **`handleAnonymousSessionMigration(supabaseClient, userId, req)`**:
    *   Retrieves the `x-anonymous-session-id` header from the request.
    *   Queries the `anonymous_sessions` table (and related `anonymous_study_guides`) for the given session ID.
    *   If an unmigrated anonymous session with study guides is found, it maps these guides to the newly authenticated `user_id` and inserts them into the `study_guides` table.
    *   Updates the `anonymous_sessions` table to mark the session as `is_migrated: true`.
    *   Returns an object indicating whether migration occurred and how many guides were migrated.
-   **`determineRedirectUrl(req, user)`**:
    *   Determines the appropriate URL to redirect the user to after successful authentication.
    *   Prioritizes a `x-redirect-url` header if provided.
    *   For mobile clients (identified by user agent or lack of referer), it constructs a deep link (`com.disciplefy.bible_study_app://auth/callback`).
    *   For web clients, it uses `http://localhost:59641/auth/callback` for local development and `https://disciplefy.com/auth/callback` for production.

## 5. Security Considerations

The function incorporates several security measures:

-   **POST Method Enforcement**: Prevents sensitive data from being exposed in URLs.
-   **Referer Validation**: Helps mitigate CSRF attacks by ensuring requests originate from expected domains.
-   **Rate Limiting**: Protects against brute-force attacks and abuse.
-   **State Parameter Validation**: Aims to prevent CSRF attacks, though the current implementation is basic and needs enhancement for full protection (server-side state generation and validation).
-   **Logging**: Extensive logging of OAuth errors, security violations, and successful authentications provides an audit trail and helps detect suspicious activity.

## 6. Data Flow for Anonymous Migration

1.  A guest user (anonymous session) generates study guides. These are stored in `anonymous_study_guides` linked to an `anonymous_sessions` entry.
2.  The user decides to sign in with Google. The frontend sends the `x-anonymous-session-id` header with the Google OAuth callback request to this function.
3.  Upon successful Google authentication and session creation, `handleAnonymousSessionMigration` is called.
4.  It fetches the anonymous session and its associated guides.
5.  It then inserts these guides into the `study_guides` table, associating them with the newly authenticated `user_id`.
6.  The anonymous session is marked as migrated to prevent duplicate migration.

This function is a critical component of the authentication system, bridging Google OAuth with Supabase user management and ensuring a smooth transition for anonymous users to authenticated accounts.
