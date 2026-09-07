-- ============================================================================
-- Notification push queue (quiet hours)
-- ============================================================================
-- WHY THIS EXISTS
-- ---------------
-- Event-driven pushes (a new post, a comment, a reaction, a Discipler reply,
-- a new meeting announcement, a streak event) used to fire the instant the
-- event happened, in server time. A member in London therefore received
-- "Today's study" at 2 AM, and any 3 AM reaction landed immediately.
--
-- The product rule is: send when the event happens, UNLESS that lands inside
-- the recipient's 22:00–07:00 local night, in which case deliver at 07:00
-- their local time. Urgent notifications (meeting reminders, cancellations,
-- invites) are never deferred, and a recipient whose timezone offset is
-- unknown is always sent now — never dropped.
--
-- This table is the hold area for the deferred ones. Rows are written by
-- deliverOrQueue() in _shared/services/discipler-service.ts and drained by
-- POST /fellowship-posts/flush-pushes, which the rs-backend
-- discipler_reply_worker calls every minute.
--
-- It is deliberately a plain outbox with its own copy of the title/body rather
-- than a reference to the source row: by the time 07:00 arrives the source may
-- have been edited or deleted, and re-rendering a stale event is worse than
-- delivering exactly what the sender composed.

CREATE TABLE IF NOT EXISTS public.notification_push_queue (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind         TEXT NOT NULL,
  title        TEXT NOT NULL,
  body         TEXT NOT NULL,
  data         JSONB NOT NULL DEFAULT '{}',
  not_before   TIMESTAMPTZ NOT NULL,
  status       TEXT NOT NULL DEFAULT 'pending'
               CHECK (status IN ('pending', 'sent', 'failed')),
  attempts     INT NOT NULL DEFAULT 0,
  last_error   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at      TIMESTAMPTZ
);

COMMENT ON TABLE public.notification_push_queue IS
  'Quiet-hours hold area: pushes that would have landed in the recipient''s 22:00-07:00 local night, held until 07:00 local (not_before) and drained by fellowship-posts/flush-pushes.';

COMMENT ON COLUMN public.notification_push_queue.not_before IS
  'UTC instant at which the recipient''s local clock reads 07:00.';

-- The flush route's only query: pending rows whose time has come.
CREATE INDEX IF NOT EXISTS idx_notification_push_queue_due
  ON public.notification_push_queue (status, not_before);

ALTER TABLE public.notification_push_queue ENABLE ROW LEVEL SECURITY;

-- Service role only: written by Edge Functions, read by the flush route.
-- No client ever touches this table, so there is no anon/authenticated policy.
DROP POLICY IF EXISTS "notification_push_queue_service_all" ON public.notification_push_queue;
CREATE POLICY "notification_push_queue_service_all"
  ON public.notification_push_queue FOR ALL TO service_role
  USING (true) WITH CHECK (true);

GRANT ALL ON public.notification_push_queue TO service_role;

-- ----------------------------------------------------------------------------
-- Drop the dead outbox it replaces.
-- ----------------------------------------------------------------------------
-- fellowship_notification_queue was created by 20260308000003_community_management
-- as an "outbox pattern; processed by cron (post-MVP)". No function, worker, cron
-- or client has ever written to or read from it — the only references anywhere in
-- the repo are its own DDL and a GRANT. notification_push_queue is the outbox that
-- actually gets drained, so the empty placeholder goes.
DROP TABLE IF EXISTS public.fellowship_notification_queue;

-- ----------------------------------------------------------------------------
-- Make an unknown timezone offset distinguishable from UTC.
-- ----------------------------------------------------------------------------
-- timezone_offset_minutes defaulted to 0, so a user who never reported a device
-- offset looked exactly like a user in London. Quiet hours would then be applied
-- on London's clock to an Indian user — holding a 3:30 AM IST push that is
-- actually 9 AM for them, and sending at their 3:30 AM instead.
--
-- NULL now means "unknown", and unknown means send immediately (never defer,
-- never drop). Existing rows are deliberately NOT backfilled to NULL: a 0 that
-- was genuinely reported by a UTC device is indistinguishable from a defaulted
-- one, and the app rewrites the real offset on the next token registration or
-- preferences save anyway.
ALTER TABLE public.user_notification_preferences
  ALTER COLUMN timezone_offset_minutes DROP DEFAULT;

ALTER TABLE public.user_notification_preferences
  ALTER COLUMN timezone_offset_minutes DROP NOT NULL;

COMMENT ON COLUMN public.user_notification_preferences.timezone_offset_minutes IS
  'Device UTC offset in minutes (IST = 330). NULL means unknown — quiet hours are not applied and the push is sent immediately.';

-- ----------------------------------------------------------------------------
-- Widen notification_logs to cover the fellowship pushes that now log.
-- ----------------------------------------------------------------------------
-- Fellowship, reaction and meeting pushes went out through FCMService directly
-- and never called logNotification, so they were absent from notification_logs
-- entirely: invisible to auditing, and outside the cross-category spacing rule
-- that keeps a user from being hit by four notifications in one minute.
-- deliverOrQueue now logs every push it sends or defers, which means these
-- types must be accepted by the CHECK constraint — logNotification swallows
-- insert errors, so a rejected type would silently log nothing at all.
--
-- Keep in sync with NotificationType in notification-helper-service.ts
-- (enforced by notification-type-constraint.test.ts).
ALTER TABLE notification_logs
  DROP CONSTRAINT IF EXISTS notification_logs_notification_type_check;

ALTER TABLE notification_logs
  ADD CONSTRAINT notification_logs_notification_type_check
  CHECK (notification_type IN (
    'daily_verse',
    'recommended_topic',
    'continue_learning',
    'streak_reminder',
    'streak_milestone',
    'streak_lost',
    'memory_verse_reminder',
    'memory_verse_overdue',
    'achievement_unlocked',
    'meeting_invite',
    'fellowship_daily_post',
    'fellowship_discipler_reply',
    'fellowship_discipler_activity',
    'fellowship_new_post',
    'fellowship_new_comment',
    'fellowship_reaction',
    'fellowship_meeting',
    'fellowship_meeting_reminder',
    'fellowship_meeting_cancelled',
    'fellowship_meeting_invite'
  ));
