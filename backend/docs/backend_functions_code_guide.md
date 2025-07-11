# Backend Codebase Guide: Understanding Supabase Edge Functions

This guide provides an overview of the architecture and conventions used within the `backend/supabase/functions` directory, which houses the Supabase Edge Functions (powered by Deno).

## 1. Supabase Edge Functions Overview

Supabase Edge Functions are server-side TypeScript functions that run on the edge (closer to your users) using Deno. They are ideal for handling API endpoints, webhooks, and backend logic that needs to be highly performant and scalable. In this project, they serve as the primary interface between the frontend application and the Supabase database/external services.

**Key Characteristics:**
-   **Deno Runtime:** Functions are written in TypeScript and run on Deno, offering a secure and modern JavaScript/TypeScript runtime.
-   **Stateless:** Each function invocation is independent. State should be managed externally (e.g., in the database).
-   **HTTP Triggers:** Functions are typically invoked via HTTP requests.
-   **Integrated with Supabase:** Seamless integration with Supabase Auth, Database, and Storage.

## 2. Project Structure (`backend/supabase/functions`)

The `functions` directory contains individual Edge Functions, each residing in its own subdirectory. There's also a special `_shared` directory for common utilities.

```
backend/supabase/functions/
├── _shared/              // Reusable modules and utilities
│   ├── cors.ts
│   ├── error-handler.ts
│   ├── security-validator.ts
│   ├── rate-limiter.ts
│   ├── llm-service.ts
│   ├── request-validator.ts
│   └── analytics-logger.ts
├── auth-google-callback/ // Example: Specific function for Google OAuth callback
│   └── index.ts
├── daily-verse/          // Example: Function to fetch daily Bible verse
│   └── index.ts
├── study-generate/       // Example: Function to generate study guides
│   ├── index.ts
│   └── study-guide-repository.ts // Feature-specific repository
└── ... (other functions)
```

### 2.1. Individual Function Structure (`<function_name>/index.ts`)

Each function's entry point is typically an `index.ts` file. A common structure includes:

-   **Imports:** Deno standard library modules (`serve`), Supabase client (`@supabase/supabase-js`), and shared utility modules from `../_shared/`.
-   **Interfaces:** TypeScript interfaces defining the expected request payload and response structure.
-   **`serve` function:** The main entry point for the HTTP request. It wraps the core logic in a `try-catch` block for robust error handling.
-   **Helper Functions:** Internal functions to handle specific parts of the request processing (e.g., `validateEnvironment`, `createSupabaseClient`, `initializeDependencies`, `parseAndValidateRequest`, `performSecurityValidation`, `enforceRateLimit`, `buildStudyGuideResponse`, `createSuccessResponse`).

### 2.2. Shared Modules (`_shared/`)

The `_shared` directory is crucial for maintaining a DRY (Don't Repeat Yourself) codebase. It contains common functionalities used across multiple Edge Functions:

-   **`cors.ts`:** Defines CORS (Cross-Origin Resource Sharing) headers for API responses.
-   **`error-handler.ts`:** Centralized error handling logic, including custom `AppError` classes for consistent error responses.
-   **`security-validator.ts`:** Handles input validation and sanitization to prevent common security vulnerabilities (e.g., prompt injection).
-   **`rate-limiter.ts`:** Implements rate limiting logic to protect against abuse and ensure fair usage.
-   **`llm-service.ts`:** Abstracts interactions with Large Language Models (LLMs) for content generation.
-   **`request-validator.ts`:** Provides utility functions for validating incoming HTTP request bodies and parameters.
-   **`analytics-logger.ts`:** Handles logging of analytics events to the database.

## 3. Request Flow and Execution

When an HTTP request hits an Edge Function, the general flow is as follows:

1.  **CORS Preflight:** The `serve` function first checks for `OPTIONS` requests (CORS preflight) and returns appropriate headers.
2.  **Environment Validation:** Ensures all necessary environment variables are set.
3.  **Supabase Client Initialization:** A Supabase client is created, often with the user's authentication token from the request headers.
4.  **Dependency Initialization:** Shared services (e.g., `SecurityValidator`, `RateLimiter`, `AnalyticsLogger`) are instantiated.
5.  **Request Parsing & Validation:** The incoming JSON request body is parsed and validated against predefined rules.
6.  **Security Validation:** The request input is checked for potential security threats.
7.  **Rate Limiting:** The request is checked against rate limits to prevent abuse.
8.  **Core Business Logic:** This is where the function's primary purpose is executed (e.g., generating a study guide, fetching data, processing feedback). This often involves interacting with the Supabase database or external APIs.
9.  **Analytics Logging:** Relevant events are logged for monitoring and analysis.
10. **Response Generation:** A success response is constructed and returned.
11. **Error Handling:** Any errors encountered during the process are caught by the `try-catch` block and handled by the `ErrorHandler`, returning a standardized error response.

## 4. How to Read the Backend Code

To effectively understand and debug the Edge Functions:

1.  **Start at `index.ts`:** Every function's entry point is its `index.ts` file. Begin by understanding the overall flow within the `serve` function.
2.  **Identify Shared Utilities:** Pay attention to imports from `../_shared/`. These modules encapsulate common logic, so understanding their purpose will clarify the main function's code.
3.  **Trace Function Calls:** Follow the sequence of function calls within `serve`. For example, if you're looking at `study-generate`, you'll see calls to `performSecurityValidation`, `enforceRateLimit`, and then the core generation/saving logic.
4.  **Examine Feature-Specific Repositories/Services:** Some functions (like `study-generate`) might have their own dedicated repository or service files within their directory (e.g., `study-guide-repository.ts`). These handle direct database interactions for that specific feature.
5.  **Understand Supabase Interactions:** Look for `supabaseClient.from(...)`, `supabaseClient.auth(...)`, etc., to understand how data is queried, inserted, or updated in the database.
6.  **Review Interfaces:** The TypeScript interfaces at the top of `index.ts` files provide a quick understanding of the expected input and output data structures.
7.  **Error Handling:** Observe how `AppError` is thrown and caught, and how the `ErrorHandler` processes different types of errors.
8.  **Deno Environment:** Remember that these are Deno functions. While much of it looks like Node.js TypeScript, be aware of Deno-specific APIs (e.g., `Deno.env.get`, `serve`).

By following this guide, you should be able to effectively navigate and comprehend the Supabase Edge Functions codebase.