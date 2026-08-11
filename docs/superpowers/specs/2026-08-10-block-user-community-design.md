# Block User — Community Moderation (Apple Guideline 1.2)

**Date:** 2026-08-10
**Status:** Approved design, ready for implementation plan

## Background

iOS 1.0.2 (build 45599) was rejected under **Guideline 1.2 — Safety: User-Generated Content**. The fellowship feed carries user-generated posts and comments, and Apple requires four precautions. Current state:

| Precaution | Status |
|---|---|
| EULA / terms shown before register or login | Missing (out of scope here) |
| Flag objectionable content | Present — `CommunityRepository.reportContent` |
| **Block abusive users** | **Missing — this spec** |
| Developer acts on reports within 24h | No moderation queue exists |

Apple's wording: blocking "should also notify the developer of the inappropriate content and should remove it from the user's feed instantly."

## Scope

In scope: viewer-level block (data, backend, Flutter UI), and an admin-web moderation queue so reports are actionable.

Out of scope: the EULA/terms gate on signup and login (tracked separately; also required before resubmission), and the App Review screen recording.

## Decisions

1. **Block is global and mutual.** A block applies across every fellowship, not just the one where the abuse occurred, and hides each user from the other in both directions. A reviewer may test in any fellowship, so a per-fellowship block would look broken. Mutual invisibility also denies a harasser continued visibility of their target.
2. **Blocking writes a report row.** Each block inserts a `fellowship_reports` row with `reason: 'user_blocked'`, carrying the offending `content_id` when the block started from a post or comment. This satisfies "notify the developer" and keeps flags and blocks in one moderation queue.
3. **Admin moderation page ships alongside.** Report rows are written today but nothing reads them, so nobody can act within 24h.

## Existing code

- `fellowship_reports`, `fellowship_mutes` — `backend/supabase/migrations/20260308000003_community_management.sql`
- Report path — `community_repository.dart:188` → impl `:574` → datasource `:1377` → `FellowshipFeedBloc` `:378`
- Post list query — `backend/supabase/functions/fellowship-posts/index.ts:71`
- Post overflow menu — `fellowship_post_card.dart:131`
- Strings — `frontend/lib/core/localization/app_localizations.dart` (hand-written map: three locale blocks near lines 386 / 959 / 1535, plus a getter near 2161)
- Admin nav — `admin-web/components/sidebar.tsx`

**Pre-existing bug to fix in passing:** `fellowship_mutes` is documented as "posts/comments filtered in list queries" but is only read by `fellowship-members`. Muted members' posts are still visible to everyone. The block filter will cover mutes on the same code path.

## Data model

New migration, `user_blocks`:

```sql
CREATE TABLE user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_user_block UNIQUE (blocker_id, blocked_id),
  CONSTRAINT chk_no_self_block CHECK (blocker_id <> blocked_id)
);
```

Indexes on `blocker_id` and `blocked_id` — both directions are queried on every feed load.

RLS: a user may `SELECT`, `INSERT`, and `DELETE` only rows where `blocker_id = auth.uid()`. No `UPDATE` policy; unblock is a delete.

Helper `blocked_user_ids(uid UUID) RETURNS SETOF UUID` (STABLE, SECURITY DEFINER) returns the union of both directions. Every list query calls it, so the symmetry rule lives in one place.

## Backend

New Edge Function `fellowship-blocks`, built with `function-factory.ts`:

- `POST` — block. Body: `blocked_user_id`, optional `fellowship_id`, `content_type`, `content_id`, `reason`. Inserts into `user_blocks` and `fellowship_reports` inside a single Postgres RPC so a failed report cannot orphan a block. Re-blocking an already-blocked user is idempotent (returns success, no duplicate report).
- `DELETE` — unblock. Removes the `user_blocks` row. Report rows are retained as moderation history.
- `GET` — list blocked users with display names, for the settings screen. Names resolve through `auth.admin.getUserById`, matching how `fellowship-posts` resolves post authors.

Filtering, applied in `fellowship-posts` (list and detail) and `fellowship-comments` (list): resolve the caller's blocked set once per request, then exclude those authors via `.not('author_user_id', 'in', ...)`. The same set includes muted members for that fellowship.

Comment counts must use the filtered set. Otherwise a post reads "3 comments" and renders one.

## Flutter

Follows the existing report path exactly.

- `CommunityRepository`: `blockUser`, `unblockUser`, `getBlockedUsers` → `community_repository_impl.dart` → `community_remote_datasource.dart`.
- New `BlockedUserEntity` and model.
- `FellowshipFeedBloc`: `BlockUserRequested` event. **On success the bloc strips that author's posts and comments from state immediately**, before any refetch — Apple tests instant removal directly.
- Entry points: post overflow menu (`fellowship_post_card.dart`), comment menu, and member rows in the members tab. Note the existing menu hides Report when `isMentor`; Block must show for any author other than self, mentors included.
- Confirm dialog stating the block is mutual and applies everywhere.
- New `Settings → Blocked Users` screen: list with Unblock, and an empty state.
- All strings added to the three locale blocks and getters in `app_localizations.dart` (en, hi, ml).
- Register the new dependencies in `injection_container.dart`; add the route in `app_router.dart`.

## Admin

New `admin-web/app/(dashboard)/moderation` page, linked from `sidebar.tsx` under System.

Lists pending `fellowship_reports` joined to the offending post or comment text and to both users, showing whether the report came from a flag or a block. Actions: Resolve, Dismiss, Delete content. Filtering, counts, and paging happen in SQL, following the pattern established by the recent admin pages.

## Testing

Backend: a blocked author's posts are absent from the list; filtering holds in both directions; unblock restores visibility; muted members are filtered; comment counts match rendered comments; re-blocking is idempotent.

Flutter: bloc emits state with the author's posts stripped on block success; repository maps network and server failures; blocked-users screen renders list and empty states.

## Constraints

Migrations are applied and tested **locally only**. Production `supabase db push` is run by the user, never by the agent.

## Follow-up (required before resubmission, not in this spec)

- Terms-of-use acceptance on the signup and login screens.
- Screen recording on a physical device showing terms at login, flagging content, and blocking a user. Goes in App Review Information → Notes.
- Remove China mainland from Pricing and Availability, clearing the Guideline 2.1 permit rejection.
