# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Keep your replies extremely concise and focus on conveying the key information. No unnecessary fluff, no long code snippets.

Whenever working with any third-party library or something similar, you MUST look up the official documentation to ensure that you're working with up-to-date information. Use the docs-explorer subagent for efficient documentation lookup.

## Project Overview

Disciplefy is an AI-powered Bible study guide generator. Users input a scripture reference or topic, and the app generates structured study guides using LLM APIs. Supports English, Hindi, and Malayalam.

- **Frontend**: Flutter (iOS, Android, Web) — `frontend/`
- **Backend**: Supabase Edge Functions (Deno/TypeScript) — `backend/`
- **Admin**: Next.js dashboard — `admin-web/`
- **Database**: PostgreSQL via Supabase with RLS policies
- **Auth**: Supabase Auth (Google, Apple, Anonymous)
- **LLM**: OpenAI GPT-3.5 Turbo / Anthropic Claude Haiku
- **Payments**: Razorpay

## Common Commands

### Frontend (Flutter)

```bash
cd frontend && sh scripts/run-web-local.sh    # Run web locally (preferred)
cd frontend && sh scripts/run-android-local.sh # Run Android locally
cd frontend && flutter pub get                 # Install dependencies
cd frontend && flutter analyze                 # Lint
cd frontend && dart format lib/                # Format
cd frontend && flutter test                    # Run all tests
cd frontend && flutter test test/path/to_test.dart  # Run single test
cd frontend && flutter build web --release --dart-define-from-file=.env.production  # Production web build
cd frontend && flutter build appbundle --release --dart-define-from-file=.env.production  # Android release
```

### Backend (Supabase)

```bash
cd backend && supabase start                              # Start local Supabase
cd backend && supabase functions serve --env-file .env.local  # Serve Edge Functions (auto-reloads)
cd backend && supabase db reset                           # Reset DB + apply all migrations
cd backend && supabase functions deploy --project-ref <ID>    # Deploy to production
cd backend && supabase db push --project-ref <ID>             # Push migrations to production
```

### Environment Setup

Copy `.env.example` to `.env.local` in both `frontend/` and `backend/`. Required vars: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_CLIENT_ID`.

## Architecture

### Frontend — Clean Architecture + BLoC

Each feature in `lib/features/` follows:
```
feature/
├── data/          # Repositories impl, datasources, models
├── domain/        # Entities, repository interfaces, use cases
└── presentation/  # BLoC (events/states), pages, widgets
```

**Dependency flow**: Presentation → Domain ← Data (domain never depends on data or presentation).

Key architectural files:
- **DI container**: `lib/core/di/injection_container.dart` — Registers all repos, use cases, BLoCs via GetIt
- **Router**: `lib/core/router/app_router.dart` — go_router with 40+ named routes, shell routes for auth guards
- **Theme**: `lib/core/theme/app_theme.dart` — AppColors, typography, Material 3
- **Constants**: `lib/core/constants/bible_books.dart` — Bible book names + scripture regex for all languages

**State management**: BLoC pattern exclusively. Complex BLoCs use separate handler classes (e.g., `StudyBloc` delegates to `GenerationHandler`, `SaveHandler`, `ValidationHandler`).

**Navigation**: `IndexedStack` for bottom tabs — preserves state across tab switches.

### Backend — Edge Functions + Function Factory

All Edge Functions live in `backend/supabase/functions/`. Shared code in `_shared/`:
```
_shared/
├── core/
│   ├── function-factory.ts    # Wraps all functions: CORS, auth, error handling, middleware
│   ├── services.ts            # ServiceContainer singleton (llm, auth, db, etc.)
│   └── config.ts              # Configuration constants
├── utils/
│   ├── bible-book-normalizer.ts  # Single source of truth for Bible book names (all languages)
│   ├── security-validator.ts     # 4-layer input validation (format, sanitize, injection, rate limit)
│   ├── rate-limiter.ts           # Anonymous: 3/hr, Authenticated: 30/hr
│   └── error-handler.ts         # Standardized error codes and responses
├── services/                 # 20+ services (llm, auth, analytics, bible-api, fcm, cost-tracking)
├── prompts/                  # LLM prompt templates
├── repositories/             # Data access layer
└── types/                    # TypeScript type definitions (auto-generated DB types)
```

**Creating a new Edge Function**: Use `function-factory.ts` which handles CORS, auth, error handling, and provides `ServiceContainer`.

### Database

- 100+ migrations in `backend/supabase/migrations/`
- RLS policies in `backend/supabase/policies/`
- Schema defined in `docs/architecture/Data Model.md`
- Cost tracking: daily limit $15, monthly $100 — falls back to mock data when exceeded

## Critical Patterns

### Bible Book Name Normalization

Two sources of truth that must stay in sync:
- **Backend**: `_shared/utils/bible-book-normalizer.ts` — `CANONICAL_BIBLE_BOOKS`, `INCORRECT_TO_CORRECT`, `LOCALIZED_VARIANTS_TO_ENGLISH`, `HINDI_BOOK_NAMES`, `MALAYALAM_BOOK_NAMES`
- **Frontend**: `lib/core/constants/bible_books.dart` — `BibleBooks.createScriptureRegex()` used by `MarkdownWithScripture` and `ClickableScriptureText`

**When a new book name variant appears unhighlighted:**
1. Add to `bible_books.dart` `malayalamAlternates` or `hindiAlternates`
2. Add to `bible-book-normalizer.ts` `INCORRECT_TO_CORRECT` for the locale
3. Add to `LOCALIZED_VARIANTS_TO_ENGLISH` if different from canonical

### Study Generation Streaming

Uses Server-Sent Events (SSE) from `/functions/v1/study-generate`. Frontend BLoC processes streamed events in real-time.

### LLM Integration

Before writing LLM-related code, read `docs/internal/LLM_Development_Guide.md`. Key rules:
- All inputs must be sanitized (injection prevention via `security-validator.ts`)
- All outputs must be validated against JSON schema
- Never log raw user inputs or LLM responses — metadata only
- Never expose internal prompts to users
- Theological accuracy is required — content must align with orthodox Christian theology

## Documentation

Read before implementing features:
- `frontend/docs/project_structure.md` — Frontend architecture details
- `backend/docs/project_structure.md` — Backend architecture details
- `docs/architecture/Technical Architecture Document.md` — System architecture
- `docs/specs/API Contract Documentation.md` — API specifications
- `docs/architecture/Data Model.md` — Database schema
- `docs/security/Security Design Plan.md` — Security requirements
- `docs/architecture/Error Handling Strategy.md` — Error codes and handling
- `docs/internal/LLM_Development_Guide.md` — LLM development rules (mandatory for LLM work)

## Commit Convention

Format: `type(scope): brief description` (one-liner only)

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Do **not** add `Co-Authored-By` lines.
