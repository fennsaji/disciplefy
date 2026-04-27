# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Disciplefy Bible Study app backend — Supabase Edge Functions (Deno/TypeScript) powering AI-driven Bible study guide generation, subscriptions, memory verse tracking, fellowship groups, and notifications.

## Commands

```bash
# Start local Supabase (PostgreSQL, Auth, Storage, Edge Functions runtime)
supabase start

# Serve all Edge Functions locally (auto-reloads on TS changes)
supabase functions serve --env-file .env.local

# Full local dev startup (recommended)
sh scripts/run_local_server.sh              # preserves DB
sh scripts/run_local_server.sh --reset      # resets DB with migrations

# IAP testing with ngrok tunnel
sh scripts/run_iap_local_server.sh

# Apply all migrations fresh (resets database)
supabase db reset

# Apply migrations incrementally
supabase migration up

# Create new migration
supabase migration new <name>

# TypeScript compilation check
sh scripts/check-compilation-simple.sh      # checks each function individually
sh scripts/check-quick.sh                   # fast batch check with deno check

# Deploy to production
supabase functions deploy --project-ref <ref>
supabase functions deploy <function-name> --project-ref <ref>
supabase db push --project-ref <ref>

# View function logs
supabase functions logs <function-name>

# Check service status
supabase status
```

## Architecture

### Runtime & Language
- **Deno** runtime with TypeScript (strict mode via `deno.json`)
- Imports use URL-based modules (`https://esm.sh/`, `https://deno.land/std@0.208.0/`)
- npm packages via `npm:` prefix (e.g., `razorpay`, `pdf-lib`)
- Import map at `supabase/functions/_shared/import_map.json`

### Edge Function Structure
Each function lives in `supabase/functions/<function-name>/index.ts`. All functions use the **function factory pattern** from `_shared/core/function-factory.ts`:

```typescript
// Public endpoint (no auth required)
createSimpleFunction(handler, { allowedMethods: ['POST'], timeout: 15000 })

// Endpoint that parses JWT but doesn't require it
createFunction(handler, { allowGuestOnJwtFailure: true })

// Auth-required endpoint
createAuthenticatedFunction(handler, { requireAuth: true })

// Background/scheduled jobs (service role key auth)
createServiceRoleFunction(handler)
```

The factory handles CORS, JWT parsing, timeout, rate limiting, error handling, and analytics logging. Handlers receive `(req, services, userContext?)`.

### Dependency Injection — ServiceContainer
`_shared/core/services.ts` provides a **singleton ServiceContainer** initialized lazily via `getServiceContainer()`. All services (LLM, repositories, rate limiter, token service, analytics, etc.) are instantiated once and reused across invocations.

Key services:
- `llmService` — LLM abstraction (OpenAI/Anthropic/mock) with multi-pass study generation
- `studyGuideService` / `studyGuideRepository` — study guide CRUD
- `tokenService` — token balance and consumption
- `rateLimiter` / `rateLimitService` — per-user rate limiting
- `analyticsLogger` — event logging
- `securityValidator` — input validation and prompt injection detection
- `supabaseServiceClient` — service-role Supabase client

### Shared Code (`_shared/`)
```
_shared/
├── core/           # function-factory.ts, services.ts (DI container), config.ts (env vars)
├── types/          # TypeScript interfaces (database.types.ts, token-types.ts, etc.)
├── utils/          # cors.ts, error-handler.ts (AppError), security-validator.ts,
│                   # bible-book-normalizer.ts, rate-limiter.ts, request-validator.ts
├── services/       # Business logic services
│   ├── llm-clients/    # OpenAI and Anthropic API clients
│   ├── llm-config/     # Per-language LLM configuration
│   ├── llm-utils/      # Prompt builder, response parser, multi-pass strategies
│   │                   # (standard, deep, lectio, sermon modes)
│   └── payment-providers/  # Razorpay, Google Play, Apple App Store
├── repositories/   # Database access layer (study guides, topics, feedback, voice)
├── middleware/      # feature-access-middleware.ts, maintenance-middleware.ts
├── locales/        # i18n strings (en.ts, hi.ts, ml.ts)
├── config/         # subscription-config.ts
└── prompts/        # LLM prompt templates
```

### Error Handling Pattern
Use `AppError` from `_shared/utils/error-handler.ts`:
```typescript
throw new AppError('VALIDATION_ERROR', 'message', 400)
throw new AppError('DATABASE_ERROR', 'message', 500)
```
The function factory catches these and returns structured JSON responses with `{ success: false, error: { code, message, requestId } }`.

### Environment Configuration
`_shared/core/config.ts` is the single source of truth for env vars. Required: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`. Optional: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `LLM_PROVIDER`. Auto-enables mock mode if no LLM keys are set.

Use `.env.local` for local development. Never commit `.env` files with real keys.

### Database
- PostgreSQL via Supabase with 100+ migrations in `supabase/migrations/`
- RLS (Row Level Security) enabled on all user-facing tables
- Seed data in `supabase/seed.sql`
- Key tables: `study_guides`, `user_profiles`, `subscriptions`, `tokens`, `memory_verses`, `feedback`, `learning_paths`, `fellowships`

### Bible Book Normalization
`_shared/utils/bible-book-normalizer.ts` is the single source of truth for mapping Bible book name variants (Hindi, Malayalam, LLM-generated) to canonical forms. `fetch-verse` imports from here — never duplicate these mappings.

### Function Categories
- **Study generation**: `study-generate`, `study-generate-v2`, `study-followup`, `study-guides`
- **Subscriptions/payments**: `create-subscription`, `create-subscription-v2`, `cancel-subscription`, `resume-subscription`, `razorpay-webhook`, `google-play-webhook`, `subscription-pricing`, `sync-subscription-status`
- **Tokens**: `token-status`, `token-usage-history`, `purchase-tokens`, `confirm-token-purchase`, `study-get-token-costs`
- **Memory verses**: `add-memory-verse-*`, `delete-memory-verse`, `get-due-memory-verses`, `get-memory-*`, `submit-memory-*`
- **Fellowship**: `fellowship`, `fellowship-comments`, `fellowship-invites`, `fellowship-meetings`, `fellowship-members`, `fellowship-posts`, `fellowship-study`
- **Learning paths**: `learning-paths`, `continue-learning`, `topic-progress`
- **Notifications**: `send-daily-verse-notification`, `send-streak-*`, `register-fcm-token`, `cleanup-fcm-tokens`
- **Admin**: `admin-*` functions (study guides, learning paths, analytics, promo codes, subscriptions)
- **User**: `user-profile`, `save-personalization`, `profile-setup`, `delete-account`
- **Content**: `daily-verse`, `fetch-verse`, `get-bible-books`, `topics-*`

### Supported Languages
English (`en`), Hindi (`hi`), Malayalam (`ml`) — configured in `_shared/locales/` and `_shared/services/llm-config/language-configs.ts`.
