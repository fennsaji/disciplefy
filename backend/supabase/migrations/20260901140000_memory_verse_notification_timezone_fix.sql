-- ============================================================================
-- Memory Verse Notifications — Timezone Fix + Overdue Selector
-- ============================================================================
-- Fixes get_memory_verse_reminder_notification_users() and adds the missing
-- get_memory_verse_overdue_notification_users().
--
-- WHY
-- ---
-- The reminder selector had three defects that together meant it almost never
-- fired for anyone:
--
--   1. NO TIMEZONE CONVERSION. It compared the user's LOCAL preference
--      directly against the UTC clock:
--          EXTRACT(HOUR FROM unp.memory_verse_reminder_time) = target_hour
--      So a user asking for 09:00 was only matched when it was 09:00 *UTC* —
--      14:30 local for IST. The timezone_offset_minutes it returned came from
--      EXTRACT(TIMEZONE FROM NOW()), which is the DATABASE server's offset
--      (always 0/UTC), not the user's, so it could not have worked.
--
--   2. EXACT MINUTE MATCH. It also required
--          EXTRACT(MINUTE FROM ...) = target_minute
--      against the real wall-clock minute of the cron run. Scheduled GitHub
--      Actions runs start at an arbitrary minute (they are routinely delayed),
--      so this only matched if a run happened to begin in the exact minute of
--      the user's preference.
--
--   3. DUPLICATE SENDS. No DISTINCT ON (user_id), so a user with two
--      registered devices produced two rows and received the notification
--      twice in the same batch.
--
-- Both selectors now use the same local-time catch-up window as the streak
-- reminder: match once the user's local time has reached their preferred time,
-- and stay eligible for a few hours so a delayed or dropped cron is picked up
-- by a later hourly run. Per-day dedup in the Edge Function prevents repeats.
--
-- The overdue selector never existed at all: the workflow calls
-- send-memory-verse-notification?type=overdue, but the function ignored the
-- query parameter and always ran the reminder path, so memory_verse_overdue
-- notifications were never sent to anyone.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Reminder selector — timezone-correct, catch-up window, deduped by user
-- ============================================================================

CREATE OR REPLACE FUNCTION get_memory_verse_reminder_notification_users(
  target_hour INTEGER,
  target_minute INTEGER
)
RETURNS TABLE (
  user_id UUID,
  fcm_token TEXT,
  timezone_offset_minutes INTEGER,
  platform VARCHAR(20),
  due_verse_count INTEGER,
  overdue_verse_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  -- How long after the user's preferred time the reminder stays deliverable.
  catch_up_minutes CONSTANT INTEGER := 180;
  target_total_minutes INTEGER;
BEGIN
  target_total_minutes := target_hour * 60 + target_minute;

  RETURN QUERY
  SELECT DISTINCT ON (unp.user_id)
    unp.user_id,
    unt.fcm_token,
    unp.timezone_offset_minutes,
    unt.platform,
    (
      SELECT COUNT(*)::INTEGER
      FROM memory_verses mv
      WHERE mv.user_id = unp.user_id
        AND mv.next_review_date <= NOW()
    ) AS due_verse_count,
    (
      SELECT COUNT(*)::INTEGER
      FROM memory_verses mv
      WHERE mv.user_id = unp.user_id
        AND mv.next_review_date < NOW() - INTERVAL '1 day'
    ) AS overdue_verse_count
  FROM user_notification_preferences unp
  INNER JOIN user_notification_tokens unt ON unt.user_id = unp.user_id
  WHERE unp.memory_verse_reminder_enabled = TRUE
    -- Local time is at or past the preferred time, within the catch-up window.
    -- Local minutes = (UTC minutes + timezone offset + 1440) % 1440
    AND (
      (target_total_minutes + unp.timezone_offset_minutes + 1440) % 1440
      BETWEEN
        (EXTRACT(HOUR FROM unp.memory_verse_reminder_time)::INTEGER * 60
          + EXTRACT(MINUTE FROM unp.memory_verse_reminder_time)::INTEGER)
      AND
        LEAST(
          EXTRACT(HOUR FROM unp.memory_verse_reminder_time)::INTEGER * 60
            + EXTRACT(MINUTE FROM unp.memory_verse_reminder_time)::INTEGER
            + catch_up_minutes - 1,
          1439
        )
    )
    AND EXISTS (
      SELECT 1
      FROM memory_verses mv
      WHERE mv.user_id = unp.user_id
        AND mv.next_review_date <= NOW()
    )
  -- For users with multiple devices, prefer the most recently updated token
  ORDER BY unp.user_id, unt.token_updated_at DESC;
END;
$$;

COMMENT ON FUNCTION get_memory_verse_reminder_notification_users IS
  'Returns users eligible for a memory verse review reminder at the given UTC hour/minute. '
  'Matches users whose LOCAL time (UTC + their stored timezone offset) is at or past their '
  'memory_verse_reminder_time and still within a 3-hour catch-up window, and who have verses '
  'due for review. One row per user (most recent device token).';

-- ============================================================================
-- 2. Overdue selector — new
-- ============================================================================
-- Fires at 6 PM local for users whose verses are more than a day past due.
-- Gated on memory_verse_overdue_enabled, which the reminder selector ignores.

CREATE OR REPLACE FUNCTION get_memory_verse_overdue_notification_users(
  target_hour INTEGER,
  target_minute INTEGER
)
RETURNS TABLE (
  user_id UUID,
  fcm_token TEXT,
  timezone_offset_minutes INTEGER,
  platform VARCHAR(20),
  due_verse_count INTEGER,
  overdue_verse_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  -- Overdue alerts target 6 PM local.
  overdue_local_minutes CONSTANT INTEGER := 18 * 60;
  catch_up_minutes CONSTANT INTEGER := 180;
  target_total_minutes INTEGER;
BEGIN
  target_total_minutes := target_hour * 60 + target_minute;

  RETURN QUERY
  SELECT DISTINCT ON (unp.user_id)
    unp.user_id,
    unt.fcm_token,
    unp.timezone_offset_minutes,
    unt.platform,
    (
      SELECT COUNT(*)::INTEGER
      FROM memory_verses mv
      WHERE mv.user_id = unp.user_id
        AND mv.next_review_date <= NOW()
    ) AS due_verse_count,
    (
      SELECT COUNT(*)::INTEGER
      FROM memory_verses mv
      WHERE mv.user_id = unp.user_id
        AND mv.next_review_date < NOW() - INTERVAL '1 day'
    ) AS overdue_verse_count
  FROM user_notification_preferences unp
  INNER JOIN user_notification_tokens unt ON unt.user_id = unp.user_id
  WHERE unp.memory_verse_overdue_enabled = TRUE
    AND (
      (target_total_minutes + unp.timezone_offset_minutes + 1440) % 1440
      BETWEEN overdue_local_minutes
      AND LEAST(overdue_local_minutes + catch_up_minutes - 1, 1439)
    )
    -- Only users who actually have overdue verses (more than a day past due)
    AND EXISTS (
      SELECT 1
      FROM memory_verses mv
      WHERE mv.user_id = unp.user_id
        AND mv.next_review_date < NOW() - INTERVAL '1 day'
    )
  ORDER BY unp.user_id, unt.token_updated_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_memory_verse_overdue_notification_users(INTEGER, INTEGER) TO service_role;

COMMENT ON FUNCTION get_memory_verse_overdue_notification_users IS
  'Returns users eligible for a memory verse OVERDUE alert (6 PM local, 3-hour catch-up window) '
  'who have verses more than a day past their review date. Gated on memory_verse_overdue_enabled. '
  'One row per user (most recent device token).';

COMMIT;
