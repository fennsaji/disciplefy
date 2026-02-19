-- ============================================================================
-- Streak Reminder Notification Function
-- ============================================================================
-- Creates the PostgreSQL function used by the send-streak-reminder-notification
-- Edge Function to fetch eligible users for streak reminder push notifications.
--
-- Called by: backend/supabase/functions/send-streak-reminder-notification/index.ts
-- Triggered via: GitHub Actions cron workflow
-- ============================================================================

-- ============================================================================
-- FUNCTION: get_streak_reminder_notification_users
-- ============================================================================
-- Returns users who should receive a streak reminder at the given UTC time.
--
-- Logic:
--   1. User must have streak_reminder_enabled = true
--   2. User's local time (UTC + timezone_offset_minutes) must be 8 PM (20:00)
--      within a 15-minute matching window
--   3. User must not have viewed today's daily verse yet (verse streak at risk)
--   4. User must have at least one valid FCM token
--
-- Returns one row per (user, token) — if a user has multiple devices, they
-- get one notification per registered FCM token.
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
    -- Reminder fires at 8 PM local time (20 * 60 = 1200 minutes from midnight)
    reminder_time_minutes CONSTANT INTEGER := 20 * 60;
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

        -- Match users whose local time falls in the 8 PM reminder window.
        -- Local minutes = (UTC minutes + timezone offset + 1440) % 1440
        -- The +1440 before modulo ensures a non-negative result in PostgreSQL.
        AND (
            (target_total_minutes + unp.timezone_offset_minutes + 1440) % 1440
            BETWEEN reminder_time_minutes
                AND (reminder_time_minutes + window_minutes - 1)
        )

        -- Only remind users who haven't viewed today's verse yet.
        -- If they have already viewed it their streak is safe, no need to remind.
        AND (
            dvs.last_viewed_at IS NULL
            OR DATE(dvs.last_viewed_at AT TIME ZONE 'UTC') < CURRENT_DATE
        )

    -- For users with multiple devices, prefer the most recently updated token
    ORDER BY unt.user_id, unt.token_updated_at DESC;
END;
$$;

-- Allow the Edge Function service role to call this function
GRANT EXECUTE ON FUNCTION get_streak_reminder_notification_users(INTEGER, INTEGER) TO service_role;

COMMENT ON FUNCTION get_streak_reminder_notification_users IS
    'Returns users eligible for a streak reminder push notification at the given UTC hour/minute. '
    'Matches users whose local time (UTC + timezone offset) falls in an 8 PM window '
    'and who have not yet viewed today''s daily verse. '
    'Used by the send-streak-reminder-notification Edge Function.';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'get_streak_reminder_notification_users'
          AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    ) THEN
        RAISE NOTICE '✓ get_streak_reminder_notification_users function created successfully';
    ELSE
        RAISE WARNING '✗ get_streak_reminder_notification_users function NOT found — check for errors above';
    END IF;
END $$;
