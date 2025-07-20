# Centralized Configuration Refactoring Plan

**Analysis Date:** July 19, 2025

## 1. Goal

This document outlines the specific, actionable steps required to eliminate all direct calls to `Deno.env.get()` outside of the centralized configuration module (`_shared/core/config.ts`). The goal is to enforce a strict single source of truth for all environment variables, improving maintainability, testability, and architectural consistency.

---

## 2. Refactoring Plan (Prioritized)

### Priority 1: `_shared/utils/request-validator.ts`

-   **Issue**: The `validateEnvironmentVariables` function directly accesses `Deno.env`, creating a second, rogue source of configuration validation.
-   **Impact**: This is redundant and violates the single-source-of-truth principle. All environment validation MUST occur at application startup within `config.ts` to ensure the system fails fast if misconfigured.
-   **Status**: `Pending`
-   **Action Plan**:
    1.  **Delete** the entire `validateEnvironmentVariables` function from `_shared/utils/request-validator.ts`.
    2.  **Search** the codebase for any calls to `RequestValidator.validateEnvironmentVariables` and remove them. These calls are now obsolete as the `config.ts` module handles this responsibility upon initialization.

---

### Priority 2: `_shared/core/services.ts`

-   **Issue**: This file contains two violations: a redundant `createEnvironmentConfig` function and a `createUserSupabaseClient` function that directly accesses `Deno.env`.
-   **Impact**: This creates hidden dependencies on environment variables deep within the service layer, making the system harder to configure and test.
-   **Status**: `Pending`
-   **Action Plan**:
    1.  **Delete** the `createEnvironmentConfig` function from `_shared/core/services.ts`. It is fully superseded by the `config` module.
    2.  **Refactor** the `createUserSupabaseClient` function to remove its direct dependency on `Deno.env`.

        **Before:**
        ```typescript
        export function createUserSupabaseClient(authToken: string): SupabaseClient {
          const supabaseUrl = Deno.env.get('SUPABASE_URL')
          const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
          // ...
        }
        ```

        **After:**
        ```typescript
        // This function will now be called from within the function factory, which has access to the config.
        export function createUserSupabaseClient(authToken: string, supabaseUrl: string, supabaseAnonKey: string): SupabaseClient {
          if (!supabaseUrl || !supabaseAnonKey) {
            throw new AppError('CONFIGURATION_ERROR', 'Missing Supabase configuration for user client', 500)
          }
          // ...
        }
        ```
    3.  **Update** the call site within `_shared/core/function-factory.ts` to pass the required values from the `config` object.

---

### Priority 3: `_shared/services/auth-service.ts`

-   **Issue**: The `createAuthClient` method directly calls `Deno.env.get()` to get the Supabase URL and anon key.
-   **Impact**: This gives the `AuthService` a hidden dependency on the environment, making it less portable and harder to unit test.
-   **Status**: `Pending`
-   **Action Plan**:
    1.  **Modify** the `AuthService` constructor to accept the required configuration.
    2.  **Update** the service container in `_shared/core/services.ts` to inject these values during initialization.

        **Before (`auth-service.ts`):**
        ```typescript
        export class AuthService {
          createAuthClient(req: Request): SupabaseClient {
            const supabaseUrl = Deno.env.get('SUPABASE_URL')
            const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
            // ...
          }
        }
        ```

        **After (`auth-service.ts`):**
        ```typescript
        export class AuthService {
          constructor(
            private readonly supabaseUrl: string,
            private readonly supabaseAnonKey: string
          ) {}

          createAuthClient(req: Request): SupabaseClient {
            // Now uses constructor-injected values
            return createClient(this.supabaseUrl, this.supabaseAnonKey, { /* ... */ });
          }
        }
        ```

        **Update (`services.ts`):**
        ```typescript
        // In initializeServiceContainer()
        const authService = new AuthService(config.supabaseUrl, config.supabaseAnonKey);
        ```

---

### Priority 4: `_shared/services/llm-service.ts`

-   **Issue**: The `getApiKeyForProvider` method directly calls `Deno.env.get()` to retrieve API keys.
-   **Impact**: This creates a hidden dependency and makes it impossible to test the service without setting actual environment variables.
-   **Status**: `Pending`
-   **Action Plan**:
    1.  The `LLMService` already correctly receives its API keys via the `LLMServiceConfig` object in its constructor. The `getApiKeyForProvider` method must be refactored to use these constructor-injected values.

        **Before:**
        ```typescript
        private getApiKeyForProvider(provider: LLMProvider): string {
          const apiKeyEnv = provider === 'openai' ? 'OPENAI_API_KEY' : 'ANTHROPIC_API_KEY'
          const apiKey = Deno.env.get(apiKeyEnv)
          // ...
        }
        ```

        **After:**
        ```typescript
        private getApiKeyForProvider(provider: LLMProvider): string {
          const apiKey = provider === 'openai' ? this.config.openaiApiKey : this.config.anthropicApiKey;
          if (!apiKey || apiKey.trim().length === 0) {
            throw new Error(`API key not available for provider: ${provider}`)
          }
          return apiKey;
        }
        ```
    2.  Ensure the `LLMService` constructor properly stores the config object in a private field (e.g., `private readonly config: LLMServiceConfig`).

---

## 3. Verification

Once all steps are completed, a global search for `Deno.env.get()` within the `backend/supabase/functions/` directory should **only** return matches inside the `_shared/core/config.ts` file. This will confirm that the refactoring was successful.
