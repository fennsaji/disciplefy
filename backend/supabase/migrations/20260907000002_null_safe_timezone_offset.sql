-- ============================================================================
-- Null-Safe Timezone Offset in Scheduled Notification Selectors
-- ============================================================================
-- 20260907000001_notification_push_queue.sql made
-- user_notification_preferences.timezone_offset_minutes nullable, so "unknown"
-- can be distinguished from "UTC" for the new quiet-hours logic.
--
-- Regression: the four scheduled-notification selector RPCs below (created in
-- 20260902070000_widen_catch_up_windows.sql) do arithmetic directly on
-- unp.timezone_offset_minutes — e.g.
--   (target_total_minutes + unp.timezone_offset_minutes + 1440) % 1440
-- NULL propagates through that arithmetic, so any user with an unknown offset
-- now matches nothing and silently receives no daily verse, streak, or memory
-- verse notification at all.
--
-- Before the column was made nullable it defaulted to 0, i.e. unknown users
-- were treated as UTC. This migration restores exactly that behaviour inside
-- the RPCs by wrapping every read of unp.timezone_offset_minutes in
-- COALESCE(unp.timezone_offset_minutes, 0), rather than editing the old
-- migration in place. The corresponding TypeScript senders that read the
-- column directly (send-daily-verse-notification, send-recommended-topic-
-- notification) are fixed separately in application code with the same
-- "null means UTC" fallback.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Streak reminder
-- ============================================================================

CREATE OR REPLACE FUNCTION get_streak_reminder_notification_users(
    target_hour INTEGER,
    target_minute INTEGER
)
RETURNS TABLE (
    user_id UUID,
    fcm_token TEXT,
    current_streak INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
    catch_up_minutes CONSTANT INTEGER := 360;
    target_total_minutes INTEGER;
BEGIN
    target_total_minutes := target_hour * 60 + target_minute;

    RETURN QUERY
    SELECT DISTINCT ON (unt.user_id)
        unt.user_id,
        unt.fcm_token,
        COALESCE(dvs.current_streak, 0)::INTEGER AS current_streak
    FROM user_notification_preferences unp
    INNER JOIN user_notification_tokens unt
        ON unt.user_id = unp.user_id
    LEFT JOIN daily_verse_streaks dvs
        ON dvs.user_id = unp.user_id
    WHERE
        unp.streak_reminder_enabled = true
        AND (
            (target_total_minutes + COALESCE(unp.timezone_offset_minutes, 0) + 1440) % 1440
            BETWEEN
                (EXTRACT(HOUR FROM unp.streak_reminder_time)::INTEGER * 60
                  + EXTRACT(MINUTE FROM unp.streak_reminder_time)::INTEGER)
            AND
                LEAST(
                    EXTRACT(HOUR FROM unp.streak_reminder_time)::INTEGER * 60
                      + EXTRACT(MINUTE FROM unp.streak_reminder_time)::INTEGER
                      + catch_up_minutes - 1,
                    1439
                )
        )
        AND (
            dvs.last_viewed_at IS NULL
            OR DATE(dvs.last_viewed_at AT TIME ZONE 'UTC') < CURRENT_DATE
        )
    ORDER BY unt.user_id, unt.token_updated_at DESC;
END;
$$;

-- ============================================================================
-- 2. Streak lost
-- ============================================================================

CREATE OR REPLACE FUNCTION get_streak_lost_notification_users(
    target_hour INTEGER,
    target_minute INTEGER
)
RETURNS TABLE (
    user_id UUID,
    fcm_token TEXT,
    current_streak INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
    target_local_minutes CONSTANT INTEGER := 10 * 60;
    catch_up_minutes CONSTANT INTEGER := 360;
    min_streak_worth_saving CONSTANT INTEGER := 2;
    target_total_minutes INTEGER;
BEGIN
    target_total_minutes := target_hour * 60 + target_minute;

    RETURN QUERY
    SELECT DISTINCT ON (unt.user_id)
        unt.user_id,
        unt.fcm_token,
        dvs.current_streak
    FROM user_notification_preferences unp
    INNER JOIN user_notification_tokens unt
        ON unt.user_id = unp.user_id
    INNER JOIN daily_verse_streaks dvs
        ON dvs.user_id = unp.user_id
    WHERE
        unp.streak_lost_enabled = true
        AND (
            (target_total_minutes + COALESCE(unp.timezone_offset_minutes, 0) + 1440) % 1440
            BETWEEN target_local_minutes
            AND LEAST(target_local_minutes + catch_up_minutes - 1, 1439)
        )
        AND dvs.current_streak >= min_streak_worth_saving
        -- Equality, not "older than": current_streak is only reset when the app
        -- is next opened, so a churned user keeps a stale non-zero streak and a
        -- ">" comparison would re-send every day forever.
        AND dvs.last_viewed_at IS NOT NULL
        AND DATE(dvs.last_viewed_at + make_interval(mins => COALESCE(unp.timezone_offset_minutes, 0)))
            = DATE(NOW() + make_interval(mins => COALESCE(unp.timezone_offset_minutes, 0))) - 2
    ORDER BY unt.user_id, unt.token_updated_at DESC;
END;
$$;

-- ============================================================================
-- 3. Memory verse reminder
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
  catch_up_minutes CONSTANT INTEGER := 360;
  target_total_minutes INTEGER;
BEGIN
  target_total_minutes := target_hour * 60 + target_minute;

  RETURN QUERY
  SELECT DISTINCT ON (unp.user_id)
    unp.user_id,
    unt.fcm_token,
    COALESCE(unp.timezone_offset_minutes, 0) AS timezone_offset_minutes,
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
    AND (
      (target_total_minutes + COALESCE(unp.timezone_offset_minutes, 0) + 1440) % 1440
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
  ORDER BY unp.user_id, unt.token_updated_at DESC;
END;
$$;

-- ============================================================================
-- 4. Memory verse overdue
-- ============================================================================

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
  overdue_local_minutes CONSTANT INTEGER := 18 * 60;
  catch_up_minutes CONSTANT INTEGER := 360;
  target_total_minutes INTEGER;
BEGIN
  target_total_minutes := target_hour * 60 + target_minute;

  RETURN QUERY
  SELECT DISTINCT ON (unp.user_id)
    unp.user_id,
    unt.fcm_token,
    COALESCE(unp.timezone_offset_minutes, 0) AS timezone_offset_minutes,
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
      (target_total_minutes + COALESCE(unp.timezone_offset_minutes, 0) + 1440) % 1440
      BETWEEN overdue_local_minutes
      AND LEAST(overdue_local_minutes + catch_up_minutes - 1, 1439)
    )
    AND EXISTS (
      SELECT 1
      FROM memory_verses mv
      WHERE mv.user_id = unp.user_id
        AND mv.next_review_date < NOW() - INTERVAL '1 day'
    )
  ORDER BY unp.user_id, unt.token_updated_at DESC;
END;
$$;

COMMIT;
