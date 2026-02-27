-- ============================================================================
-- Notification Preferences — Missing Columns
-- ============================================================================
-- Adds the 4 preference columns that the frontend entity / backend functions
-- reference but that were absent from the original core schema.
--
-- Adds:
--   • streak_milestone_enabled  — Milestone Achievements toggle
--   • streak_lost_enabled       — Streak Reset Motivation toggle
--   • streak_reminder_time      — User-chosen daily streak reminder time
--   • memory_verse_reminder_time — User-chosen memory verse reminder time
--
-- Also updates get_streak_reminder_notification_users() to honour the per-user
-- streak_reminder_time instead of the previously hardcoded 20:00 window.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Add missing columns to user_notification_preferences
-- ============================================================================

ALTER TABLE user_notification_preferences
  ADD COLUMN IF NOT EXISTS streak_milestone_enabled   BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS streak_lost_enabled        BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS streak_reminder_time       TIME    DEFAULT '20:00:00',
  ADD COLUMN IF NOT EXISTS memory_verse_reminder_time TIME    DEFAULT '09:00:00';

COMMENT ON COLUMN user_notification_preferences.streak_milestone_enabled IS
  'Whether to send Milestone Achievement notifications (7, 30, 100, 365-day streaks)';
COMMENT ON COLUMN user_notification_preferences.streak_lost_enabled IS
  'Whether to send Streak Reset Motivation notifications after a streak break';
COMMENT ON COLUMN user_notification_preferences.streak_reminder_time IS
  'User-preferred local time for the daily streak reminder (default 20:00)';
COMMENT ON COLUMN user_notification_preferences.memory_verse_reminder_time IS
  'User-preferred local time for the daily memory verse review reminder (default 09:00)';

-- Partial indexes for the new boolean columns (consistent with existing style)
CREATE INDEX IF NOT EXISTS idx_notification_prefs_streak_milestone
  ON user_notification_preferences (streak_milestone_enabled)
  WHERE streak_milestone_enabled = true;

CREATE INDEX IF NOT EXISTS idx_notification_prefs_streak_lost
  ON user_notification_preferences (streak_lost_enabled)
  WHERE streak_lost_enabled = true;

-- ============================================================================
-- 2. Update get_streak_reminder_notification_users to use per-user time
-- ============================================================================
-- Previously the function matched against a hardcoded 8 PM window.
-- Now it matches against each user's streak_reminder_time preference.

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
    -- Match within a 15-minute window to align with the cron schedule frequency
    window_minutes CONSTANT INTEGER := 15;
    target_total_minutes INTEGER;
BEGIN
    -- Total UTC minutes from midnight for this invocation
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
        -- Streak reminders must be enabled for this user
        unp.streak_reminder_enabled = true

        -- Match users whose local time falls in their preferred reminder window.
        -- User's preferred time is stored as local TIME; we convert to minutes-from-midnight.
        -- Local minutes = (UTC minutes + timezone offset + 1440) % 1440
        AND (
            (target_total_minutes + unp.timezone_offset_minutes + 1440) % 1440
            BETWEEN
                (EXTRACT(HOUR FROM unp.streak_reminder_time)::INTEGER * 60
                  + EXTRACT(MINUTE FROM unp.streak_reminder_time)::INTEGER)
            AND
                (EXTRACT(HOUR FROM unp.streak_reminder_time)::INTEGER * 60
                  + EXTRACT(MINUTE FROM unp.streak_reminder_time)::INTEGER
                  + window_minutes - 1)
        )

        -- Only remind users who haven't viewed today's verse yet.
        AND (
            dvs.last_viewed_at IS NULL
            OR DATE(dvs.last_viewed_at AT TIME ZONE 'UTC') < CURRENT_DATE
        )

    -- For users with multiple devices, prefer the most recently updated token
    ORDER BY unt.user_id, unt.token_updated_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_streak_reminder_notification_users(INTEGER, INTEGER) TO service_role;

COMMENT ON FUNCTION get_streak_reminder_notification_users IS
    'Returns users eligible for a streak reminder push notification at the given UTC hour/minute. '
    'Matches users whose local time (UTC + timezone offset) falls within a 15-minute window '
    'around their preferred streak_reminder_time, and who have not yet viewed today''s daily verse. '
    'Used by the send-streak-reminder-notification Edge Function.';

-- ============================================================================
-- 3. Verification
-- ============================================================================

DO $$
BEGIN
    -- Verify columns were added
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_notification_preferences'
          AND column_name = 'streak_milestone_enabled'
    ) THEN
        RAISE NOTICE '✓ streak_milestone_enabled column added';
    ELSE
        RAISE WARNING '✗ streak_milestone_enabled column NOT found';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_notification_preferences'
          AND column_name = 'streak_lost_enabled'
    ) THEN
        RAISE NOTICE '✓ streak_lost_enabled column added';
    ELSE
        RAISE WARNING '✗ streak_lost_enabled column NOT found';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_notification_preferences'
          AND column_name = 'streak_reminder_time'
    ) THEN
        RAISE NOTICE '✓ streak_reminder_time column added';
    ELSE
        RAISE WARNING '✗ streak_reminder_time column NOT found';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_notification_preferences'
          AND column_name = 'memory_verse_reminder_time'
    ) THEN
        RAISE NOTICE '✓ memory_verse_reminder_time column added';
    ELSE
        RAISE WARNING '✗ memory_verse_reminder_time column NOT found';
    END IF;

    -- Verify function was updated
    IF EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'get_streak_reminder_notification_users'
          AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    ) THEN
        RAISE NOTICE '✓ get_streak_reminder_notification_users updated to use per-user time';
    ELSE
        RAISE WARNING '✗ get_streak_reminder_notification_users function NOT found';
    END IF;
END $$;

COMMIT;
