# Admin Edge Function Consolidation — Design

## Context

Production Supabase project is at the Free-plan cap of **100 Edge Functions** (confirmed via `supabase functions list --project-ref wzdcwxvyjuxjgzpnukvm`). Deploying the 4 new `admin-*-affiliate-keyword` functions pushed past it (`402: Max number of functions reached for project`), breaking the backend deploy workflow.

Fix: consolidate several families of thin, single-purpose admin Edge Functions into fewer router-style functions, each dispatching internally on HTTP method + URL path segments. This pattern already exists in the codebase (`admin-learning-paths/index.ts`) — it becomes the template.

**Hard constraint**: never touch any function the Flutter app depends on. Every function in scope below was verified admin-web-only via repo-wide grep (including `frontend/`) during research — zero Flutter/webhook/cron callers found for any of them.

## Scope

Five consolidations, saving **9 functions** (103 → 94, before re-adding the 4 affiliate-keyword functions this unblocks → 98 total, comfortably under 100 with headroom for near-term growth):

| New function | Absorbs | Saves |
|---|---|---|
| `admin-affiliate-keywords` | `admin-list/create/toggle/delete-affiliate-keyword` (4) | 3 |
| `admin-promo-codes` | `admin-list/create/toggle-promo-code` (3) | 2 |
| `admin-learning-paths` (existing, extended) | `admin-learning-path-topics` (1, under new `/topics` sub-route) | 1 |
| `admin-subscriptions` | `admin-update-subscription` + `admin-update-subscription-price` (2) | 1 |
| `admin-analytics` | `admin-usage-analytics` + `admin-usage-logs` + `admin-pl-analytics` (3) | 2 |

**Explicitly excluded**: `admin-study-generator` (SSE streaming, GET-only, different auth model and factory than `admin-study-guides` — forcing a merge adds real risk for one saved slot) and `admin-study-guides` (has an apparently-orphaned `handleGetById` path — admin-web's live UI bypasses the Edge Function and queries `study_guides` directly; that's a separate cleanup, not touched here). `admin-recommended-topics` has no natural pair and stays as-is.

## Router pattern (template: `admin-learning-paths/index.ts`)

Every merged function keeps the SAME per-function auth preamble already used by the family being merged (do not introduce a new shared auth helper in this pass — that's a separate, larger refactor). Dispatch shape:

```ts
const url = new URL(req.url)
const pathParts = url.pathname.split('/').filter(Boolean)  // drops leading "admin-xxx" segment already stripped by Supabase's routing
const method = req.method

if (method === 'GET' && pathParts.length === 0) return handleList(...)
else if (method === 'POST' && pathParts.length === 0) return handleCreate(...)
else if (method === 'POST' && pathParts[0] === 'toggle') return handleToggle(...)
// ...one branch per absorbed operation, named handlers unchanged from their source files
else return json({ error: 'Not found' }, 404)
```

Each absorbed operation's handler function is copied over **verbatim** (same body, same table/RPC calls) — only the outer routing changes. This keeps the diff reviewable per-operation and avoids introducing new bugs into logic that already works in production.

## Per-group design

### 1. `admin-affiliate-keywords`

Source functions are near-identical (bare `Deno.serve`, hand-rolled `requireAdmin()` preamble, `affiliate_keywords` table). Merge via method-only dispatch (no sub-resources, so no path segments needed beyond an action segment for toggle/delete):

- `GET /` → list
- `POST /` → create
- `POST /toggle` → toggle (body carries `{id, is_active}`)
- `POST /delete` → delete (body carries `{id}`)

(POST-with-body for toggle/delete rather than DELETE-with-path-param, matching the source functions' existing request shape — no reason to redesign the wire contract, only the deployment boundary.)

### 2. `admin-promo-codes`

Same shape as affiliate-keywords: `GET /` list, `POST /` create, `POST /toggle` toggle. **Also fixes a pre-existing bug while touching this code**: promo-code audit logs currently insert into `admin_audit_log`, a table that doesn't exist anywhere in the migrations (same bug already fixed for affiliate-keywords earlier this session) — real table is `admin_logs`. Fix the table name as part of this merge.

### 3. `admin-learning-paths` absorbs `admin-learning-path-topics`

Topics' auth pattern differs from `admin-learning-paths`' (JWT-forwarding via `.functions.invoke` vs `admin-learning-paths`' service-role-key comparison) — **unify on `admin-learning-paths`' existing service-role pattern**, since that's the function surviving. New routes, namespaced under `/topics` to avoid colliding with the existing id-based routes (real path/topic IDs are UUIDs, never the literal string `"topics"`, so no ambiguity):

- `POST /topics` → add topic (was `admin-learning-path-topics` POST /)
- `DELETE /topics` → remove topic (was DELETE /)
- `PATCH /topics/reorder` → reorder (was PATCH /reorder)
- `PATCH /topics/:pathId/:topicId/milestone` → toggle milestone (was PATCH /:pathId/:topicId/milestone)

admin-web's 3 route files for topics currently call via `supabaseUser.functions.invoke('admin-learning-path-topics', ...)` (forwarding the user's own JWT) — since the merged target now expects the service-role auth pattern, these 3 routes switch from `.functions.invoke(...)` to the raw `fetch()` + service-role-key + `x-admin-user-id` pattern already used by `admin-learning-paths`' other routes (e.g. `app/api/admin/learning-paths/route.ts`). Only the `functionUrl`/call mechanism changes — request/response shapes, wrapper functions (`addTopicToPath`, `removeTopicFromPath`, `reorderPathTopics`, `toggleMilestone` in `lib/api/admin.ts`), and their types are untouched.

### 4. `admin-subscriptions`

Highest-complexity merge — the two source functions differ in cors module import, auth-client setup (anon-then-admin vs service-role-from-start), and audit mechanism (direct `admin_audit_log` table insert — same nonexistent-table bug, fix to `admin_logs` here too — vs a Postgres RPC `log_subscription_price_change`, which stays as-is since it's a different, valid mechanism for a different purpose). Both are `POST`-only today, so route by an explicit path segment:

- `POST /` → update subscription (was `admin-update-subscription`)
- `POST /price` → update price (was `admin-update-subscription-price`, keeps its Razorpay SDK usage and RPC audit call untouched)

Standardize on ONE cors import (`../_shared/cors.ts`, matching `admin-update-subscription`'s choice — no functional reason to prefer the other) and ONE auth-client pattern (service-role-from-start, matching the price function — simpler, one fewer round trip).

admin-web side: `app/api/admin/update-subscription/route.ts` currently calls via `supabase.functions.invoke(...)`; `app/api/admin/subscription/update-price/route.ts` (inconsistently nested path) calls via raw `fetch()` with its own `is_admin` check. Both switch to raw `fetch()` targeting `admin-subscriptions` and `admin-subscriptions/price` respectively — standardizing on the fetch pattern used everywhere else in this consolidation. **Also fix while touching it**: `subscription-price-update-modal.tsx:106` currently calls `/api/admin/subscription/update-price` via a direct inline `fetch()`, bypassing `lib/api/admin.ts` entirely (the only wrapper-less call site found across all 5 groups) — add a proper `updateSubscriptionPrice()` wrapper matching the existing `updateSubscription()` pattern and switch the modal to use it.

### 5. `admin-analytics`

Three functions, one shared consumer page (`llm-costs`). Route by explicit segment (all `POST`, all take date-range bodies):

- `POST /usage` → was `admin-usage-analytics` (heavy: multiple RPCs + paginated table scans)
- `POST /logs` → was `admin-usage-logs` (paginated raw rows)
- `POST /pl` → was `admin-pl-analytics` (live FX rate + paginated scans + RPC)

**Also clean up while touching it**: `admin-usage-analytics` and `admin-pl-analytics` each have their own near-identical local `fetchAllRows` pagination helper — dedupe into a single shared helper function inside the merged file (module-private, not promoted to `_shared/` — this pass doesn't touch the shared-code layer).

admin-web: `app/api/admin/usage-analytics/route.ts`, `usage-logs/route.ts`, `pl-analytics/route.ts` all switch their `functionUrl` to `admin-analytics/usage`, `admin-analytics/logs`, `admin-analytics/pl` respectively. Wrapper functions (`fetchUsageAnalytics`, `fetchUsageLogs`, `fetchPlAnalytics`) and their callers (`llm-costs/page.tsx`, `detailed-logs-table.tsx`) are untouched — only the Next.js route's internal target changes.

## Deployment / cutover sequence

Deleting an old function and deploying its replacement are separate `supabase functions deploy`/`delete` operations — there is no atomic swap. Sequence per group, to avoid a window where admin-web calls a function that's been deleted but whose replacement isn't live yet:

1. Deploy the new merged function (production now has both old and new for that group — briefly over quota again for a single group's function count, which is fine since we're deleting the old ones same-session).
2. Update and deploy the admin-web routes for that group to point at the new function.
3. Verify (manual smoke check against the merged endpoints).
4. Delete the old function(s) for that group via `supabase functions delete <name> --project-ref <ref>`.

Repeat per group (5 iterations) rather than batching all deletes to the end — keeps each group independently verifiable and limits blast radius if one group's merge has an issue.

## Non-goals

- No shared auth helper / router factory addition to `_shared/core/function-factory.ts` in this pass — each merged function keeps its family's existing hand-rolled preamble. A proper `createRouterFunction` factory abstraction is a separate, larger refactor worth doing later once this pattern has 5+ real examples to generalize from.
- No touching `admin-study-generator`/`admin-study-guides` (see Scope).
- No touching any non-`admin-*` function family (fellowship-*, memory-verse-*, subscription-* consumer-facing, webhooks, etc.) — out of scope, and several of those are already router-style or are Flutter-facing.
- No RLS/migration changes — this is purely a function-count/deployment-topology change; database schema is untouched.

## Testing

- `deno check` on each new merged function file.
- Manual smoke test per group after step 2/3 of the cutover sequence above (admin-web dev pointed at the newly-deployed function, exercise each absorbed operation once).
- No new automated test infra — admin-web has no test framework today (per its `CLAUDE.md`), consistent with existing convention.
