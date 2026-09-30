# App Performance Plan — Phases 1–3

**Date:** 2026-09-30
**Scope:** Flutter app (web at app.disciplefy.in, Android, iOS) and Supabase Edge Functions.
**Goal:** Cut first-screen time on the web from ~10 s to ≤ 3 s on a cold visit and ≤ 1.5 s on a repeat visit, and make every Home/Topics/Community API call return in < 400 ms warm.

---

## 1. Baseline (measured 2026-09-30, production, cold visit)

| Metric | Value |
|---|---|
| First contentful paint | **~9.9 s** |
| JS bundle `main.dart.js` | 9.3 MB raw / 2.5 MB brotli |
| CanvasKit wasm | 7.2 MB raw / 2.9 MB brotli |
| Fonts downloaded before first frame | 8 TTFs, ~1 MB transferred (~2 MB raw) |
| Cache headers on all web assets | `max-age=0, must-revalidate` (revalidated every visit) |
| Service worker | Flutter's self-unregistering stub — no offline cache |
| Blocking network before first frame | `system-config` 1.4 s → `subscription-pricing` 0.8 s → `get-bible-books` 4.6 s (serial) |
| `/user-profile` calls per launch | 6–8 (language lookups; 5-min cache declared but unused) |
| Warm edge function latency (direct) | 0.35–0.8 s each |

Root causes: serial network work before the first frame, uncached language lookups, no browser/asset caching, and backend requests that make many sequential round trips (auth re-verification, awaited analytics inserts, N+1 queries).

---

## 2. Phase 1 — done (commits `b51c4f70`, `5ba11c28`)

- Language: in-memory + local cache, one shared server fetch, background reconcile; no network before first frame.
- Startup: Hive / Firebase / Supabase and local services initialise in parallel; deep links, version check and IAP setup run after the first frame; Bible books, system config and pricing are stale-while-revalidate.
- One shared session refresh for concurrent requests.
- Daily verse: duplicate launch request removed, language switch re-renders from the cached verse (no network).
- Learning paths: recommended / "continue learning" path persisted per user + language (7 days), shown instantly, always refreshed in the background; all learning-path caches keyed by user + language (fixes a cross-account leak after logout); tab switches refresh in the background instead of reloading.
- Walkthrough sync once per session; Home reloads once per language change (was 3×).
- Web: removed render-blocking Material Icons stylesheets, lazy-loaded the esm.sh SSE helper, splash hides on Flutter's first frame (15 s safety).
- Web cache headers: bootstrap / main.dart.js revalidate with `stale-while-revalidate=86400`; `/canvaskit`, `/icons` 7 days; `/assets` 1 h + SWR 7 days; HTML no-cache. **Deploy workflows now emit these headers** (they previously overwrote `vercel.json` with a legacy config whose headers never applied).
- Backend: analytics and read-only usage logging moved off the response path (`EdgeRuntime.waitUntil`); unused plan lookup removed from `learning-paths`; leaderboard `Cache-Control: private`; per-worker TTL caches for daily verse (until UTC midnight), learning-path translations and topic counts (10 min), system config (5 min), subscription pricing (10 min); `system-config` / `subscription-pricing` send public cache headers; timeout timer leak fixed.

Verified: 1820 frontend tests, backend type-check, manual checks (EN → HI → ML → EN switching on Home/Topics/Generate, enroll updates Home, offline shows saved content, cold-start deep link). Local Home first paint ≈ 350 ms.

**Measure after deploy:** re-run the production waterfall (FCP, number and timing of calls before first paint) and confirm the new `Cache-Control` headers on `/assets`, `/canvaskit`, `main.dart.js`.

---

## 3. Phase 2 — backend round trips (every request faster)

Target: each Home / Topics / Community endpoint ≤ 3 sequential DB/auth round trips warm; p50 < 400 ms.

### 2.1 Resolve auth once per request, locally  *(high impact, medium effort)*
- **Problem:** `createFunction` calls GoTrue `auth.getUser()` over the network on every request (`_shared/core/function-factory.ts:~180, ~524`), including simple functions. Handlers then call `AuthService.getUserContext` (another `getUser` + `user_profiles` read) and `getUserPlan`, which calls `getUserContext` again (`_shared/services/auth-service.ts:~91, ~119, ~410, ~431`). `token-status` makes 3 GoTrue calls + 2 profile reads before its real work. The `fellowship*` functions call `auth.getUser(token)` themselves.
- **Change:**
  - Verify the JWT locally (`supabase.auth.getClaims()` with cached JWKS, or `jose` with the project secret — confirm against current Supabase docs before implementing).
  - Build `userContext` once in the factory and pass it to handlers; `AuthService.getUserContext/getUserPlan` accept it, with a per-request memo for the plan.
  - Skip auth entirely for `createSimpleFunction` handlers that don't use it.
  - Update ~25 callers (token-status, continue-learning, get-due-memory-verses, learning-paths, fellowship*, …).
- **Risk:** auth is security-critical. Keep token expiry / signature / audience checks; add tests for expired, tampered and anonymous tokens; roll out behind a flag if possible.

### 2.2 Remove N+1 queries  *(high impact, low–medium effort)*
| Endpoint | Today | Change |
|---|---|---|
| `continue-learning` (`index.ts:~256-272`) | 2 queries per topic in a loop | 2 `.in()` queries (topic ids, path ids) in `Promise.all` |
| `topics-for-you` (`index.ts:~130`, `_shared/topic-selector.ts:~411-419`) | new client + 1 translation query per topic | one `.in('topic_id', ids).eq('language_code', lang)`; reuse the service client |
| `learning-paths?action=recommended` (`index.ts:~218-268, ~1227-1243, ~1328-1361, ~1414-1440`) | 11–20+ sequential calls | batch translations + completed counts for all candidates in 2 queries, or one RPC `get_recommended_path(user, lang)` |
| `fellowship` list (`index.ts:~101-176`) | `auth.admin.getUserById` per mentor + 2 queries per fellowship | names/avatars from `user_profiles` via `.in()`; member counts via one grouped query/RPC; study rows via one `.in()` |

### 2.3 Parallelise independent queries  *(medium impact, low effort)*
- `get-user-usage-stats` (`index.ts:~63-150`): 4 independent queries → `Promise.all`.
- `user-profile` GET (`index.ts:~332-400`): profile, preferences in parallel; drop `auth.admin.getUserById` (email is in the JWT claims); cache `admin_emails`; run the admin auto-grant only on POST/sync, not every GET.
- `topics-recommended` (`index.ts:~220-232`): include `getTopics` in the existing parallel batch.

### 2.4 More server + HTTP caching of global data  *(medium impact, low effort)*
- 5–15 min per-worker caches + `Cache-Control: public, max-age=300, stale-while-revalidate=3600` for `get-plans`, `get-token-pricing`, `study-get-token-costs`, `topics-categories`, `topics-recommended` (without progress), learning-path catalog when `include_progress=false`.
- `daily-verse`: strip `timestamp` / `fromCache` from the body so an ETag stays stable.

### 2.5 Frontend request hygiene  *(medium impact, low effort)*
- `/user-profile` still fires ~4× per launch from `UserProfileApiService` / `AuthStateProvider` (not language): one shared, cached profile source (in memory for the session + persisted, SWR).
- Community on Home: `fellowship` list requested twice; `fellowship-meetings` fetched sequentially per fellowship → one batched call or parallel requests.
- Anonymous requests wait ~1 s each (`getAuthHeaders` retries 3×500 ms when there is no session) — only retry while an OAuth callback is actually in progress.

### Phase 2 testing
- Backend: unit tests for local JWT verification (valid / expired / tampered / anon) and for each batched query; `deno check`; run functions locally with `per_worker` policy to observe cache hits.
- Frontend: full `flutter test`; manual pass (login/logout, account switch, language switch, enroll/complete/reset, fellowship Home and lessons, token/credits screens).
- Production: compare p50/p95 per function in Supabase logs before/after; watch error rates for 24 h after deploy.

---

## 4. Phase 3 — bigger / structural items

### 3.1 Persist more client state (instant screens after reload)  *(medium impact, medium effort)*
- Persist + SWR: token status (`tokens/presentation/bloc/token_bloc.dart`), subscription status (`subscription/presentation/bloc/subscription_bloc.dart`), usage stats, fellowships list and discover, user profile.
- Key by user id; clear on logout / user switch; refresh after purchase / join / leave.

### 3.2 Web payload  *(high impact on cold visits, medium effort)*
- Fonts: drop unused weights; subset Inter/Poppins to the glyphs used (Latin + Devanagari/Malayalam handled by fallback fonts) — ~2 MB raw today (`pubspec.yaml:~144-164`).
- Hero photos: 9 JPGs at 1333×2000, 218–650 KB → ~1000 px tall, q70 or WebP (~80–120 KB each); `AIDiscipler.png` 204 KB.
- Deferred imports: Hindi/Malayalam translation maps (`core/i18n/app_translations.dart`, ~595 KB), PDF export, TTS, admin screens.
- Evaluate `--wasm` (skwasm) builds and hashed asset filenames so `/assets` and `main.dart.js` can be cached `immutable`.
- Replace the dead `flutter_service_worker.js` import in `web/firebase-messaging-sw.js` with a small cache-first service worker for the shell and assets (with versioned cache names and update-on-deploy).

### 3.3 Backend cold start  *(medium impact, medium effort)*
- `_shared/core/services.ts` statically imports and constructs every service (LLM clients, voice streaming, study guide service, security validator — ~11k lines) for every function → lazy getters / dynamic `import()`.
- One supabase-js version via `_shared/import_map.json` (currently `@2`, `@2.39.0`, `@2.39.3`, and `jsr:@supabase/supabase-js@2` in system-config); one shared service client instead of per-call clients.

### 3.4 Leaderboards  *(medium impact, medium effort; also a correctness bug)*
- `get-memory-champions-leaderboard` loads 1000 profiles, all mastered verses and all streaks, then ranks in JS; PostgREST `max_rows=1000` silently truncates, so ranks are already wrong. Move to an SQL RPC (`GROUP BY … ORDER BY … LIMIT`) or a materialized view refreshed by cron; cache 5 min.
- Review `get_leaderboard` / `get_user_gamification_stats` the same way (aggregates over all users per call).

### 3.5 Database  *(low–medium impact, low effort; migrations)*
- Rewrite `get_user_plan_with_subscription` as one query ordered by plan rank; add `subscriptions(user_id, status)` index.
- Retention job for `analytics_events` (e.g. 90 days) and drop unused indexes on it.
- Precompute `total_topics` on `learning_paths` (used by `get_available_learning_paths` correlated subqueries).
- RLS: wrap `auth.uid()` as `(select auth.uid())` in policies for tables the app queries directly (Supabase `auth_rls_initplan` advisor).
- Migrations are applied by the deploy pipeline; never `db reset` local or push to production manually.

### Phase 3 testing
- Web: Lighthouse / WebPageTest on production (cold + repeat), bundle-size report per build.
- Leaderboard: compare RPC results with the current output on a copy of the data; verify > 1000 users.
- DB: run Supabase advisors after migrations; EXPLAIN the rewritten RPCs.

---

## 5. Success metrics

| Metric | Baseline | Phase 1 target | Phase 2 target | Phase 3 target |
|---|---|---|---|---|
| Web FCP, cold | 9.9 s | ≤ 4 s | ≤ 3 s | ≤ 2.5 s |
| Web FCP, repeat visit | ~9 s | ≤ 2 s | ≤ 1.5 s | ≤ 1 s |
| Calls blocking first paint | 3 (serial) + profile | 0 with cache | 0 | 0 |
| `/user-profile` per launch | 6–8 | ≤ 4 | 1 | 1 |
| Home endpoints p50 (warm) | 0.35–0.8 s | — | < 400 ms | < 300 ms |
| Web cold download | ~5.5 MB brotli | same | same | ≤ 3.5 MB |

## 6. Order of work
1. Deploy Phase 1, re-measure production, fix regressions.
2. Phase 2: 2.2 → 2.3 → 2.4 → 2.5 (low risk), then 2.1 (auth) as a separately reviewed change.
3. Phase 3: 3.2 (web payload) and 3.4 (leaderboard correctness) first, then 3.1, 3.3, 3.5.
