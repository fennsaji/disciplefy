# Admin Edge Function Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge 5 families of thin admin-only Edge Functions into 5 router-style functions, freeing 9 function slots on the Supabase project (currently at the 100-function plan cap) so the backend deploy can succeed again.

**Architecture:** Each merged function keeps its absorbed functions' handler bodies verbatim, adding only an outer HTTP-method + URL-path-segment dispatcher — the same pattern already used by `admin-learning-paths/index.ts`. Each group is cut over independently: deploy new function → repoint admin-web → verify → delete old functions. No shared router abstraction is introduced in this pass.

**Tech Stack:** Deno Edge Functions (Supabase), Next.js 16 API routes (admin-web), `@supabase/supabase-js`.

**Spec:** `docs/superpowers/specs/2026-08-15-admin-function-consolidation-design.md`

## Global Constraints

- **Never touch anything the Flutter app depends on.** Every function in this plan was verified admin-web-only via repo-wide grep (including `frontend/`) during design research. Do not extend scope to any function not explicitly named here without re-verifying it's admin-web-only first.
- **Never run `git commit` or `git push` unless the user explicitly says so** — leave changes uncommitted for manual review, per this project's standing rule.
- **Never deploy to production or delete a production function without explicit confirmation from the user first** — this plan's steps describe the deploy/delete commands to run, but each one is a real, hard-to-reverse production action. Present the command, explain what it does, and wait for an explicit go-ahead before running any `supabase functions deploy` or `supabase functions delete` step against the production project ref. Local `deno check` and file edits do not require this.
- Copy handler function bodies **verbatim** from their source files — do not "improve" or refactor absorbed logic while moving it, except where a step explicitly calls out a bug fix (audit-log table name fixes, `fetchAllRows` dedup).
- Production project ref: `wzdcwxvyjuxjgzpnukvm`.

---

### Task 1: `admin-affiliate-keywords` — backend merge

**Files:**
- Create: `backend/supabase/functions/admin-affiliate-keywords/index.ts`
- Delete (after Task 2 verifies): `backend/supabase/functions/admin-list-affiliate-keywords/`, `admin-create-affiliate-keyword/`, `admin-toggle-affiliate-keyword/`, `admin-delete-affiliate-keyword/`

**Interfaces:**
- Produces: one Edge Function `admin-affiliate-keywords` responding to `GET /`, `POST /`, `POST /toggle`, `POST /delete`, each with the same request/response JSON shapes the 4 source functions already have.

- [ ] **Step 1: Read the 4 source files in full**

Read `backend/supabase/functions/admin-list-affiliate-keywords/index.ts`, `admin-create-affiliate-keyword/index.ts`, `admin-toggle-affiliate-keyword/index.ts`, `admin-delete-affiliate-keyword/index.ts`. Note their shared preamble (CORS headers, `json()` helper, `requireAdmin()` function) — these 4 files' preambles are identical; you'll keep exactly one copy of it in the merged file.

- [ ] **Step 2: Write the merged file**

Structure (preamble comes from the 4 source files, copied once; each handler body comes from its source file's main logic, copied verbatim into a named function):

```ts
import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

async function requireAdmin(req: Request): Promise<
  { adminSupabase: ReturnType<typeof createClient>; adminUserId: string } | Response
> {
  // Copy this function's body verbatim from any one of the 4 source files
  // (they are identical) — service-role bearer token check, then
  // user_profiles.is_admin lookup for x-admin-user-id.
}

// Copy verbatim from admin-list-affiliate-keywords/index.ts's main logic
// (everything after the requireAdmin call), renamed to a plain async
// function taking (auth: {adminSupabase, adminUserId}) instead of being
// the Deno.serve handler body directly.
async function handleList(auth: { adminSupabase: ReturnType<typeof createClient>; adminUserId: string }) {
  // ... verbatim body ...
}

// Copy verbatim from admin-create-affiliate-keyword/index.ts, same
// treatment — takes (auth, req) since create needs to parse the request body.
async function handleCreate(auth: { adminSupabase: ReturnType<typeof createClient>; adminUserId: string }, req: Request) {
  // ... verbatim body, including the length/bracket-char validation and
  // the 23505 -> 409 duplicate handling ...
}

// Copy verbatim from admin-toggle-affiliate-keyword/index.ts
async function handleToggle(auth: { adminSupabase: ReturnType<typeof createClient>; adminUserId: string }, req: Request) {
  // ... verbatim body, including PGRST116 -> 404 handling ...
}

// Copy verbatim from admin-delete-affiliate-keyword/index.ts
async function handleDelete(auth: { adminSupabase: ReturnType<typeof createClient>; adminUserId: string }, req: Request) {
  // ... verbatim body, including PGRST116 -> 404 handling ...
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const url = new URL(req.url)
    // pathParts[0] is always this function's own name — Supabase does NOT
    // strip it (confirmed against admin-learning-paths, which reads
    // pathParts[1] as its id segment). Base route = length 1.
    const pathParts = url.pathname.split('/').filter(Boolean)
    const method = req.method

    if (method === 'GET' && pathParts.length === 1) return await handleList(auth)
    if (method === 'POST' && pathParts.length === 1) return await handleCreate(auth, req)
    if (method === 'POST' && pathParts.length === 2 && pathParts[1] === 'toggle') return await handleToggle(auth, req)
    if (method === 'POST' && pathParts.length === 2 && pathParts[1] === 'delete') return await handleDelete(auth, req)

    return json({ error: 'Not found' }, 404)
  } catch (error) {
    console.error('Error in admin-affiliate-keywords:', error)
    return json({ error: 'Internal server error' }, 500)
  }
})
```

- [ ] **Step 3: Typecheck**

Run: `cd backend && deno check supabase/functions/admin-affiliate-keywords/index.ts`
Expected: no errors.

- [ ] **Step 4: Confirm before deploying to production**

Show the user the file and this command, and wait for explicit confirmation before running it:
`supabase functions deploy admin-affiliate-keywords --project-ref wzdcwxvyjuxjgzpnukvm`

- [ ] **Step 5: Do not delete the 4 old functions yet** — that happens in Task 2 after admin-web is repointed and verified.

---

### Task 2: `admin-affiliate-keywords` — admin-web repoint + old function cleanup

**Files:**
- Modify: `admin-web/app/api/admin/list-affiliate-keywords/route.ts`
- Modify: `admin-web/app/api/admin/create-affiliate-keyword/route.ts`
- Modify: `admin-web/app/api/admin/toggle-affiliate-keyword/route.ts`
- Modify: `admin-web/app/api/admin/delete-affiliate-keyword/route.ts`

**Interfaces:**
- Consumes: `admin-affiliate-keywords` Edge Function from Task 1 (`GET /`, `POST /`, `POST /toggle`, `POST /delete`).
- No changes to `admin-web/lib/api/admin.ts` wrapper functions, `admin-web/types/admin.ts` types, or `admin-web/app/(dashboard)/affiliate-keywords/page.tsx` — request/response shapes are unchanged, only which Edge Function URL each route calls.

- [ ] **Step 1: Update each route's `functionUrl`**

In each of the 4 route files, change the Edge Function URL target:
- `list-affiliate-keywords/route.ts`: `${NEXT_PUBLIC_SUPABASE_URL}/functions/v1/admin-list-affiliate-keywords` → `${NEXT_PUBLIC_SUPABASE_URL}/functions/v1/admin-affiliate-keywords`
- `create-affiliate-keyword/route.ts`: → `.../admin-affiliate-keywords` (same base, method stays POST)
- `toggle-affiliate-keyword/route.ts`: → `.../admin-affiliate-keywords/toggle`
- `delete-affiliate-keyword/route.ts`: → `.../admin-affiliate-keywords/delete`

Everything else in each route file (auth checks, request forwarding, error handling) stays exactly as-is.

- [ ] **Step 2: Typecheck**

Run: `cd admin-web && npm run type-check`
Expected: no errors.

- [ ] **Step 3: Manual verification**

With local Supabase running and `admin-affiliate-keywords` deployed (Task 1 Step 4) or served locally (`supabase functions serve`), run `cd admin-web && npm run dev`, open `/affiliate-keywords`, and exercise: load list, add a keyword, toggle it, delete it. Confirm all 4 operations still work end to end.

- [ ] **Step 4: Confirm before deleting the 4 old functions from production**

Show the user this command and wait for explicit confirmation:
```
supabase functions delete admin-list-affiliate-keywords --project-ref wzdcwxvyjuxjgzpnukvm
supabase functions delete admin-create-affiliate-keyword --project-ref wzdcwxvyjuxjgzpnukvm
supabase functions delete admin-toggle-affiliate-keyword --project-ref wzdcwxvyjuxjgzpnukvm
supabase functions delete admin-delete-affiliate-keyword --project-ref wzdcwxvyjuxjgzpnukvm
```

- [ ] **Step 5: Delete the local source directories**

After production deletion is confirmed done: `rm -rf backend/supabase/functions/admin-list-affiliate-keywords backend/supabase/functions/admin-create-affiliate-keyword backend/supabase/functions/admin-toggle-affiliate-keyword backend/supabase/functions/admin-delete-affiliate-keyword`

---

### Task 3: `admin-promo-codes` — backend merge (with audit-log fix)

**Files:**
- Create: `backend/supabase/functions/admin-promo-codes/index.ts`
- Delete (after Task 4 verifies): `backend/supabase/functions/admin-list-promo-codes/`, `admin-create-promo-code/`, `admin-toggle-promo-code/`

**Interfaces:**
- Produces: `admin-promo-codes` responding to `GET /`, `POST /`, `POST /toggle`.

- [ ] **Step 1: Read the 3 source files in full**

Read `backend/supabase/functions/admin-list-promo-codes/index.ts`, `admin-create-promo-code/index.ts`, `admin-toggle-promo-code/index.ts`. Note each has its own inline auth block (not shared via a common preamble the way affiliate-keywords' functions were) — you'll consolidate to one copy.

- [ ] **Step 2: Write the merged file**

Same structure as Task 1's `admin-affiliate-keywords`: one preamble (auth check + CORS + json helper, copied from any one of the 3 — they're functionally equivalent), three handlers (`handleList`, `handleCreate`, `handleToggle`) each copied verbatim from their source file's logic, dispatched by method + path:

```ts
// pathParts[0] is always this function's own name (see the routing
// ruling in the ledger / Task 1's note) — base route = length 1.
// list and create are BOTH POST (list takes a filter body, not query
// params — confirmed against the real source, and confirmed to collide
// with create's POST / if both were routed to the base path) — list gets
// an explicit /list suffix, matching the action-suffix pattern already
// used for toggle. create keeps POST / (unchanged, matches this
// codebase's convention — see admin-learning-paths' own POST /=create).
if (method === 'POST' && pathParts.length === 2 && pathParts[1] === 'list') return await handleList(auth, req)
if (method === 'POST' && pathParts.length === 1) return await handleCreate(auth, req)
if (method === 'POST' && pathParts.length === 2 && pathParts[1] === 'toggle') return await handleToggle(auth, req)
return json({ error: 'Not found' }, 404)
```

**Audit-log fix**: wherever the copied `handleCreate`/`handleToggle` bodies write to `admin_audit_log`, change the table name to `admin_logs` (same fix already applied to affiliate-keywords earlier — `admin_audit_log` does not exist in any migration; `admin_logs` does, with matching `admin_user_id`/`action`/`details` columns).

- [ ] **Step 3: Typecheck**

Run: `cd backend && deno check supabase/functions/admin-promo-codes/index.ts`
Expected: no errors.

- [ ] **Step 4: Confirm before deploying to production**

Show the user the file and wait for confirmation before: `supabase functions deploy admin-promo-codes --project-ref wzdcwxvyjuxjgzpnukvm`

---

### Task 4: `admin-promo-codes` — admin-web repoint + old function cleanup

**Files:**
- Modify: the admin-web route file(s) that currently call `admin-list-promo-codes`, `admin-create-promo-code`, `admin-toggle-promo-code`. Find them with `grep -rl "admin-list-promo-codes\|admin-create-promo-code\|admin-toggle-promo-code" admin-web/app/api/admin/` (route file names may not exactly mirror the function names — verify before editing).

**Interfaces:**
- Consumes: `admin-promo-codes` from Task 3 (`POST /list`, `POST /` for create, `POST /toggle`).
- No changes to `admin-web/lib/api/admin.ts` (`listPromoCodes`, `createPromoCode`, `togglePromoCode`), types, or `admin-web/app/(dashboard)/promo-codes/page.tsx`.

- [ ] **Step 1: Update each route's function URL target to `admin-promo-codes`** — the list route needs a `/list` suffix (list is `POST /list`, not the base path — see Task 3's ruling), create keeps the base path (`POST /`, no suffix), toggle keeps `/toggle`. Same URL-swap pattern as Task 2 Step 1 otherwise.

- [ ] **Step 2: Typecheck**

Run: `cd admin-web && npm run type-check`
Expected: no errors.

- [ ] **Step 3: Manual verification**

`/promo-codes` page: load list, create a campaign, toggle its status. Confirm all 3 still work.

- [ ] **Step 4: Confirm before deleting the 3 old functions from production**

```
supabase functions delete admin-list-promo-codes --project-ref wzdcwxvyjuxjgzpnukvm
supabase functions delete admin-create-promo-code --project-ref wzdcwxvyjuxjgzpnukvm
supabase functions delete admin-toggle-promo-code --project-ref wzdcwxvyjuxjgzpnukvm
```
(wait for explicit user confirmation first)

- [ ] **Step 5: Delete local source directories**

`rm -rf backend/supabase/functions/admin-list-promo-codes backend/supabase/functions/admin-create-promo-code backend/supabase/functions/admin-toggle-promo-code`

---

### Task 5: `admin-learning-paths` absorbs `admin-learning-path-topics` — backend merge

**Files:**
- Modify: `backend/supabase/functions/admin-learning-paths/index.ts`
- Delete (after Task 6 verifies): `backend/supabase/functions/admin-learning-path-topics/`

**Interfaces:**
- Produces: `admin-learning-paths` gains 4 new routes under `/topics`: `POST /topics`, `DELETE /topics`, `PATCH /topics/reorder`, `PATCH /topics/:pathId/:topicId/milestone` — in addition to its existing `GET /`, `GET /:id`, `POST /`, `PUT /:id`, `DELETE /:id`, `PATCH /:id/reorder`, `PATCH /:id/toggle` routes (unchanged).

- [ ] **Step 1: Read both files in full**

Read `backend/supabase/functions/admin-learning-paths/index.ts` (the surviving file, ~693 lines) and `backend/supabase/functions/admin-learning-path-topics/index.ts` (~442 lines, being absorbed).

Note `admin-learning-path-topics` uses a DIFFERENT auth pattern (JWT-forwarding: `createClient(url, ANON_KEY, {global:{headers:{Authorization: req.headers.get('Authorization')!}}})` + `auth.getUser()`) than `admin-learning-paths` (service-role-key comparison + `x-admin-user-id` header). You are unifying on `admin-learning-paths`' existing pattern — the copied topics handlers must be adapted to receive whatever auth-context shape `admin-learning-paths`' existing handlers already use (check its `handleList`/`handleCreate` signatures for the exact shape and match it), not the JWT-forwarding one.

- [ ] **Step 2: Add the 4 topics handlers**

Copy `handleAddTopic`, `handleRemoveTopic`, `handleReorder` (topics' reorder — will need a distinct name from `admin-learning-paths`' own existing `handleReorder` for path reordering; call this one `handleReorderTopics`), and `handleToggleMilestone` verbatim from `admin-learning-path-topics/index.ts` into `admin-learning-paths/index.ts`, below the existing handlers. Adjust only the auth-context parameter to match `admin-learning-paths`' existing pattern (the query/mutation logic itself — table names, RPC call to `shift_learning_path_topics`, `recalculateTotalXP` — stays verbatim). Also copy `recalculateTotalXP` if it's a standalone helper the topics handlers call.

- [ ] **Step 3: Add the 4 new dispatch branches**

Add these branches to the existing `if/else if` chain in `admin-learning-paths/index.ts`, checking `pathParts[0] === 'topics'` first so they don't collide with the existing id-based routes (real learning-path IDs are UUIDs, never the literal string `"topics"`):

```ts
// pathParts[0] is always "admin-learning-paths" itself (matches this
// file's existing branches above, which already read pathParts[1] as the
// id — see the routing ruling in the ledger). Topics routes therefore
// start checking at pathParts[1], one deeper than the earlier draft had it.
else if (method === 'POST' && pathParts.length === 2 && pathParts[1] === 'topics')
  return handleAddTopic(...)
else if (method === 'DELETE' && pathParts.length === 2 && pathParts[1] === 'topics')
  return handleRemoveTopic(...)
else if (method === 'PATCH' && pathParts.length === 3 && pathParts[1] === 'topics' && pathParts[2] === 'reorder')
  return handleReorderTopics(...)
else if (method === 'PATCH' && pathParts.length === 5 && pathParts[1] === 'topics' && pathParts[4] === 'milestone')
  return handleToggleMilestone(pathParts[2], pathParts[3], ...)
```

Insert these branches BEFORE the existing `else if (method === 'PATCH' && pathParts.length === 3 && pathParts[2] === 'reorder')` branch in the chain, so the `pathParts[0] === 'topics'` checks are evaluated first (the existing branches use `pathParts.length` checks that could otherwise ambiguously match — verify no overlap by re-reading the full existing chain before inserting).

- [ ] **Step 4: Typecheck**

Run: `cd backend && deno check supabase/functions/admin-learning-paths/index.ts`
Expected: no errors.

- [ ] **Step 5: Confirm before deploying to production**

Wait for explicit confirmation, then: `supabase functions deploy admin-learning-paths --project-ref wzdcwxvyjuxjgzpnukvm`

---

### Task 6: `admin-learning-paths`/topics — admin-web repoint + old function cleanup

**Files:**
- Modify: `admin-web/app/api/admin/path-topics/route.ts`
- Modify: `admin-web/app/api/admin/path-topics/reorder/route.ts`
- Modify: `admin-web/app/api/admin/path-topics/[pathId]/[topicId]/milestone/route.ts`

**Interfaces:**
- Consumes: the 4 new `/topics`-prefixed routes on `admin-learning-paths` from Task 5.
- No changes to `admin-web/lib/api/admin.ts` wrapper functions (`addTopicToPath`, `removeTopicFromPath`, `reorderPathTopics`, `toggleMilestone`), `admin-web/types/admin.ts`, or `admin-web/components/dialogs/path-topic-organizer.tsx`.

- [ ] **Step 1: Switch from `.functions.invoke(...)` to `fetch()` + service-role pattern**

These 3 routes currently call via `supabaseUser.functions.invoke('admin-learning-path-topics', {...})`, forwarding the user's own JWT. Since the merged target (`admin-learning-paths`) expects the service-role + `x-admin-user-id` pattern, rewrite each route to match `admin-learning-paths`' existing routes (e.g. `admin-web/app/api/admin/learning-paths/route.ts`) — read that file first for the exact `fetch()` + header pattern to copy, then apply it here with the target URL changed to:
- `path-topics/route.ts`: `POST` → `.../admin-learning-paths/topics`, `DELETE` → `.../admin-learning-paths/topics`
- `path-topics/reorder/route.ts`: `PATCH` → `.../admin-learning-paths/topics/reorder`
- `path-topics/[pathId]/[topicId]/milestone/route.ts`: `PATCH` → `` `.../admin-learning-paths/topics/${pathId}/${topicId}/milestone` ``

Each route already does its own user-auth + `is_admin` check before calling the Edge Function (per the design doc's research) — keep that check, only change the call mechanism and target.

- [ ] **Step 2: Typecheck**

Run: `cd admin-web && npm run type-check`
Expected: no errors.

- [ ] **Step 3: Manual verification**

In the learning-paths admin UI, open the topic organizer dialog for a path: add a topic, reorder topics, toggle a milestone, remove a topic. Confirm all 4 still work.

- [ ] **Step 4: Confirm before deleting the old function from production**

Wait for explicit confirmation, then: `supabase functions delete admin-learning-path-topics --project-ref wzdcwxvyjuxjgzpnukvm`

- [ ] **Step 5: Delete local source directory**

`rm -rf backend/supabase/functions/admin-learning-path-topics`

---

### Task 7: `admin-subscriptions` — backend merge (with cors/auth/audit-log standardization)

**Files:**
- Create: `backend/supabase/functions/admin-subscriptions/index.ts`
- Delete (after Task 8 verifies): `backend/supabase/functions/admin-update-subscription/`, `admin-update-subscription-price/`

**Interfaces:**
- Produces: `admin-subscriptions` responding to `POST /` (was `admin-update-subscription`) and `POST /price` (was `admin-update-subscription-price`).

This is the highest-complexity merge in this plan — the two source functions differ in CORS import, auth-client setup, and audit mechanism. Read carefully before writing.

- [ ] **Step 1: Read both source files in full**

Read `backend/supabase/functions/admin-update-subscription/index.ts` (283 lines) and `admin-update-subscription-price/index.ts` (419 lines). Confirm for yourself: (a) which `cors.ts` module each imports (`admin-update-subscription` uses `../_shared/cors.ts`; `admin-update-subscription-price` uses `../_shared/utils/cors.ts` — these are two different files that may have different contents, check both), (b) `admin-update-subscription`'s auth flow (anon-key client + bearer auth header, then a separate admin/service-role client for the actual mutation) vs `admin-update-subscription-price`'s (service-role client from the very start), (c) `admin-update-subscription`'s audit write (direct insert into `admin_audit_log` — needs the same table-name fix as other groups, to `admin_logs`) vs `admin-update-subscription-price`'s (RPC call `log_subscription_price_change` — this one is a different, valid mechanism; do NOT change it).

- [ ] **Step 2: Write the merged file**

Standardize on:
- CORS: `../_shared/cors.ts` (matches `admin-update-subscription`'s choice)
- Auth: service-role-client-from-the-start pattern (matches `admin-update-subscription-price`'s — simpler, fewer round trips). Adapt the copied `admin-update-subscription` handler body to use this auth shape instead of its original anon-then-admin-client pattern.
- Audit for the `/` route: fix `admin_audit_log` → `admin_logs` while copying the handler over.
- Audit for the `/price` route: keep the `log_subscription_price_change` RPC call exactly as-is.

```ts
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    // service-role auth check (adapted from admin-update-subscription-price's pattern) — copy that file's auth block verbatim as the single auth path for this merged function.
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const url = new URL(req.url)
    // pathParts[0] is always this function's own name — base route = length 1.
    const pathParts = url.pathname.split('/').filter(Boolean)

    if (req.method === 'POST' && pathParts.length === 1) return await handleUpdateSubscription(auth, req)
    if (req.method === 'POST' && pathParts.length === 2 && pathParts[1] === 'price') return await handleUpdatePrice(auth, req)

    return json({ error: 'Not found' }, 404)
  } catch (error) {
    console.error('Error in admin-subscriptions:', error)
    return json({ error: 'Internal server error' }, 500)
  }
})
```

`handleUpdateSubscription` = `admin-update-subscription`'s core logic (tier→plan_code mapping, `subscription_plans`/`subscription_plan_providers` lookups, period/billing date computation, UPDATE-or-INSERT, duplicate cancellation, audit to `admin_logs`) — all copied verbatim except the auth-context shape and audit table name.

`handleUpdatePrice` = `admin-update-subscription-price`'s core logic (price-range validation, `subscription_plan_providers` join, provider branching — Razorpay SDK plan creation vs Google Play/Apple manual-update flow, `log_subscription_price_change` RPC call) — copied verbatim, including its `npm:razorpay@2.9.2` import.

- [ ] **Step 3: Typecheck**

Run: `cd backend && deno check supabase/functions/admin-subscriptions/index.ts`
Expected: no errors.

- [ ] **Step 4: Confirm before deploying to production**

Wait for explicit confirmation, then: `supabase functions deploy admin-subscriptions --project-ref wzdcwxvyjuxjgzpnukvm`

---

### Task 8: `admin-subscriptions` — admin-web repoint, wrapper addition, and old function cleanup

**Files:**
- Modify: `admin-web/app/api/admin/update-subscription/route.ts`
- Modify: `admin-web/app/api/admin/subscription/update-price/route.ts`
- Modify: `admin-web/lib/api/admin.ts` (add a new wrapper)
- Modify: `admin-web/components/modals/subscription-price-update-modal.tsx`

**Interfaces:**
- Consumes: `admin-subscriptions` from Task 7 (`POST /`, `POST /price`).
- Produces: `updateSubscriptionPrice(params): Promise<...>` wrapper in `lib/api/admin.ts`, matching the existing `updateSubscription()` wrapper's style (read that function first, lines ~123-137, and copy its shape — same fetch pattern, same `credentials: 'include'`, hitting `/api/admin/subscription/update-price`).

- [ ] **Step 1: Update `update-subscription/route.ts`**

**Ruling (verified against real source, corrects an earlier plan error):** `admin-subscriptions` (Task 7) authenticates via JWT-forwarding (`auth.getUser()` on the caller's own bearer token) for BOTH its routes — NOT service-role-key + `x-admin-user-id` like the other merged functions in this project. Do NOT switch to that pattern here.

This route currently calls via `supabase.functions.invoke('admin-update-subscription', {...})`, which forwards `Authorization: Bearer ${session.access_token}` — this already matches what `admin-subscriptions` expects. Only change the target function name string from `'admin-update-subscription'` to `'admin-subscriptions'` (still the base path — maps to `POST /`). Do not change the auth/header mechanism.

- [ ] **Step 2: Update `subscription/update-price/route.ts`**

Already uses raw `fetch()` forwarding `Authorization: Bearer ${session.access_token}` (line ~76) — this also already matches. Only change the target URL to `${NEXT_PUBLIC_SUPABASE_URL}/functions/v1/admin-subscriptions/price`. Keep its existing explicit `is_admin` check and its existing `Authorization` header forwarding exactly as-is.

- [ ] **Step 3: Add the `updateSubscriptionPrice` wrapper**

In `admin-web/lib/api/admin.ts`, near the existing `updateSubscription` function, add:

```ts
export async function updateSubscriptionPrice(params: {
  plan_provider_id: string
  new_price_minor: number
  notes?: string
  external_console_updated?: boolean
}) {
  const response = await fetch('/api/admin/subscription/update-price', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify(params),
  })
  if (!response.ok) {
    const err = await response.json().catch(() => ({}))
    throw new Error(err.error || 'Failed to update subscription price')
  }
  return response.json()
}
```

(Adjust the parameter type to match whatever `UpdatePriceRequest` shape the route already expects — check `admin-web/types/admin.ts` for an existing type to reuse instead of inlining one, if present.)

- [ ] **Step 4: Switch the modal to use the wrapper**

In `admin-web/components/modals/subscription-price-update-modal.tsx`, replace the direct inline `fetch('/api/admin/subscription/update-price', ...)` call (around line 106) with a call to `updateSubscriptionPrice(...)` imported from `@/lib/api/admin`, passing the same parameters the inline fetch currently sends.

- [ ] **Step 5: Typecheck**

Run: `cd admin-web && npm run type-check`
Expected: no errors.

- [ ] **Step 6: Manual verification**

Update a user's subscription tier via the edit page; update a plan's price via the price-update modal. Confirm both work.

- [ ] **Step 7: Confirm before deleting the 2 old functions from production**

```
supabase functions delete admin-update-subscription --project-ref wzdcwxvyjuxjgzpnukvm
supabase functions delete admin-update-subscription-price --project-ref wzdcwxvyjuxjgzpnukvm
```
(wait for explicit user confirmation first)

- [ ] **Step 8: Delete local source directories**

`rm -rf backend/supabase/functions/admin-update-subscription backend/supabase/functions/admin-update-subscription-price`

---

### Task 9: `admin-analytics` — backend merge (with pagination-helper dedup)

**Files:**
- Create: `backend/supabase/functions/admin-analytics/index.ts`
- Delete (after Task 10 verifies): `backend/supabase/functions/admin-usage-analytics/`, `admin-usage-logs/`, `admin-pl-analytics/`

**Interfaces:**
- Produces: `admin-analytics` responding to `POST /usage` (was `admin-usage-analytics`), `POST /logs` (was `admin-usage-logs`), `POST /pl` (was `admin-pl-analytics`).

- [ ] **Step 1: Read all 3 source files in full**

Read `backend/supabase/functions/admin-usage-analytics/index.ts` (417 lines), `admin-usage-logs/index.ts` (127 lines), `admin-pl-analytics/index.ts` (230 lines). Note `admin-usage-analytics` and `admin-pl-analytics` each define their own local `fetchAllRows` pagination helper — compare the two implementations to confirm they're functionally equivalent (same signature, same 1000-row-page loop behavior) before deduping; if they differ in a way that matters (different page size, different error handling), keep the more complete one and verify both callers still work with it.

- [ ] **Step 2: Write the merged file**

One shared `fetchAllRows` helper (module-private, deduped from the two near-identical copies), one auth preamble (copy from any one of the 3 — verify they're equivalent first), three handlers copied verbatim otherwise:

```ts
async function fetchAllRows(/* signature from the source helper */) {
  // deduped body
}

async function handleUsageAnalytics(auth, req) {
  // verbatim from admin-usage-analytics/index.ts, using the shared fetchAllRows
}

async function handleUsageLogs(auth, req) {
  // verbatim from admin-usage-logs/index.ts (doesn't use fetchAllRows — already paginates via .range())
}

async function handlePlAnalytics(auth, req) {
  // verbatim from admin-pl-analytics/index.ts, using the shared fetchAllRows
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const auth = await requireAdmin(req)
    if (auth instanceof Response) return auth

    const url = new URL(req.url)
    // pathParts[0] is always this function's own name — action segment is pathParts[1].
    const pathParts = url.pathname.split('/').filter(Boolean)

    if (req.method === 'POST' && pathParts.length === 2 && pathParts[1] === 'usage') return await handleUsageAnalytics(auth, req)
    if (req.method === 'POST' && pathParts.length === 2 && pathParts[1] === 'logs') return await handleUsageLogs(auth, req)
    if (req.method === 'POST' && pathParts.length === 2 && pathParts[1] === 'pl') return await handlePlAnalytics(auth, req)

    return json({ error: 'Not found' }, 404)
  } catch (error) {
    console.error('Error in admin-analytics:', error)
    return json({ error: 'Internal server error' }, 500)
  }
})
```

- [ ] **Step 3: Typecheck**

Run: `cd backend && deno check supabase/functions/admin-analytics/index.ts`
Expected: no errors.

- [ ] **Step 4: Confirm before deploying to production**

Wait for explicit confirmation, then: `supabase functions deploy admin-analytics --project-ref wzdcwxvyjuxjgzpnukvm`

---

### Task 10: `admin-analytics` — admin-web repoint + old function cleanup

**Files:**
- Modify: `admin-web/app/api/admin/usage-analytics/route.ts`
- Modify: `admin-web/app/api/admin/usage-logs/route.ts`
- Modify: `admin-web/app/api/admin/pl-analytics/route.ts`

**Interfaces:**
- Consumes: `admin-analytics` from Task 9 (`POST /usage`, `POST /logs`, `POST /pl`).
- No changes to `admin-web/lib/api/admin.ts` (`fetchUsageAnalytics`, `fetchUsageLogs`, `fetchPlAnalytics`), or their callers (`llm-costs/page.tsx`, `detailed-logs-table.tsx`).

- [ ] **Step 1: Update each route's function URL**
- `usage-analytics/route.ts`: → `.../admin-analytics/usage`
- `usage-logs/route.ts`: → `.../admin-analytics/logs`
- `pl-analytics/route.ts`: → `.../admin-analytics/pl`

- [ ] **Step 2: Typecheck**

Run: `cd admin-web && npm run type-check`
Expected: no errors.

- [ ] **Step 3: Manual verification**

Open `/llm-costs`, confirm the analytics overview, detailed logs table, and P&L view all still load data correctly.

- [ ] **Step 4: Confirm before deleting the 3 old functions from production**

```
supabase functions delete admin-usage-analytics --project-ref wzdcwxvyjuxjgzpnukvm
supabase functions delete admin-usage-logs --project-ref wzdcwxvyjuxjgzpnukvm
supabase functions delete admin-pl-analytics --project-ref wzdcwxvyjuxjgzpnukvm
```
(wait for explicit user confirmation first)

- [ ] **Step 5: Delete local source directories**

`rm -rf backend/supabase/functions/admin-usage-analytics backend/supabase/functions/admin-usage-logs backend/supabase/functions/admin-pl-analytics`

---

### Task 11: Verify quota headroom and re-deploy the affiliate-keywords functions that started this

**Files:** none (verification + deploy only)

**Interfaces:**
- Consumes: all prior tasks' deletions (production should now be at 100 − 9 = 91 functions).

- [ ] **Step 1: Confirm current production function count**

Run: `supabase functions list --project-ref wzdcwxvyjuxjgzpnukvm | grep -c ACTIVE`
Expected: 91 (100 minus the 9 saved across Tasks 1-10). If it's not 91, some deletion step was skipped or a group's math doesn't match — investigate before proceeding.

- [ ] **Step 2: Trigger the backend deploy workflow**

The 4 `admin-*-affiliate-keyword` functions from the earlier affiliate-keywords feature (already merged into `admin-affiliate-keywords` by Task 1 in THIS plan, so they no longer need separate deployment) — confirm the backend GitHub Actions deploy workflow (`.github/workflows/backend-deploy.yml`) now succeeds on the next push/dispatch, since production is comfortably under the 100-function cap (91 + headroom for normal future growth).

- [ ] **Step 3: Report final function count and headroom to the user.**

---

## Self-Review Notes

- **Spec coverage:** all 5 consolidation groups from the spec have a backend-merge task + admin-web-repoint task ✓. Cutover sequence (deploy new → repoint → verify → delete old) followed in every group ✓. Audit-log table-name fixes (affiliate-keywords already fixed pre-plan; promo-codes Task 3; subscriptions Task 7) called out explicitly ✓. `fetchAllRows` dedup (Task 9) ✓. New `updateSubscriptionPrice` wrapper + modal switch (Task 8) ✓. Excluded `admin-study-*` pair — no task references it, correctly absent ✓.
- **Placeholders:** several handler-body steps say "copy verbatim from X" rather than inlining the full source — this is a deliberate, precise instruction (exact file, exact function name, exact treatment), not a vague TBD; the alternative (pasting 400+ line handler bodies into this plan sight-unseen from research summaries rather than fresh reads) risks transcription errors the "read the file first" instruction avoids. Acceptable for this refactor-shaped plan.
- **Type consistency:** dispatch pattern (`pathParts`/`method` checks, `requireAdmin` return shape `{adminSupabase, adminUserId} | Response`) is consistent across Tasks 1, 3, 5, 7, 9. Route URL suffixes (`/toggle`, `/delete`, `/topics`, `/price`, `/usage`, `/logs`, `/pl`) match exactly between each backend task's dispatch table and its paired admin-web task's URL updates.
- **Destructive-action safety:** every `supabase functions delete` step is gated behind an explicit "wait for user confirmation" instruction, per Global Constraints — these are irreversible production actions and must not be automated past a human checkpoint.
