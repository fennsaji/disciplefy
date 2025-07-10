# Supabase Edge Function: `feedback`

This document provides an analysis of the `feedback` Supabase Edge Function, detailing its purpose, implementation flows, and key functionalities for handling user feedback.

## 1. Purpose

The `feedback` Edge Function is designed to receive and process user feedback related to study guides and Jeff Reed sessions. Its core functionalities include:

-   **Feedback Submission**: Allows users to submit feedback, indicating whether a resource was helpful and providing an optional message and category.
-   **Sentiment Analysis**: Calculates a sentiment score for the feedback message.
-   **Security Validation**: Implements various security checks on the incoming request and feedback message.
-   **Resource Verification**: Ensures that the referenced `study_guide_id` or `jeff_reed_session_id` actually exist and are accessible.
-   **Analytics Tracking**: Logs feedback submission events for usage metrics and analysis.

## 2. Key Imports and Dependencies

The function relies on several modules and services:

-   **`serve` (Deno HTTP Server)**: For handling incoming HTTP requests.
-   **`createClient` (Supabase JS SDK)**: To interact with the Supabase API (database).
-   **`corsHeaders` (from `../_shared/cors.ts`)**: For handling Cross-Origin Resource Sharing.
-   **`SecurityValidator` (from `../_shared/security-validator.ts`)**: For input validation and security checks.
-   **`ErrorHandler`, `AppError` (from `../_shared/error-handler.ts`)**: For centralized error management and custom application errors.
-   **`RequestValidator` (from `../_shared/request-validator.ts`)**: For validating HTTP methods and environment variables.
-   **`AnalyticsLogger` (from `../_shared/analytics-logger.ts`)**: For logging analytics events.
-   **`FeedbackService` (from `./feedback-service.ts`)**: Contains business logic, specifically for sentiment analysis.
-   **`FeedbackRepository` (from `./feedback-repository.ts`)**: Handles database interactions for saving feedback and verifying resource existence.
-   **Deno Environment Variables**: Accesses `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

## 3. Execution Flow

The main `index.ts` file orchestrates the feedback submission process through a series of modular functions:

1.  **CORS Preflight Handling**: Responds to `OPTIONS` requests with appropriate CORS headers.
2.  **Environment and Method Validation**:
    *   `validateEnvironment()`: Checks for the presence of required environment variables (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
    *   `RequestValidator.validateHttpMethod()`: Ensures the request method is `POST`.
3.  **Dependency Initialization**:
    *   `createSupabaseClient()`: Creates a Supabase client, configured to use the `Authorization` header from the incoming request.
    *   `initializeDependencies()`: Instantiates `SecurityValidator`, `AnalyticsLogger`, `FeedbackService`, and `FeedbackRepository`.
4.  **Request Parsing and Validation**:
    *   `parseAndValidateRequest(req)`:
        *   Parses the request body as JSON.
        *   `validateFeedbackStructure()`: Validates the basic structure of the feedback request (e.g., `was_helpful` is boolean, at least one of `study_guide_id` or `jeff_reed_session_id` is provided).
        *   Validates optional fields like `category` (must be from `ALLOWED_CATEGORIES`) and `message` length.
        *   `validateUserContext()`: Validates the `user_context` object if provided (ensuring `user_id` for authenticated users and `session_id` for anonymous users).
5.  **Security Validation**:
    *   `performSecurityValidation()`:
        *   If a `message` is provided, it calls `securityValidator.validateInput()` to check for malicious content.
        *   If a security violation is detected, it logs a `security_violation` event but **sanitizes** the message instead of blocking the feedback entirely (allowing feedback to be submitted even if it contains potentially problematic content, but cleaning it first).
        *   Returns the original or sanitized message.
6.  **Resource Verification**:
    *   `verifyResourceAccess()`:
        *   If `study_guide_id` is provided, it calls `repository.verifyStudyGuideExists()` to ensure the study guide exists and the user has access.
        *   If `jeff_reed_session_id` is provided, it calls `repository.verifyJeffReedSessionExists()`.
        *   Throws `NOT_FOUND` if a referenced resource doesn't exist or access is denied.
7.  **Feedback Processing and Saving**:
    *   `processFeedback()`:
        *   Calls `feedbackService.calculateSentimentScore()` on the `validatedMessage` (if present).
        *   Prepares the feedback data, including `studyGuideId`, `jeffReedSessionId`, `userId`, `wasHelpful`, `message`, `category`, and `sentimentScore`.
        *   Calls `repository.saveFeedback()` to persist the feedback to the database.
8.  **Analytics Logging (Submission)**:
    *   `logFeedbackSubmission()`: Logs a `feedback_submitted` event to `analytics_events`, including details like `was_helpful`, `category`, `has_message`, `sentiment_score`, and user/session IDs.
9.  **Response Building**:
    *   `buildFeedbackResponse()`: Formats the saved feedback data into the `FeedbackResponse` structure.
    *   `createSuccessResponse()`: Creates a successful HTTP response (201 Created) with the formatted data and a success message.
10. **Error Handling**: A `try-catch` block wraps the entire process, using `ErrorHandler.handleError` to catch any exceptions and return a standardized error response.

## 4. Helper Functions and Modules

-   **`FeedbackService` (`./feedback-service.ts`)**:
    *   Currently, its primary responsibility is `calculateSentimentScore()`. This method is a placeholder (`TODO`) for actual sentiment analysis integration (e.g., with an external NLP API or a local model). For now, it returns a random score.
-   **`FeedbackRepository` (`./feedback-repository.ts`)**:
    *   Handles database interactions:
        *   `saveFeedback()`: Inserts the feedback record into the `feedback` table.
        *   `verifyStudyGuideExists()`: Checks if a `study_guides` entry exists and is accessible to the user (considering authentication status).
        *   `verifyJeffReedSessionExists()`: Checks if a `jeff_reed_sessions` entry exists.
-   **`SecurityValidator` (`../_shared/security-validator.ts`)**:
    *   Provides `validateInput()` for content-based security checks (e.g., detecting SQL injection, XSS, prompt injection patterns).
    *   Provides `sanitizeInput()` to clean potentially malicious input.
-   **`AnalyticsLogger` (`../_shared/analytics-logger.ts`)**:
    *   Used to log various events to the `analytics_events` table, providing insights into user behavior and system health.

## 5. Data Structures

-   **`FeedbackRequest`**: Defines the expected structure of the incoming request body.
-   **`FeedbackResponse`**: Defines the structure of the successful response data.
-   **`ApiResponse`**: The complete structure of the successful API response.

## 6. Configuration Constants

-   `DEFAULT_CATEGORY`: Default category for feedback if not provided.
-   `ALLOWED_CATEGORIES`: Whitelist of accepted feedback categories.
-   `MAX_MESSAGE_LENGTH`: Maximum allowed length for the feedback message.
-   `REQUIRED_ENV_VARS`: List of environment variables that must be present.

## 7. Security Considerations

-   **POST Method Enforcement**: Ensures feedback is submitted via POST, preventing data exposure in URLs.
-   **Input Validation**: Extensive validation of the request payload, including data types, presence of required fields, and length limits.
-   **Category Whitelisting**: Prevents arbitrary categories from being submitted.
-   **Security Validator Integration**: Uses a shared `SecurityValidator` to check feedback messages for malicious patterns.
-   **Sanitization over Blocking**: For feedback messages, the function chooses to sanitize potentially malicious content rather than outright blocking the submission. This is a deliberate choice to ensure all user feedback is captured, even if it's malformed, while still protecting the system.
-   **Resource Access Verification**: Crucially, it verifies that the `study_guide_id` or `jeff_reed_session_id` actually exist and that the user has permission to provide feedback on them, preventing feedback on non-existent or unauthorized resources.
-   **Authentication/Session Context**: The `user_context` in the request allows associating feedback with authenticated users (`user_id`) or anonymous sessions (`session_id`), which is important for tracking and analysis.

This `feedback` Edge Function is a well-structured and secure endpoint for collecting valuable user insights, demonstrating best practices in validation, security, and modular design.
