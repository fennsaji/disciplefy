# Supabase Edge Function: `study-generate`

This document provides a comprehensive analysis of the `study-generate` Supabase Edge Function, detailing its purpose, implementation flows, and key functionalities for generating AI-powered Bible study guides.

## 1. Purpose

The `study-generate` Edge Function is designed to:

-   Generate AI-powered Bible study guides based on user-provided scripture references or topics.
-   Implement a structured methodology for study guide content (Context, Interpretation, Related Verses, Reflection Questions, Prayer Points).
-   Enforce robust security measures, including input validation, content moderation, and rate limiting.
-   Persist generated study guides for both authenticated and anonymous users.
-   Track analytics for study guide generation events.

## 2. Key Imports and Dependencies

The function relies on several modules and services:

-   **`serve` (Deno HTTP Server)**: For handling incoming HTTP requests.
-   **`createClient` (Supabase JS SDK)**: To interact with the Supabase API (database, authentication).
-   **`corsHeaders` (from `../_shared/cors.ts`)**: For handling Cross-Origin Resource Sharing.
-   **`SecurityValidator` (from `../_shared/security-validator.ts`)**: For input validation and content moderation.
-   **`RateLimiter` (from `../_shared/rate-limiter.ts`)**: For controlling the frequency of requests to prevent abuse.
-   **`LLMService` (from `../_shared/llm-service.ts`)**: The core service for interacting with the Large Language Model to generate study guide content.
-   **`ErrorHandler`, `AppError` (from `../_shared/error-handler.ts`)**: For centralized error management and custom application errors.
-   **`RequestValidator` (from `../_shared/request-validator.ts`)**: For validating HTTP methods and request body structure.
-   **`AnalyticsLogger` (from `../_shared/analytics-logger.ts`)**: For logging analytics events.
-   **`StudyGuideService` (from `./study-guide-service.ts`)**: Orchestrates the LLM interaction and formats the generated study guide.
-   **`StudyGuideRepository` (from `./study-guide-repository.ts`)**: Handles database persistence for study guides.
-   **Deno Environment Variables**: Accesses `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

## 3. Execution Flow (`index.ts`)

The main `index.ts` file handles the HTTP request and orchestrates the study guide generation process:

1.  **CORS Preflight Handling**: Responds to `OPTIONS` requests with appropriate CORS headers.
2.  **Environment and Method Validation**:
    *   `validateEnvironment()`: Checks for the presence of required environment variables.
    *   `RequestValidator.validateHttpMethod()`: Ensures the request method is `POST`.
3.  **Dependency Initialization**:
    *   `createSupabaseClient()`: Creates a Supabase client, configured to use the `Authorization` header from the incoming request.
    *   `initializeDependencies()`: Instantiates `SecurityValidator`, `RateLimiter`, `AnalyticsLogger`, `StudyGuideService`, and `StudyGuideRepository`.
4.  **Request Parsing and Validation**:
    *   `parseAndValidateRequest(req)`:
        *   Parses the request body as JSON.
        *   Validates the request body against predefined rules (e.g., `input_type` must be 'scripture' or 'topic', `input_value` length, `language` allowed values).
        *   `validateUserContext()`: Validates the `user_context` object if provided (ensuring `user_id` for authenticated users and `session_id` for anonymous users).
5.  **Security Validation**:
    *   `performSecurityValidation()`: Calls `securityValidator.validateInput()` on the `input_value` to check for malicious content (e.g., prompt injection, inappropriate content). If a security violation is detected, it logs an event and throws an `AppError`, blocking the generation.
6.  **Rate Limiting**:
    *   `enforceRateLimit()`: Uses `RateLimiter` to check and enforce rate limits based on the user's context (authenticated `user_id` or anonymous `session_id`). If the limit is exceeded, it throws an `AppError`.
7.  **Generate Study Guide**:
    *   `generateStudyGuide()`: Calls `studyGuideService.generateStudyGuide()` to interact with the LLM and get the structured study guide content.
8.  **Store Study Guide**:
    *   `saveStudyGuide()`: Calls `repository.saveAuthenticatedStudyGuide()` or `repository.saveAnonymousStudyGuide()` based on the user's authentication status.
        *   For anonymous users, the `input_value` is hashed (`inputValueHash`) before storage for privacy.
9.  **Analytics Logging**:
    *   `logStudyGeneration()`: Logs a `study_guide_generated` event to `analytics_events`, including details like input type, language, and user context.
10. **Response Building**:
    *   `buildStudyGuideResponse()`: Formats the saved study guide data into the `StudyGuideResponse` structure.
    *   `createSuccessResponse()`: Creates a successful HTTP response (200 OK) with the generated study guide data and rate limit information.
11. **Error Handling**: A `try-catch` block wraps the entire process, using `ErrorHandler.handleError` to catch any exceptions and return a standardized error response.

## 4. Core Logic (`study-guide-service.ts`)

The `StudyGuideService` class is responsible for the actual generation of the study guide content using the LLM.

### 4.1. Properties

-   **`llmService`**: An instance of `LLMService`, which abstracts the interaction with the Large Language Model (e.g., Google Gemini, OpenAI GPT).

### 4.2. Methods

-   **`constructor()`**: Initializes the `LLMService`.
-   **`generateStudyGuide(params: StudyGuideGenerationParams): Promise<GeneratedStudyGuide>`**:
    *   **Input Validation**: `validateGenerationParams()` ensures the `inputType`, `inputValue`, and `language` are valid.
    *   **LLM Interaction**: Calls `this.llmService.generateStudyGuide()` to send the request to the LLM.
    *   **Result Formatting and Validation**: `formatStudyGuideResult()` validates the structure of the LLM's raw output (ensuring all required sections like `summary`, `context`, `relatedVerses` are present and correctly typed).
    *   **Sanitization**: `sanitizeText()` is applied to all text fields to normalize whitespace and prevent excessively long content, ensuring safe storage and display.

## 5. Data Persistence (`study-guide-repository.ts`)

The `StudyGuideRepository` class handles all database interactions related to study guides.

### 5.1. Properties

-   **`supabaseClient`**: A Supabase client instance for database operations.

### 5.2. Methods

-   **`saveAuthenticatedStudyGuide(userId: string, studyGuideData: StudyGuideData): Promise<StudyGuideRecord>`**:
    *   Saves a study guide to the `study_guides` table, associating it with a `user_id`.
    *   Performs validation on `userId` and `studyGuideData`.
-   **`saveAnonymousStudyGuide(sessionId: string, studyGuideData: AnonymousStudyGuideData): Promise<StudyGuideRecord>`**:
    *   Saves a study guide to the `anonymous_study_guides` table, associating it with a `session_id`.
    *   **Privacy**: Stores `inputValueHash` instead of `inputValue` for anonymous guides.
    *   Ensures the anonymous session exists (`ensureAnonymousSessionExists`) and updates its activity (`updateAnonymousSessionActivity`).
    *   Performs validation on `sessionId` and `studyGuideData`.
-   **`getAuthenticatedStudyGuides(userId: string, limit, offset): Promise<readonly StudyGuideRecord[]>`**:
    *   Retrieves study guides for an authenticated user from the `study_guides` table, with pagination and ordering.
-   **`getAnonymousStudyGuides(sessionId: string, limit, offset): Promise<readonly StudyGuideRecord[]>`**:
    *   Retrieves study guides for an anonymous session from the `anonymous_study_guides` table, with pagination and ordering.
-   **`deleteAuthenticatedStudyGuide(userId: string, studyGuideId: string): Promise<void>`**:
    *   Deletes a study guide for an authenticated user, ensuring the user can only delete their own guides.
-   **`ensureAnonymousSessionExists(sessionId: string): Promise<void>`**:
    *   Checks if an anonymous session exists; if not, it creates a new one with a 24-hour expiration.
-   **`updateAnonymousSessionActivity(sessionId: string): Promise<void>`**:
    *   Updates the `last_activity` timestamp for an anonymous session.
-   **Validation Helpers**: Includes private methods for validating `userId`, `sessionId`, `studyGuideId`, `StudyGuideData`, `AnonymousStudyGuideData`, and pagination parameters.

## 6. Security Considerations

-   **Input Validation**: Comprehensive validation of all incoming request parameters and LLM output.
-   **Content Moderation**: `SecurityValidator` checks `input_value` for malicious or inappropriate content, blocking generation if detected.
-   **Rate Limiting**: Protects the LLM and backend resources from abuse and denial-of-service attacks.
-   **Authentication/Authorization**: Differentiates between authenticated and anonymous users, storing data appropriately and ensuring users can only access/modify their own data.
-   **Privacy for Anonymous Users**: For anonymous users, the original `input_value` is not stored directly; instead, a hash (`inputValueHash`) is used, enhancing privacy.
-   **Error Handling**: Centralized error handling ensures consistent and secure error responses, preventing sensitive information leakage.
-   **Sanitization**: Sanitizes LLM output to prevent XSS or other injection vulnerabilities when displaying content.

## 7. Data Flow for Study Guide Generation

1.  **Client Request**: The frontend sends a `POST` request to the `study-generate` Edge Function with `input_type`, `input_value`, `language`, and `user_context`.
2.  **Validation & Security**: The function validates the request, performs security checks on the input, and enforces rate limits.
3.  **LLM Call**: `StudyGuideService` calls `LLMService` with the validated input to generate the study guide content.
4.  **LLM Response**: The LLM returns raw study guide content (summary, context, verses, questions, prayers).
5.  **Formatting & Sanitization**: `StudyGuideService` formats and sanitizes the LLM's output.
6.  **Persistence**: `StudyGuideRepository` saves the generated study guide to either `study_guides` (for authenticated users) or `anonymous_study_guides` (for anonymous users, with hashed input).
7.  **Analytics**: An analytics event is logged.
8.  **Response to Client**: The function returns the generated study guide data and rate limit information to the client.

This `study-generate` Edge Function is a complex but well-architected component that combines AI capabilities with robust backend services, security, and data management for a core application feature.
