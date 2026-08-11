# Block User (Community) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user block another user so both become invisible to each other everywhere in the community, with the block reported to the developer and an admin queue to act on it — clearing the Apple Guideline 1.2 rejection.

**Architecture:** A single `user_blocks` table holds global, mutual blocks. One `SECURITY DEFINER` helper, `blocked_user_ids(uid)`, returns the union of both block directions and is the only place the symmetry rule lives; every post and comment list query calls it. A new `fellowship-blocks` Edge Function handles block, unblock, and list. Flutter mirrors the existing report path (datasource → repository → bloc) and strips the blocked author's content from bloc state optimistically. An admin-web moderation page reads the resulting reports.

**Tech Stack:** PostgreSQL (Supabase migrations), Deno/TypeScript Edge Functions, Flutter with BLoC + GetIt + dartz, Next.js admin dashboard with TanStack Query.

## Global Constraints

- Migrations run **locally only**. Never run `supabase db push` and never pass `--project-ref`. The user deploys.
- Commit messages: one-liner, `type(scope): description`. No `Co-Authored-By` lines.
- **Never run `git commit`.** All nine tasks land as ONE squashed commit at the very end, made only after the user approves. Steps that say "Stage" mean `git add` and nothing more. The controller snapshots each task with `git write-tree` to produce per-task review diffs.
- Work on branch `dev`. No feature branches.
- Backend Edge Functions are built with `createSimpleFunction` from `_shared/core/function-factory.ts` and throw `AppError` from `_shared/utils/error-handler.ts`. All DB access uses `services.supabaseServiceClient`.
- Community-feature Flutter strings go in `lib/core/localization/app_localizations.dart` (three locale maps + a getter). Settings-screen strings go through `context.tr(TranslationKeys.…)` in `lib/core/i18n/app_translations.dart`. Both systems must get every new string in **en, hi, ml**.
- After Flutter changes: `cd frontend && flutter analyze` must be clean and `dart format lib/ test/` applied.
- RLS convention for fellowship tables is **service_role only** — all access goes through Edge Functions. Do not add `authenticated` policies or grants.

---

### Task 1: `user_blocks` table, helper, and block RPC

**Files:**
- Create: `backend/supabase/migrations/20260810000001_user_blocks.sql`
- Create: `backend/supabase/sql/user_blocks_verify.sql`

**Interfaces:**
- Consumes: existing tables `fellowship_reports`, `auth.users`.
- Produces:
  - `blocked_user_ids(p_user_id UUID) RETURNS TABLE(user_id UUID)` — union of both block directions.
  - `block_user(p_blocker_id UUID, p_blocked_id UUID, p_fellowship_id UUID, p_content_type TEXT, p_content_id UUID, p_reason TEXT) RETURNS BOOLEAN` — true when a new block row was created, false when it already existed.

- [ ] **Step 1: Write the failing verification script**

Create `backend/supabase/sql/user_blocks_verify.sql`:

```sql
-- Verification for the user_blocks migration. Run against local Supabase only.
-- Exits with an exception on the first failed assertion.

BEGIN;

-- Two throwaway users. auth.users rows are created directly because this
-- script runs against a local database with no auth server involved.
INSERT INTO auth.users (id, instance_id, aud, role, email)
VALUES
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'blocker@test.local'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'blocked@test.local')
ON CONFLICT (id) DO NOTHING;

DO $$
DECLARE
  v_first BOOLEAN;
  v_second BOOLEAN;
  v_forward INT;
  v_reverse INT;
BEGIN
  -- 1. First block returns true and creates the row.
  v_first := block_user(
    '00000000-0000-0000-0000-0000000000a1',
    '00000000-0000-0000-0000-0000000000b2',
    NULL, NULL, NULL, NULL
  );
  IF NOT v_first THEN
    RAISE EXCEPTION 'FAIL: first block_user should return true';
  END IF;

  -- 2. Re-blocking is idempotent and returns false.
  v_second := block_user(
    '00000000-0000-0000-0000-0000000000a1',
    '00000000-0000-0000-0000-0000000000b2',
    NULL, NULL, NULL, NULL
  );
  IF v_second THEN
    RAISE EXCEPTION 'FAIL: repeat block_user should return false';
  END IF;

  -- 3. blocked_user_ids sees the block from the blocker's side.
  SELECT COUNT(*) INTO v_forward
  FROM blocked_user_ids('00000000-0000-0000-0000-0000000000a1')
  WHERE user_id = '00000000-0000-0000-0000-0000000000b2';
  IF v_forward <> 1 THEN
    RAISE EXCEPTION 'FAIL: blocker should see blocked user, got % rows', v_forward;
  END IF;

  -- 4. And from the blocked user's side — the block is mutual.
  SELECT COUNT(*) INTO v_reverse
  FROM blocked_user_ids('00000000-0000-0000-0000-0000000000b2')
  WHERE user_id = '00000000-0000-0000-0000-0000000000a1';
  IF v_reverse <> 1 THEN
    RAISE EXCEPTION 'FAIL: block should be mutual, got % rows', v_reverse;
  END IF;

  -- 5. Self-blocks are rejected by the CHECK constraint.
  BEGIN
    INSERT INTO user_blocks (blocker_id, blocked_id)
    VALUES ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1');
    RAISE EXCEPTION 'FAIL: self-block should have been rejected';
  EXCEPTION WHEN check_violation THEN
    NULL; -- expected
  END;

  RAISE NOTICE 'PASS: all user_blocks assertions held';
END $$;

ROLLBACK;
```

- [ ] **Step 2: Run it to verify it fails**

```bash
cd backend && supabase start
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/sql/user_blocks_verify.sql
```

Expected: FAIL with `ERROR:  function block_user(...) does not exist`.

- [ ] **Step 3: Write the migration**

Create `backend/supabase/migrations/20260810000001_user_blocks.sql`:

```sql
-- =====================================================
-- Migration: User Blocks (Apple Guideline 1.2 compliance)
-- Date: 2026-08-10
-- Tables:  user_blocks
-- Helpers: blocked_user_ids(), block_user()
-- =====================================================

BEGIN;

-- =====================================================
-- SECTION 1: TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_user_block UNIQUE (blocker_id, blocked_id),
  CONSTRAINT chk_no_self_block CHECK (blocker_id <> blocked_id)
);

COMMENT ON TABLE user_blocks IS 'Viewer-level blocks. Global across fellowships and mutual; filtered out of every post/comment list query via blocked_user_ids()';

-- =====================================================
-- SECTION 2: SECURITY DEFINER HELPERS
-- =====================================================

CREATE OR REPLACE FUNCTION blocked_user_ids(p_user_id UUID)
RETURNS TABLE(user_id UUID)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT blocked_id FROM user_blocks WHERE blocker_id = p_user_id
  UNION
  SELECT blocker_id FROM user_blocks WHERE blocked_id = p_user_id;
$$;

COMMENT ON FUNCTION blocked_user_ids IS 'Union of both block directions for one viewer; single source of truth for feed filtering';

CREATE OR REPLACE FUNCTION block_user(
  p_blocker_id UUID,
  p_blocked_id UUID,
  p_fellowship_id UUID DEFAULT NULL,
  p_content_type TEXT DEFAULT NULL,
  p_content_id UUID DEFAULT NULL,
  p_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rows INT;
BEGIN
  INSERT INTO user_blocks (blocker_id, blocked_id, reason)
  VALUES (p_blocker_id, p_blocked_id, p_reason)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

  GET DIAGNOSTICS v_rows = ROW_COUNT;

  -- Only a genuinely new block notifies the developer, and only when the
  -- block was started from a specific post or comment. fellowship_reports
  -- requires a non-null content_id, so contentless blocks (member list)
  -- surface through the Blocks tab of the admin moderation page instead.
  IF v_rows > 0
     AND p_fellowship_id IS NOT NULL
     AND p_content_type IS NOT NULL
     AND p_content_id IS NOT NULL THEN
    INSERT INTO fellowship_reports (
      fellowship_id, reporter_user_id, content_type, content_id, reason
    )
    VALUES (
      p_fellowship_id, p_blocker_id, p_content_type, p_content_id, 'user_blocked'
    );
  END IF;

  RETURN v_rows > 0;
END;
$$;

COMMENT ON FUNCTION block_user IS 'Atomically records a block and, for content-originated blocks, the matching moderation report';

-- =====================================================
-- SECTION 3: INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks(blocked_id);

-- =====================================================
-- SECTION 4: RLS AND GRANTS
-- =====================================================

ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_blocks_service_all" ON user_blocks;
CREATE POLICY "user_blocks_service_all" ON user_blocks FOR ALL TO service_role USING (true) WITH CHECK (true);

GRANT ALL ON public.user_blocks TO service_role;

COMMIT;
```

- [ ] **Step 4: Apply and re-run the verification**

```bash
cd backend && supabase db reset
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/sql/user_blocks_verify.sql
```

Expected: `NOTICE:  PASS: all user_blocks assertions held`, no `ERROR`.

- [ ] **Step 5: Stage (do NOT commit)**

```bash
git add backend/supabase/migrations/20260810000001_user_blocks.sql backend/supabase/sql/user_blocks_verify.sql
```

---

### Task 2: `fellowship-blocks` Edge Function

**Files:**
- Create: `backend/supabase/functions/fellowship-blocks/index.ts`

**Interfaces:**
- Consumes: `block_user()` and `blocked_user_ids()` from Task 1.
- Produces three routes, all requiring a bearer token:
  - `POST /functions/v1/fellowship-blocks` — body `{ blocked_user_id, fellowship_id?, content_type?, content_id? }` → `{ success: true, message }`
  - `DELETE /functions/v1/fellowship-blocks` — body `{ blocked_user_id }` → `{ success: true, message }`
  - `GET /functions/v1/fellowship-blocks` → `{ success: true, data: BlockedUserResponse[] }` where `BlockedUserResponse = { user_id: string, display_name: string, avatar_url: string | null, blocked_at: string }`

- [ ] **Step 1: Write the function**

Create `backend/supabase/functions/fellowship-blocks/index.ts`:

```ts
/**
 * fellowship-blocks
 * Routes:
 *   POST   /fellowship-blocks  → block a user (global, mutual)
 *   DELETE /fellowship-blocks  → unblock a user
 *   GET    /fellowship-blocks  → list users the caller has blocked
 *
 * Blocks are global (not scoped to a fellowship) and mutual: neither party
 * sees the other's posts or comments anywhere. See
 * docs/superpowers/specs/2026-08-10-block-user-community-design.md
 */

import { createSimpleFunction } from '../_shared/core/function-factory.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { checkMaintenanceMode } from '../_shared/middleware/maintenance-middleware.ts'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

interface BlockedUserResponse {
  user_id: string
  display_name: string
  avatar_url: string | null
  blocked_at: string
}

/** Resolves the caller from the Authorization header or throws. */
async function requireUser(req: Request, services: ServiceContainer) {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) throw new AppError('AUTHENTICATION_ERROR', 'Authentication required', 401)
  const { data: { user }, error } = await services.supabaseServiceClient.auth.getUser(
    authHeader.replace('Bearer ', '')
  )
  if (error || !user) throw new AppError('AUTHENTICATION_ERROR', 'Invalid token', 401)
  return user
}

// ---------------------------------------------------------------------------
// Block  POST /fellowship-blocks
// ---------------------------------------------------------------------------

async function handleBlock(req: Request, services: ServiceContainer): Promise<Response> {
  const user = await requireUser(req, services)

  let body: {
    blocked_user_id: string
    fellowship_id?: string
    content_type?: string
    content_id?: string
  }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }

  if (!body.blocked_user_id) throw new AppError('VALIDATION_ERROR', 'blocked_user_id is required', 400)
  if (!UUID_RE.test(body.blocked_user_id)) throw new AppError('VALIDATION_ERROR', 'blocked_user_id must be a valid UUID', 400)
  if (body.blocked_user_id === user.id) throw new AppError('VALIDATION_ERROR', 'Cannot block yourself', 400)

  if (body.content_type && !['post', 'comment'].includes(body.content_type)) {
    throw new AppError('VALIDATION_ERROR', "content_type must be 'post' or 'comment'", 400)
  }
  if (body.content_id && !UUID_RE.test(body.content_id)) {
    throw new AppError('VALIDATION_ERROR', 'content_id must be a valid UUID', 400)
  }
  if (body.fellowship_id && !UUID_RE.test(body.fellowship_id)) {
    throw new AppError('VALIDATION_ERROR', 'fellowship_id must be a valid UUID', 400)
  }

  const db = services.supabaseServiceClient

  const { data: created, error } = await db.rpc('block_user', {
    p_blocker_id: user.id,
    p_blocked_id: body.blocked_user_id,
    p_fellowship_id: body.fellowship_id ?? null,
    p_content_type: body.content_type ?? null,
    p_content_id: body.content_id ?? null,
    p_reason: null
  })

  if (error) {
    console.error('[fellowship-blocks/block] RPC error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to block user', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: created ? 'User blocked' : 'User is already blocked' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Unblock  DELETE /fellowship-blocks
// ---------------------------------------------------------------------------

async function handleUnblock(req: Request, services: ServiceContainer): Promise<Response> {
  const user = await requireUser(req, services)

  let body: { blocked_user_id: string }
  try { body = await req.json() } catch { throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400) }
  if (!body.blocked_user_id) throw new AppError('VALIDATION_ERROR', 'blocked_user_id is required', 400)
  if (!UUID_RE.test(body.blocked_user_id)) throw new AppError('VALIDATION_ERROR', 'blocked_user_id must be a valid UUID', 400)

  const { error } = await services.supabaseServiceClient
    .from('user_blocks')
    .delete()
    .eq('blocker_id', user.id)
    .eq('blocked_id', body.blocked_user_id)

  if (error) {
    console.error('[fellowship-blocks/unblock] Delete error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to unblock user', 500)
  }

  return new Response(
    JSON.stringify({ success: true, message: 'User unblocked' }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// List  GET /fellowship-blocks
// ---------------------------------------------------------------------------

async function handleList(req: Request, services: ServiceContainer): Promise<Response> {
  const user = await requireUser(req, services)
  const db = services.supabaseServiceClient

  // Only outbound blocks: a user manages the blocks they made, and must not
  // learn who blocked them.
  const { data: rows, error } = await db
    .from('user_blocks')
    .select('blocked_id, created_at')
    .eq('blocker_id', user.id)
    .order('created_at', { ascending: false })

  if (error) {
    console.error('[fellowship-blocks/list] Query error:', error)
    throw new AppError('DATABASE_ERROR', 'Failed to fetch blocked users', 500)
  }

  const blockRows = (rows ?? []) as { blocked_id: string; created_at: string }[]

  const blocked: BlockedUserResponse[] = await Promise.all(
    blockRows.map(async (row) => {
      try {
        const { data: userData, error: userError } =
          await db.auth.admin.getUserById(row.blocked_id)
        if (userError || !userData?.user) {
          return { user_id: row.blocked_id, display_name: 'Unknown Member', avatar_url: null, blocked_at: row.created_at }
        }
        const u = userData.user
        const displayName: string =
          u.user_metadata?.full_name ?? u.user_metadata?.name ??
          u.user_metadata?.display_name ?? u.email ?? 'Unknown Member'
        return {
          user_id: row.blocked_id,
          display_name: displayName,
          avatar_url: (u.user_metadata?.avatar_url ?? null) as string | null,
          blocked_at: row.created_at
        }
      } catch {
        return { user_id: row.blocked_id, display_name: 'Unknown Member', avatar_url: null, blocked_at: row.created_at }
      }
    })
  )

  return new Response(
    JSON.stringify({ success: true, data: blocked }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  )
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

async function handleBlocks(req: Request, services: ServiceContainer): Promise<Response> {
  await checkMaintenanceMode(req, services)

  if (req.method === 'GET') return handleList(req, services)
  if (req.method === 'POST') return handleBlock(req, services)
  if (req.method === 'DELETE') return handleUnblock(req, services)

  throw new AppError('METHOD_NOT_ALLOWED', 'Method not allowed', 405)
}

createSimpleFunction(handleBlocks, {
  allowedMethods: ['GET', 'POST', 'DELETE'],
  enableAnalytics: true,
  timeout: 15000,
})
```

- [ ] **Step 2: Serve and smoke-test all three routes**

```bash
cd backend && supabase functions serve --env-file .env.local
```

In a second shell, with `TOKEN` set to a local user's access token and `TARGET` to another user's UUID:

```bash
BASE=http://127.0.0.1:54321/functions/v1/fellowship-blocks

# Block — expect {"success":true,"message":"User blocked"}
curl -s -X POST "$BASE" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d "{\"blocked_user_id\":\"$TARGET\"}"

# Re-block — expect "User is already blocked"
curl -s -X POST "$BASE" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d "{\"blocked_user_id\":\"$TARGET\"}"

# List — expect the target in data[]
curl -s "$BASE" -H "Authorization: Bearer $TOKEN"

# Self-block — expect 400 "Cannot block yourself"
curl -s -X POST "$BASE" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d "{\"blocked_user_id\":\"$(echo $TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | grep -o '"sub":"[^"]*"' | cut -d'"' -f4)\"}"

# Unblock — expect {"success":true,"message":"User unblocked"}
curl -s -X DELETE "$BASE" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d "{\"blocked_user_id\":\"$TARGET\"}"

# No auth — expect 401
curl -s -X POST "$BASE" -H 'Content-Type: application/json' -d '{"blocked_user_id":"'$TARGET'"}'
```

- [ ] **Step 3: Stage (do NOT commit)**

```bash
git add backend/supabase/functions/fellowship-blocks/index.ts
```

---

### Task 3: Filter blocked and muted authors out of the post feed

**Files:**
- Create: `backend/supabase/functions/_shared/utils/hidden-authors.ts`
- Create: `backend/supabase/functions/_shared/utils/hidden-authors.test.ts`
- Modify: `backend/supabase/functions/fellowship-posts/index.ts:71-120`

**Interfaces:**
- Consumes: `blocked_user_ids()` from Task 1.
- Produces: `hiddenAuthorIds(db: SupabaseLike, userId: string, fellowshipId: string): Promise<string[]>`, exported from `_shared/utils/hidden-authors.ts` and imported by both `fellowship-posts` (this task) and `fellowship-comments` (Task 4). One definition only — the block-filtering rule must not drift between posts and comments.

This also fixes a standing bug: `fellowship_mutes` is documented as filtered in list queries but was only ever read by `fellowship-members`, so muted members' posts stayed visible.

- [ ] **Step 1: Write the failing helper test**

Create `backend/supabase/functions/_shared/utils/hidden-authors.test.ts`, following the convention in `reset-scope.test.ts`:

```ts
// ============================================================================
// Hidden Authors Resolver Unit Tests
// ============================================================================
// Run with: deno test --allow-env hidden-authors.test.ts

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.208.0/assert/mod.ts";
import { hiddenAuthorIds } from "./hidden-authors.ts";
import { AppError } from "./error-handler.ts";

/** Minimal stand-in for the Supabase service client used by hiddenAuthorIds. */
function fakeDb(opts: {
  blocked?: { user_id: string }[];
  muted?: { muted_user_id: string }[];
  blockedError?: unknown;
  mutedError?: unknown;
}) {
  return {
    rpc: (_fn: string, _args: unknown) =>
      Promise.resolve({ data: opts.blocked ?? [], error: opts.blockedError ?? null }),
    from: (_table: string) => ({
      select: (_cols: string) => ({
        eq: (_col: string, _val: string) =>
          Promise.resolve({ data: opts.muted ?? [], error: opts.mutedError ?? null }),
      }),
    }),
  };
}

Deno.test("returns an empty array when nothing is hidden", async () => {
  const result = await hiddenAuthorIds(fakeDb({}), "viewer", "fellowship");
  assertEquals(result, []);
});

Deno.test("unions blocked users and muted members", async () => {
  const result = await hiddenAuthorIds(
    fakeDb({ blocked: [{ user_id: "a" }], muted: [{ muted_user_id: "b" }] }),
    "viewer",
    "fellowship",
  );
  assertEquals(result.sort(), ["a", "b"]);
});

Deno.test("deduplicates a user who is both blocked and muted", async () => {
  const result = await hiddenAuthorIds(
    fakeDb({ blocked: [{ user_id: "a" }], muted: [{ muted_user_id: "a" }] }),
    "viewer",
    "fellowship",
  );
  assertEquals(result, ["a"]);
});

Deno.test("throws AppError when the block lookup fails", async () => {
  await assertRejects(
    () => hiddenAuthorIds(fakeDb({ blockedError: { message: "boom" } }), "viewer", "fellowship"),
    AppError,
    "Failed to resolve blocked users",
  );
});

Deno.test("throws AppError when the mute lookup fails", async () => {
  await assertRejects(
    () => hiddenAuthorIds(fakeDb({ mutedError: { message: "boom" } }), "viewer", "fellowship"),
    AppError,
    "Failed to resolve muted members",
  );
});
```

- [ ] **Step 1b: Run it to verify it fails**

```bash
cd backend/supabase/functions/_shared/utils && deno test --allow-env hidden-authors.test.ts
```

Expected: FAIL — `Module not found "./hidden-authors.ts"`.

- [ ] **Step 1c: Write the shared helper**

Create `backend/supabase/functions/_shared/utils/hidden-authors.ts`:

```ts
import { AppError } from './error-handler.ts'

/**
 * The subset of the Supabase client surface this helper needs. Declared
 * structurally so the function can be unit-tested without a live client.
 */
export interface SupabaseLike {
  rpc(fn: string, args: Record<string, unknown>): Promise<{ data: unknown; error: unknown }>
  from(table: string): {
    select(columns: string): {
      eq(column: string, value: string): Promise<{ data: unknown; error: unknown }>
    }
  }
}

/**
 * Author IDs whose content must not be shown to [userId] in [fellowshipId]:
 * everyone in a mutual block relationship with them, plus members muted by a
 * mentor. Returns an empty array when nothing is hidden.
 *
 * Shared by fellowship-posts and fellowship-comments so the two can never
 * disagree about who is hidden.
 */
export async function hiddenAuthorIds(
  db: SupabaseLike,
  userId: string,
  fellowshipId: string
): Promise<string[]> {
  const [blockedResult, mutesResult] = await Promise.all([
    db.rpc('blocked_user_ids', { p_user_id: userId }),
    db.from('fellowship_mutes').select('muted_user_id').eq('fellowship_id', fellowshipId)
  ])

  if (blockedResult.error) {
    console.error('[hidden-authors] blocked_user_ids error:', blockedResult.error)
    throw new AppError('DATABASE_ERROR', 'Failed to resolve blocked users', 500)
  }
  if (mutesResult.error) {
    console.error('[hidden-authors] mutes query error:', mutesResult.error)
    throw new AppError('DATABASE_ERROR', 'Failed to resolve muted members', 500)
  }

  return [...new Set([
    ...((blockedResult.data ?? []) as { user_id: string }[]).map((r) => r.user_id),
    ...((mutesResult.data ?? []) as { muted_user_id: string }[]).map((r) => r.muted_user_id)
  ])]
}
```

- [ ] **Step 1d: Run the test to verify it passes**

```bash
cd backend/supabase/functions/_shared/utils && deno test --allow-env hidden-authors.test.ts
```

Expected: `ok | 5 passed | 0 failed`.

Then import it in `backend/supabase/functions/fellowship-posts/index.ts`:

```ts
import { hiddenAuthorIds } from '../_shared/utils/hidden-authors.ts'
```

- [ ] **Step 2: Apply the filter to the post query**

In `handleListPosts`, immediately before `let query = db` (line ~71), add:

```ts
  const hiddenIds = await hiddenAuthorIds(db, user.id, fellowshipId)
```

Then, after the existing `if (cursor) query = query.lt('created_at', cursor)` line, add:

```ts
  // UUIDs come from the database, so interpolation here is safe.
  if (hiddenIds.length > 0) query = query.not('author_user_id', 'in', `(${hiddenIds.join(',')})`)
```

- [ ] **Step 3: Apply the same filter to the comment-count query**

Replace the comment-count line inside the `Promise.all` (line ~119):

```ts
    db.from('fellowship_comments').select('post_id').in('post_id', postIds).eq('is_deleted', false),
```

with:

```ts
    (() => {
      let q = db.from('fellowship_comments').select('post_id').in('post_id', postIds).eq('is_deleted', false)
      if (hiddenIds.length > 0) q = q.not('author_user_id', 'in', `(${hiddenIds.join(',')})`)
      return q
    })(),
```

Without this a post reads "3 comments" and renders one.

- [ ] **Step 4: Apply the same filter to the topic-count query**

In the `count_by_topic=true` branch (line ~53), the query is built as `db.from('fellowship_posts').select('topic_id')`. Resolve `hiddenIds` before it and chain the same `.not(...)` call, so per-topic badges match the filtered feed.

- [ ] **Step 5: Verify by hand**

With two local accounts in one fellowship, both having posted:

```bash
cd backend && supabase functions serve --env-file .env.local
```

```bash
# Before blocking — B's posts appear
curl -s "http://127.0.0.1:54321/functions/v1/fellowship-posts?fellowship_id=$FELLOWSHIP" \
  -H "Authorization: Bearer $TOKEN_A" | grep -c "$USER_B"

# Block, then re-list — expect 0 matches
curl -s -X POST http://127.0.0.1:54321/functions/v1/fellowship-blocks \
  -H "Authorization: Bearer $TOKEN_A" -H 'Content-Type: application/json' \
  -d "{\"blocked_user_id\":\"$USER_B\"}"

curl -s "http://127.0.0.1:54321/functions/v1/fellowship-posts?fellowship_id=$FELLOWSHIP" \
  -H "Authorization: Bearer $TOKEN_A" | grep -c "$USER_B"

# Mutual: A's posts must also vanish for B — expect 0
curl -s "http://127.0.0.1:54321/functions/v1/fellowship-posts?fellowship_id=$FELLOWSHIP" \
  -H "Authorization: Bearer $TOKEN_B" | grep -c "$USER_A"
```

- [ ] **Step 6: Stage (do NOT commit)**

```bash
git add backend/supabase/functions/fellowship-posts/index.ts
```

---

### Task 4: Filter blocked and muted authors out of comments

**Files:**
- Modify: `backend/supabase/functions/fellowship-comments/index.ts:57-62`

**Interfaces:**
- Consumes: `hiddenAuthorIds` from `_shared/utils/hidden-authors.ts` (Task 3). Import it — do NOT copy the function body into this file.

- [ ] **Step 1: Resolve the fellowship for the post**

The comments list handler receives `post_id`, not `fellowship_id`, but mute filtering needs the fellowship. Before the comments query, fetch it:

```ts
  const { data: postRow, error: postError } = await db
    .from('fellowship_posts')
    .select('fellowship_id')
    .eq('id', postId)
    .maybeSingle()

  if (postError) {
    console.error('[fellowship-comments/list] Post lookup error:', postError)
    throw new AppError('DATABASE_ERROR', 'Failed to resolve post', 500)
  }
  if (!postRow) throw new AppError('NOT_FOUND', 'Post not found', 404)
```

If the handler already loads the post for a membership check, reuse that row instead of adding a second query.

- [ ] **Step 2: Import the shared helper and apply the filter**

Add the import at the top of the file:

```ts
import { hiddenAuthorIds } from '../_shared/utils/hidden-authors.ts'
```

Then, before the comments query:

```ts
  const hiddenIds = await hiddenAuthorIds(db, user.id, (postRow as { fellowship_id: string }).fellowship_id)
```

Change the query from a `const` chain to a reassignable one and apply the filter:

```ts
  let commentsQuery = db
    .from('fellowship_comments')
    .select('id, post_id, content, author_user_id, is_deleted, created_at')
    .eq('post_id', postId)
    .eq('is_deleted', false)
    .order('created_at', { ascending: true })

  if (hiddenIds.length > 0) {
    commentsQuery = commentsQuery.not('author_user_id', 'in', `(${hiddenIds.join(',')})`)
  }

  const { data, error } = await commentsQuery
```

- [ ] **Step 3: Verify**

```bash
# With A having blocked B, open a post B commented on. Expect B's comment absent.
curl -s "http://127.0.0.1:54321/functions/v1/fellowship-comments?post_id=$POST" \
  -H "Authorization: Bearer $TOKEN_A" | grep -c "$USER_B"
```

Expected: `0`. Then confirm the feed's comment count for that post matches the number of comments returned here.

- [ ] **Step 4: Stage (do NOT commit)**

```bash
git add backend/supabase/functions/fellowship-comments/index.ts
```

---

### Task 5: Flutter domain and data layer

**Files:**
- Create: `frontend/lib/features/community/domain/entities/blocked_user_entity.dart`
- Create: `frontend/lib/features/community/data/models/blocked_user_model.dart`
- Modify: `frontend/lib/features/community/domain/repositories/community_repository.dart` (add after `reportContent`, line ~193)
- Modify: `frontend/lib/features/community/data/repositories/community_repository_impl.dart` (add after `reportContent`, line ~595)
- Modify: `frontend/lib/features/community/data/datasources/community_remote_datasource.dart` (interface after line ~174; endpoint const near line ~290; impl after line ~1410)

**Interfaces:**
- Produces, on `CommunityRepository`:
  - `Future<Either<Failure, void>> blockUser({required String blockedUserId, String? fellowshipId, String? contentType, String? contentId})`
  - `Future<Either<Failure, void>> unblockUser(String blockedUserId)`
  - `Future<Either<Failure, List<BlockedUserEntity>>> getBlockedUsers()`
- Produces `BlockedUserEntity(userId, displayName, avatarUrl, blockedAt)`.

- [ ] **Step 1: Create the entity**

`frontend/lib/features/community/domain/entities/blocked_user_entity.dart`:

```dart
import 'package:equatable/equatable.dart';

/// A user the current user has blocked.
///
/// Blocks are global and mutual: neither party sees the other's posts or
/// comments in any fellowship.
class BlockedUserEntity extends Equatable {
  /// Supabase auth UID of the blocked user.
  final String userId;

  /// Display name resolved server-side; 'Unknown Member' when unavailable.
  final String displayName;

  /// Avatar URL, or null when the user has none.
  final String? avatarUrl;

  /// When the block was created.
  final DateTime blockedAt;

  const BlockedUserEntity({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.blockedAt,
  });

  @override
  List<Object?> get props => [userId, displayName, avatarUrl, blockedAt];
}
```

- [ ] **Step 2: Create the model**

`frontend/lib/features/community/data/models/blocked_user_model.dart`:

```dart
import '../../domain/entities/blocked_user_entity.dart';

/// Data-layer representation of a blocked user, parsed from the
/// `fellowship-blocks` GET response.
class BlockedUserModel extends BlockedUserEntity {
  const BlockedUserModel({
    required super.userId,
    required super.displayName,
    super.avatarUrl,
    required super.blockedAt,
  });

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) =>
      BlockedUserModel(
        userId: json['user_id'] as String,
        displayName: (json['display_name'] as String?) ?? 'Unknown Member',
        avatarUrl: json['avatar_url'] as String?,
        blockedAt:
            DateTime.tryParse(json['blocked_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );
}
```

- [ ] **Step 3: Add the datasource interface methods**

In `community_remote_datasource.dart`, after the `reportContent` declaration (line ~174), add to the abstract class:

```dart
  /// Blocks [blockedUserId] globally and mutually.
  ///
  /// When the block originates from a specific post or comment, pass
  /// [fellowshipId], [contentType] (`'post'` or `'comment'`) and [contentId]
  /// so the server records a moderation report alongside the block.
  Future<void> blockUser({
    required String blockedUserId,
    String? fellowshipId,
    String? contentType,
    String? contentId,
  });

  /// Removes the current user's block on [blockedUserId].
  Future<void> unblockUser(String blockedUserId);

  /// Returns the users the current user has blocked, newest first.
  Future<List<BlockedUserModel>> getBlockedUsers();
```

Add the import `import '../models/blocked_user_model.dart';` at the top of the file.

- [ ] **Step 4: Add the endpoint constant**

In the endpoints block of `CommunityRemoteDatasourceImpl` (near line ~290), after the members endpoints, add:

```dart
  // fellowship-blocks (block, unblock, list)
  static const String _fellowshipBlocksEndpoint =
      '/functions/v1/fellowship-blocks';
```

- [ ] **Step 5: Implement the three datasource methods**

Append to `CommunityRemoteDatasourceImpl`, after `reportContent` (line ~1410):

```dart
  // ---------------------------------------------------------------------------
  // User blocks
  // ---------------------------------------------------------------------------

  @override
  Future<void> blockUser({
    required String blockedUserId,
    String? fellowshipId,
    String? contentType,
    String? contentId,
  }) async {
    try {
      final url = '$_baseUrl$_fellowshipBlocksEndpoint';
      final body = jsonEncode({
        'blocked_user_id': blockedUserId,
        if (fellowshipId != null) 'fellowship_id': fellowshipId,
        if (contentType != null) 'content_type': contentType,
        if (contentId != null) 'content_id': contentId,
      });

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.post(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to block user',
          code: 'FELLOWSHIP_BLOCK_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to block user: $e',
        code: 'FELLOWSHIP_BLOCK_ERROR',
      );
    }
  }

  @override
  Future<void> unblockUser(String blockedUserId) async {
    try {
      final url = '$_baseUrl$_fellowshipBlocksEndpoint';
      final body = jsonEncode({'blocked_user_id': blockedUserId});

      final headers = await _httpService.createHeaders();
      final response =
          await _httpService.delete(url, headers: headers, body: body);

      if (response.statusCode >= 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to unblock user',
          code: 'FELLOWSHIP_UNBLOCK_ERROR',
        );
      }
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to unblock user: $e',
        code: 'FELLOWSHIP_UNBLOCK_ERROR',
      );
    }
  }

  @override
  Future<List<BlockedUserModel>> getBlockedUsers() async {
    try {
      final url = '$_baseUrl$_fellowshipBlocksEndpoint';

      final headers = await _httpService.createHeaders();
      final response = await _httpService.get(url, headers: headers);

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 400) {
        throw ServerException(
          message: (json['error'] as String?) ?? 'Failed to fetch blocked users',
          code: 'FELLOWSHIP_BLOCKED_LIST_ERROR',
        );
      }

      final data = (json['data'] as List<dynamic>? ?? []);
      return data
          .map((e) => BlockedUserModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to fetch blocked users: $e',
        code: 'FELLOWSHIP_BLOCKED_LIST_ERROR',
      );
    }
  }
```

- [ ] **Step 6: Add the repository interface methods**

In `community_repository.dart`, after `reportContent` (line ~193), add — with `import '../entities/blocked_user_entity.dart';` at the top:

```dart
  /// Blocks [blockedUserId] globally and mutually.
  ///
  /// Pass [fellowshipId], [contentType] and [contentId] when the block starts
  /// from a specific post or comment so the server files a moderation report.
  Future<Either<Failure, void>> blockUser({
    required String blockedUserId,
    String? fellowshipId,
    String? contentType,
    String? contentId,
  });

  /// Removes the current user's block on [blockedUserId].
  Future<Either<Failure, void>> unblockUser(String blockedUserId);

  /// Returns the users the current user has blocked, newest first.
  Future<Either<Failure, List<BlockedUserEntity>>> getBlockedUsers();
```

- [ ] **Step 7: Implement them in the repository**

Append to `community_repository_impl.dart` after `reportContent` (line ~595), matching its existing failure-mapping shape:

```dart
  @override
  Future<Either<Failure, void>> blockUser({
    required String blockedUserId,
    String? fellowshipId,
    String? contentType,
    String? contentId,
  }) async {
    try {
      await _datasource.blockUser(
        blockedUserId: blockedUserId,
        fellowshipId: fellowshipId,
        contentType: contentType,
        contentId: contentId,
      );
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to block user: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unblockUser(String blockedUserId) async {
    try {
      await _datasource.unblockUser(blockedUserId);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to unblock user: $e'));
    }
  }

  @override
  Future<Either<Failure, List<BlockedUserEntity>>> getBlockedUsers() async {
    try {
      final models = await _datasource.getBlockedUsers();
      return Right(models);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to fetch blocked users: $e'));
    }
  }
```

Add `import '../../domain/entities/blocked_user_entity.dart';` to the imports.

- [ ] **Step 8: Verify it analyzes**

```bash
cd frontend && dart format lib/ && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 9: Stage (do NOT commit)**

```bash
git add frontend/lib/features/community/domain frontend/lib/features/community/data
```

---

### Task 6: Feed bloc block handling with instant removal

**Files:**
- Modify: `frontend/lib/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart` (add after `FellowshipReportRequested`, line ~221)
- Modify: `frontend/lib/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart` (add status enum + field + copyWith + props)
- Modify: `frontend/lib/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart` (register handler at line ~36, implement after `_onReportRequested`)
- Create: `frontend/test/features/community/fellowship_block_test.dart`

**Interfaces:**
- Consumes: `CommunityRepository.blockUser` from Task 5.
- Produces:
  - Event `FellowshipBlockUserRequested({required String blockedUserId, String? fellowshipId, String? contentType, String? contentId})`
  - `enum FellowshipBlockStatus { idle, loading, success, failure }`
  - `FellowshipFeedState.blockStatus`, defaulting to `FellowshipBlockStatus.idle`

Apple tests instant removal directly, so the handler strips the author's posts and comments from state **before** awaiting the network call, mirroring the optimistic pattern already in `_onPostDeleteRequested`.

- [ ] **Step 1: Write the failing test**

`frontend/test/features/community/fellowship_block_test.dart`:

```dart
// Verifies that blocking a user strips their posts and comments from feed
// state immediately, which is what Apple's Guideline 1.2 review checks.

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_comment_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/entities/fellowship_post_entity.dart';
import 'package:disciplefy_bible_study/features/community/domain/repositories/community_repository.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_bloc.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_event.dart';
import 'package:disciplefy_bible_study/features/community/presentation/bloc/fellowship_feed/fellowship_feed_state.dart';

import 'fellowship_block_test.mocks.dart';

@GenerateMocks([CommunityRepository])
void main() {
  late MockCommunityRepository repository;

  const abuser = 'user-abuser';
  const friend = 'user-friend';

  FellowshipPostEntity post(String id, String authorId) => FellowshipPostEntity(
        id: id,
        fellowshipId: 'fellowship-1',
        content: 'content of $id',
        postType: 'general',
        authorUserId: authorId,
        authorName: authorId,
        createdAt: DateTime(2026, 8, 10),
      );

  FellowshipCommentEntity comment(String id, String authorId) =>
      FellowshipCommentEntity(
        id: id,
        postId: 'post-friend',
        content: 'comment $id',
        authorUserId: authorId,
        authorName: authorId,
        createdAt: DateTime(2026, 8, 10),
      );

  final seeded = FellowshipFeedState.initial().copyWith(
    status: FellowshipFeedStatus.success,
    posts: [post('post-abuser', abuser), post('post-friend', friend)],
    comments: [comment('c-abuser', abuser), comment('c-friend', friend)],
  );

  setUp(() {
    repository = MockCommunityRepository();
  });

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'removes the blocked author\'s posts and comments and reports success',
    build: () {
      when(repository.blockUser(
        blockedUserId: anyNamed('blockedUserId'),
        fellowshipId: anyNamed('fellowshipId'),
        contentType: anyNamed('contentType'),
        contentId: anyNamed('contentId'),
      )).thenAnswer((_) async => const Right(null));
      return FellowshipFeedBloc(repository: repository);
    },
    seed: () => seeded,
    act: (bloc) => bloc.add(const FellowshipBlockUserRequested(
      blockedUserId: abuser,
      fellowshipId: 'fellowship-1',
      contentType: 'post',
      contentId: 'post-abuser',
    )),
    verify: (bloc) {
      expect(bloc.state.posts.map((p) => p.id), ['post-friend']);
      expect(bloc.state.comments.map((c) => c.id), ['c-friend']);
      expect(bloc.state.blockStatus, FellowshipBlockStatus.success);
    },
  );

  blocTest<FellowshipFeedBloc, FellowshipFeedState>(
    'restores the removed content when the block request fails',
    build: () {
      when(repository.blockUser(
        blockedUserId: anyNamed('blockedUserId'),
        fellowshipId: anyNamed('fellowshipId'),
        contentType: anyNamed('contentType'),
        contentId: anyNamed('contentId'),
      )).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'network down')));
      return FellowshipFeedBloc(repository: repository);
    },
    seed: () => seeded,
    act: (bloc) => bloc.add(const FellowshipBlockUserRequested(
      blockedUserId: abuser,
      fellowshipId: 'fellowship-1',
    )),
    verify: (bloc) {
      expect(bloc.state.posts.length, 2);
      expect(bloc.state.blockStatus, FellowshipBlockStatus.failure);
      expect(bloc.state.errorMessage, 'network down');
    },
  );
}
```

If `FellowshipPostEntity` or `FellowshipCommentEntity` require constructor fields beyond those used above, read the entity files and supply them — do not change the entities to fit the test.

- [ ] **Step 2: Run it to verify it fails**

```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/community/fellowship_block_test.dart
```

Expected: compile failure — `FellowshipBlockUserRequested` and `FellowshipBlockStatus` are undefined.

- [ ] **Step 3: Add the event**

Append to `fellowship_feed_event.dart` after `FellowshipReportRequested`:

```dart
/// Requests a global, mutual block of [blockedUserId].
///
/// [fellowshipId], [contentType] and [contentId] are set when the block was
/// started from a specific post or comment; they let the server file a
/// moderation report alongside the block.
class FellowshipBlockUserRequested extends FellowshipFeedEvent {
  final String blockedUserId;
  final String? fellowshipId;
  final String? contentType;
  final String? contentId;

  const FellowshipBlockUserRequested({
    required this.blockedUserId,
    this.fellowshipId,
    this.contentType,
    this.contentId,
  });

  @override
  List<Object?> get props => [blockedUserId, fellowshipId, contentType, contentId];
}
```

- [ ] **Step 4: Add the state field**

In `fellowship_feed_state.dart`, beside the existing `FellowshipReportStatus` enum (line ~13):

```dart
/// Status of a block-user operation.
enum FellowshipBlockStatus { idle, loading, success, failure }
```

Add the field beside `reportStatus` (line ~69):

```dart
  /// Status of the most recent block-user operation.
  final FellowshipBlockStatus blockStatus;
```

Add `this.blockStatus = FellowshipBlockStatus.idle,` to the constructor (beside line ~90), `blockStatus,` to `props` (beside line ~123), `FellowshipBlockStatus? blockStatus,` to the `copyWith` signature (beside line ~145), and `blockStatus: blockStatus ?? this.blockStatus,` to its body (beside line ~165).

- [ ] **Step 5: Register and implement the handler**

Register beside the other handlers in the constructor (line ~36):

```dart
    on<FellowshipBlockUserRequested>(_onBlockUserRequested);
```

Implement after `_onReportRequested`:

```dart
  /// Blocks a user and strips their content from the feed immediately.
  ///
  /// Removal happens before the network call completes because App Review
  /// checks that blocked content disappears instantly. On failure the removed
  /// posts and comments are restored.
  Future<void> _onBlockUserRequested(
    FellowshipBlockUserRequested event,
    Emitter<FellowshipFeedState> emit,
  ) async {
    final previousPosts = state.posts;
    final previousComments = state.comments;

    emit(state.copyWith(
      blockStatus: FellowshipBlockStatus.loading,
      posts: previousPosts
          .where((p) => p.authorUserId != event.blockedUserId)
          .toList(),
      comments: previousComments
          .where((c) => c.authorUserId != event.blockedUserId)
          .toList(),
      clearErrorMessage: true,
    ));

    final result = await _repository.blockUser(
      blockedUserId: event.blockedUserId,
      fellowshipId: event.fellowshipId,
      contentType: event.contentType,
      contentId: event.contentId,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        blockStatus: FellowshipBlockStatus.failure,
        posts: previousPosts,
        comments: previousComments,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(blockStatus: FellowshipBlockStatus.success)),
    );
  }
```

- [ ] **Step 6: Run the test to verify it passes**

```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/community/fellowship_block_test.dart
```

Expected: both tests PASS.

- [ ] **Step 7: Stage (do NOT commit)**

```bash
cd frontend && dart format lib/ test/ && flutter analyze
git add frontend/lib/features/community/presentation/bloc/fellowship_feed frontend/test/features/community/fellowship_block_test.dart frontend/test/features/community/fellowship_block_test.mocks.dart
```

---

### Task 7: Block entry points and strings

**Files:**
- Modify: `frontend/lib/core/localization/app_localizations.dart` (three locale maps near lines 386 / 959 / 1535; getters near 2161)
- Modify: `frontend/lib/features/community/presentation/widgets/fellowship_post_card.dart:47-176`
- Modify: `frontend/lib/features/community/presentation/screens/fellowship_feed_tab_screen.dart:288, 499`
- Modify: `frontend/lib/features/community/presentation/screens/fellowship_members_tab_screen.dart:330-380`

**Interfaces:**
- Consumes: `FellowshipBlockUserRequested` from Task 6.
- Produces: `FellowshipPostCard.onBlockTap` (`VoidCallback?`), and a shared `showBlockUserConfirmation` helper.

- [ ] **Step 1: Add the strings**

Add to each of the three locale maps in `app_localizations.dart`, then a getter for each key, following the existing `reportTitle` pattern exactly:

```dart
// English map
'blockUserTitle': 'Block User',
'blockUserConfirmTitle': 'Block this user?',
'blockUserConfirmBody': "You will no longer see their posts or comments, and they will no longer see yours. This applies across all your fellowships. Our team is notified so we can review the content.",
'blockUserConfirmAction': 'Block',
'blockUserCancel': 'Cancel',
'blockUserSuccess': 'User blocked',
'blockedUsersTitle': 'Blocked Users',
'blockedUsersEmpty': "You haven't blocked anyone.",
'blockedUsersSubtitle': 'Manage the people you have blocked',
'unblockAction': 'Unblock',
'unblockSuccess': 'User unblocked',
```

```dart
// Hindi map
'blockUserTitle': 'उपयोगकर्ता को ब्लॉक करें',
'blockUserConfirmTitle': 'इस उपयोगकर्ता को ब्लॉक करें?',
'blockUserConfirmBody': 'आप उनकी पोस्ट और टिप्पणियाँ नहीं देख पाएंगे, और वे आपकी नहीं देख पाएंगे। यह आपकी सभी फ़ेलोशिप पर लागू होता है। हमारी टीम को सूचित किया जाता है ताकि हम सामग्री की समीक्षा कर सकें।',
'blockUserConfirmAction': 'ब्लॉक करें',
'blockUserCancel': 'रद्द करें',
'blockUserSuccess': 'उपयोगकर्ता ब्लॉक किया गया',
'blockedUsersTitle': 'ब्लॉक किए गए उपयोगकर्ता',
'blockedUsersEmpty': 'आपने किसी को ब्लॉक नहीं किया है।',
'blockedUsersSubtitle': 'आपके द्वारा ब्लॉक किए गए लोगों को प्रबंधित करें',
'unblockAction': 'अनब्लॉक करें',
'unblockSuccess': 'उपयोगकर्ता अनब्लॉक किया गया',
```

```dart
// Malayalam map
'blockUserTitle': 'ഉപയോക്താവിനെ ബ്ലോക്ക് ചെയ്യുക',
'blockUserConfirmTitle': 'ഈ ഉപയോക്താവിനെ ബ്ലോക്ക് ചെയ്യണോ?',
'blockUserConfirmBody': 'അവരുടെ പോസ്റ്റുകളും അഭിപ്രായങ്ങളും നിങ്ങൾ കാണില്ല, നിങ്ങളുടേത് അവരും കാണില്ല. ഇത് നിങ്ങളുടെ എല്ലാ കൂട്ടായ്മകളിലും ബാധകമാണ്. ഉള്ളടക്കം പരിശോധിക്കാൻ ഞങ്ങളുടെ ടീമിനെ അറിയിക്കുന്നു.',
'blockUserConfirmAction': 'ബ്ലോക്ക് ചെയ്യുക',
'blockUserCancel': 'റദ്ദാക്കുക',
'blockUserSuccess': 'ഉപയോക്താവിനെ ബ്ലോക്ക് ചെയ്തു',
'blockedUsersTitle': 'ബ്ലോക്ക് ചെയ്ത ഉപയോക്താക്കൾ',
'blockedUsersEmpty': 'നിങ്ങൾ ആരെയും ബ്ലോക്ക് ചെയ്തിട്ടില്ല.',
'blockedUsersSubtitle': 'നിങ്ങൾ ബ്ലോക്ക് ചെയ്ത ആളുകളെ കൈകാര്യം ചെയ്യുക',
'unblockAction': 'അൺബ്ലോക്ക് ചെയ്യുക',
'unblockSuccess': 'ഉപയോക്താവിനെ അൺബ്ലോക്ക് ചെയ്തു',
```

Then one getter per key, e.g.:

```dart
  String get blockUserTitle =>
      _localizedValues[locale.languageCode]!['blockUserTitle']!;
```

- [ ] **Step 2: Add the confirmation helper**

Create `frontend/lib/features/community/presentation/widgets/block_user_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

/// Shows the block confirmation dialog.
///
/// Returns true when the user confirms. The copy states that the block is
/// mutual and global, which is what App Review looks for.
Future<bool> showBlockUserConfirmation(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.blockUserConfirmTitle),
      content: Text(l10n.blockUserConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.blockUserCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            l10n.blockUserConfirmAction,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
```

- [ ] **Step 3: Add Block to the post overflow menu**

In `fellowship_post_card.dart`, add the callback beside `onReportTap` (line ~49):

```dart
  /// Called when the "Block" menu item is tapped (interactive mode only).
  final VoidCallback? onBlockTap;
```

Add `this.onBlockTap,` to the constructor (beside line ~59). In `onSelected` (line ~139), add:

```dart
                      } else if (value == 'block') {
                        onBlockTap?.call();
```

Add the menu item after the existing `report` item. Note the report item is gated on `!isMentor`; Block must be available to mentors too, so gate only on authorship:

```dart
                      if (post.authorUserId != currentUserId)
                        PopupMenuItem<String>(
                          value: 'block',
                          child: Row(
                            children: [
                              const Icon(Icons.block,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.blockUserTitle,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
```

- [ ] **Step 4: Wire the post card callback**

In `fellowship_feed_tab_screen.dart`, beside the `onReportTap` wiring (line ~288):

```dart
                    onBlockTap: () async {
                      final bloc = context.read<FellowshipFeedBloc>();
                      final messenger = ScaffoldMessenger.of(context);
                      final successText =
                          AppLocalizations.of(context)!.blockUserSuccess;
                      if (await showBlockUserConfirmation(context)) {
                        bloc.add(FellowshipBlockUserRequested(
                          blockedUserId: post.authorUserId,
                          fellowshipId: widget.fellowshipId,
                          contentType: 'post',
                          contentId: post.id,
                        ));
                        messenger.showSnackBar(
                          SnackBar(content: Text(successText)),
                        );
                      }
                    },
```

Import `block_user_dialog.dart`. Capture `bloc`, `messenger` and the string **before** the await — using `context` after an await triggers `use_build_context_synchronously` in `flutter analyze`.

- [ ] **Step 5: Add Block to the comment menu**

At the comment `_ReportSheet` call site (line ~499), add a sibling Block action in the same menu using the identical pattern, passing `contentType: 'comment'` and `contentId: comment.id`, with `blockedUserId: comment.authorUserId`.

- [ ] **Step 6: Add Block to the members tab**

In `fellowship_members_tab_screen.dart`, the row already has a `PopupMenuButton<_MemberAction>` (line ~330) with mute/unmute/remove. Add a `block` value to the `_MemberAction` enum and a menu item shown when `member.userId != currentUserId`. On selection, call `showBlockUserConfirmation`, then dispatch on the feed bloc:

```dart
FellowshipBlockUserRequested(blockedUserId: member.userId)
```

No `contentId` here — there is no offending post, so the server records the block without a report row, and it surfaces in the admin Blocks tab instead.

The members tab does not currently own a `FellowshipFeedBloc`; read it from the ancestor provider that `fellowship_home_screen.dart` installs. If it is not in scope there, inject `sl<CommunityRepository>()` and call `blockUser` directly, then refresh the member list.

- [ ] **Step 7: Verify**

```bash
cd frontend && dart format lib/ && flutter analyze && flutter test
```

Expected: `No issues found!` and all tests pass.

Then run the app and confirm by hand that blocking from a post removes that author's posts from the list without a manual refresh:

```bash
cd frontend && sh scripts/run-web-local.sh
```

- [ ] **Step 8: Stage (do NOT commit)**

```bash
git add frontend/lib/core/localization/app_localizations.dart frontend/lib/features/community/presentation
```

---

### Task 8: Blocked Users settings screen

**Files:**
- Create: `frontend/lib/features/community/presentation/bloc/blocked_users/blocked_users_bloc.dart`
- Create: `frontend/lib/features/community/presentation/bloc/blocked_users/blocked_users_event.dart`
- Create: `frontend/lib/features/community/presentation/bloc/blocked_users/blocked_users_state.dart`
- Create: `frontend/lib/features/community/presentation/screens/blocked_users_screen.dart`
- Modify: `frontend/lib/core/router/app_routes.dart:19` (add the constant)
- Modify: `frontend/lib/core/router/app_router.dart:370` (add the route)
- Modify: `frontend/lib/core/di/injection_container.dart:1064` (register the bloc)
- Modify: `frontend/lib/features/settings/presentation/pages/settings_screen.dart:534` (add the tile)
- Modify: `frontend/lib/core/i18n/app_translations.dart` (settings tile strings, all three languages)

**Interfaces:**
- Consumes: `CommunityRepository.getBlockedUsers` and `unblockUser` from Task 5.
- Produces: `BlockedUsersBloc` with events `BlockedUsersLoadRequested()` and `BlockedUserUnblockRequested(String userId)`, and `BlockedUsersState(status, users, errorMessage)` where `status` is `enum BlockedUsersStatus { initial, loading, success, failure }`.

- [ ] **Step 1: Write the bloc**

`blocked_users_event.dart`:

```dart
import 'package:equatable/equatable.dart';

abstract class BlockedUsersEvent extends Equatable {
  const BlockedUsersEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the current user's block list.
class BlockedUsersLoadRequested extends BlockedUsersEvent {
  const BlockedUsersLoadRequested();
}

/// Unblocks [userId] and removes them from the list.
class BlockedUserUnblockRequested extends BlockedUsersEvent {
  final String userId;
  const BlockedUserUnblockRequested(this.userId);
  @override
  List<Object?> get props => [userId];
}
```

`blocked_users_state.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../../domain/entities/blocked_user_entity.dart';

enum BlockedUsersStatus { initial, loading, success, failure }

class BlockedUsersState extends Equatable {
  final BlockedUsersStatus status;
  final List<BlockedUserEntity> users;
  final String? errorMessage;

  const BlockedUsersState({
    this.status = BlockedUsersStatus.initial,
    this.users = const [],
    this.errorMessage,
  });

  BlockedUsersState copyWith({
    BlockedUsersStatus? status,
    List<BlockedUserEntity>? users,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) =>
      BlockedUsersState(
        status: status ?? this.status,
        users: users ?? this.users,
        errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props => [status, users, errorMessage];
}
```

`blocked_users_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/community_repository.dart';
import 'blocked_users_event.dart';
import 'blocked_users_state.dart';

/// Manages the Settings → Blocked Users list.
class BlockedUsersBloc extends Bloc<BlockedUsersEvent, BlockedUsersState> {
  final CommunityRepository _repository;

  BlockedUsersBloc({required CommunityRepository repository})
      : _repository = repository,
        super(const BlockedUsersState()) {
    on<BlockedUsersLoadRequested>(_onLoadRequested);
    on<BlockedUserUnblockRequested>(_onUnblockRequested);
  }

  Future<void> _onLoadRequested(
    BlockedUsersLoadRequested event,
    Emitter<BlockedUsersState> emit,
  ) async {
    emit(state.copyWith(
        status: BlockedUsersStatus.loading, clearErrorMessage: true));

    final result = await _repository.getBlockedUsers();

    result.fold(
      (failure) => emit(state.copyWith(
        status: BlockedUsersStatus.failure,
        errorMessage: failure.message,
      )),
      (users) => emit(state.copyWith(
        status: BlockedUsersStatus.success,
        users: users,
      )),
    );
  }

  Future<void> _onUnblockRequested(
    BlockedUserUnblockRequested event,
    Emitter<BlockedUsersState> emit,
  ) async {
    final previous = state.users;

    // Optimistic removal, restored on failure.
    emit(state.copyWith(
      users: previous.where((u) => u.userId != event.userId).toList(),
      clearErrorMessage: true,
    ));

    final result = await _repository.unblockUser(event.userId);

    result.fold(
      (failure) => emit(state.copyWith(
        users: previous,
        status: BlockedUsersStatus.failure,
        errorMessage: failure.message,
      )),
      (_) => emit(state.copyWith(status: BlockedUsersStatus.success)),
    );
  }
}
```

- [ ] **Step 2: Write the screen**

`blocked_users_screen.dart`: a `StatelessWidget` wrapping `BlocProvider(create: (_) => sl<BlockedUsersBloc>()..add(const BlockedUsersLoadRequested()))`. Body switches on status — `CircularProgressIndicator` while loading, the error message with a Retry button on failure, `l10n.blockedUsersEmpty` centred when `users.isEmpty`, otherwise a `ListView.builder` of `ListTile`s with `CircleAvatar` (from `avatarUrl`, falling back to the first letter of `displayName`), `title: Text(user.displayName)`, and a trailing `TextButton` labelled `l10n.unblockAction` that dispatches `BlockedUserUnblockRequested(user.userId)` and shows a `SnackBar` with `l10n.unblockSuccess`. Title the `AppBar` with `l10n.blockedUsersTitle`.

- [ ] **Step 3: Register route, DI, and the settings tile**

In `app_routes.dart`, beside line 19:

```dart
  static const String blockedUsers = '/blocked-users';
```

In `app_router.dart`, beside the `notificationSettings` route (line ~370):

```dart
      GoRoute(
        path: AppRoutes.blockedUsers,
        name: 'blocked_users',
        builder: (context, state) =>
            const MaxWidthWrapper(child: BlockedUsersScreen()),
      ),
```

In `injection_container.dart`, beside the `FellowshipFeedBloc` registration (line ~1064):

```dart
  sl.registerFactory<BlockedUsersBloc>(
    () => BlockedUsersBloc(repository: sl()),
  );
```

In `settings_screen.dart`, beside the notification-preferences tile (line ~534):

```dart
          _buildSettingsTile(
            context: context,
            icon: Icons.block,
            title: context.tr(TranslationKeys.settingsBlockedUsers),
            subtitle: context.tr(TranslationKeys.settingsBlockedUsersSubtitle),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            onTap: () => context.push(AppRoutes.blockedUsers),
          ),
```

Add `settingsBlockedUsers` ("Blocked Users" / "ब्लॉक किए गए उपयोगकर्ता" / "ബ്ലോക്ക് ചെയ്ത ഉപയോക്താക്കൾ") and `settingsBlockedUsersSubtitle` ("Manage the people you have blocked" / "आपके द्वारा ब्लॉक किए गए लोगों को प्रबंधित करें" / "നിങ്ങൾ ബ്ലോക്ക് ചെയ്ത ആളുകളെ കൈകാര്യം ചെയ്യുക") to `TranslationKeys` and all three language maps in `app_translations.dart`.

- [ ] **Step 4: Verify**

```bash
cd frontend && dart format lib/ && flutter analyze && flutter test
```

Then run the app, block someone, open Settings → Blocked Users, confirm they are listed, unblock, and confirm the row disappears and their posts return to the feed after a refresh.

- [ ] **Step 5: Stage (do NOT commit)**

```bash
git add frontend/lib/features/community/presentation/bloc/blocked_users frontend/lib/features/community/presentation/screens/blocked_users_screen.dart frontend/lib/core/router frontend/lib/core/di/injection_container.dart frontend/lib/core/i18n/app_translations.dart frontend/lib/features/settings/presentation/pages/settings_screen.dart
```

---

### Task 9: Admin moderation queue

**Files:**
- Create: `admin-web/app/api/admin/moderation/route.ts`
- Create: `admin-web/app/(dashboard)/moderation/page.tsx`
- Modify: `admin-web/components/sidebar.tsx:44` (add the nav item)

**Interfaces:**
- Consumes: `fellowship_reports` and `user_blocks` from Task 1.
- Produces:
  - `GET /api/admin/moderation?tab=reports|blocks&status=pending&limit=&offset=` → `{ data: ModerationReport[] | ModerationBlock[], total: number }`
  - `PATCH /api/admin/moderation` — body `{ report_id, status }` where status is `'reviewed' | 'dismissed'`
  - `DELETE /api/admin/moderation` — body `{ content_type, content_id }`, soft-deletes by setting `is_deleted = true`

- [ ] **Step 1: Write the API route**

`admin-web/app/api/admin/moderation/route.ts`, following the auth and admin-check preamble in `app/api/admin/feedback/route.ts` verbatim (Supabase user client for `auth.getUser`, then an admin client checking `user_profiles.is_admin`).

`GET` with `tab=reports`: select from `fellowship_reports` with `{ count: 'exact' }`, filtered by `status` (default `pending`), ordered by `created_at` descending, ranged by `offset`/`limit`. Then batch-resolve the referenced posts and comments — `fellowship_posts` for rows with `content_type = 'post'`, `fellowship_comments` for `'comment'` — and the reporter and author display names via `getAuthEmailMap`. Mark each row `source: reason === 'user_blocked' ? 'block' : 'flag'`.

`GET` with `tab=blocks`: select `blocker_id, blocked_id, created_at` from `user_blocks` with `{ count: 'exact' }`, newest first, paged the same way, with names resolved the same way.

All filtering, counting and paging happen in SQL — never fetch the whole table and slice in JS.

`PATCH`: validate `status` is one of `reviewed` or `dismissed`, then update that `fellowship_reports` row.

`DELETE`: validate `content_type` is `post` or `comment`, then set `is_deleted = true` on the matching row in `fellowship_posts` or `fellowship_comments`.

- [ ] **Step 2: Write the page**

`admin-web/app/(dashboard)/moderation/page.tsx`, modelled on `app/(dashboard)/issues/page.tsx`: `'use client'`, `PageHeader`, `TabNav` with `reports` and `blocks` tabs, `useQuery` with `keepPreviousData` for the list, `useMutation` + `queryClient.invalidateQueries` for resolve, dismiss and delete, and the same `Pagination` component with `PAGE_SIZE = 50`.

The reports table shows: reported content excerpt, content type, source (Flag or Block), reporter, author, created date, and Resolve / Dismiss / Delete Content buttons. The blocks table shows blocker, blocked, and created date — read-only.

- [ ] **Step 3: Add the nav item**

In `admin-web/components/sidebar.tsx`, beside the Issues entry (line ~44):

```tsx
      { name: 'Moderation', href: '/moderation', emoji: '🚫' },
```

- [ ] **Step 4: Verify**

```bash
cd admin-web && npm run lint && npm run build
```

Then run the dashboard, block a user from the app with a post selected, and confirm the report appears under Moderation → Reports with source "Block". Block from the members list and confirm it appears under Moderation → Blocks. Exercise Resolve, Dismiss, and Delete Content, then confirm the deleted post no longer appears in the app feed.

- [ ] **Step 5: Stage (do NOT commit)**

```bash
git add admin-web/app/api/admin/moderation admin-web/app/\(dashboard\)/moderation admin-web/components/sidebar.tsx
```

---

## After the plan

Once all nine tasks are done, the Guideline 1.2 blocking requirement is met. Still outstanding before resubmission, tracked separately:

1. **Terms-of-use gate** on the signup and login screens — Apple named this in the same rejection.
2. **Screen recording on a physical device** showing terms at login, flagging content, and blocking a user. Goes in App Store Connect → App Review Information → Notes.
3. **Remove China mainland** from Pricing and Availability, which clears the separate Guideline 2.1 permit rejection.
4. **Deploy**: you run `supabase db push` and `supabase functions deploy` — the plan never does.
