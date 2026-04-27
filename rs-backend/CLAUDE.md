# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Rust backend service for the Disciplefy Bible Study app. It serves a **blog/content API** and runs **CRON jobs** that auto-generate multilingual blog posts (en/hi/ml) from learning path topics by calling Supabase Edge Functions.

## Build & Run

```bash
# Build
cargo build
cargo build --release

# Run locally (requires .env — copy from .env.example)
cargo run
# Server starts on PORT (default 8080), logs controlled by RUST_LOG env var

# Check compilation without building
cargo check

# Docker
docker build -t rs-backend:local .
docker compose -f docker-compose.yml -f docker-compose.local.yml up
```

There are no tests in this codebase currently.

## Architecture

**Stack**: Axum 0.7 + SQLx (Postgres) + Tokio + reqwest

**AppState** (`src/main.rs`): Shared across all handlers — holds `PgPool`, `Config`, `Client`, `JobScheduler`, and `cron_job_ids` mutex.

### Module Layout

```
src/
├── main.rs          — App startup, CORS, graceful shutdown
├── config.rs        — Config::from_env() loads all env vars
├── auth.rs          — Supabase JWT validation + admin check via user_profiles.is_admin
├── db.rs            — PgPool creation (statement_cache_capacity=0 for Supabase compatibility)
├── error.rs         — AppError enum → JSON error responses
├── models/
│   ├── post.rs      — BlogPost CRUD, pagination, full-text search, topic finder queries
│   └── cron_config.rs — cron_config table CRUD
├── routes/
│   ├── health.rs    — GET /health
│   ├── posts.rs     — Public blog API (list, get by slug, tags, search)
│   └── admin.rs     — Admin-only: post CRUD, cron control, blog generation from study guides
├── cron/
│   ├── mod.rs       — Scheduler setup, CronGuard (AtomicBool-based concurrency lock)
│   ├── schedules.rs — Cron expression constants
│   └── blog_generator.rs — Main generation logic: pick topic → call study API → format → save
└── services/
    ├── study_api.rs         — SSE client for Supabase study-generate-v2 Edge Function
    └── content_formatter.rs — Transforms study guide sections into localized markdown blog posts
```

### Key Data Flow

1. **CRON or admin trigger** → `blog_generator::run_blog_generation`
2. Finds next learning path topic missing locale coverage (query joins `learning_path_topics`, `recommended_topics`, `learning_paths` + translation tables)
3. Spawns parallel tasks per missing locale (en/hi/ml)
4. Each calls `study_api::generate_study_guide` → SSE stream from Supabase Edge Function `study-generate-v2`
5. `content_formatter::format_blog_post` → markdown with localized section headers
6. Saves to `blog_posts` table via `post::create_post`

### Auth Pattern

Admin routes call `verify_admin()` → extracts Bearer token → validates against Supabase Auth `/auth/v1/user` → checks `user_profiles.is_admin` in DB.

### CRON System

- Two jobs: `blog_generation` (daily midnight UTC) and `blog_retry` (every 4h for partial failures)
- Schedules stored in `cron_config` DB table, with hardcoded fallbacks
- `CronGuard` uses `AtomicBool` + `compare_exchange` to prevent concurrent runs of the same job
- Admin can hot-reload schedules via PUT endpoint (removes old job, adds new one to scheduler)
- Cron expressions validated with `croner` crate (6-field format: sec min hour dom month dow)

### API Response Convention

All responses wrap in `{ "success": true/false, "data": ..., "error": { "code": "...", "message": "..." } }`.

## Database

Connects to Supabase-hosted Postgres. Key tables:
- `blog_posts` — generated blog content with locale, tags, slug, source tracking
- `cron_config` — schedule/enabled state per cron job
- `user_profiles` — admin flag check
- `learning_path_topics`, `recommended_topics`, `learning_paths` + translation tables — source content

SQLx is used with **raw queries** (no compile-time checking). Statement cache is disabled (`statement_cache_capacity(0)`) and `DEALLOCATE ALL` runs on each new connection for Supabase PgBouncer compatibility.

## Deployment

- Production: Docker image `ghcr.io/fennsaji/disciplefy-rs-backend:latest` on VPS
- Caddy reverse-proxies `api.disciplefy.in` → `localhost:8090`
- Vector sidecar ships Docker logs to Axiom
- Port is 8090 in production (Dockerfile EXPOSE + compose), 8080 default in code

## Environment Variables

Required: `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `INTERNAL_API_KEY`
Optional: `PORT` (8080), `ALLOWED_ORIGINS` (comma-separated), `DB_POOL_SIZE` (5), `RUST_LOG` (info)
