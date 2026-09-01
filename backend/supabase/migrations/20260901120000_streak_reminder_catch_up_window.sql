-- ============================================================================
-- Streak Reminder — Catch-Up Delivery Window
-- ============================================================================
-- Replaces the 15-minute exact-slot match in
-- get_streak_reminder_notification_users() with a forward-looking catch-up
-- window.
--
-- WHY
-- ---
-- The previous version matched only users whose local time fell in the
-- 15 minutes starting at their streak_reminder_time. Two things broke it:
--
--   1. Half-hour timezones could never match. The cron fires hourly at :00, so
--      for IST (UTC+05:30) the local minute is always :30 — but the window only
--      covered :00–:14. With the default 20:00 reminder, a push required the
--      GitHub Actions run to be delayed by exactly 30–44 minutes. India, Sri
--      Lanka and Nepal (the primary user base) effectively never received one.
--
--   2. Scheduled GitHub Actions runs are best-effort and are routinely delayed
--      or dropped entirely. A missed run meant the 15-minute slot passed
--      unserved and the user got nothing that day — there was no retry.
--
-- The window now runs from the user's reminder time forward for
-- catch_up_minutes, so any later hourly run still delivers it. The Edge
-- Function already filters out users who were sent one today
-- (getAlreadySentUserIds), so widening the window cannot cause repeat sends.
-- ============================================================================

BEGIN;

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
    -- How long after the user's preferred time the reminder stays deliverable.
    -- Long enough to survive several consecutive dropped hourly runs, short
    -- enough that an evening reminder can never arrive after local midnight.
    catch_up_minutes CONSTANT INTEGER := 180;
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

        -- The user's local time is at or past their preferred reminder time,
        -- and still within the catch-up window that follows it.
        -- Local minutes = (UTC minutes + timezone offset + 1440) % 1440
        AND (
            (target_total_minutes + unp.timezone_offset_minutes + 1440) % 1440
            BETWEEN
                (EXTRACT(HOUR FROM unp.streak_reminder_time)::INTEGER * 60
                  + EXTRACT(MINUTE FROM unp.streak_reminder_time)::INTEGER)
            AND
                -- Clamped at 1439 so the window never wraps past local midnight
                -- into the following day.
                LEAST(
                    EXTRACT(HOUR FROM unp.streak_reminder_time)::INTEGER * 60
                      + EXTRACT(MINUTE FROM unp.streak_reminder_time)::INTEGER
                      + catch_up_minutes - 1,
                    1439
                )
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
    'Matches users whose local time (UTC + timezone offset) is at or past their preferred '
    'streak_reminder_time and still within a 3-hour catch-up window after it, and who have not yet '
    'viewed today''s daily verse. The catch-up window lets a later hourly run cover for a delayed or '
    'dropped cron; per-day dedup in the Edge Function prevents repeat sends. '
    'Used by the send-streak-reminder-notification Edge Function.';

COMMIT;
