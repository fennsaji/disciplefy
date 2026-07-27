# Reset User Progress — Design

**Date:** 2026-07-25
**Status:** Approved, ready for implementation planning

## Problem

Users have no way to start over. A user who wants to re-run learning paths from scratch, or clear an accumulated memory-verse deck, must delete their whole account.

## Goal

Two independent, user-triggered reset actions:

1. **Reset learning paths progress** — on the Study Topics screen.
2. **Reset memory verses** — on the Memory Verses home page.

Each is global (all paths / all verses), irreversible, and touches only its own feature's data plus the achievements it can re-award.

## Non-Goals

- Per-path reset on the learning path detail page.
- Undo, soft-delete, or a restore window.
- Resetting saved study guides, subscription state, token balance, daily-verse progress, or voice-buddy data.
- Admin-triggered reset of another user's progress.

## Data Contract

Two `SECURITY DEFINER` Postgres functions, each running all of its deletes in one transaction.

### `reset_user_learning_progress(p_user_id UUID) RETURNS JSONB`

| Table | Action |
|---|---|
| `user_learning_path_progress` | DELETE all rows for user |
| `user_topic_progress` | DELETE all rows for user |
| `user_study_streaks` | DELETE row for user |
| `user_achievements` | DELETE rows whose `achievement_id` is in `SELECT id FROM achievements WHERE category IN ('study','streak')` |

XP needs no explicit handling, but it does not fully zero. The leaderboard is derived, not stored — there is no XP ledger to decrement, so no risk of a negative balance. `get_leaderboard` (see `20260415000001_fix_leaderboard_include_achievement_xp.sql:29-36`) computes:

```
COALESCE(SUM(utp.xp_earned), 0) + COALESCE(SUM(a.xp_reward) over ALL user_achievements, 0)
```

The achievement half is **not** filtered by category. So deleting `user_topic_progress` plus the `study`/`streak` achievements removes the topic XP and those badges' XP, but a user who also holds `voice` or `saved` badges keeps that portion of their XP and may stay on the leaderboard.

This is a consequence of the category split: `voice` and `saved` badges are not re-earnable through learning paths, so neither reset may delete them. User-facing copy must therefore say XP and rank will *drop*, never that they reset to zero.

`user_study_streaks` is deleted rather than zeroed; the existing streak logic re-creates the row lazily on the next study activity.

All `streak`-category achievements are study-streak based (`7-day study streak`, `30-day study streak`, `100-day study streak`), so they belong to this reset, not the memory one.

Returns:

```json
{ "paths_reset": 3, "topics_reset": 27, "achievements_reset": 5, "streak_reset": true }
```

### `reset_user_memory_progress(p_user_id UUID) RETURNS JSONB`

| Table | Action |
|---|---|
| `memory_verses` | DELETE all rows for user |
| `memory_verse_collections` | DELETE all rows for user |
| `memory_verse_streaks` | DELETE row for user |
| `memory_daily_goals` | DELETE all rows for user |
| `daily_unlocked_modes` | DELETE all rows for user |
| `user_challenge_progress` | DELETE rows for user (memory challenges) |
| `user_achievements` | DELETE rows whose `achievement_id` is in `SELECT id FROM achievements WHERE category = 'memory'` |

Deleting `memory_verses` cascades to six child tables, all of which declare `memory_verse_id ... REFERENCES memory_verses(id) ON DELETE CASCADE` (verified in `20260119000600_memory_system.sql` at lines 108, 176, 213, 279, 983, 1018):

- `review_sessions`
- `review_history`
- `daily_unlocked_modes`
- `memory_verse_collection_items`
- `memory_practice_modes` (per-user, per-verse, per-mode stats)
- `memory_verse_mastery`

`daily_unlocked_modes` therefore cascades and its explicit `DELETE` in the table above is redundant. It is kept anyway as belt-and-braces: it costs one cheap indexed delete and keeps the function correct if that FK is ever relaxed.

Returns:

```json
{ "verses_deleted": 42, "collections_deleted": 2, "challenges_reset": 4, "achievements_reset": 3, "streak_reset": true }
```

### Deliberately Untouched

- `daily_verse_streaks` — daily-verse feature, not memory.
- `achievements`, `suggested_verses`, `suggested_verse_translations`, `memory_challenges` — global catalog rows, not user data.
- `user_achievements` rows in the `voice` and `saved` categories — neither reset can re-award them.
- `study_guides`, saved guides, subscription, token, and payment state.

### Grants

```sql
GRANT EXECUTE ON FUNCTION reset_user_learning_progress(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION reset_user_memory_progress(UUID) TO service_role;
```

Not granted to `authenticated`. The Edge Function is the only caller, so a leaked anon key cannot invoke a reset.

Both functions set `SET search_path = public` to avoid search-path injection in a `SECURITY DEFINER` context.

## Backend API

New Edge Function: `backend/supabase/functions/reset-progress/index.ts`

```
POST /functions/v1/reset-progress
Body: { "scope": "learning_paths" | "memory_verses" }
```

Built with `createFunction(handler, { requireAuth: true, allowedMethods: ['POST'] })`.

Rules:

- **Scope validation** — strict allowlist of the two literal strings. Anything else returns `VALIDATION_ERROR`. Scope maps to an RPC name through a literal lookup object, never string interpolation into the RPC call.
- **Identity** — `user_id` is read from the validated JWT only, never from the request body. A user cannot reset another user's data.
- **No guest access** — `allowGuestOnJwtFailure` is left at its default `false`. Anonymous sessions get `AUTHENTICATION_ERROR`.
- **Rate limit** — 5 requests/hour per user via the existing `_shared/utils/rate-limiter.ts`. Guards against accidental repeat taps and abuse.
- **Analytics** — log `scope` and the returned counts only. Never log verse text or verse references.

Response:

```json
{ "success": true, "data": { "scope": "memory_verses", "counts": { "verses_deleted": 42 } } }
```

## Frontend

### Shared Widget

`frontend/lib/core/widgets/destructive_confirm_dialog.dart` — reusable typed-confirmation dialog:

- Title and a bulleted list naming exactly what will be deleted.
- A `TextField`; the confirm button stays disabled until the user types the confirm word.
- The confirm word comes from a translation key, not a hardcoded `RESET`, so Hindi and Malayalam users are not forced to type English.
- Confirm button uses the error/destructive color from `AppColors`.

### Learning Paths

- `study_topics/data/datasources/learning_paths_remote_datasource.dart` → `resetLearningProgress()`. POSTs via `_httpService` with `createHeaders()`, following the `delete-memory-verse` call pattern in `memory_verse_remote_datasource.dart:303`.
- `study_topics/domain/repositories/learning_paths_repository.dart` + impl → `Future<Either<Failure, ResetProgressResult>>`.
- New domain entity `ResetProgressResult` holding the returned counts.
- New use case extending `UseCase<ResetProgressResult, NoParams>`.
- On success the impl clears the `learning_paths_cache` Hive box. The `learning_path_downloads` box holds offline study *content*, not progress, and is left alone.
- `LearningPathsBloc` gains a `ResetLearningProgressRequested` event and resetting/success/error states. On success it re-dispatches its load event and triggers a refresh of `LeaderboardBloc`, `ContinueLearningBloc`, and `GamificationBloc` — XP, rank, badges, and streak have all changed.
- UI: new destructive item in the existing `PopupMenuButton` in `StudyTopicsAppBar` (`study_topics_screen.dart:643`).

### Memory Verses

- `memory_verses/data/datasources/memory_verse_remote_datasource.dart` → `resetMemoryProgress()`.
- Repository interface + impl + use case, mirroring the learning-paths shape.
- On success clear the `memory_verses_cache` and `verse_text_cache` Hive boxes. `suggested_verses_cache` holds global suggestions and is left alone.
- `MemoryVerseBloc` gains `ResetMemoryProgressRequested`. On success it reloads into the empty state and refreshes `GamificationBloc`.
- UI: add a `PopupMenuButton` to the AppBar `actions` list in `memory_verses_home_page.dart:211` (that AppBar currently has only `IconButton`s).

### Localization

New keys in en/hi/ml for: both menu labels, both dialog titles, both dialog body bullet lists, the confirm word, and the success and error messages. Follows the existing `memory.*` / feature-scoped key convention in `core/i18n/translation_keys.dart`.

## Error Handling

Because each RPC is a single transaction, there is no partial-reset state — either everything in scope is gone or nothing changed. Both operations are idempotent, so retrying after an ambiguous network timeout is safe.

Failures map to existing `Failure` types:

| Failure | User-facing behavior |
|---|---|
| `NetworkFailure` | "No connection — try again" with a retry affordance |
| `RateLimitFailure` | "Too many reset attempts, try again later" |
| `AuthenticationFailure` | Prompt to sign in |
| `ServerFailure` | Generic error message |

On any failure the local Hive caches are left untouched, so the UI keeps showing accurate pre-reset state rather than a phantom empty list.

## Testing

- **Deno unit test** for `reset-progress` — scope allowlist accepts the two valid values and rejects everything else; guest/unauthenticated requests are rejected; `user_id` is taken from the JWT and a body-supplied `user_id` is ignored. Pattern: `_shared/utils/rate-limiter.test.ts`.
- **`bloc_test`** for both reset events — success path clears the cache and reloads; failure path emits the error state and leaves the cache intact.
- **Widget test** for `DestructiveConfirmDialog` — confirm button is disabled on open, stays disabled on wrong input, enables on the exact confirm word.

## Deployment Notes

The user's standing constraint is that Claude does not run database mutations. The migration and the Edge Function are written and committed here; applying them (`supabase db push`, `supabase functions deploy reset-progress`) is done by the user.
