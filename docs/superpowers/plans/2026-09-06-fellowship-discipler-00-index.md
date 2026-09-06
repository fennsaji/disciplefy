# Fellowship 1.0.5 (Discipler) Implementation Plan — Index

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship release 1.0.5: an AI helper called Discipler that posts a daily learning-path study, answers or reacts to member questions under mentor control, plus multiple mentors, post sharing, mentor preferences, and the community feed cleanups.

**Architecture:** Five subsystems, executed in order. Database first (migrations and the Discipler system user), then Edge Function routes (no new functions), then two rs-backend crons (daily post, reply worker), then Flutter, then admin-web. Each plan file ends with working, testable software.

**Tech Stack:** PostgreSQL/Supabase migrations, Deno Edge Functions (TypeScript), Rust (axum, sqlx, tokio-cron-scheduler), Flutter (BLoC, GetIt, go_router, mockito/bloc_test), Next.js 16 + React Query (admin-web).

**Spec:** `docs/superpowers/specs/2026-09-06-fellowship-discipler-redesign-design.md` (approved 2026-09-06).

## Global Constraints

- **No new Edge Functions.** 94 of 100 used. Every new route lives inside `fellowship`, `fellowship-posts`, `fellowship-comments`, `fellowship-members`, `fellowship-blocks`.
- **Discipler user id is fixed:** `00000000-0000-4000-8000-00000000d15c`. Email `discipler@disciplefy.in`. Display name `Discipler` (from `auth.users.raw_user_meta_data.full_name`).
- **Discipler is not a `fellowship_members` row.** It writes through the service-role client; membership checks never apply to it. Clients show it as a "Helper" when `discipler_allowed` is true. (Spec §1 "Membership" is superseded by this.)
- **Model:** `claude-haiku-4-5-20251001` (already priced in `LLM_PRICING`), `max_tokens: 350`, `temperature: 0.3`. OpenAI fallback `gpt-4o-mini-2024-07-18`.
- **Reaction map (no model):** prayer → `amen`, praise → `hands`, study_note / shared_guide / general-without-`?` → `heart`. Never `i_prayed`.
- **Post types after this release:** `general, prayer, praise, question, study_note, shared_guide, daily`. `system` is removed and its rows deleted.
- **Mentor preference columns on `fellowships`:** `discipler_reply_mode` (`off|auto|review`, default `auto`), `discipler_reply_scope` (`all|lessons_only`, default `all`), `discipler_reply_delay_min` (`0|30|120|720`, default `0`), `discipler_react_enabled` (default `true`), `daily_post_on` (default `true`). Admin columns: `is_official`, `discipler_allowed`, `daily_post_allowed` (all default `false`).
- **Notification types added:** `fellowship_daily_post`, `fellowship_discipler_reply`, `fellowship_discipler_activity`. Each must appear in: `NotificationType` union, `APPLICATION_TYPES` in `notification-type-constraint.test.ts`, the new CHECK migration, and the Dart `validTypes` set.
- **Crons:** `fellowship_daily_post` = `0 0 1 * * *`; `discipler_reply_worker` = `0 * * * * *`.
- **Version:** `frontend/pubspec.yaml` → `1.0.5+5`; `system_config.latest_app_version` → `1.0.5`.
- **Commits:** one-line `type(scope): message`, no AI trailer, on branch `dev`. Ask the user before committing unless they pre-approved the batch. Never run `supabase db push` or anything with `--project-ref`.
- **Local verification stack:** `cd backend && sh scripts/run_local_server.sh` (Supabase + functions), `psql postgresql://postgres:postgres@127.0.0.1:54322/postgres`. Local test users exist: `anna@test.local` (admin+mentor), `rahul@test.local`, `meera@test.local`, password `Test1234!`, fellowship `f0000000-0000-0000-0000-000000000001`.

## Plan files, in execution order

| # | File | Produces |
|---|---|---|
| 01 | `2026-09-06-fellowship-discipler-01-database.md` | Migrations, Discipler user, new tables, FTS index, notification types, cron rows |
| 02 | `2026-09-06-fellowship-discipler-02-edge-functions.md` | Discipler helpers, LLM method, prompt, all new routes on existing functions |
| 03 | `2026-09-06-fellowship-discipler-03-rs-backend.md` | Daily post cron, reply worker cron, admin cron arms, study API guide id |
| 04 | `2026-09-06-fellowship-discipler-04-flutter.md` | Entities, datasource, blocs, screens, share, mentions, notifications, version |
| 05 | `2026-09-06-fellowship-discipler-05-admin-web.md` | Fellowships page, API route, Discipler stats |

## Spec coverage map

| Spec item | Plan / task |
|---|---|
| R1 daily post | 03 T1–T5 |
| R2, R6, R7, R18, R19 auto-reply, language, react, guide | 02 T2–T6, 03 T6–T7 |
| R3, R15 admin flags | 01 T2, 02 T7, 04 T8, 05 T2 |
| R4 admin adds groups | 05 T1–T3 |
| R5, R8 no system posts, join notify | 01 T2, 02 T7 |
| R9 share post | 04 T11 |
| R10 discover All | 04 T6 |
| R11, R12 Discipler identity, moderation | 01 T1, 02 T8–T9, 04 T4 |
| R13 mentors, ask a mentor | 02 T10, 04 T7, T9 |
| R14 version | 04 T13 |
| R16 mentor prefs | 02 T7, 04 T8 |
| R17 mentions | 02 T3, T5, 04 T10 |
| R20 mentor oversight | 02 T4, T6, T11, 03 T7, 04 T12, 05 T3 |
| R21 no new functions | all of 02 |
| Cleanups (unlimited badge, web handler, invite-join push) | 04 T6, T12; 02 T7 |
