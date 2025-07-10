# Supabase Edge Function: `topics-recommended`

This document provides an analysis of the `topics-recommended` Supabase Edge Function, detailing its purpose, implementation flows, and key functionalities for serving curated Bible study topics.

## 1. Purpose

The `topics-recommended` Edge Function is designed to:

-   Provide access to a curated list of Bible study topics.
-   Support filtering of topics by category and difficulty level.
-   Implement pagination for efficient data retrieval.
-   Track analytics for topic access.

## 2. Key Imports and Dependencies

The function relies on several modules and services:

-   **`serve` (Deno HTTP Server)**: For handling incoming HTTP requests.
-   **`createClient` (Supabase JS SDK)**: To interact with the Supabase API (though primarily used for analytics logging in this function).
-   **`corsHeaders` (from `../_shared/cors.ts`)**: For handling Cross-Origin Resource Sharing.
-   **`ErrorHandler`, `AppError` (from `../_shared/error-handler.ts`)**: For centralized error management and custom application errors.
-   **`RequestValidator` (from `../_shared/request-validator.ts`)**: For validating HTTP methods.
-   **`AnalyticsLogger` (from `../_shared/analytics-logger.ts`)**: For logging analytics events.
-   **`TopicsRepository` (from `./topics-repository.ts`)**: The core logic for retrieving and managing the list of recommended topics.

## 3. Execution Flow (`index.ts`)

The main `index.ts` file handles the HTTP request and orchestrates the calls to the `TopicsRepository`.

1.  **CORS Preflight Handling**: Responds to `OPTIONS` requests with appropriate CORS headers.
2.  **Method Validation**: `validateHttpMethod()` ensures the request method is `GET`.
3.  **Query Parameter Parsing**: `parseQueryParameters()` extracts `category`, `difficulty`, `language`, `limit`, and `offset` from the request URL. It also validates `limit` and `offset` values.
4.  **Dependency Initialization**:
    *   `createSupabaseClient()`: Creates a Supabase client (used by `AnalyticsLogger`).
    *   `topicsRepository`: Instantiates `TopicsRepository`.
    *   `analyticsLogger`: Instantiates `AnalyticsLogger`.
5.  **Get Filtered Topics**: `getFilteredTopics()` is called to retrieve and filter the topics based on the parsed query parameters.
6.  **Analytics Logging**: `logTopicsAccess()` logs a `recommended_guide_topics_accessed` event to `analytics_events`, including filter criteria and total results.
7.  **Response Building**: `createSuccessResponse()` constructs a successful JSON response containing the `topics`, `categories`, and `total` count.
8.  **Error Handling**: A `try-catch` block wraps the entire process, using `ErrorHandler.handleError` to catch any exceptions and return a standardized error response.

## 4. Core Logic (`topics-repository.ts`)

The `TopicsRepository` class is responsible for providing access to the curated list of recommended topics.

### 4.1. Data Source

-   **`getEnglishTopics()`**: This private method contains a hardcoded array of `RecommendedGuideTopic` objects. This is the primary data source for the recommended topics.

### 4.2. Methods

-   **`getTopicsByLanguage(language: string): Promise<readonly RecommendedGuideTopic[]>`**:
    *   Currently, it only supports `'en'` (English) and returns the `getEnglishTopics()`. For any other language, it returns an empty array. This indicates a future potential for multi-language topic sets.
-   **`getTopicById(id: string, language = 'en'): Promise<RecommendedGuideTopic | undefined>`**:
    *   Retrieves a specific topic by its ID.
-   **`getTopicsByCategory(category: string, language = 'en'): Promise<readonly RecommendedGuideTopic[]>`**:
    *   Filters topics by category (case-insensitive).
-   **`getTopicsByDifficulty(difficulty: 'beginner' | 'intermediate' | 'advanced', language = 'en'): Promise<readonly RecommendedGuideTopic[]>`**:
    *   Filters topics by difficulty level.
-   **`getCategories(language = 'en'): Promise<readonly string[]>`**:
    *   Extracts all unique categories from the available topics.
-   **`searchTopics(query: string, language = 'en'): Promise<readonly RecommendedGuideTopic[]>`**:
    *   Searches topics by title, description, and tags (case-insensitive).

## 5. Filtering and Pagination Logic (`index.ts` helper functions)

The `index.ts` file contains helper functions that apply filtering and pagination to the data retrieved from the `TopicsRepository`.

-   **`getFilteredTopics(repository, queryParams)`**:
    *   Fetches all topics for the specified language from the repository.
    *   Applies `filterByCategory()` if `category` is provided in `queryParams`.
    *   Applies `filterByDifficulty()` if `difficulty` is provided.
    *   Applies `applyPagination()` using `limit` and `offset`.
    *   Extracts unique categories from the *original* (unfiltered) set of topics using `extractUniqueCategories()`.
-   **`filterByCategory(topics, category)`**: Filters an array of topics by category.
-   **`filterByDifficulty(topics, difficulty)`**: Filters an array of topics by difficulty.
-   **`applyPagination(topics, limit, offset)`**: Slices the array to implement pagination.
-   **`extractUniqueCategories(topics)`**: Returns a unique list of categories from a given set of topics.

## 6. Configuration Constants

-   `DEFAULT_LANGUAGE`, `DEFAULT_LIMIT`, `DEFAULT_OFFSET`: Default values for query parameters.
-   `MAX_LIMIT`: Maximum allowed value for the `limit` query parameter (100).

## 7. Security and Validation

-   **Method Restriction**: Only `GET` requests are allowed.
-   **Parameter Validation**: `parseQueryParameters()` validates `limit` (must be positive integer, not exceeding `MAX_LIMIT`) and `offset` (must be non-negative integer).
-   **Environment Variable Check**: `createSupabaseClient()` ensures `SUPABASE_URL` and `SUPABASE_ANON_KEY` are present.

## 8. Analytics

-   The function integrates with `AnalyticsLogger` to track `recommended_guide_topics_accessed` events. This provides insights into which topics are being accessed, filter usage, and overall demand.

## 9. Future Enhancements (as per comments)

-   Expansion of `getTopicsByLanguage` to include actual translations for topics beyond English. This would involve managing topic data for multiple languages.
-   The current implementation uses a hardcoded list of topics. In a more dynamic system, these topics might be managed in a database table, allowing for easier updates and expansion without code changes.

This `topics-recommended` Edge Function provides a simple yet effective way to serve curated content, demonstrating good practices in data filtering, pagination, and analytics tracking within a serverless environment.
