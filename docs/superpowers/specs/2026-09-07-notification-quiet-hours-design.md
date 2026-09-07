# Quiet hours for every push notification

**Date:** 2026-09-07 · **Status:** Proposed, awaiting approval
**Rule the product owner set:** a notification arrives when the thing happens, except when that would land in the middle of the recipient's night, in which case it waits until their morning.

## Why

Six senders already deliver in the recipient's local time. Fourteen fire the instant an event happens, in server time, and two more fire at a fixed UTC hour for everyone. Nothing anywhere implements quiet hours. The result is that a member in London gets "Today's study" at 2am, and any post, comment or reaction at 3am local lands immediately.

## The one rule

For every notification that is not already locally scheduled:

- Compute the recipient's local time from `user_notification_preferences.timezone_offset_minutes`.
- **Outside 22:00–07:00 local:** send now, exactly as today.
- **Inside 22:00–07:00 local:** hold, and deliver at 07:00 local.
- **Urgent notifications never wait** (see the table).
- **No offset available:** send now. Never silently drop.

One helper decides this, and one queue holds what is deferred. No per-sender special cases.

## Classification

**Leave alone — already local (6).** `daily_verse` 06:00, `recommended_topic` / `continue_learning` 08:00, `streak_reminder` user-set default 20:00, `streak_lost` 10:00, `memory_verse_reminder` user-set default 09:00, `memory_verse_overdue` 18:00. These self-filter on an hourly cron and their targets already sit outside quiet hours.

**Urgent — never defer (3).** `fellowship_meeting_reminder`, `fellowship_meeting_cancelled`, `fellowship_meeting_invite`. A reminder for a meeting that has started, or a cancellation delivered after the slot, is worse than useless. A meeting genuinely at 6am should still notify.

**Apply quiet hours (12).**

| Type | Trigger today | Change |
|---|---|---|
| `fellowship_daily_post` | rs-backend cron 01:00 UTC | Hold per member until 07:00 local. Post creation time is unchanged. |
| `fellowship_new_post` | member posts | Immediate, unless recipient is in quiet hours |
| `fellowship_new_comment` | member comments | Same |
| `fellowship_reaction` | member reacts | Same |
| `fellowship_discipler_reply` (auto) | reply worker | Same |
| `fellowship_discipler_reply` (approved) | mentor approves | Same |
| `fellowship_discipler_activity` (per event) | reply worker | Same |
| `fellowship_discipler_activity` (digest) | top of each UTC hour | Same; a digest is never urgent |
| `fellowship_meeting` (new meeting) | mentor schedules | Same. An announcement can wait for morning; the reminders above cannot. |
| `streak_lost` (client) | app detects on verse view | Same |
| `streak_milestone` | app detects on verse view | Same |
| `fellowship_daily_post` teaser follow-ups | — | Covered by the row above |

## Work

**1. Migration.** `notification_push_queue(id, user_id, kind, title, body, data jsonb, not_before timestamptz, status pending|sent|failed, attempts, last_error, created_at, sent_at)`, indexed on `(status, not_before)`, cascading on `auth.users`. Also drop `fellowship_notification_queue`, a dead outbox that nothing reads or writes.

**2. Shared helpers**, in `_shared/utils/notification-window.ts` beside the existing window code, unit-tested: `isQuietHours(offsetMinutes, now)` for 22:00–07:00 local, and `nextLocalTimeUtc(offsetMinutes, targetLocalMinutes, now)` returning the next instant the recipient's clock reads the target. Tests must cover negative offsets, the midnight wrap and both edges.

**3. One send path.** Give the shared FCM sender a `deliverOrQueue(db, userIds, notification, data, { urgent })` entry point that looks up each recipient's offset, sends now or queues, and is the only way fellowship, meeting, streak and Discipler code sends a push. Recipients are decided per user, so one call can send to some and queue for others.

**4. Drain.** A `notification-push/flush` style route on an existing function, guarded by the internal API key, sends due rows and retries up to three times. The rs-backend `discipler_reply_worker`, which already ticks every minute, calls it after draining its own queue. No new cron, no new Edge Function.

**5. Fix the offset gaps the survey exposed.** These make quiet hours meaningful rather than theoretical:
- Fellowship, meeting and Discipler senders never read `user_notification_preferences` at all, so they have no offset to reason about. They must join it.
- `timezone_offset_minutes` defaults to `0`, so a user who never set it is treated as UTC and an Indian user would be quiet-houred on London's clock. The app should write the device offset on login and on resume, and the column should be nullable so "unknown" is distinguishable from "UTC" — unknown means send now.
- A user with no preferences row currently receives none of the six scheduled notifications, ever. That is a separate fail-closed bug worth fixing while we are here.

**6. Observability.** Fellowship pushes never call `logNotification`, so they are absent from `notification_logs` and take no part in dedup or the 60-minute spacing rule. Log them, so a deferred push is auditable and the spacing rule applies uniformly.

## Out of scope

Per-fellowship posting time, per-user configurable quiet hours, and a digest that batches a noisy night into one morning summary. All are reasonable follow-ups once the fixed 22:00–07:00 rule is in place.

## Testing

Unit tests for both helpers. Live verification against local Supabase with members whose offsets are set to IST and to a US value: the daily post queues for each at their own 07:00; a due row is sent and marked; a daytime event sends immediately with no queue row; a night-time event queues; a meeting reminder at 3am local still sends.
