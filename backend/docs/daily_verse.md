# Supabase Edge Function: `daily-verse`

This document provides an analysis of the `daily-verse` Supabase Edge Function, detailing its purpose, implementation flows, and key functionalities for serving daily Bible verses.

## 1. Purpose

The `daily-verse` Edge Function is designed to provide daily Bible verses in multiple translations (ESV, Hindi, Malayalam). Its core purpose is to:

-   Serve a consistent "Verse of the Day" to users.
-   Minimize external API calls by implementing a caching mechanism.
-   Ensure reliability and offline support through deterministic fallback verses.
-   Track usage metrics for analytics.

## 2. Key Imports and Dependencies

The function relies on several modules and services:

-   **`serve` (Deno HTTP Server)**: For handling incoming HTTP requests.
-   **`corsHeaders` (from `../_shared/cors.ts`)**: For handling Cross-Origin Resource Sharing.
-   **`ErrorHandler` (from `../_shared/error-handler.ts`)**: For centralized error management.
-   **`RequestValidator` (from `../_shared/request-validator.ts`)**: For validating HTTP methods.
-   **`AnalyticsLogger` (from `../_shared/analytics-logger.ts`)**: For logging analytics events.
-   **`DailyVerseService` (from `./daily-verse-service.ts`)**: The core logic for fetching, generating, and caching verses.

## 3. Execution Flow (`index.ts`)

The main `index.ts` file handles the HTTP request and orchestrates the calls to the `DailyVerseService`.

1.  **CORS Preflight Handling**: Responds to `OPTIONS` requests with appropriate CORS headers.
2.  **Request Logging**: Logs the incoming request method and URL for debugging.
3.  **Method Validation**: Uses `RequestValidator.validateHttpMethod` to ensure only `GET` requests are allowed.
4.  **Query Parameter Parsing**: Extracts the `date` query parameter (if present) from the request URL.
5.  **Service Initialization**: Initializes `DailyVerseService` and `AnalyticsLogger`.
6.  **Get Daily Verse Data**: Calls `dailyVerseService.getDailyVerse(requestDate)` to retrieve the verse.
7.  **Analytics Logging (Success)**: If the verse is successfully retrieved, it logs a `daily_verse_fetched` event to `analytics_events`, including the verse date, whether a custom date was requested, and a truncated user agent.
8.  **Return Response**: Returns a JSON response with `success: true`, the `verseData`, and appropriate headers, including `Cache-Control` for 1-hour caching.
9.  **Error Handling**: If any error occurs during the process:
    *   It logs a `daily_verse_error` event to `analytics_events`.
    *   It uses `ErrorHandler.handleError` to return a standardized error response.

## 4. Core Logic (`daily-verse-service.ts`)

The `DailyVerseService` class encapsulates the main business logic for the daily verse feature.

### 4.1. Properties

-   **`supabase`**: A Supabase client instance, initialized with `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` (or `SUPABASE_ANON_KEY` as fallback). This client is used to interact with the `daily_verses_cache` table.
-   **`CACHE_TABLE`**: Constant for the cache table name (`daily_verses_cache`).
-   **`FALLBACK_VERSES`**: A hardcoded array of pre-selected Bible verses (John 3:16, Psalm 23:1, etc.) in ESV, Hindi, and Malayalam. These serve as reliable fallbacks.

### 4.2. Methods

-   **`constructor()`**: Initializes the Supabase client.
-   **`getSupabaseClient()`**: Returns the initialized Supabase client.
-   **`getDailyVerse(requestDate?: string | null): Promise<DailyVerseData>`**:
    *   This is the main method for retrieving a daily verse.
    *   Determines the `targetDate` (today or the `requestDate`).
    *   **Caching Strategy**:
        1.  Attempts to retrieve the verse from the `daily_verses_cache` table using `getCachedVerse`.
        2.  If a cached verse is found, it's returned immediately (cache hit).
        3.  If no cached verse is found, it proceeds to `generateDailyVerse`.
        4.  After generating a new verse, it attempts to `cacheVerse` (non-blocking) for future requests.
    *   **Error Fallback**: If any error occurs during fetching or generation, it falls back to `getFallbackVerse` to ensure a verse is always returned.
-   **`generateDailyVerse(date: Date): Promise<DailyVerseData>`**:
    *   **Current Implementation (MVP)**: Uses a deterministic selection from `FALLBACK_VERSES` based on the date. This ensures the same verse is served for a given date across all users and provides high reliability without external API dependencies.
    *   **Future Enhancement (TODO)**: Comments indicate a plan to integrate with external Bible APIs (e.g., `api.bible` or `bible-api.com`) for more dynamic verse selection.
-   **`getDeterministicVerseIndex(date: Date): number`**:
    *   Calculates an index into `FALLBACK_VERSES` based on the year and day of the year. This makes the verse selection predictable and consistent.
-   **`getCachedVerse(dateKey: string): Promise<DailyVerseData | null>`**:
    *   Queries the `daily_verses_cache` table for a verse matching the `date_key` and `is_active: true`.
    *   Returns the `verse_data` if found, otherwise `null`.
-   **`cacheVerse(dateKey: string, verseData: DailyVerseData): Promise<void>`**:
    *   Inserts or updates (upserts) a verse into the `daily_verses_cache` table.
    *   Sets `date_key`, `verse_data`, `is_active: true`, `created_at`, and `expires_at` (7 days from now).
-   **`getFallbackVerse(date: Date): DailyVerseData`**:
    *   Selects a verse from `FALLBACK_VERSES` using the deterministic index based on the provided `date`.
-   **`formatDateKey(date: Date): string`**:
    *   Formats a `Date` object into a `YYYY-MM-DD` string for consistent caching keys.
-   **`getExpirationDate(): string`**:
    *   Calculates a date 7 days from the current date for cache expiration.

## 5. Caching Strategy

The `daily-verse` function employs a robust caching strategy:

-   **Database Caching (`daily_verses_cache` table)**:
    *   Stores `verse_data` (JSON object containing reference and translations) against a `date_key` (YYYY-MM-DD).
    *   Uses `upsert` to either insert a new verse or update an existing one for a given date.
    *   Includes an `expires_at` timestamp (7 days) for cache invalidation.
-   **In-memory Caching (Implicit)**: The Supabase Edge Function environment might provide some level of in-memory caching for frequently accessed data or function instances, further speeding up responses.
-   **HTTP Caching (`Cache-Control` header)**: The function sets `Cache-Control: public, max-age=3600` in the response headers, instructing clients (browsers, mobile apps) and intermediate proxies to cache the response for 1 hour. This reduces the load on the Edge Function itself.

## 6. Reliability and Fallbacks

-   **Deterministic Verse Selection**: By using `FALLBACK_VERSES` and a deterministic index, the function guarantees that a verse will always be available, even if external APIs or the database are temporarily unreachable.
-   **Cache as Primary Source**: The function prioritizes serving from its internal database cache, reducing reliance on external services.
-   **Error Handling**: Comprehensive `try-catch` blocks ensure that errors are gracefully handled, and a fallback verse is provided.

## 7. Analytics

-   The function integrates with `AnalyticsLogger` to track `daily_verse_fetched` and `daily_verse_error` events. This provides valuable insights into usage patterns and potential issues.

## 8. Future Enhancements (as per comments)

-   Integration with external Bible APIs (e.g., `api.bible` or `bible-api.com`) to provide a wider variety of verses beyond the hardcoded fallbacks. This would require managing API keys and mapping translations.

This function is a well-designed example of an Edge Function that combines API interaction, database caching, and robust error handling to deliver a reliable and performant service.
