# Reset User Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give users two independent, irreversible reset actions — one clearing all learning-path progress from the Study Topics screen, one clearing all memory verses from the Memory Verses home page.

**Architecture:** Two `SECURITY DEFINER` Postgres functions each perform their scope's deletes in one transaction. A single authenticated Edge Function (`reset-progress`) takes a `scope` parameter, maps it to an RPC through a literal lookup, and calls it with the JWT's user id. Flutter reaches it through the normal datasource → repository → use case → BLoC chain, clearing the relevant Hive caches on success. Both entry points share one typed-confirmation dialog widget.

**Tech Stack:** PostgreSQL (Supabase), Deno/TypeScript Edge Functions, Flutter with BLoC + GetIt + dartz `Either`, Hive for local cache.

**Spec:** `docs/superpowers/specs/2026-07-25-reset-user-progress-design.md`

## Global Constraints

- **STAGED-ONLY WORKFLOW. Never run `git commit`.** Every task ends by running `git add` on its files and nothing more. The controller commits once, at the end, after the user reviews the whole change. Each task's final step records the message the commit will eventually use — that is a note, not a command to run.
- Reviews therefore run on `git diff --cached`, not on commit ranges.
- Work on the `dev` branch. Do not create feature branches. Never mention Claude in a commit message and never add `Co-Authored-By` lines.
- **Local database migrations may be applied freely** (`supabase migration up`, `supabase db reset` against the local stack). **Production migrations are forbidden** — never run `supabase db push`, `supabase functions deploy`, or anything with `--project-ref`. Those are the user's to run.
- Flutter: package imports only (`import 'package:disciplefy_bible_study/...'`) in `lib/`; relative imports are the existing convention inside feature folders — match the file you are editing.
- `print()` is banned in Flutter code. Use `Logger` from `lib/core/utils/logger.dart`.
- Never log verse text, verse references, or raw user input. Metadata and counts only.
- All user-facing strings go through `context.tr(TranslationKeys.x)` with entries added to all three language maps in `app_translations.dart` (English ~line 12, Hindi ~line 2015, Malayalam ~line 4036 — locate by searching for the sibling key you are adding next to).
- Supported languages: `en`, `hi`, `ml`. A key added to one map must be added to all three.

---

### Task 1: Postgres reset functions

**Files:**
- Create: `backend/supabase/migrations/20260725000000_reset_user_progress.sql`

**Interfaces:**
- Consumes: nothing.
- Produces: `reset_user_learning_progress(p_user_id UUID) RETURNS JSONB` and `reset_user_memory_progress(p_user_id UUID) RETURNS JSONB`, both `EXECUTE`-granted to `service_role` only. Task 3 calls these by name.

- [ ] **Step 1: Write the migration**

Create `backend/supabase/migrations/20260725000000_reset_user_progress.sql`:

```sql
-- =====================================================
-- Reset User Progress
-- =====================================================
-- Two SECURITY DEFINER functions that let a user wipe their own progress
-- for one feature area at a time. Each runs all of its deletes inside the
-- calling transaction, so a failure leaves no partial-reset state.
--
-- Callable by service_role only. The reset-progress Edge Function is the
-- sole caller and supplies p_user_id from a validated JWT.

-- -----------------------------------------------------
-- Function: reset_user_learning_progress
-- -----------------------------------------------------
-- Clears learning path enrollments, topic progress, study streak, and the
-- study/streak-category achievements.
--
-- XP needs no explicit handling because it is derived, never stored.
-- get_leaderboard (20260415000001) computes
--   SUM(user_topic_progress.xp_earned) + SUM(a.xp_reward) over ALL user_achievements
-- The achievement half is NOT category-filtered, so this reset removes topic XP
-- and study/streak badge XP but leaves any voice/saved badge XP intact. XP drops
-- sharply; it does not necessarily reach zero.

CREATE OR REPLACE FUNCTION reset_user_learning_progress(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_paths_reset INTEGER;
  v_topics_reset INTEGER;
  v_achievements_reset INTEGER;
  v_streak_reset INTEGER;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  DELETE FROM user_learning_path_progress WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_paths_reset = ROW_COUNT;

  DELETE FROM user_topic_progress WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_topics_reset = ROW_COUNT;

  DELETE FROM user_achievements
  WHERE user_id = p_user_id
    AND achievement_id IN (
      SELECT id FROM achievements WHERE category IN ('study', 'streak')
    );
  GET DIAGNOSTICS v_achievements_reset = ROW_COUNT;

  DELETE FROM user_study_streaks WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_streak_reset = ROW_COUNT;

  RETURN jsonb_build_object(
    'paths_reset', v_paths_reset,
    'topics_reset', v_topics_reset,
    'achievements_reset', v_achievements_reset,
    'streak_reset', v_streak_reset > 0
  );
END;
$$;

COMMENT ON FUNCTION reset_user_learning_progress(UUID) IS
  'Deletes all learning path enrollments, topic progress, study streak, and study/streak achievements for one user. Irreversible. Zeroes leaderboard XP as a side effect since XP is derived from user_topic_progress.';

-- -----------------------------------------------------
-- Function: reset_user_memory_progress
-- -----------------------------------------------------
-- Deletes the user's entire memory verse deck and all derived progress.
--
-- Deleting memory_verses cascades to review_sessions, review_history,
-- daily_unlocked_modes, memory_verse_collection_items,
-- memory_practice_modes, and memory_verse_mastery — all six declare
-- memory_verse_id ... ON DELETE CASCADE.
--
-- daily_unlocked_modes is also deleted explicitly. That is redundant given
-- the cascade, but keeps this function correct if that FK is ever relaxed.

CREATE OR REPLACE FUNCTION reset_user_memory_progress(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_verses_deleted INTEGER;
  v_collections_deleted INTEGER;
  v_challenges_reset INTEGER;
  v_achievements_reset INTEGER;
  v_streak_reset INTEGER;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  DELETE FROM memory_verses WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_verses_deleted = ROW_COUNT;

  DELETE FROM daily_unlocked_modes WHERE user_id = p_user_id;

  DELETE FROM memory_verse_collections WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_collections_deleted = ROW_COUNT;

  DELETE FROM memory_daily_goals WHERE user_id = p_user_id;

  DELETE FROM user_challenge_progress WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_challenges_reset = ROW_COUNT;

  DELETE FROM user_achievements
  WHERE user_id = p_user_id
    AND achievement_id IN (
      SELECT id FROM achievements WHERE category = 'memory'
    );
  GET DIAGNOSTICS v_achievements_reset = ROW_COUNT;

  DELETE FROM memory_verse_streaks WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_streak_reset = ROW_COUNT;

  RETURN jsonb_build_object(
    'verses_deleted', v_verses_deleted,
    'collections_deleted', v_collections_deleted,
    'challenges_reset', v_challenges_reset,
    'achievements_reset', v_achievements_reset,
    'streak_reset', v_streak_reset > 0
  );
END;
$$;

COMMENT ON FUNCTION reset_user_memory_progress(UUID) IS
  'Deletes a user entire memory verse deck plus collections, daily goals, unlocked modes, memory challenge progress, memory achievements, and memory streak. Irreversible.';

-- -----------------------------------------------------
-- Grants
-- -----------------------------------------------------
-- service_role only. Not granted to authenticated: the reset-progress Edge
-- Function is the sole caller, so a leaked anon key cannot trigger a reset.

REVOKE ALL ON FUNCTION reset_user_learning_progress(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION reset_user_memory_progress(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION reset_user_learning_progress(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION reset_user_memory_progress(UUID) TO service_role;
```

- [ ] **Step 2: Apply the migration locally**

Local migrations are allowed. Run:

```bash
cd backend && supabase migration up
```

Expected: `Applying migration 20260725000000_reset_user_progress.sql...` with no errors.

If `supabase migration up` reports the local database is out of sync, the user may instead run `cd backend && supabase db reset`, which reapplies every migration from scratch.

- [ ] **Step 3: Verify the functions exist with the right grants (SELECT-only)**

Run:

```bash
cd backend && supabase db execute --stdin <<'SQL'
SELECT p.proname,
       p.prosecdef AS is_security_definer,
       pg_get_function_identity_arguments(p.oid) AS args,
       has_function_privilege('service_role', p.oid, 'EXECUTE') AS service_role_can_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('reset_user_learning_progress', 'reset_user_memory_progress')
ORDER BY p.proname;
SQL
```

Expected: two rows, both with `is_security_definer = t`, `args = p_user_id uuid`, `service_role_can_execute = t`, and `authenticated_can_execute = f`.

If `supabase db execute` is unavailable in the installed CLI version, run the same SQL through `psql "$(supabase status -o env | grep DB_URL | cut -d= -f2-)"`.

- [ ] **Step 4: Functional smoke test on a local user**

Local only — never against production. The transaction rolls back, so nothing is actually deleted:

```bash
cd backend && supabase db execute --stdin <<'SQL'
BEGIN;
-- Pick any existing local user
SELECT id AS uid FROM auth.users LIMIT 1 \gset
SELECT reset_user_learning_progress(:'uid'::uuid) AS learning_result;
SELECT reset_user_memory_progress(:'uid'::uuid) AS memory_result;
ROLLBACK;
SQL
```

Expected: two JSONB rows of counts, then `ROLLBACK` — nothing is actually deleted. Both calls must succeed without a `relation does not exist` or `column does not exist` error. If either errors, the table or column name in the migration is wrong; fix it and repeat from Step 2.

- [ ] **Step 5: Stage (do NOT commit)**

```bash
git add backend/supabase/migrations/20260725000000_reset_user_progress.sql
# NO COMMIT. Staged only — the controller commits once at the end.
# Intended message when it is committed: feat(backend): add reset user progress SQL functions
```

---

### Task 2: Scope resolver utility

Extracting the scope→RPC mapping into a pure module makes it unit-testable without booting the Edge Function runtime, and guarantees the RPC name is never built by string interpolation.

**Files:**
- Create: `backend/supabase/functions/_shared/utils/reset-scope.ts`
- Test: `backend/supabase/functions/_shared/utils/reset-scope.test.ts`

**Interfaces:**
- Consumes: `AppError` from `../utils/error-handler.ts`.
- Produces:
  - `type ResetScope = 'learning_paths' | 'memory_verses'`
  - `type ResetRpcName = 'reset_user_learning_progress' | 'reset_user_memory_progress'`
  - `resolveResetRpc(scope: unknown): ResetRpcName` — throws `AppError('VALIDATION_ERROR', ..., 400)` for anything not in the allowlist.

- [ ] **Step 1: Write the failing test**

Create `backend/supabase/functions/_shared/utils/reset-scope.test.ts`:

```typescript
// ============================================================================
// Reset Scope Resolver Unit Tests
// ============================================================================
// Run with: deno test --allow-env reset-scope.test.ts

import {
  assertEquals,
  assertThrows,
} from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { resolveResetRpc } from './reset-scope.ts';
import { AppError } from './error-handler.ts';

Deno.test({
  name: 'resolveResetRpc: maps learning_paths to the learning RPC',
  fn: () => {
    assertEquals(
      resolveResetRpc('learning_paths'),
      'reset_user_learning_progress',
    );
  },
});

Deno.test({
  name: 'resolveResetRpc: maps memory_verses to the memory RPC',
  fn: () => {
    assertEquals(
      resolveResetRpc('memory_verses'),
      'reset_user_memory_progress',
    );
  },
});

Deno.test({
  name: 'resolveResetRpc: rejects an unknown scope',
  fn: () => {
    assertThrows(
      () => resolveResetRpc('everything'),
      AppError,
      'Invalid scope',
    );
  },
});

Deno.test({
  name: 'resolveResetRpc: rejects a missing scope',
  fn: () => {
    assertThrows(() => resolveResetRpc(undefined), AppError, 'Invalid scope');
    assertThrows(() => resolveResetRpc(null), AppError, 'Invalid scope');
    assertThrows(() => resolveResetRpc(''), AppError, 'Invalid scope');
  },
});

Deno.test({
  name: 'resolveResetRpc: rejects non-string scopes',
  fn: () => {
    assertThrows(() => resolveResetRpc(42), AppError, 'Invalid scope');
    assertThrows(() => resolveResetRpc({}), AppError, 'Invalid scope');
    assertThrows(
      () => resolveResetRpc(['learning_paths']),
      AppError,
      'Invalid scope',
    );
  },
});

Deno.test({
  name: 'resolveResetRpc: does not resolve prototype keys',
  fn: () => {
    // A plain-object lookup table would return Object.prototype members here.
    assertThrows(() => resolveResetRpc('toString'), AppError, 'Invalid scope');
    assertThrows(
      () => resolveResetRpc('constructor'),
      AppError,
      'Invalid scope',
    );
    assertThrows(
      () => resolveResetRpc('__proto__'),
      AppError,
      'Invalid scope',
    );
  },
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd backend/supabase/functions/_shared/utils && DENO_TESTING=true deno test --allow-env reset-scope.test.ts
```

Expected: FAIL — `Module not found "file:///.../reset-scope.ts"`.

- [ ] **Step 3: Write the implementation**

Create `backend/supabase/functions/_shared/utils/reset-scope.ts`:

```typescript
/**
 * Reset Scope Resolver
 *
 * Maps the caller-supplied `scope` value to the name of the Postgres
 * function that performs that reset.
 *
 * The mapping lives in a Map rather than a plain object so that inherited
 * keys such as `toString` and `__proto__` cannot resolve to anything. The
 * RPC name is always one of two literals — it is never built from caller
 * input.
 */

import { AppError } from './error-handler.ts'

/** Feature areas a user can reset. */
export type ResetScope = 'learning_paths' | 'memory_verses'

/** Postgres functions that perform the resets. */
export type ResetRpcName =
  | 'reset_user_learning_progress'
  | 'reset_user_memory_progress'

const SCOPE_TO_RPC = new Map<ResetScope, ResetRpcName>([
  ['learning_paths', 'reset_user_learning_progress'],
  ['memory_verses', 'reset_user_memory_progress'],
])

/** Every valid scope, for error messages. */
export const VALID_RESET_SCOPES: readonly ResetScope[] = [
  'learning_paths',
  'memory_verses',
]

/**
 * Resolve a caller-supplied scope to its RPC name.
 *
 * @param scope - Untrusted value from the request body
 * @returns The Postgres function name to call
 * @throws AppError VALIDATION_ERROR (400) if the scope is not in the allowlist
 */
export function resolveResetRpc(scope: unknown): ResetRpcName {
  if (typeof scope !== 'string') {
    throw new AppError(
      'VALIDATION_ERROR',
      `Invalid scope. Expected one of: ${VALID_RESET_SCOPES.join(', ')}`,
      400,
    )
  }

  const rpc = SCOPE_TO_RPC.get(scope as ResetScope)

  if (!rpc) {
    throw new AppError(
      'VALIDATION_ERROR',
      `Invalid scope. Expected one of: ${VALID_RESET_SCOPES.join(', ')}`,
      400,
    )
  }

  return rpc
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
cd backend/supabase/functions/_shared/utils && DENO_TESTING=true deno test --allow-env reset-scope.test.ts
```

Expected: PASS — `ok | 6 passed | 0 failed`.

- [ ] **Step 5: Stage (do NOT commit)**

```bash
git add backend/supabase/functions/_shared/utils/reset-scope.ts backend/supabase/functions/_shared/utils/reset-scope.test.ts
# NO COMMIT. Staged only — the controller commits once at the end.
# Intended message when it is committed: feat(backend): add reset scope resolver with allowlist validation
```

---

### Task 3: `reset-progress` Edge Function

**Files:**
- Create: `backend/supabase/functions/reset-progress/index.ts`

**Interfaces:**
- Consumes: `resolveResetRpc` from Task 2; `reset_user_learning_progress` / `reset_user_memory_progress` from Task 1; `createAuthenticatedFunction` from `_shared/core/function-factory.ts`; `AppError` from `_shared/utils/error-handler.ts`; `RateLimiter` from `_shared/utils/rate-limiter.ts`.
- Produces: `POST /functions/v1/reset-progress` accepting `{ "scope": "learning_paths" | "memory_verses" }` and returning `{ success: true, data: { scope, counts } }`. Tasks 6 and 9 call this.

- [ ] **Step 1: Write the function**

Create `backend/supabase/functions/reset-progress/index.ts`:

```typescript
/**
 * Reset Progress Edge Function
 *
 * Lets an authenticated user irreversibly wipe their own progress for one
 * feature area:
 *
 * - `learning_paths` — enrollments, topic progress, study streak, and
 *   study/streak achievements. Zeroes leaderboard XP as a side effect,
 *   because XP is derived from user_topic_progress.
 * - `memory_verses` — the whole memory verse deck plus collections, daily
 *   goals, unlocked modes, memory challenge progress, memory achievements,
 *   and the memory streak.
 *
 * Security:
 * - Authenticated users only. Guest sessions are rejected.
 * - user_id comes from the validated JWT, never from the request body, so a
 *   user cannot reset someone else's data.
 * - `scope` is checked against a two-value allowlist and mapped to an RPC
 *   name through a literal lookup — never string interpolation.
 * - Rate limited to 5 resets per hour per user.
 *
 * Each RPC runs its deletes in a single transaction, so there is no
 * partial-reset state and retrying after a timeout is safe.
 */

import { createAuthenticatedFunction } from '../_shared/core/function-factory.ts'
import { AppError } from '../_shared/utils/error-handler.ts'
import { ApiSuccessResponse, UserContext } from '../_shared/types/index.ts'
import { ServiceContainer } from '../_shared/core/services.ts'
import { RateLimiter } from '../_shared/utils/rate-limiter.ts'
import { resolveResetRpc } from '../_shared/utils/reset-scope.ts'

/** 5 resets per hour per user. */
const resetLimiter = new RateLimiter({
  windowMs: 60 * 60 * 1000,
  maxRequests: 5,
})

interface ResetProgressData {
  readonly scope: string
  readonly counts: Record<string, unknown>
}

interface ResetProgressResponse extends ApiSuccessResponse<ResetProgressData> {}

async function handleResetProgress(
  req: Request,
  services: ServiceContainer,
  userContext?: UserContext
): Promise<Response> {
  // Authenticated users only — a guest has no server-side progress to reset
  if (!userContext || userContext.type !== 'authenticated' || !userContext.userId) {
    throw new AppError(
      'AUTHENTICATION_ERROR',
      'Authentication required to reset progress',
      401
    )
  }

  const userId = userContext.userId

  // Rate limit per user, not per IP — this is a per-account destructive action
  if (!resetLimiter.allow(userId)) {
    throw new AppError(
      'RATE_LIMIT_EXCEEDED',
      'Too many reset attempts. Please try again later.',
      429
    )
  }

  // Parse body
  let body: Record<string, unknown>
  try {
    body = await req.json()
  } catch {
    throw new AppError('VALIDATION_ERROR', 'Request body must be valid JSON', 400)
  }

  // Validate scope against the allowlist and resolve the RPC name.
  // Throws VALIDATION_ERROR for anything unexpected.
  const rpcName = resolveResetRpc(body.scope)
  const scope = body.scope as string

  // Call the RPC with the JWT's user id. body.user_id, if present, is ignored.
  const { data, error } = await services.supabaseServiceClient.rpc(rpcName, {
    p_user_id: userId,
  })

  if (error) {
    console.error('[ResetProgress] RPC error:', {
      scope,
      rpc: rpcName,
      message: error.message,
    })
    throw new AppError('DATABASE_ERROR', 'Failed to reset progress', 500)
  }

  const counts = (data ?? {}) as Record<string, unknown>

  // Analytics: scope and counts only, never verse text or references
  try {
    await services.analyticsLogger.logEvent(
      'user_progress_reset',
      {
        user_id: userId,
        scope,
        counts,
      },
      req.headers.get('x-forwarded-for')
    )
  } catch (analyticsError) {
    console.error('[ResetProgress] Analytics logging failed:', {
      error: analyticsError,
      user_id: userId,
      scope,
    })
    // Non-fatal — the reset already succeeded
  }

  const response: ResetProgressResponse = {
    success: true,
    data: { scope, counts },
  }

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}

createAuthenticatedFunction(handleResetProgress, {
  allowedMethods: ['POST'],
  enableAnalytics: true,
  timeout: 30000, // 30s — deleting a large verse deck cascades to several tables
})
```

- [ ] **Step 2: Type-check the function**

Run:

```bash
cd backend && deno check supabase/functions/reset-progress/index.ts
```

Expected: `Check file:///.../reset-progress/index.ts` with no errors.

If `deno check` reports unresolved remote imports because of a cold cache, run `cd backend && sh scripts/check-quick.sh` instead and confirm `reset-progress` is not listed as failing.

- [ ] **Step 3: Serve locally and exercise the endpoint**

Local only. In one terminal:

```bash
cd backend && supabase functions serve --env-file .env.local
```

Then in another terminal, with `$ANON_KEY` set to the local anon key from `supabase status` and `$USER_JWT` set to a signed-in user's access token:

```bash
# 1. Invalid scope -> 400 VALIDATION_ERROR
curl -s -X POST http://localhost:54321/functions/v1/reset-progress \
  -H "Authorization: Bearer $USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"scope":"everything"}' | jq

# 2. Missing auth -> 401 AUTHENTICATION_ERROR
curl -s -X POST http://localhost:54321/functions/v1/reset-progress \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"scope":"memory_verses"}' | jq

# 3. Valid reset -> 200 with counts (THIS DELETES DATA on the local DB)
curl -s -X POST http://localhost:54321/functions/v1/reset-progress \
  -H "Authorization: Bearer $USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"scope":"memory_verses"}' | jq
```

Expected:
1. `{ "success": false, "error": { "code": "VALIDATION_ERROR", ... } }`
2. `{ "success": false, "error": { "code": "AUTHENTICATION_ERROR", ... } }`
3. `{ "success": true, "data": { "scope": "memory_verses", "counts": { "verses_deleted": N, ... } } }`

- [ ] **Step 4: Stage (do NOT commit)**

```bash
git add backend/supabase/functions/reset-progress/index.ts
# NO COMMIT. Staged only — the controller commits once at the end.
# Intended message when it is committed: feat(backend): add reset-progress edge function
```

---

### Task 4: `ResetProgressResult` model

Shared by both features, so it lives in `core/models/` alongside the other cross-feature models rather than being duplicated in two feature domains.

**Files:**
- Create: `frontend/lib/core/models/reset_progress_result.dart`
- Test: `frontend/test/core/models/reset_progress_result_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `ResetProgressResult` with `final String scope`, `final Map<String, int> counts`, `int get totalAffected`, `factory ResetProgressResult.fromJson(Map<String, dynamic> json)`. Tasks 6, 7, 9, and 10 use it.

- [ ] **Step 1: Write the failing test**

Create `frontend/test/core/models/reset_progress_result_test.dart`:

```dart
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResetProgressResult.fromJson', () {
    test('parses scope and integer counts', () {
      final result = ResetProgressResult.fromJson(const {
        'scope': 'memory_verses',
        'counts': {
          'verses_deleted': 42,
          'collections_deleted': 2,
        },
      });

      expect(result.scope, 'memory_verses');
      expect(result.counts['verses_deleted'], 42);
      expect(result.counts['collections_deleted'], 2);
    });

    test('ignores non-integer count values such as booleans', () {
      final result = ResetProgressResult.fromJson(const {
        'scope': 'learning_paths',
        'counts': {
          'paths_reset': 3,
          'streak_reset': true,
        },
      });

      expect(result.counts['paths_reset'], 3);
      expect(result.counts.containsKey('streak_reset'), isFalse);
    });

    test('defaults to an empty counts map when counts is missing', () {
      final result = ResetProgressResult.fromJson(const {
        'scope': 'learning_paths',
      });

      expect(result.scope, 'learning_paths');
      expect(result.counts, isEmpty);
      expect(result.totalAffected, 0);
    });

    test('defaults scope to an empty string when absent', () {
      final result = ResetProgressResult.fromJson(const {});

      expect(result.scope, '');
    });

    test('totalAffected sums all integer counts', () {
      final result = ResetProgressResult.fromJson(const {
        'scope': 'learning_paths',
        'counts': {
          'paths_reset': 3,
          'topics_reset': 27,
          'achievements_reset': 5,
          'streak_reset': true,
        },
      });

      expect(result.totalAffected, 35);
    });

    test('equality is value-based', () {
      const json = {
        'scope': 'memory_verses',
        'counts': {'verses_deleted': 1},
      };

      expect(
        ResetProgressResult.fromJson(json),
        ResetProgressResult.fromJson(json),
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd frontend && flutter test test/core/models/reset_progress_result_test.dart
```

Expected: FAIL — `Error: Couldn't resolve the package 'disciplefy_bible_study' ... reset_progress_result.dart` / `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `frontend/lib/core/models/reset_progress_result.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Outcome of a progress reset, as reported by the `reset-progress`
/// Edge Function.
///
/// [counts] holds only the integer row counts from the backend response.
/// Boolean flags such as `streak_reset` are intentionally dropped — this
/// model exists to tell the user how much was removed.
class ResetProgressResult extends Equatable {
  /// The feature area that was reset (`learning_paths` or `memory_verses`).
  final String scope;

  /// Row counts keyed by the backend's field names.
  final Map<String, int> counts;

  const ResetProgressResult({
    required this.scope,
    required this.counts,
  });

  /// Parses the `data` object of a `reset-progress` response.
  factory ResetProgressResult.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    final counts = <String, int>{};

    if (rawCounts is Map) {
      rawCounts.forEach((key, value) {
        if (key is String && value is int) {
          counts[key] = value;
        }
      });
    }

    return ResetProgressResult(
      scope: json['scope'] is String ? json['scope'] as String : '',
      counts: Map.unmodifiable(counts),
    );
  }

  /// Total number of rows removed across all counted tables.
  int get totalAffected =>
      counts.values.fold<int>(0, (sum, value) => sum + value);

  @override
  List<Object?> get props => [scope, counts];
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
cd frontend && flutter test test/core/models/reset_progress_result_test.dart
```

Expected: PASS — `All tests passed!` (6 tests).

- [ ] **Step 5: Stage (do NOT commit)**

```bash
git add frontend/lib/core/models/reset_progress_result.dart frontend/test/core/models/reset_progress_result_test.dart
# NO COMMIT. Staged only — the controller commits once at the end.
# Intended message when it is committed: feat(frontend): add ResetProgressResult model
```

---

### Task 5: Destructive confirm dialog + shared translations

**Files:**
- Create: `frontend/lib/core/widgets/destructive_confirm_dialog.dart`
- Modify: `frontend/lib/core/i18n/translation_keys.dart`
- Modify: `frontend/lib/core/i18n/app_translations.dart`
- Test: `frontend/test/core/widgets/destructive_confirm_dialog_test.dart`

**Interfaces:**
- Consumes: `context.tr` from `core/extensions/translation_extension.dart`.
- Produces: `DestructiveConfirmDialog.show(BuildContext context, {required String title, required List<String> consequences, required String confirmWord, required String confirmLabel}) → Future<bool>` — resolves `true` only if the user typed `confirmWord` and pressed confirm. Tasks 8 and 10 call this.
- Produces translation keys: `TranslationKeys.resetProgressConfirmWord`, `resetProgressTypeToConfirm`, `resetProgressCancel`, `resetProgressIrreversible`.

- [ ] **Step 1: Add the translation keys**

In `frontend/lib/core/i18n/translation_keys.dart`, append to the end of the `TranslationKeys` class body (immediately before the closing `}` of the class):

```dart
  // ==========================================================================
  // Reset Progress (shared by learning paths and memory verses)
  // ==========================================================================

  /// Word the user must type to confirm a destructive reset.
  static const resetProgressConfirmWord = 'reset_progress.confirm_word';
  static const resetProgressTypeToConfirm =
      'reset_progress.type_to_confirm';
  static const resetProgressCancel = 'reset_progress.cancel';
  static const resetProgressIrreversible = 'reset_progress.irreversible';
```

- [ ] **Step 2: Add the translation values to all three language maps**

In `frontend/lib/core/i18n/app_translations.dart`, add a `'reset_progress'` block to each of the three maps. Insert it immediately after the `'memory': { ... }` block's closing `},` in each map (search for `'optionsMenu': {` to find each map's memory section, then scroll to that section's end).

English (`_englishTranslations`):

```dart
    'reset_progress': {
      'confirm_word': 'RESET',
      'type_to_confirm': 'Type {word} to confirm',
      'cancel': 'Cancel',
      'irreversible': 'This cannot be undone.',
    },
```

Hindi (`_hindiTranslations`):

```dart
    'reset_progress': {
      'confirm_word': 'रीसेट',
      'type_to_confirm': 'पुष्टि के लिए {word} लिखें',
      'cancel': 'रद्द करें',
      'irreversible': 'इसे पूर्ववत नहीं किया जा सकता।',
    },
```

Malayalam (`_malayalamTranslations`):

```dart
    'reset_progress': {
      'confirm_word': 'റീസെറ്റ്',
      'type_to_confirm': 'സ്ഥിരീകരിക്കാൻ {word} എന്ന് ടൈപ്പ് ചെയ്യുക',
      'cancel': 'റദ്ദാക്കുക',
      'irreversible': 'ഇത് പഴയപടിയാക്കാൻ കഴിയില്ല.',
    },
```

- [ ] **Step 3: Write the failing widget test**

Create `frontend/test/core/widgets/destructive_confirm_dialog_test.dart`:

```dart
import 'package:disciplefy_bible_study/core/widgets/destructive_confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_translation_provider.dart';

void main() {
  /// Pumps a screen with a button that opens the dialog, and records the
  /// value the dialog resolves with.
  Future<void> pumpHost(
    WidgetTester tester, {
    required List<bool?> results,
  }) async {
    await tester.pumpWidget(
      MockTranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final confirmed = await DestructiveConfirmDialog.show(
                    context,
                    title: 'Reset memory verses?',
                    consequences: const [
                      'All 42 verses will be deleted',
                      'Practice history will be deleted',
                    ],
                    confirmWord: 'RESET',
                    confirmLabel: 'Reset',
                  );
                  results.add(confirmed);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the title and every consequence line', (tester) async {
    await pumpHost(tester, results: []);

    expect(find.text('Reset memory verses?'), findsOneWidget);
    expect(find.text('All 42 verses will be deleted'), findsOneWidget);
    expect(find.text('Practice history will be deleted'), findsOneWidget);
  });

  testWidgets('confirm button is disabled before anything is typed',
      (tester) async {
    await pumpHost(tester, results: []);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reset'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('confirm button stays disabled for the wrong word',
      (tester) async {
    await pumpHost(tester, results: []);

    await tester.enterText(find.byType(TextField), 'RESE');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reset'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('confirm button enables on the exact word and returns true',
      (tester) async {
    final results = <bool?>[];
    await pumpHost(tester, results: results);

    await tester.enterText(find.byType(TextField), 'RESET');
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reset'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });

  testWidgets('accepts the confirm word regardless of case and whitespace',
      (tester) async {
    final results = <bool?>[];
    await pumpHost(tester, results: results);

    await tester.enterText(find.byType(TextField), '  reset ');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();

    expect(results, [true]);
  });

  testWidgets('cancel resolves to false', (tester) async {
    final results = <bool?>[];
    await pumpHost(tester, results: results);

    await tester.enterText(find.byType(TextField), 'RESET');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(results, [false]);
  });
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run:

```bash
cd frontend && flutter test test/core/widgets/destructive_confirm_dialog_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../destructive_confirm_dialog.dart'`.

If the failure is instead `Target of URI doesn't exist: '../../helpers/mock_translation_provider.dart'`, check the actual path of that helper with `ls frontend/test/helpers/` and fix the relative import.

- [ ] **Step 5: Write the implementation**

Create `frontend/lib/core/widgets/destructive_confirm_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import '../extensions/translation_extension.dart';
import '../i18n/translation_keys.dart';

/// Confirmation dialog for irreversible destructive actions.
///
/// The confirm button stays disabled until the user types [confirmWord],
/// which makes an accidental tap impossible. [consequences] is rendered as a
/// bulleted list so the user sees exactly what is about to be deleted.
///
/// The comparison is case-insensitive and trims surrounding whitespace —
/// the friction should come from having to read and type, not from matching
/// capitalisation.
///
/// Returns `true` only when the user typed the word and pressed confirm.
class DestructiveConfirmDialog extends StatefulWidget {
  /// Dialog headline, e.g. "Reset memory verses?".
  final String title;

  /// Bulleted list of what will be deleted.
  final List<String> consequences;

  /// Word the user must type. Pass a localized value.
  final String confirmWord;

  /// Label for the destructive confirm button.
  final String confirmLabel;

  const DestructiveConfirmDialog({
    super.key,
    required this.title,
    required this.consequences,
    required this.confirmWord,
    required this.confirmLabel,
  });

  /// Shows the dialog and resolves to the user's decision.
  ///
  /// Resolves to `false` if the dialog is dismissed by tapping outside.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required List<String> consequences,
    required String confirmWord,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DestructiveConfirmDialog(
        title: title,
        consequences: consequences,
        confirmWord: confirmWord,
        confirmLabel: confirmLabel,
      ),
    );
    return result ?? false;
  }

  @override
  State<DestructiveConfirmDialog> createState() =>
      _DestructiveConfirmDialogState();
}

class _DestructiveConfirmDialogState extends State<DestructiveConfirmDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final matches = _controller.text.trim().toLowerCase() ==
        widget.confirmWord.trim().toLowerCase();
    if (matches != _canConfirm) {
      setState(() => _canConfirm = matches);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: errorColor),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final consequence in widget.consequences)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(consequence)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              context.tr(TranslationKeys.resetProgressIrreversible),
              style: theme.textTheme.bodySmall?.copyWith(
                color: errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: context
                    .tr(TranslationKeys.resetProgressTypeToConfirm)
                    .replaceAll('{word}', widget.confirmWord),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.tr(TranslationKeys.resetProgressCancel)),
        ),
        FilledButton(
          onPressed:
              _canConfirm ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: errorColor,
            foregroundColor: theme.colorScheme.onError,
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run:

```bash
cd frontend && flutter test test/core/widgets/destructive_confirm_dialog_test.dart
```

Expected: PASS — `All tests passed!` (6 tests).

- [ ] **Step 7: Lint and format**

Run:

```bash
cd frontend && dart format lib/core/widgets/destructive_confirm_dialog.dart lib/core/i18n/ && flutter analyze lib/core/widgets/destructive_confirm_dialog.dart lib/core/i18n/
```

Expected: `No issues found!`

- [ ] **Step 8: Stage (do NOT commit)**

```bash
git add frontend/lib/core/widgets/destructive_confirm_dialog.dart frontend/lib/core/i18n/translation_keys.dart frontend/lib/core/i18n/app_translations.dart frontend/test/core/widgets/destructive_confirm_dialog_test.dart
# NO COMMIT. Staged only — the controller commits once at the end.
# Intended message when it is committed: feat(frontend): add destructive confirm dialog with typed confirmation
```

---

### Task 6: Learning paths data layer

**Files:**
- Modify: `frontend/lib/features/study_topics/data/datasources/learning_paths_remote_datasource.dart`
- Modify: `frontend/lib/features/study_topics/data/repositories/learning_paths_repository_impl.dart`
- Modify: `frontend/lib/features/study_topics/domain/repositories/learning_paths_repository.dart`
- Create: `frontend/lib/features/study_topics/domain/usecases/reset_learning_progress.dart`
- Modify: `frontend/lib/core/di/injection_container.dart:780-782`
- Test: `frontend/test/features/study_topics/domain/usecases/reset_learning_progress_test.dart`

**Interfaces:**
- Consumes: `ResetProgressResult` (Task 4); `POST /functions/v1/reset-progress` (Task 3).
- Produces:
  - `LearningPathsRemoteDataSource.resetLearningProgress() → Future<ResetProgressResult>`
  - `LearningPathsRepository.resetLearningProgress() → Future<Either<Failure, ResetProgressResult>>`
  - `ResetLearningProgress` use case, callable as `await useCase()`
  - GetIt registration `sl<ResetLearningProgress>()`

- [ ] **Step 1: Write the failing use case test**

Create `frontend/test/features/study_topics/domain/usecases/reset_learning_progress_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/usecases/reset_learning_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'reset_learning_progress_test.mocks.dart';

@GenerateMocks([LearningPathsRepository])
void main() {
  late MockLearningPathsRepository repository;
  late ResetLearningProgress useCase;

  setUp(() {
    repository = MockLearningPathsRepository();
    useCase = ResetLearningProgress(repository);
  });

  const result = ResetProgressResult(
    scope: 'learning_paths',
    counts: {'paths_reset': 3, 'topics_reset': 27},
  );

  test('returns the repository result on success', () async {
    when(repository.resetLearningProgress())
        .thenAnswer((_) async => const Right(result));

    final actual = await useCase();

    expect(actual, const Right<Failure, ResetProgressResult>(result));
    verify(repository.resetLearningProgress()).called(1);
  });

  test('propagates the failure on error', () async {
    const failure = ServerFailure(message: 'boom', code: 'SERVER_ERROR');
    when(repository.resetLearningProgress())
        .thenAnswer((_) async => const Left(failure));

    final actual = await useCase();

    expect(actual, const Left<Failure, ResetProgressResult>(failure));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd frontend && flutter test test/features/study_topics/domain/usecases/reset_learning_progress_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../reset_learning_progress.dart'` and a missing `reset_learning_progress_test.mocks.dart`.

- [ ] **Step 3: Add the datasource method**

In `frontend/lib/features/study_topics/data/datasources/learning_paths_remote_datasource.dart`:

Add the import near the other core imports at the top of the file:

```dart
import '../../../../core/models/reset_progress_result.dart';
```

Add to the `LearningPathsRemoteDataSource` abstract class, after the `enrollInPath` declaration:

```dart
  /// Reset all of the user's learning path progress.
  ///
  /// Irreversible. Clears enrollments, topic progress, study streak, and
  /// study/streak achievements, which also zeroes leaderboard XP.
  Future<ResetProgressResult> resetLearningProgress();
```

Add the endpoint constant next to `_endpoint` in `LearningPathsRemoteDataSourceImpl`:

```dart
  static const String _resetProgressEndpoint = '/functions/v1/reset-progress';
```

Add the implementation to `LearningPathsRemoteDataSourceImpl`, after `enrollInPath`:

```dart
  @override
  Future<ResetProgressResult> resetLearningProgress() async {
    try {
      _logDebug('Resetting all learning path progress');

      final headers = await _httpService.createHeaders();
      final body = jsonEncode({'scope': 'learning_paths'});

      final response = await _httpService.post(
        '$_baseUrl$_resetProgressEndpoint',
        headers: headers,
        body: body,
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode != 200) {
        _logDebug('Reset API error: ${response.statusCode}');
        throw ServerException(
          message: 'Failed to reset learning progress: ${response.statusCode}',
          code: 'RESET_PROGRESS_API_ERROR',
        );
      }

      // Progress is gone server-side — drop the cached path list so
      // enrollment state is refetched on the next load.
      await _cache.clearCache();

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw ServerException(
          message: 'Malformed reset response',
          code: 'RESET_PROGRESS_PARSE_ERROR',
        );
      }

      _logDebug('Learning progress reset');
      return ResetProgressResult.fromJson(data);
    } on ServerException {
      rethrow;
    } on ClientException {
      rethrow;
    } catch (e) {
      _logDebug('Exception in resetLearningProgress: $e');
      throw ServerException(
        message: 'Failed to reset learning progress',
        code: 'RESET_PROGRESS_ERROR',
      );
    }
  }
```

- [ ] **Step 4: Add the repository interface method**

In `frontend/lib/features/study_topics/domain/repositories/learning_paths_repository.dart`, add the import:

```dart
import '../../../../core/models/reset_progress_result.dart';
```

and add to the `LearningPathsRepository` abstract class, after `enrollInPath`:

```dart
  /// Reset all of the user's learning path progress.
  ///
  /// Irreversible. Clears enrollments, topic progress, study streak, and
  /// study/streak achievements, which also zeroes leaderboard XP.
  Future<Either<Failure, ResetProgressResult>> resetLearningProgress();
```

- [ ] **Step 5: Add the shared exception→failure mapper**

Both this task and Task 9 need the same exception translation. Write it once here; Task 9 reuses it.

Create `frontend/lib/core/error/exception_failure_mapper.dart`:

```dart
import 'exceptions.dart';
import 'failures.dart';

/// Translates a thrown datasource exception into the matching [Failure].
///
/// Repositories catch broadly and delegate here so the exception→failure
/// mapping stays in one place. Anything unrecognised — including a raw
/// `Exception` from a parsing bug — becomes a [ServerFailure] carrying
/// [fallbackMessage], so callers always get a presentable message.
Failure mapExceptionToFailure(
  Object error, {
  required String fallbackMessage,
  String fallbackCode = 'UNEXPECTED_ERROR',
}) {
  if (error is AuthenticationException) {
    return AuthenticationFailure(message: error.message, code: error.code);
  }
  if (error is AuthorizationException) {
    return AuthorizationFailure(message: error.message, code: error.code);
  }
  if (error is RateLimitException) {
    return RateLimitFailure(message: error.message, code: error.code);
  }
  if (error is NetworkException) {
    return NetworkFailure(message: error.message, code: error.code);
  }
  if (error is ValidationException) {
    return ValidationFailure(message: error.message, code: error.code);
  }
  if (error is CacheException) {
    return CacheFailure(message: error.message, code: error.code);
  }
  if (error is ServerException) {
    return ServerFailure(message: error.message, code: error.code);
  }
  if (error is ClientException) {
    return ClientFailure(message: error.message, code: error.code);
  }
  return ServerFailure(message: fallbackMessage, code: fallbackCode);
}
```

Before writing it, confirm every referenced exception and failure class exists with a `{required String message, required String code}` constructor:

```bash
cd frontend && grep -n "^class " lib/core/error/exceptions.dart lib/core/error/failures.dart
```

Drop any branch whose exception or failure class is not present rather than inventing one.

Add a test at `frontend/test/core/error/exception_failure_mapper_test.dart`:

```dart
import 'package:disciplefy_bible_study/core/error/exception_failure_mapper.dart';
import 'package:disciplefy_bible_study/core/error/exceptions.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapExceptionToFailure', () {
    test('maps each known exception to its matching failure', () {
      expect(
        mapExceptionToFailure(
          const NetworkException(message: 'offline', code: 'NETWORK_ERROR'),
          fallbackMessage: 'fallback',
        ),
        isA<NetworkFailure>()
            .having((f) => f.message, 'message', 'offline')
            .having((f) => f.code, 'code', 'NETWORK_ERROR'),
      );

      expect(
        mapExceptionToFailure(
          const RateLimitException(message: 'slow', code: 'RATE_LIMIT'),
          fallbackMessage: 'fallback',
        ),
        isA<RateLimitFailure>(),
      );

      expect(
        mapExceptionToFailure(
          const AuthenticationException(message: 'nope', code: 'AUTH'),
          fallbackMessage: 'fallback',
        ),
        isA<AuthenticationFailure>(),
      );

      expect(
        mapExceptionToFailure(
          const ServerException(message: 'boom', code: 'SERVER_ERROR'),
          fallbackMessage: 'fallback',
        ),
        isA<ServerFailure>().having((f) => f.message, 'message', 'boom'),
      );
    });

    test('falls back to ServerFailure for an unrecognised error', () {
      final failure = mapExceptionToFailure(
        FormatException('bad json'),
        fallbackMessage: 'Failed to reset',
        fallbackCode: 'RESET_PROGRESS_ERROR',
      );

      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Failed to reset');
      expect(failure.code, 'RESET_PROGRESS_ERROR');
    });
  });
}
```

Run it:

```bash
cd frontend && flutter test test/core/error/exception_failure_mapper_test.dart
```

Expected: PASS. If a `const` constructor call fails to compile, drop the `const` — the exception classes' constructors are `const` but the test does not depend on that.

- [ ] **Step 6: Add the repository implementation**

In `frontend/lib/features/study_topics/data/repositories/learning_paths_repository_impl.dart`, add the imports:

```dart
import '../../../../core/error/exception_failure_mapper.dart';
import '../../../../core/models/reset_progress_result.dart';
```

and add the method to the class body:

```dart
  @override
  Future<Either<Failure, ResetProgressResult>> resetLearningProgress() async {
    try {
      final result = await remoteDataSource.resetLearningProgress();
      return Right(result);
    } catch (e) {
      return Left(mapExceptionToFailure(
        e,
        fallbackMessage: 'Failed to reset learning progress',
        fallbackCode: 'RESET_PROGRESS_ERROR',
      ));
    }
  }
```

Do not restyle the file's existing methods to use the mapper — that is out of scope for this task.

- [ ] **Step 7: Write the use case**

Create `frontend/lib/features/study_topics/domain/usecases/reset_learning_progress.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/reset_progress_result.dart';
import '../repositories/learning_paths_repository.dart';

/// Use case for resetting all of the user's learning path progress.
///
/// This is irreversible. It clears every learning path enrollment, all topic
/// progress, the study streak, and the study/streak achievements. Because
/// leaderboard XP is derived from topic progress, the user's XP and rank
/// reset as a side effect.
///
/// **Usage:**
/// ```dart
/// final result = await sl<ResetLearningProgress>()();
///
/// result.fold(
///   (failure) => showError(failure.message),
///   (counts) => showSuccess(counts.totalAffected),
/// );
/// ```
class ResetLearningProgress {
  final LearningPathsRepository repository;

  ResetLearningProgress(this.repository);

  /// Executes the reset.
  ///
  /// **Returns:**
  /// - `Right(ResetProgressResult)` with the row counts that were removed
  /// - `Left(NetworkFailure)` if offline
  /// - `Left(RateLimitFailure)` if the hourly reset limit is hit
  /// - `Left(AuthenticationFailure)` if the session is invalid or a guest
  /// - `Left(ServerFailure)` on any other backend error
  Future<Either<Failure, ResetProgressResult>> call() =>
      repository.resetLearningProgress();
}
```

- [ ] **Step 8: Generate mocks and run the test**

Run:

```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/study_topics/domain/usecases/reset_learning_progress_test.dart
```

Expected: PASS — `All tests passed!` (2 tests).

- [ ] **Step 9: Register the use case in the DI container**

In `frontend/lib/core/di/injection_container.dart`, immediately after the `LearningPathsRepository` registration (around line 780-782), add:

```dart
  sl.registerLazySingleton(() => ResetLearningProgress(sl()));
```

Add the import alongside the other `study_topics` imports at the top of the file:

```dart
import '../../features/study_topics/domain/usecases/reset_learning_progress.dart';
```

- [ ] **Step 10: Verify the whole feature still analyzes**

Run:

```bash
cd frontend && dart format lib/features/study_topics/ lib/core/di/injection_container.dart && flutter analyze lib/features/study_topics/ lib/core/di/injection_container.dart
```

Expected: `No issues found!`

- [ ] **Step 11: Stage (do NOT commit)**

```bash
git add frontend/lib/features/study_topics/ frontend/lib/core/di/injection_container.dart frontend/test/features/study_topics/domain/usecases/
# NO COMMIT. Staged only — the controller commits once at the end.
# Intended message when it is committed: feat(frontend): add reset learning progress data layer and use case
```

---

### Task 7: Learning paths BLoC wiring

**Files:**
- Modify: `frontend/lib/features/study_topics/presentation/bloc/learning_paths_event.dart`
- Modify: `frontend/lib/features/study_topics/presentation/bloc/learning_paths_state.dart`
- Modify: `frontend/lib/features/study_topics/presentation/bloc/learning_paths_bloc.dart`
- Modify: `frontend/lib/core/di/injection_container.dart` (the `LearningPathsBloc` registration)
- Test: `frontend/test/features/study_topics/presentation/bloc/learning_paths_reset_test.dart`

**Interfaces:**
- Consumes: `ResetLearningProgress` (Task 6), `ResetProgressResult` (Task 4).
- Produces: `ResetLearningProgressRequested` event; `LearningPathsResetting`, `LearningPathsResetSuccess(result)`, and the existing `LearningPathsError` states. Task 8's UI listens for these.

- [ ] **Step 1: Write the failing bloc test**

Create `frontend/test/features/study_topics/presentation/bloc/learning_paths_reset_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/repositories/learning_paths_repository.dart';
import 'package:disciplefy_bible_study/features/study_topics/domain/usecases/reset_learning_progress.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_bloc.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_event.dart';
import 'package:disciplefy_bible_study/features/study_topics/presentation/bloc/learning_paths_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'learning_paths_reset_test.mocks.dart';

@GenerateMocks([LearningPathsRepository])
void main() {
  late MockLearningPathsRepository repository;

  setUp(() {
    repository = MockLearningPathsRepository();
  });

  const resetResult = ResetProgressResult(
    scope: 'learning_paths',
    counts: {'paths_reset': 3, 'topics_reset': 27},
  );

  LearningPathsBloc buildBloc() => LearningPathsBloc(
        repository: repository,
        resetLearningProgress: ResetLearningProgress(repository),
      );

  blocTest<LearningPathsBloc, LearningPathsState>(
    'emits [Resetting, ResetSuccess] when the reset succeeds',
    build: () {
      when(repository.resetLearningProgress())
          .thenAnswer((_) async => const Right(resetResult));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const ResetLearningProgressRequested()),
    expect: () => [
      const LearningPathsResetting(),
      const LearningPathsResetSuccess(result: resetResult),
    ],
    verify: (_) {
      verify(repository.resetLearningProgress()).called(1);
    },
  );

  blocTest<LearningPathsBloc, LearningPathsState>(
    'emits [Resetting, Error] when the reset fails',
    build: () {
      when(repository.resetLearningProgress()).thenAnswer(
        (_) async => const Left(
          RateLimitFailure(message: 'Slow down', code: 'RATE_LIMIT_EXCEEDED'),
        ),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const ResetLearningProgressRequested()),
    expect: () => [
      const LearningPathsResetting(),
      const LearningPathsError(message: 'Slow down'),
    ],
  );
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd frontend && flutter test test/features/study_topics/presentation/bloc/learning_paths_reset_test.dart
```

Expected: FAIL — undefined `ResetLearningProgressRequested`, `LearningPathsResetting`, `LearningPathsResetSuccess`, and no `resetLearningProgress` named parameter on `LearningPathsBloc`.

- [ ] **Step 3: Add the event**

In `frontend/lib/features/study_topics/presentation/bloc/learning_paths_event.dart`, append before the end of the file:

```dart
/// Reset all of the user's learning path progress.
///
/// Irreversible. The UI must confirm with the user before dispatching this.
class ResetLearningProgressRequested extends LearningPathsEvent {
  const ResetLearningProgressRequested();
}
```

- [ ] **Step 4: Add the states**

In `frontend/lib/features/study_topics/presentation/bloc/learning_paths_state.dart`, append before the end of the file. Add the import for `ResetProgressResult` at the top:

```dart
import '../../../../core/models/reset_progress_result.dart';
```

```dart
/// The reset request is in flight.
class LearningPathsResetting extends LearningPathsState {
  const LearningPathsResetting();
}

/// The reset completed. [result] holds the row counts that were removed.
class LearningPathsResetSuccess extends LearningPathsState {
  /// Counts of what was deleted.
  final ResetProgressResult result;

  const LearningPathsResetSuccess({required this.result});

  @override
  List<Object?> get props => [result];
}
```

- [ ] **Step 5: Wire the handler into the BLoC**

In `frontend/lib/features/study_topics/presentation/bloc/learning_paths_bloc.dart`:

Add the import:

```dart
import '../../domain/usecases/reset_learning_progress.dart';
```

Add the field next to `_repository`:

```dart
  final ResetLearningProgress _resetLearningProgress;
```

Change the constructor to accept it and register the handler:

```dart
  LearningPathsBloc({
    required LearningPathsRepository repository,
    required ResetLearningProgress resetLearningProgress,
  })  : _repository = repository,
        _resetLearningProgress = resetLearningProgress,
        super(const LearningPathsInitial()) {
```

and add this line alongside the other `on<...>` registrations in the constructor body:

```dart
    on<ResetLearningProgressRequested>(_onResetLearningProgress);
```

Add the handler method to the class body:

```dart
  Future<void> _onResetLearningProgress(
    ResetLearningProgressRequested event,
    Emitter<LearningPathsState> emit,
  ) async {
    emit(const LearningPathsResetting());

    final result = await _resetLearningProgress();

    result.fold(
      (failure) => emit(LearningPathsError(message: failure.message)),
      (resetResult) => emit(LearningPathsResetSuccess(result: resetResult)),
    );
  }
```

- [ ] **Step 6: Update the DI registration**

In `frontend/lib/core/di/injection_container.dart`, find the `LearningPathsBloc` registration and add the new dependency:

```dart
  sl.registerLazySingleton(
    () => LearningPathsBloc(
      repository: sl(),
      resetLearningProgress: sl(),
    ),
  );
```

- [ ] **Step 7: Generate mocks and run the test**

Run:

```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/study_topics/presentation/bloc/learning_paths_reset_test.dart
```

Expected: PASS — `All tests passed!` (2 tests).

- [ ] **Step 8: Run the full study_topics test suite to catch constructor breakage**

The `LearningPathsBloc` constructor gained a required parameter, so any existing test that builds it directly now fails to compile.

Run:

```bash
cd frontend && flutter test test/features/study_topics/
```

Expected: PASS. If a pre-existing test fails to compile because it constructs `LearningPathsBloc`, add `resetLearningProgress: ResetLearningProgress(mockRepository)` to that call using whatever mock repository that test already has.

- [ ] **Step 9: Stage (do NOT commit)**

```bash
git add frontend/lib/features/study_topics/presentation/bloc/ frontend/lib/core/di/injection_container.dart frontend/test/features/study_topics/
# NO COMMIT. Staged only — the controller commits once at the end.
# Intended message when it is committed: feat(frontend): add reset learning progress bloc handling
```

---

### Task 8: Learning paths reset UI

**Files:**
- Modify: `frontend/lib/features/study_topics/presentation/pages/study_topics_screen.dart:642-681` (the `StudyTopicsAppBar` `PopupMenuButton`)
- Modify: `frontend/lib/core/i18n/translation_keys.dart`
- Modify: `frontend/lib/core/i18n/app_translations.dart`

**Interfaces:**
- Consumes: `DestructiveConfirmDialog.show` (Task 5), `ResetLearningProgressRequested` / `LearningPathsResetting` / `LearningPathsResetSuccess` (Task 7).
- Produces: user-reachable reset flow on the Study Topics screen.

- [ ] **Step 1: Add the translation keys**

In `frontend/lib/core/i18n/translation_keys.dart`, add next to the other `studyTopics*` keys (around line 574):

```dart
  static const studyTopicsResetProgress = 'study_topics.reset_progress';
  static const studyTopicsResetProgressTitle =
      'study_topics.reset_progress_title';
  static const studyTopicsResetItemPaths =
      'study_topics.reset_item_paths';
  static const studyTopicsResetItemTopics =
      'study_topics.reset_item_topics';
  static const studyTopicsResetItemXp = 'study_topics.reset_item_xp';
  static const studyTopicsResetItemBadges =
      'study_topics.reset_item_badges';
  static const studyTopicsResetSuccess = 'study_topics.reset_success';
```

- [ ] **Step 2: Add the translation values to all three maps**

In `frontend/lib/core/i18n/app_translations.dart`, add these entries inside the existing `'study_topics'` block of each map (search for `'more_options_tooltip'` to find each one):

English:

```dart
      'reset_progress': 'Reset Progress',
      'reset_progress_title': 'Reset learning progress?',
      'reset_item_paths': 'All learning path enrollments will be removed',
      'reset_item_topics': 'All completed topics will be marked incomplete',
      'reset_item_xp': 'Your XP and leaderboard rank will drop sharply',
      'reset_item_badges': 'Study and streak badges will be removed',
      'reset_success': 'Learning progress reset',
```

Hindi:

```dart
      'reset_progress': 'प्रगति रीसेट करें',
      'reset_progress_title': 'लर्निंग प्रगति रीसेट करें?',
      'reset_item_paths': 'सभी लर्निंग पाथ नामांकन हटा दिए जाएंगे',
      'reset_item_topics': 'सभी पूर्ण किए गए विषय अपूर्ण चिह्नित होंगे',
      'reset_item_xp': 'आपका XP और लीडरबोर्ड रैंक बहुत घट जाएगा',
      'reset_item_badges': 'स्टडी और स्ट्रीक बैज हटा दिए जाएंगे',
      'reset_success': 'लर्निंग प्रगति रीसेट हो गई',
```

Malayalam:

```dart
      'reset_progress': 'പ്രോഗ്രസ് റീസെറ്റ് ചെയ്യുക',
      'reset_progress_title': 'ലേണിംഗ് പ്രോഗ്രസ് റീസെറ്റ് ചെയ്യണോ?',
      'reset_item_paths': 'എല്ലാ ലേണിംഗ് പാത്ത് എൻറോൾമെന്റുകളും നീക്കംചെയ്യും',
      'reset_item_topics': 'പൂർത്തിയാക്കിയ എല്ലാ വിഷയങ്ങളും അപൂർണ്ണമായി അടയാളപ്പെടുത്തും',
      'reset_item_xp': 'നിങ്ങളുടെ XP-യും ലീഡർബോർഡ് റാങ്കും വളരെ കുറയും',
      'reset_item_badges': 'സ്റ്റഡി, സ്ട്രീക്ക് ബാഡ്ജുകൾ നീക്കംചെയ്യും',
      'reset_success': 'ലേണിംഗ് പ്രോഗ്രസ് റീസെറ്റ് ചെയ്തു',
```

- [ ] **Step 3: Add the menu item and reset flow**

In `frontend/lib/features/study_topics/presentation/pages/study_topics_screen.dart`, add these imports near the existing ones:

```dart
import '../../../../core/widgets/destructive_confirm_dialog.dart';
import '../bloc/learning_paths_bloc.dart';
import '../bloc/learning_paths_event.dart';
import '../bloc/learning_paths_state.dart';
```

Some of these may already be imported — do not duplicate them.

In `StudyTopicsAppBar.build`, extend the `PopupMenuButton`'s `onSelected` (currently at line 649):

```dart
            onSelected: (value) {
              if (value == 'language') {
                _showLanguageSelector(context, onLanguageChange);
              } else if (value == 'study_mode') {
                _showStudyModeSelector(context);
              } else if (value == 'reset_progress') {
                _handleResetProgress(context);
              }
            },
```

and add a third `PopupMenuItem` after the `study_mode` item (line 677), separated so the destructive action reads as distinct:

```dart
              PopupMenuItem<String>(
                value: 'reset_progress',
                child: Row(
                  children: [
                    Icon(
                      Icons.restart_alt,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.tr(TranslationKeys.studyTopicsResetProgress),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
```

Add this method to the `StudyTopicsAppBar` class:

```dart
  /// Confirms and then dispatches a full learning-progress reset.
  Future<void> _handleResetProgress(BuildContext context) async {
    final bloc = context.read<LearningPathsBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final successMessage =
        context.tr(TranslationKeys.studyTopicsResetSuccess);

    final confirmed = await DestructiveConfirmDialog.show(
      context,
      title: context.tr(TranslationKeys.studyTopicsResetProgressTitle),
      consequences: [
        context.tr(TranslationKeys.studyTopicsResetItemPaths),
        context.tr(TranslationKeys.studyTopicsResetItemTopics),
        context.tr(TranslationKeys.studyTopicsResetItemXp),
        context.tr(TranslationKeys.studyTopicsResetItemBadges),
      ],
      confirmWord: context.tr(TranslationKeys.resetProgressConfirmWord),
      confirmLabel: context.tr(TranslationKeys.studyTopicsResetProgress),
    );

    if (!confirmed) return;

    // Wait for the bloc to settle so the snackbar reflects the real outcome.
    final completion = bloc.stream.firstWhere(
      (state) =>
          state is LearningPathsResetSuccess || state is LearningPathsError,
    );

    bloc.add(const ResetLearningProgressRequested());

    final outcome = await completion;

    if (outcome is LearningPathsResetSuccess) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      // Progress is gone — reload paths, leaderboard, and continue-learning.
      bloc.add(const LoadLearningPaths(forceRefresh: true));
    } else if (outcome is LearningPathsError) {
      messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
    }
  }
```

- [ ] **Step 4: Refresh the sibling BLoCs**

XP, rank, badges, and the continue-learning card are all derived from the data just deleted, so they must be refetched.

Add these imports to `study_topics_screen.dart`:

```dart
import '../../../gamification/presentation/bloc/gamification_bloc.dart';
import '../../../gamification/presentation/bloc/gamification_event.dart';
import '../bloc/continue_learning_bloc.dart';
import '../bloc/continue_learning_event.dart';
import '../bloc/leaderboard_bloc.dart';
import '../bloc/leaderboard_event.dart';
```

In `_handleResetProgress`, capture the sibling BLoCs **before** the first `await`, so no `BuildContext` is used across an async gap, and dispatch their refresh events in the success branch. The full method becomes:

```dart
  /// Confirms and then dispatches a full learning-progress reset.
  Future<void> _handleResetProgress(BuildContext context) async {
    final bloc = context.read<LearningPathsBloc>();
    final leaderboardBloc = context.read<LeaderboardBloc>();
    final continueLearningBloc = context.read<ContinueLearningBloc>();
    final gamificationBloc = context.read<GamificationBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final successMessage =
        context.tr(TranslationKeys.studyTopicsResetSuccess);

    final confirmed = await DestructiveConfirmDialog.show(
      context,
      title: context.tr(TranslationKeys.studyTopicsResetProgressTitle),
      consequences: [
        context.tr(TranslationKeys.studyTopicsResetItemPaths),
        context.tr(TranslationKeys.studyTopicsResetItemTopics),
        context.tr(TranslationKeys.studyTopicsResetItemXp),
        context.tr(TranslationKeys.studyTopicsResetItemBadges),
      ],
      confirmWord: context.tr(TranslationKeys.resetProgressConfirmWord),
      confirmLabel: context.tr(TranslationKeys.studyTopicsResetProgress),
    );

    if (!confirmed) return;

    // Wait for the bloc to settle so the snackbar reflects the real outcome.
    final completion = bloc.stream.firstWhere(
      (state) =>
          state is LearningPathsResetSuccess || state is LearningPathsError,
    );

    bloc.add(const ResetLearningProgressRequested());

    final outcome = await completion;

    if (outcome is LearningPathsResetSuccess) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));

      // Everything derived from the deleted rows must be refetched:
      // the path list, XP/rank, the continue-learning card, and badges.
      bloc.add(const LoadLearningPaths(forceRefresh: true));
      leaderboardBloc.add(const RefreshLeaderboard());
      continueLearningBloc.add(const RefreshContinueLearning());
      gamificationBloc.add(const RefreshGamificationStats());
    } else if (outcome is LearningPathsError) {
      messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
    }
  }
```

Two things to verify against the real code before moving on, since `StudyTopicsAppBar` sits inside whatever providers wrap the screen:

```bash
cd frontend && sed -n '12,50p' lib/features/study_topics/presentation/bloc/continue_learning_event.dart
cd frontend && sed -n '12,25p' lib/features/study_topics/presentation/bloc/leaderboard_event.dart
cd frontend && sed -n '24,30p' lib/features/gamification/presentation/bloc/gamification_event.dart
```

1. If any of these events take required parameters, pass them — use the same arguments the screen already uses for its initial load of that bloc.
2. If `flutter analyze` or a runtime `ProviderNotFoundException` shows that `LeaderboardBloc` or `ContinueLearningBloc` is not provided above `StudyTopicsAppBar`, drop that one line rather than adding a provider, and say so in the commit message. `GamificationBloc` is provided app-wide in `main.dart`, so it is always available.

- [ ] **Step 5: Verify it analyzes and the suite is green**

Run:

```bash
cd frontend && dart format lib/features/study_topics/ lib/core/i18n/ && flutter analyze lib/features/study_topics/ lib/core/i18n/ && flutter test test/features/study_topics/
```

Expected: `No issues found!` then `All tests passed!`

- [ ] **Step 6: USER ACTION — verify in the running app**

Ask the user to run:

```bash
cd frontend && sh scripts/run-web-local.sh
```

Then: open Study Topics → 3-dot menu → **Reset Progress**. Confirm that the confirm button is disabled until `RESET` is typed, that cancelling changes nothing, and that confirming empties enrollments, drops XP to zero, and shows the success snackbar.

- [ ] **Step 7: Stage (do NOT commit)**

```bash
git add frontend/lib/features/study_topics/ frontend/lib/core/i18n/
# NO COMMIT. Staged only — the controller commits once at the end.
# Intended message when it is committed: feat(frontend): add reset progress action to study topics screen
```

---

### Task 9: Memory verses data layer

**Files:**
- Modify: `frontend/lib/features/memory_verses/data/datasources/memory_verse_remote_datasource.dart`
- Modify: `frontend/lib/features/memory_verses/data/datasources/memory_verse_local_datasource.dart`
- Modify: `frontend/lib/features/memory_verses/data/repositories/memory_verse_repository_impl.dart`
- Modify: `frontend/lib/features/memory_verses/domain/repositories/memory_verse_repository.dart`
- Create: `frontend/lib/features/memory_verses/domain/usecases/reset_memory_progress.dart`
- Modify: `frontend/lib/core/di/injection_container.dart` (near line 578)
- Test: `frontend/test/features/memory_verses/domain/usecases/reset_memory_progress_test.dart`

**Interfaces:**
- Consumes: `ResetProgressResult` (Task 4), `POST /functions/v1/reset-progress` (Task 3).
- Produces:
  - `MemoryVerseRemoteDataSource.resetMemoryProgress() → Future<ResetProgressResult>`
  - `MemoryVerseRepository.resetMemoryProgress() → Future<Either<Failure, ResetProgressResult>>`
  - `ResetMemoryProgress` use case, callable as `await useCase()`
  - GetIt registration `sl<ResetMemoryProgress>()`

- [ ] **Step 1: Write the failing use case test**

Create `frontend/test/features/memory_verses/domain/usecases/reset_memory_progress_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/repositories/memory_verse_repository.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/reset_memory_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'reset_memory_progress_test.mocks.dart';

@GenerateMocks([MemoryVerseRepository])
void main() {
  late MockMemoryVerseRepository repository;
  late ResetMemoryProgress useCase;

  setUp(() {
    repository = MockMemoryVerseRepository();
    useCase = ResetMemoryProgress(repository);
  });

  const result = ResetProgressResult(
    scope: 'memory_verses',
    counts: {'verses_deleted': 42},
  );

  test('returns the repository result on success', () async {
    when(repository.resetMemoryProgress())
        .thenAnswer((_) async => const Right(result));

    final actual = await useCase();

    expect(actual, const Right<Failure, ResetProgressResult>(result));
    verify(repository.resetMemoryProgress()).called(1);
  });

  test('propagates the failure on error', () async {
    const failure = NetworkFailure(message: 'offline', code: 'NETWORK_ERROR');
    when(repository.resetMemoryProgress())
        .thenAnswer((_) async => const Left(failure));

    final actual = await useCase();

    expect(actual, const Left<Failure, ResetProgressResult>(failure));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd frontend && flutter test test/features/memory_verses/domain/usecases/reset_memory_progress_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: '.../reset_memory_progress.dart'`.

- [ ] **Step 3: Add the datasource method**

In `frontend/lib/features/memory_verses/data/datasources/memory_verse_remote_datasource.dart`, add the import:

```dart
import '../../../../core/models/reset_progress_result.dart';
```

add the endpoint constant next to the others (after `_getSuggestedVersesEndpoint`):

```dart
  // Progress reset endpoint
  static const String _resetProgressEndpoint = '/functions/v1/reset-progress';
```

and add the method to the class, next to `deleteVerse`:

```dart
  /// Deletes the user's entire memory verse deck and all derived progress.
  ///
  /// Irreversible. Also clears collections, daily goals, unlocked modes,
  /// memory challenge progress, memory badges, and the memory streak.
  Future<ResetProgressResult> resetMemoryProgress() async {
    try {
      _errorHandler.logDebug('Resetting all memory verse progress');

      final url = '$_baseUrl$_resetProgressEndpoint';
      final headers = await _httpService.createHeaders();
      final response = await _httpService.post(
        url,
        headers: headers,
        body: jsonEncode({'scope': 'memory_verses'}),
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode >= 400) {
        _errorHandler.handleErrorResponse(response);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw const ServerException(
          message: 'Malformed reset response',
          code: 'RESET_PROGRESS_PARSE_ERROR',
        );
      }

      _errorHandler.logSuccess('Memory progress reset');
      return ResetProgressResult.fromJson(data);
    } catch (e) {
      _errorHandler.handleException(e, 'resetting memory progress');
    }
  }
```

If `handleException` has return type `Never`, no trailing `throw` is needed. If `flutter analyze` reports `body_might_complete_normally`, add `rethrow;` as the final statement of the `catch` block.

**Preserve the exception type — this is where the equivalent learning-paths code had a Critical bug.** The repository's `mapExceptionToFailure` can only produce `RateLimitFailure` / `AuthenticationFailure` / `NetworkFailure` if a typed exception actually reaches it. Before writing this method, read `frontend/lib/core/error/api_error_handler.dart` and establish what `handleErrorResponse` and `handleException` actually throw:

- If `handleErrorResponse` does not throw `RateLimitException` for HTTP 429 and `AuthenticationException` for 401, branch on the status code yourself before calling it, so those two cases throw the right type.
- If `handleException` rewraps everything into a generic `ServerException`, add `on AppException { rethrow; }` (from `core/error/exceptions.dart`, the base class of all of them) *before* the generic catch, so an already-typed exception passes through untouched.

Verify the result rather than assuming: a 429 from the endpoint must reach the use case as `Left(RateLimitFailure)`, a 401 as `Left(AuthenticationFailure)`, and an offline failure as `Left(NetworkFailure)`. If all three arrive as `ServerFailure`, the mapper is dead code and the error-handling table in the spec is unimplemented.

- [ ] **Step 4: Add a local cache-clearing method**

In `frontend/lib/features/memory_verses/data/datasources/memory_verse_local_datasource.dart`, check whether a method that wipes the `memory_verses_cache` box already exists:

```bash
cd frontend && grep -n "clear\|deleteBoxFromDisk" lib/features/memory_verses/data/datasources/memory_verse_local_datasource.dart
```

If a full-clear method already exists, reuse it in Step 5 and skip the rest of this step. Otherwise add:

```dart
  /// Removes every cached verse. Used after a full progress reset.
  Future<void> clearAll() async {
    final box = await _openBox();
    await box.clear();
  }
```

matching the file's existing box-access helper name (it lazily assigns `_cacheBox` via `Hive.openBox<String>(_boxName)`) rather than introducing a new one.

- [ ] **Step 5: Add the repository interface method and implementation**

In `frontend/lib/features/memory_verses/domain/repositories/memory_verse_repository.dart`, add the import:

```dart
import '../../../../core/models/reset_progress_result.dart';
```

and add after `deleteVerse` (line 98):

```dart
  /// Deletes the user's entire memory verse deck and all derived progress.
  ///
  /// Irreversible. Clears collections, daily goals, unlocked modes, memory
  /// challenge progress, memory badges, and the memory streak, then empties
  /// the local cache.
  Future<Either<Failure, ResetProgressResult>> resetMemoryProgress();
```

In `frontend/lib/features/memory_verses/data/repositories/memory_verse_repository_impl.dart`, add the import and the implementation. Match the file's existing error-mapping helper if it has one:

```dart
  @override
  Future<Either<Failure, ResetProgressResult>> resetMemoryProgress() async {
    try {
      final result = await remoteDataSource.resetMemoryProgress();

      // Only clear local state after the server confirms — a failed reset
      // must leave the cached deck intact.
      await localDataSource.clearAll();
      await VerseCacheService().clearCache();

      return Right(result);
    } catch (e) {
      return Left(mapExceptionToFailure(
        e,
        fallbackMessage: 'Failed to reset memory progress',
        fallbackCode: 'RESET_PROGRESS_ERROR',
      ));
    }
  }
```

`mapExceptionToFailure` comes from the shared mapper created in Task 6 Step 5. Import it:

```dart
import '../../../../core/error/exception_failure_mapper.dart';
```

Note the ordering that matters here: the local cache is cleared **only after** `remoteDataSource.resetMemoryProgress()` returns. If the server call throws, the `catch` runs before any cache clearing, so a failed reset leaves the cached deck intact.

Before writing this, confirm the impl's real field names and the `VerseCacheService` clear-method name:

```bash
cd frontend && grep -n "remoteDataSource\|localDataSource\|final " lib/features/memory_verses/data/repositories/memory_verse_repository_impl.dart | head -20
cd frontend && grep -n "Future<void> clear\|void clear" lib/features/memory_verses/data/services/verse_cache_service.dart
```

Use the names that grep reports. If `VerseCacheService` is injected into the repository rather than constructed, use the injected instance. Leave `suggested_verses_cache` alone — it holds global suggestions, not user progress.

- [ ] **Step 6: Write the use case**

Create `frontend/lib/features/memory_verses/domain/usecases/reset_memory_progress.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/reset_progress_result.dart';
import '../repositories/memory_verse_repository.dart';

/// Use case for deleting the user's entire memory verse deck.
///
/// This is irreversible. It removes every verse along with all review
/// sessions, review history, mastery, practice-mode stats, collections,
/// daily goals, unlocked modes, memory challenge progress, memory badges,
/// and the memory streak. The local cache is emptied only after the server
/// confirms the delete.
///
/// **Usage:**
/// ```dart
/// final result = await sl<ResetMemoryProgress>()();
///
/// result.fold(
///   (failure) => showError(failure.message),
///   (counts) => showSuccess(counts.counts['verses_deleted'] ?? 0),
/// );
/// ```
class ResetMemoryProgress {
  final MemoryVerseRepository repository;

  ResetMemoryProgress(this.repository);

  /// Executes the reset.
  ///
  /// **Returns:**
  /// - `Right(ResetProgressResult)` with the row counts that were removed
  /// - `Left(NetworkFailure)` if offline — nothing is deleted locally
  /// - `Left(RateLimitFailure)` if the hourly reset limit is hit
  /// - `Left(AuthenticationFailure)` if the session is invalid or a guest
  /// - `Left(ServerFailure)` on any other backend error
  Future<Either<Failure, ResetProgressResult>> call() =>
      repository.resetMemoryProgress();
}
```

- [ ] **Step 7: Register in the DI container**

In `frontend/lib/core/di/injection_container.dart`, next to `sl.registerLazySingleton(() => DeleteVerse(sl()));` (line 578), add:

```dart
  sl.registerLazySingleton(() => ResetMemoryProgress(sl()));
```

and add the import with the other memory verse use case imports:

```dart
import '../../features/memory_verses/domain/usecases/reset_memory_progress.dart';
```

- [ ] **Step 8: Generate mocks and run the test**

Run:

```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/memory_verses/domain/usecases/reset_memory_progress_test.dart
```

Expected: PASS — `All tests passed!` (2 tests).

- [ ] **Step 9: Analyze**

Run:

```bash
cd frontend && dart format lib/features/memory_verses/ lib/core/di/injection_container.dart && flutter analyze lib/features/memory_verses/ lib/core/di/injection_container.dart
```

Expected: `No issues found!`

- [ ] **Step 10: Stage (do NOT commit)**

```bash
git add frontend/lib/features/memory_verses/ frontend/lib/core/di/injection_container.dart frontend/test/features/memory_verses/
# NO COMMIT. Staged only — the controller commits once at the end.
# Intended message when it is committed: feat(frontend): add reset memory progress data layer and use case
```

---

### Task 10: Memory verses BLoC wiring

**Files:**
- Modify: `frontend/lib/features/memory_verses/presentation/bloc/memory_verse_event.dart`
- Modify: `frontend/lib/features/memory_verses/presentation/bloc/memory_verse_state.dart`
- Modify: `frontend/lib/features/memory_verses/presentation/bloc/memory_verse_bloc.dart`
- Modify: `frontend/lib/core/di/injection_container.dart` (the `MemoryVerseBloc` registration)
- Test: `frontend/test/features/memory_verses/presentation/bloc/memory_verse_reset_test.dart`

**Interfaces:**
- Consumes: `ResetMemoryProgress` (Task 9), `ResetProgressResult` (Task 4).
- Produces: `ResetMemoryProgressRequested` event; `MemoryProgressResetting` and `MemoryProgressResetSuccess(result)` states. Task 11's UI listens for these.

- [ ] **Step 1: Add the event**

In `frontend/lib/features/memory_verses/presentation/bloc/memory_verse_event.dart`, append before the end of the file:

```dart
/// Delete the user's entire memory verse deck and all derived progress.
///
/// Irreversible. The UI must confirm with the user before dispatching this.
class ResetMemoryProgressRequested extends MemoryVerseEvent {
  const ResetMemoryProgressRequested();
}
```

- [ ] **Step 2: Add the states**

In `frontend/lib/features/memory_verses/presentation/bloc/memory_verse_state.dart`, add the import:

```dart
import '../../../../core/models/reset_progress_result.dart';
```

and append before the end of the file:

```dart
/// The reset request is in flight.
class MemoryProgressResetting extends MemoryVerseState {
  const MemoryProgressResetting();
}

/// The reset completed. [result] holds the row counts that were removed.
class MemoryProgressResetSuccess extends MemoryVerseState {
  /// Counts of what was deleted.
  final ResetProgressResult result;

  const MemoryProgressResetSuccess({required this.result});

  @override
  List<Object?> get props => [result];
}
```

Check the existing state base class first — if `MemoryVerseState` subclasses in this file are not `const`-constructible or use a different props convention, match what is already there:

```bash
cd frontend && head -40 lib/features/memory_verses/presentation/bloc/memory_verse_state.dart
```

- [ ] **Step 3: Write the failing bloc test**

`MemoryVerseBloc` takes 26 required constructor arguments (`memory_verse_bloc.dart:98-129`), so the test mocks all of them and swaps in a real `ResetMemoryProgress` over a mock repository — that is the only dependency this test actually exercises.

Create `frontend/test/features/memory_verses/presentation/bloc/memory_verse_reset_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:disciplefy_bible_study/core/connectivity/connectivity_bloc.dart';
import 'package:disciplefy_bible_study/core/error/failures.dart';
import 'package:disciplefy_bible_study/core/models/reset_progress_result.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/services/memory_verse_notification_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/data/services/suggested_verses_cache_service.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/repositories/memory_verse_repository.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/add_verse_from_daily.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/add_verse_manually.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/claim_challenge_reward.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/delete_verse.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/fetch_verse_text.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_active_challenges.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_cached_due_verses.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_daily_goal.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_due_verses.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_mastery_progress.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_memory_champions_leaderboard.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_memory_statistics.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_memory_streak.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_practice_mode_statistics.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_statistics.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/get_suggested_verses.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/reset_memory_progress.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/select_practice_mode.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/set_daily_goal_targets.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/submit_practice_session.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/submit_review.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/update_daily_goal_progress.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/update_mastery_level.dart';
import 'package:disciplefy_bible_study/features/memory_verses/domain/usecases/use_streak_freeze.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_bloc.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_event.dart';
import 'package:disciplefy_bible_study/features/memory_verses/presentation/bloc/memory_verse_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'memory_verse_reset_test.mocks.dart';

/// ConnectivityBloc is listened to in MemoryVerseBloc's constructor, so it
/// needs a real stream. MockBloc from bloc_test provides one.
class MockConnectivityBloc
    extends MockBloc<ConnectivityEvent, ConnectivityState>
    implements ConnectivityBloc {}

@GenerateNiceMocks([
  MockSpec<MemoryVerseRepository>(),
  MockSpec<GetDueVerses>(),
  MockSpec<GetCachedDueVerses>(),
  MockSpec<AddVerseFromDaily>(),
  MockSpec<AddVerseManually>(),
  MockSpec<SubmitReview>(),
  MockSpec<GetStatistics>(),
  MockSpec<FetchVerseText>(),
  MockSpec<DeleteVerse>(),
  MockSpec<SelectPracticeMode>(),
  MockSpec<SubmitPracticeSession>(),
  MockSpec<GetPracticeModeStatistics>(),
  MockSpec<GetMemoryStreak>(),
  MockSpec<UseStreakFreeze>(),
  MockSpec<GetMasteryProgress>(),
  MockSpec<UpdateMasteryLevel>(),
  MockSpec<GetDailyGoal>(),
  MockSpec<UpdateDailyGoalProgress>(),
  MockSpec<SetDailyGoalTargets>(),
  MockSpec<GetActiveChallenges>(),
  MockSpec<ClaimChallengeReward>(),
  MockSpec<GetMemoryChampionsLeaderboard>(),
  MockSpec<GetMemoryStatistics>(),
  MockSpec<GetSuggestedVerses>(),
  MockSpec<MemoryVerseNotificationService>(),
  MockSpec<SuggestedVersesCacheService>(),
])
void main() {
  late MockMemoryVerseRepository repository;
  late MockConnectivityBloc connectivityBloc;

  setUp(() {
    repository = MockMemoryVerseRepository();
    connectivityBloc = MockConnectivityBloc();
    whenListen(
      connectivityBloc,
      const Stream<ConnectivityState>.empty(),
      initialState: ConnectivityInitial(),
    );
  });

  const resetResult = ResetProgressResult(
    scope: 'memory_verses',
    counts: {'verses_deleted': 42},
  );

  /// Builds the bloc with nice mocks everywhere except the reset use case,
  /// which is real so the repository call is actually exercised.
  MemoryVerseBloc buildBloc() => MemoryVerseBloc(
        getDueVerses: MockGetDueVerses(),
        getCachedDueVerses: MockGetCachedDueVerses(),
        addVerseFromDaily: MockAddVerseFromDaily(),
        addVerseManually: MockAddVerseManually(),
        submitReview: MockSubmitReview(),
        getStatistics: MockGetStatistics(),
        fetchVerseText: MockFetchVerseText(),
        deleteVerse: MockDeleteVerse(),
        selectPracticeMode: MockSelectPracticeMode(),
        submitPracticeSession: MockSubmitPracticeSession(),
        getPracticeModeStatistics: MockGetPracticeModeStatistics(),
        getMemoryStreak: MockGetMemoryStreak(),
        useStreakFreeze: MockUseStreakFreeze(),
        getMasteryProgress: MockGetMasteryProgress(),
        updateMasteryLevel: MockUpdateMasteryLevel(),
        getDailyGoal: MockGetDailyGoal(),
        updateDailyGoalProgress: MockUpdateDailyGoalProgress(),
        setDailyGoalTargets: MockSetDailyGoalTargets(),
        getActiveChallenges: MockGetActiveChallenges(),
        claimChallengeReward: MockClaimChallengeReward(),
        getMemoryChampionsLeaderboard: MockGetMemoryChampionsLeaderboard(),
        getMemoryStatistics: MockGetMemoryStatistics(),
        getSuggestedVerses: MockGetSuggestedVerses(),
        notificationService: MockMemoryVerseNotificationService(),
        suggestedVersesCacheService: MockSuggestedVersesCacheService(),
        connectivityBloc: connectivityBloc,
        resetMemoryProgress: ResetMemoryProgress(repository),
      );

  blocTest<MemoryVerseBloc, MemoryVerseState>(
    'emits [Resetting, ResetSuccess] when the reset succeeds',
    build: () {
      when(repository.resetMemoryProgress())
          .thenAnswer((_) async => const Right(resetResult));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const ResetMemoryProgressRequested()),
    expect: () => [
      const MemoryProgressResetting(),
      const MemoryProgressResetSuccess(result: resetResult),
    ],
    verify: (_) {
      verify(repository.resetMemoryProgress()).called(1);
    },
  );

  blocTest<MemoryVerseBloc, MemoryVerseState>(
    'emits [Resetting, Error] when the reset fails',
    build: () {
      when(repository.resetMemoryProgress()).thenAnswer(
        (_) async => const Left(
          NetworkFailure(message: 'offline', code: 'NETWORK_ERROR'),
        ),
      );
      return buildBloc();
    },
    act: (bloc) => bloc.add(const ResetMemoryProgressRequested()),
    expect: () => [
      const MemoryProgressResetting(),
      isA<MemoryVerseError>(),
    ],
  );
}
```

Two things this test asserts that must match the real code, both confirmed against `memory_verse_bloc.dart:98-129` and `memory_verse_state.dart:263`: the constructor parameter names above, and the error state class `MemoryVerseError`. If `dart run build_runner build` reports a use case class name that does not exist at the imported path, correct the import and the `MockSpec` to the real name — several use cases are imported with `as` aliases in the bloc (`add_from_daily_uc`, `add_manually_uc`, `submit_review_uc`, `delete_verse_uc`) because their class names collide with event names, and the aliased class names are `AddVerseFromDaily`, `AddVerseManually`, `SubmitReview`, and `DeleteVerse` respectively.

- [ ] **Step 4: Run the test to verify it fails**

Run:

```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/memory_verses/presentation/bloc/memory_verse_reset_test.dart
```

Expected: FAIL — no `resetMemoryProgress` named parameter on `MemoryVerseBloc`.

- [ ] **Step 5: Wire the handler into the BLoC**

In `frontend/lib/features/memory_verses/presentation/bloc/memory_verse_bloc.dart`, add the import:

```dart
import '../../domain/usecases/reset_memory_progress.dart';
```

add the field alongside `deleteVerse`:

```dart
  final ResetMemoryProgress resetMemoryProgress;
```

add `required this.resetMemoryProgress,` to the constructor parameter list, register the handler alongside the other `on<...>` calls:

```dart
    on<ResetMemoryProgressRequested>(_onResetMemoryProgress);
```

and add the handler to the class body. Use the file's existing error state name in place of `MemoryVerseError`:

```dart
  Future<void> _onResetMemoryProgress(
    ResetMemoryProgressRequested event,
    Emitter<MemoryVerseState> emit,
  ) async {
    emit(const MemoryProgressResetting());

    final result = await resetMemoryProgress();

    result.fold(
      (failure) {
        Logger.error('Memory progress reset failed: ${failure.code}');
        emit(MemoryVerseError(message: failure.message));
      },
      (resetResult) => emit(MemoryProgressResetSuccess(result: resetResult)),
    );
  }
```

- [ ] **Step 6: Update the DI registration**

In `frontend/lib/core/di/injection_container.dart`, find the `MemoryVerseBloc` registration and add `resetMemoryProgress: sl(),` to its argument list, matching the surrounding style.

- [ ] **Step 7: Run the test to verify it passes**

Run:

```bash
cd frontend && flutter test test/features/memory_verses/presentation/bloc/memory_verse_reset_test.dart
```

Expected: PASS — `All tests passed!` (2 tests).

- [ ] **Step 8: Run the whole memory verses suite**

`MemoryVerseBloc` gained a required parameter, so existing tests that construct it will fail to compile.

Run:

```bash
cd frontend && flutter test test/features/memory_verses/
```

Expected: PASS. Fix any compile failure by adding `resetMemoryProgress: ResetMemoryProgress(mockRepository)` to that test's constructor call.

- [ ] **Step 9: Stage (do NOT commit)**

```bash
git add frontend/lib/features/memory_verses/ frontend/lib/core/di/injection_container.dart frontend/test/features/memory_verses/
# NO COMMIT. Staged only — the controller commits once at the end.
# Intended message when it is committed: feat(frontend): add reset memory progress bloc handling
```

---

### Task 11: Memory verses reset UI

The Memory Verses page already routes its 3-dot button to `OptionsMenuSheet` via `_showOptionsMenu` (`memory_verses_home_page.dart:1194`), so the reset option is added to that existing sheet rather than to a new menu.

**Files:**
- Modify: `frontend/lib/features/memory_verses/presentation/widgets/options_menu_sheet.dart`
- Modify: `frontend/lib/features/memory_verses/presentation/pages/memory_verses_home_page.dart:1194-1208`
- Modify: `frontend/lib/core/i18n/translation_keys.dart`
- Modify: `frontend/lib/core/i18n/app_translations.dart`

**Interfaces:**
- Consumes: `DestructiveConfirmDialog.show` (Task 5); `ResetMemoryProgressRequested` / `MemoryProgressResetSuccess` (Task 10).
- Produces: user-reachable reset flow on the Memory Verses home page.

- [ ] **Step 1: Add the translation keys**

In `frontend/lib/core/i18n/translation_keys.dart`, add next to the other `optionsMenu*` keys (around line 982):

```dart
  static const optionsMenuResetTitle = 'memory.optionsMenu.resetTitle';
  static const optionsMenuResetSubtitle =
      'memory.optionsMenu.resetSubtitle';
  static const memoryResetTitle = 'memory.reset.title';
  static const memoryResetItemVerses = 'memory.reset.itemVerses';
  static const memoryResetItemProgress = 'memory.reset.itemProgress';
  static const memoryResetItemStreak = 'memory.reset.itemStreak';
  static const memoryResetItemBadges = 'memory.reset.itemBadges';
  static const memoryResetConfirm = 'memory.reset.confirm';
  static const memoryResetSuccess = 'memory.reset.success';
```

- [ ] **Step 2: Add the translation values to all three maps**

In `frontend/lib/core/i18n/app_translations.dart`, extend the existing `'optionsMenu'` block in each map (English at ~line 680, Hindi at ~line 2684, Malayalam at ~line 4705) and add a sibling `'reset'` block inside the same `'memory'` section.

English — add to `'optionsMenu'`:

```dart
        'resetTitle': 'Reset All Verses',
        'resetSubtitle': 'Delete every verse and all progress',
```

English — add as a sibling of `'optionsMenu'`:

```dart
      'reset': {
        'title': 'Delete all memory verses?',
        'itemVerses': 'Every verse in your deck will be deleted',
        'itemProgress': 'All practice history and mastery will be deleted',
        'itemStreak': 'Your memory streak will reset to zero',
        'itemBadges': 'Memory badges and challenge progress will be removed',
        'confirm': 'Delete All',
        'success': 'All memory verses deleted',
      },
```

Hindi — add to `'optionsMenu'`:

```dart
        'resetTitle': 'सभी वचन रीसेट करें',
        'resetSubtitle': 'हर वचन और सारी प्रगति हटाएं',
```

Hindi — sibling block:

```dart
      'reset': {
        'title': 'सभी स्मृति वचन हटाएं?',
        'itemVerses': 'आपके डेक का हर वचन हटा दिया जाएगा',
        'itemProgress': 'सारा अभ्यास इतिहास और महारत हटा दी जाएगी',
        'itemStreak': 'आपकी स्मृति स्ट्रीक शून्य हो जाएगी',
        'itemBadges': 'स्मृति बैज और चैलेंज प्रगति हटा दी जाएगी',
        'confirm': 'सभी हटाएं',
        'success': 'सभी स्मृति वचन हटा दिए गए',
      },
```

Malayalam — add to `'optionsMenu'`:

```dart
        'resetTitle': 'എല്ലാ വചനങ്ങളും റീസെറ്റ് ചെയ്യുക',
        'resetSubtitle': 'എല്ലാ വചനങ്ങളും പ്രോഗ്രസും ഇല്ലാതാക്കുക',
```

Malayalam — sibling block:

```dart
      'reset': {
        'title': 'എല്ലാ മെമ്മറി വചനങ്ങളും ഇല്ലാതാക്കണോ?',
        'itemVerses': 'നിങ്ങളുടെ ഡെക്കിലെ എല്ലാ വചനങ്ങളും ഇല്ലാതാക്കും',
        'itemProgress': 'എല്ലാ പ്രാക്ടീസ് ചരിത്രവും മാസ്റ്ററിയും ഇല്ലാതാക്കും',
        'itemStreak': 'നിങ്ങളുടെ മെമ്മറി സ്ട്രീക്ക് പൂജ്യമാകും',
        'itemBadges': 'മെമ്മറി ബാഡ്ജുകളും ചലഞ്ച് പ്രോഗ്രസും നീക്കംചെയ്യും',
        'confirm': 'എല്ലാം ഇല്ലാതാക്കുക',
        'success': 'എല്ലാ മെമ്മറി വചനങ്ങളും ഇല്ലാതാക്കി',
      },
```

- [ ] **Step 3: Add the reset option to `OptionsMenuSheet`**

Rewrite `frontend/lib/features/memory_verses/presentation/widgets/options_menu_sheet.dart` to take an `onReset` callback:

```dart
import 'package:flutter/material.dart';

import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';

/// Bottom sheet for memory verse options menu.
///
/// Provides options for:
/// - Champions leaderboard
/// - Statistics
/// - Syncing with server
/// - Resetting all verses and progress (destructive)
class OptionsMenuSheet extends StatelessWidget {
  final VoidCallback onSync;
  final VoidCallback onViewStatistics;
  final VoidCallback? onViewChampions;
  final VoidCallback onReset;

  const OptionsMenuSheet({
    super.key,
    required this.onSync,
    required this.onViewStatistics,
    required this.onReset,
    this.onViewChampions,
  });

  /// Shows the options menu bottom sheet.
  static void show(
    BuildContext context, {
    required VoidCallback onSync,
    required VoidCallback onViewStatistics,
    required VoidCallback onReset,
    VoidCallback? onViewChampions,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (bottomSheetContext) => OptionsMenuSheet(
        onSync: () {
          Navigator.pop(bottomSheetContext);
          onSync();
        },
        onViewStatistics: () {
          Navigator.pop(bottomSheetContext);
          onViewStatistics();
        },
        onReset: () {
          Navigator.pop(bottomSheetContext);
          onReset();
        },
        onViewChampions: onViewChampions != null
            ? () {
                Navigator.pop(bottomSheetContext);
                onViewChampions();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Champions
          if (onViewChampions != null)
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title:
                  Text(context.tr(TranslationKeys.optionsMenuChampionsTitle)),
              subtitle: Text(
                  context.tr(TranslationKeys.optionsMenuChampionsSubtitle)),
              onTap: onViewChampions,
            ),
          // Statistics
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: Text(context.tr(TranslationKeys.optionsMenuStatsTitle)),
            subtitle:
                Text(context.tr(TranslationKeys.optionsMenuStatsSubtitle)),
            onTap: onViewStatistics,
          ),
          const Divider(height: 1),
          // Sync
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(context.tr(TranslationKeys.optionsMenuSyncTitle)),
            subtitle: Text(context.tr(TranslationKeys.optionsMenuSyncSubtitle)),
            onTap: onSync,
          ),
          const Divider(height: 1),
          // Reset — destructive, kept visually separate from the rest
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: errorColor),
            title: Text(
              context.tr(TranslationKeys.optionsMenuResetTitle),
              style: TextStyle(color: errorColor),
            ),
            subtitle: Text(context.tr(TranslationKeys.optionsMenuResetSubtitle)),
            onTap: onReset,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Wire the reset flow in the page**

In `frontend/lib/features/memory_verses/presentation/pages/memory_verses_home_page.dart`, add the import:

```dart
import '../../../../core/widgets/destructive_confirm_dialog.dart';
```

Replace `_showOptionsMenu` (line 1194) with:

```dart
  void _showOptionsMenu(BuildContext context) {
    final memoryVerseBloc = context.read<MemoryVerseBloc>();
    OptionsMenuSheet.show(
      context,
      onSync: () => memoryVerseBloc
          .add(SyncWithRemote(language: _selectedLanguageFilter?.code)),
      onViewStatistics: () {
        // Navigate to the new comprehensive statistics page
        context.push('/memory-verses/stats');
      },
      onViewChampions: () {
        context.push('/memory-verses/champions');
      },
      onReset: () => _handleResetProgress(context),
    );
  }

  /// Confirms and then deletes the entire memory verse deck.
  Future<void> _handleResetProgress(BuildContext context) async {
    final bloc = context.read<MemoryVerseBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = context.tr(TranslationKeys.memoryResetSuccess);

    final confirmed = await DestructiveConfirmDialog.show(
      context,
      title: context.tr(TranslationKeys.memoryResetTitle),
      consequences: [
        context.tr(TranslationKeys.memoryResetItemVerses),
        context.tr(TranslationKeys.memoryResetItemProgress),
        context.tr(TranslationKeys.memoryResetItemStreak),
        context.tr(TranslationKeys.memoryResetItemBadges),
      ],
      confirmWord: context.tr(TranslationKeys.resetProgressConfirmWord),
      confirmLabel: context.tr(TranslationKeys.memoryResetConfirm),
    );

    if (!confirmed) return;

    final completion = bloc.stream.firstWhere(
      (state) =>
          state is MemoryProgressResetSuccess || state is MemoryVerseError,
    );

    bloc.add(const ResetMemoryProgressRequested());

    final outcome = await completion;

    if (outcome is MemoryProgressResetSuccess) {
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      // Deck is empty now — reload into the empty state.
      bloc.add(const LoadDueVerses());
    } else if (outcome is MemoryVerseError) {
      messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
    }
  }
```

**Guard the await against the bloc closing.** `stream.firstWhere(...)` with no `orElse` throws an uncaught `StateError` if the stream ends before a match — which happens if the user navigates away while the ~30s reset round-trip is still outstanding and the page's `dispose()` closes the bloc. Add an `orElse` returning a sentinel (or wrap the await in a `try`/`catch` on `StateError`) and simply return without showing a snackbar in that case. The reset itself still completes server-side; there is just no longer a widget to report it to. The same fix was applied to the learning-paths flow in Task 8.

Replace `MemoryVerseError` with the file's real error state name, and check `LoadDueVerses`'s required parameters before using it:

```bash
cd frontend && sed -n '25,45p' lib/features/memory_verses/presentation/bloc/memory_verse_event.dart
```

If `LoadDueVerses` requires arguments, pass the same ones the page already uses elsewhere for its initial load.

- [ ] **Step 5: Refresh gamification state**

Memory badges and challenge progress are gone, so `GamificationBloc` (provided app-wide in `main.dart`) must refetch.

Add the imports:

```dart
import '../../../gamification/presentation/bloc/gamification_bloc.dart';
import '../../../gamification/presentation/bloc/gamification_event.dart';
```

Capture the bloc before the first `await` so no `BuildContext` crosses an async gap — add this line next to the existing `final bloc = context.read<MemoryVerseBloc>();`:

```dart
    final gamificationBloc = context.read<GamificationBloc>();
```

and add the refresh to the success branch, after the reload:

```dart
      bloc.add(const LoadDueVerses());
      gamificationBloc.add(const RefreshGamificationStats());
```

`RefreshGamificationStats` is declared at `gamification_event.dart:24`. Confirm it takes no required arguments before using the `const` form:

```bash
cd frontend && sed -n '24,30p' lib/features/gamification/presentation/bloc/gamification_event.dart
```

If it does take arguments, pass the same ones `main.dart` or the gamification screen uses for its own refresh.

- [ ] **Step 6: Analyze and run the suite**

Run:

```bash
cd frontend && dart format lib/features/memory_verses/ lib/core/i18n/ && flutter analyze lib/features/memory_verses/ lib/core/i18n/ && flutter test test/features/memory_verses/
```

Expected: `No issues found!` then `All tests passed!`

- [ ] **Step 7: USER ACTION — verify in the running app**

Ask the user to run:

```bash
cd frontend && sh scripts/run-web-local.sh
```

Then: open Memory Verses → 3-dot → **Reset All Verses**. Confirm the dialog lists all four consequences, that the confirm button needs the typed word, that cancelling changes nothing, and that confirming empties the deck, zeroes the streak, and shows the success snackbar. Reload the page to confirm the empty deck is the server state and not just cleared local cache.

- [ ] **Step 8: Full verification pass**

Run:

```bash
cd frontend && flutter analyze && flutter test
```

Expected: `No issues found!` and `All tests passed!`. Report the actual output — do not claim success without it.

- [ ] **Step 9: Stage (do NOT commit)**

```bash
git add frontend/lib/features/memory_verses/ frontend/lib/core/i18n/
# NO COMMIT. Staged only — the controller commits once at the end.
# Intended message when it is committed: feat(frontend): add reset all verses action to memory verses page
```

---

## Deployment (USER ACTION)

After all tasks are complete and verified locally, the user deploys:

```bash
cd backend && supabase db push --project-ref <PROJECT_REF>
cd backend && supabase functions deploy reset-progress --project-ref <PROJECT_REF>
```

Then rebuild and ship the frontend as usual. The frontend reset options are dead until `reset-progress` is deployed, so the backend must go first.
