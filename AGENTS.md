# AGENTS.md

Guidance for AI coding agents working in this repository. Keep replies concise and factual; verify against the code before asserting. Component-specific detail lives in each `CLAUDE.md` (`frontend/`, `backend/`, `admin-web/`, `rs-backend/`, `marketing/`) — this file covers cross-cutting operation and the non-obvious gotchas.

## What this is

**Disciplefy** — an AI-powered Bible study app. Users enter a scripture reference or topic; the app generates structured study guides via LLMs. Languages: English, Hindi, Malayalam.

| Component | Path | Stack |
|---|---|---|
| Mobile/web app | `frontend/` | Flutter (iOS, Android, Web), Clean Architecture + BLoC |
| Backend API | `backend/` | Supabase Edge Functions (Deno/TypeScript) + Postgres/RLS |
| Admin dashboard | `admin-web/` | Next.js 16 (App Router, React 19) |
| Cron/worker backend | `rs-backend/` | Rust |
| Store/marketing assets | `distribution/`, `marketing/` | Play/App Store release notes, content |

## Commands

Run these from the component directory.

**Frontend** (`frontend/`)
```bash
sh scripts/run-web-local.sh                      # web dev (preferred)
sh scripts/run-ios-local.sh .env.production <device-or-sim-id>   # run on iOS device/sim with a chosen env
flutter analyze                                  # lint (CI uses --fatal-infos)
dart format lib/                                 # format (pre-commit enforces this)
flutter test                                     # all tests (currently 147)
dart run build_runner build --delete-conflicting-outputs   # regen .g.dart/.mocks.dart
```

**Backend** (`backend/`)
```bash
sh scripts/run_local_server.sh [--reset]         # local Supabase + functions
supabase functions deploy <fn> --project-ref <ref> --use-api   # deploy ONE function to prod
supabase db push --project-ref <ref>             # push migrations
```

**Admin** (`admin-web/`)
```bash
npm run dev            # port 4000
npm run type-check     # tsc --noEmit
npm run lint
npm run build
```

## Architecture (essentials)

- **Frontend**: feature-first under `lib/features/<feature>/{data,domain,presentation}`; dependency direction Presentation → Domain ← Data. Use cases return `Future<Either<Failure, T>>` (`dartz`). DI via GetIt in `lib/core/di/injection_container.dart` (`sl<T>()`). State is BLoC only. Router: `go_router` in `lib/core/router/`, with `RouterGuard` (auth/onboarding/language gates) and `AuthNotifier`.
- **Backend**: every function uses the factory in `_shared/core/function-factory.ts` (CORS, auth, rate limit, errors). Services via a singleton `ServiceContainer` (`_shared/core/services.ts`). Errors via `AppError`. Three Supabase clients: browser (anon), server (cookie session), admin (service role — server only, bypasses RLS).
- **Admin**: pages call typed fetchers in `lib/api/admin.ts` → `app/api/admin/*` routes → verify user + `is_admin` (on `user_profiles.id`) → Edge Function or direct DB.

## Conventions (hard rules)

- Commit messages: `type(scope): brief` one-liner. Types: feat/fix/docs/style/refactor/test/chore. **Never** add `Co-Authored-By`.
- Only commit/push/PR when asked. Prod deploys and outward-facing actions: confirm first.
- Frontend: package imports only (`package:disciplefy_bible_study/...`), no relative imports. `print()` is banned — use `Logger`. Use `AppColors`/`AppFonts`/`AppTheme`, never hardcode.
- Backend/admin: enable RLS on every table in `public`; check `is_admin` on the correct `id` column (not `user_id` — that column does not exist on `user_profiles`).
- Look up official docs for any third-party library before using it (use the docs-explorer/context7 tooling).

## Branching, CI, deploy

- Work on `dev`; PR `dev → main`. Merging `main` triggers CI deploy of **all** components (Android→Play beta, iOS→TestFlight, web, backend functions, admin). No manual deploy needed in the normal flow.
- Store **versionCode/build number = minutes since 2026-07-11 base** (`10000 + ($(date +%s) - 1783814400)/60`) across all Android+iOS deploy workflows — one monotonic source so any track always upgrades. Do NOT reintroduce per-workflow `run_number` schemes (they cross and Play rejects the rollout). `versionName` comes from `frontend/pubspec.yaml`.
- Release notes live in `distribution/whatsnew/whatsnew-{en-IN,en-US,hi-IN,ml-IN}` (Play limit 500 chars).
- To hotfix prod backend without a full merge: `supabase functions deploy <fn> --project-ref <ref> --use-api` (the `--use-api` bundler avoids a Docker hang). Redeploy **every** function that imports changed `_shared/` code — shared code is bundled per function.

## Gotchas (verified, load-bearing)

**Bible book names** — two synced sources of truth: backend `_shared/utils/bible-book-normalizer.ts` and frontend `core/constants/bible_books.dart`. When a variant renders unhighlighted, update both (see root `CLAUDE.md`).

**Language persistence** — four stores (SharedPreferences `user_language_preference`, Hive `settings_language`, backend `user_profiles.language_preference`, `study_content_language`) and two i18n runtimes (`AppLocalizations`/`LocaleService` vs non-reactive `TranslationService`/`context.tr`). They converge via `LanguagePreferenceService.languageChanges`. Never coerce a null DB `language_preference` to `'en'` — it overwrites a local choice. Logout must preserve the language keys (whitelist before `prefs.clear()`).

**Session expiry** — Hive `session_expires_at` tracks the **access token** (~1h), not the session. Supabase sessions are effectively indefinite (dashboard timeouts off). `RouterGuard` must attempt `auth.refreshSession()` before treating a user as logged out.

**Apple IAP** (see `frontend/lib/core/services/apple_consumable_purchase_service.dart`, `backend/.../apple-appstore-validator.ts`):
- The Apple `.p8` key is stored with escaped `\n` by the deploy workflow; the validator must un-escape it or `atob` throws "Failed to decode base64".
- Apple receipt validation uses the App Store Server API with a WebCrypto-signed JWT (Apple's official npm lib breaks on Deno).
- Subscriptions use non-consumable `buyNonConsumable`; token packs & tips are **consumables** (`buyConsumable`) with product IDs `com.disciplefy.tokens_<n>` / `com.disciplefy.tip_<amount>`. Consumables route away from the subscription flow **before** the sync-restore, are **force-finished** after backend confirm (a restored consumable reports `pendingCompletePurchase=false` yet still redelivers), and are de-duped per session against sandbox replay. Backend confirm (`confirm-apple-purchase`) is idempotent on transaction_id.
- **On a physical device the local `.storekit` config is ignored** — StoreKit hits the real sandbox, so only products that exist in App Store Connect appear. For product screenshots / clean repeat-purchase demos, use the **iOS Simulator** (local config renders all products at any price). IAP product IDs must be valid Apple price points and must be created + attached to the app version in App Store Connect.
- iOS-only compliance (guideline 3.1.1): external donation links and non-IAP promo-code redemption are hidden on iOS via `PlatformUtils.isIOS`; discounts/tips go through IAP.

**Admin data at scale** — `auth.admin.listUsers()` is capped at 50/page (use `lib/supabase/list-all-users.ts`); PostgREST caps unbounded selects at 1000 rows (use `lib/supabase/fetch-all-rows.ts` for aggregations). `admin-web/middleware.ts` refreshes sessions — without it, rotated tokens log admins out.

**API.Bible compliance** — free non-commercial tier while commercially launched: copyrighted verse text must not reach the LLM or TTS. Use Public Domain text for AI/RAG/TTS.

## Before you finish

- Verify with real commands (`flutter analyze`, `flutter test`, `npm run type-check`, `deno check`) and report actual output — no success claims without evidence.
- Pre-commit hooks run analyze + `dart format` checks; format before committing.
- For runtime changes, exercise the affected flow (the run scripts above), don't rely on tests alone.
