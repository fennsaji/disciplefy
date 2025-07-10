# Supabase Edge Function: `study-guides`

This document provides an analysis of the `study-guides` Supabase Edge Function, detailing its purpose, implementation flows, and key functionalities for managing user-generated study guides.

## 1. Purpose

The `study-guides` Edge Function serves as an API endpoint for:

-   **Retrieving Study Guides**: Allows users to fetch their generated study guides, both saved and recent, with pagination support.
-   **Saving/Unsaving Study Guides**: Enables authenticated users to mark a study guide as "saved" or "unsaved".

## 2. Key Imports and Dependencies

The function relies on several modules and services:

-   **`serve` (Deno HTTP Server)**: For handling incoming HTTP requests.
-   **`createClient` (Supabase JS SDK)**: To interact with the Supabase API (database, authentication).
-   **`corsHeaders` (from `../_shared/cors.ts`)**: For handling Cross-Origin Resource Sharing.
-   **`ErrorHandler`, `AppError` (from `../_shared/error-handler.ts`)**: For centralized error management and custom application errors.
-   **`SecurityValidator` (from `../_shared/security-validator.ts`)**: For input validation.

## 3. Execution Flow

The main `index.ts` file handles the HTTP request and dispatches to appropriate handlers based on the HTTP method:

1.  **CORS Preflight Handling**: Responds to `OPTIONS` requests with appropriate CORS headers.
2.  **Supabase Client Initialization**: Initializes a Supabase client using environment variables (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`). The client's `Authorization` header is set from the incoming request, allowing it to act on behalf of the authenticated user if present.
3.  **User Context Retrieval**: `getUserContext()` attempts to extract the authenticated user's ID from the `Authorization` header. If no authenticated user is found, it assumes an anonymous session (though the `sessionId` extraction is currently a placeholder and needs to be properly implemented from request headers/body).
4.  **Method Dispatching**:
    *   If `req.method` is `GET`, it calls `handleGetStudyGuides()`.
    *   If `req.method` is `POST`, it calls `handleSaveUnsaveGuide()`.
    *   For any other method, it throws a `METHOD_NOT_ALLOWED` error.
5.  **Error Handling**: A `try-catch` block wraps the entire process, using `ErrorHandler.handleError` to catch any exceptions and return a standardized error response.

### 3.1. `handleGetStudyGuides` Flow (GET requests)

This function handles requests to retrieve study guides.

1.  **Query Parameter Parsing**: Extracts `saved` (boolean), `limit` (integer, default 20), and `offset` (integer, default 0) from the URL query parameters.
2.  **Authentication Check**:
    *   If the user is `isAuthenticated` and `userId` is available:
        *   It queries the `study_guides` table, filtering by `user_id`.
        *   If `savedOnly` is true, it further filters by `is_saved: true`.
        *   Results are ordered by `created_at` (descending) and paginated using `range`.
    *   If the user is anonymous (`sessionId` is available, though currently a placeholder):
        *   It queries the `anonymous_study_guides` table, filtering by `session_id`.
        *   Results are ordered by `created_at` (descending) and paginated using `range`.
    *   (Note: The current `sessionId` logic is a placeholder and needs to be properly implemented to extract the anonymous session ID from the request.)
3.  **Error Handling**: Catches database errors and throws `AppError`.
4.  **Response**: Returns a JSON response containing the list of `guides`, `total` count, and `hasMore` flag (indicating if more guides are available for pagination). Each guide is formatted using `formatStudyGuideResponse()`.

### 3.2. `handleSaveUnsaveGuide` Flow (POST requests)

This function handles requests to save or unsave a study guide.

1.  **Authentication Check**: Throws `UNAUTHORIZED` if the user is not authenticated.
2.  **Request Body Parsing**: Parses the request body, expecting `guide_id` and `action` (`'save'` or `'unsave'`).
3.  **Input Validation**:
    *   Checks for the presence of `guide_id` and `action`.
    *   Validates `action` to be either `'save'` or `'unsave'`.
    *   Uses `SecurityValidator.validateInput()` on `guide_id` to prevent injection attacks.
4.  **Update Study Guide Status**:
    *   Updates the `is_saved` status in the `study_guides` table for the given `guide_id` and `user_id`.
    *   Crucially, it includes `.eq('user_id', userId)` to ensure that a user can only modify their own study guides, preventing unauthorized access.
    *   Updates the `updated_at` timestamp.
5.  **Error Handling**:
    *   If the guide is not found or the user doesn't have permission (`PGRST116` error code from PostgREST), it throws a `NOT_FOUND` error.
    *   Catches other database errors and throws `AppError`.
6.  **Response**: Returns a JSON response indicating `success: true`, a success `message`, and the `guide` object that was updated.

## 4. Helper Functions

-   **`getUserContext(supabaseClient, authHeader)`**:
    *   Attempts to get the authenticated user from the `Authorization` header.
    *   **Important**: The anonymous `sessionId` logic is a placeholder (`sessionId = 'anonymous-session'`) and needs to be properly implemented to extract the actual anonymous session ID from the request (e.g., from a custom header `x-anonymous-session-id` or a cookie).
-   **`formatStudyGuideResponse(guide: any): StudyGuideResponse`**:
    *   Formats a raw study guide record from the database into a standardized `StudyGuideResponse` structure, ensuring all fields are present and correctly typed (e.g., providing default empty arrays for lists).

## 5. Security Considerations

-   **Authentication Enforcement**: `handleSaveUnsaveGuide` strictly requires an authenticated user.
-   **Authorization (Row-Level Security)**: When updating or fetching study guides, the function explicitly filters by `user_id` (`.eq('user_id', userId)`). This is a critical security measure that ensures users can only access or modify their own data, even if they try to manipulate `guide_id`s.
-   **Input Validation**: Basic validation for request parameters and `SecurityValidator` for `guide_id` helps prevent common web vulnerabilities.
-   **Method Restrictions**: Only `GET` and `POST` methods are allowed, limiting the attack surface.
-   **Error Handling**: Centralized error handling ensures consistent and secure error responses, preventing sensitive information leakage.
-   **Privacy for Anonymous Guides**: For anonymous guides, `input_value_hash` is returned instead of `input_value`, maintaining privacy.

## 6. Data Flow for Study Guide Management

### 6.1. Fetching Guides

1.  **Client Request (GET)**: Frontend sends a GET request to `/functions/v1/study-guides`, optionally with `saved=true`, `limit`, `offset`. It includes an `Authorization` header if the user is authenticated, or an `x-anonymous-session-id` header if anonymous.
2.  **User Context**: The function determines if the user is authenticated or anonymous.
3.  **Database Query**:
    *   **Authenticated**: Queries `study_guides` table by `user_id`.
    *   **Anonymous**: Queries `anonymous_study_guides` table by `session_id`.
4.  **Response**: Returns a paginated list of study guides.

### 6.2. Saving/Unsaving Guides

1.  **Client Request (POST)**: Frontend sends a POST request to `/functions/v1/study-guides` with `guide_id` and `action` (`'save'` or `'unsave'`). It *must* include an `Authorization` header.
2.  **Authentication & Authorization**: The function verifies the user is authenticated and that the `guide_id` belongs to them.
3.  **Database Update**: Updates the `is_saved` column in the `study_guides` table for the specified guide.
4.  **Response**: Returns a success message and the updated guide.

This `study-guides` Edge Function provides a secure and efficient way to manage user-generated study guides, leveraging Supabase's capabilities for data storage and access control.
