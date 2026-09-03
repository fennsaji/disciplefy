-- ============================================================================
-- Widen Notification Catch-Up Windows (3h → 6h)
-- ============================================================================
-- Raises catch_up_minutes from 180 to 360 in the four SQL notification
-- selectors, matching DEFAULT_CATCH_UP_WINDOW_MINUTES on the TypeScript side
-- (daily verse and recommended topic have always used 6 hours).
--
-- WHY
-- ---
-- Cross-category spacing now defers any user who was pushed within the last
-- hour, so overlapping windows no longer arrive as a burst. The cost is that a
-- deferred category can miss a narrow window entirely: replaying a real
-- production outage (a run at 06:22, then nothing until 10:53) the memory verse
-- reminder was dropped because its 3-hour window closed while it waited its
-- turn. Across randomised outages, delivery fell from 5.45 to 4.83 of 6
-- categories.
--
-- Six hours gives every category enough slack to survive both a dropped cron
-- and being deferred behind another category, without pushing a morning
-- reminder into the evening. The LEAST(..., 1439) clamp still prevents any
-- window from spilling past local midnight, so late-evening reminders (a 20:00
-- streak reminder, an 18:00 overdue alert) simply stop at end of day.
--
-- The 20-hour dedup lookback remains well clear of a 6-hour window, so a user
-- still cannot receive the same category twice in a day.
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
            (target_total_minutes + unp.timezone_offset_minutes + 1440) % 1440
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
            (target_total_minutes + unp.timezone_offset_minutes + 1440) % 1440
            BETWEEN target_local_minutes
            AND LEAST(target_local_minutes + catch_up_minutes - 1, 1439)
        )
        AND dvs.current_streak >= min_streak_worth_saving
        -- Equality, not "older than": current_streak is only reset when the app
        -- is next opened, so a churned user keeps a stale non-zero streak and a
        -- ">" comparison would re-send every day forever.
        AND dvs.last_viewed_at IS NOT NULL
        AND DATE(dvs.last_viewed_at + make_interval(mins => unp.timezone_offset_minutes))
            = DATE(NOW() + make_interval(mins => unp.timezone_offset_minutes)) - 2
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
