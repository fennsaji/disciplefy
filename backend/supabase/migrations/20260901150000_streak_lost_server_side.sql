-- ============================================================================
-- Streak Lost — Server-Side Detection
-- ============================================================================
-- Adds get_streak_lost_notification_users(), so the "Streak Reset Motivation"
-- notification can be sent by cron instead of by the app.
--
-- WHY
-- ---
-- streak_lost was only ever triggered from the Flutter app, inside
-- markVerseAsViewed() (daily_verse_bloc.dart), on the condition
-- `previousCount > 1 && newCount == 1`. That fires when the user opens the app
-- and views a verse AFTER their streak already broke — so the "you lost your
-- streak, come back" nudge was delivered at the exact moment the user had
-- already come back. As re-engagement it could never work, and it explains why
-- streak notifications appeared only when the app was opened.
--
-- Detection now happens server-side: a user whose last view is old enough that
-- the streak is broken, who still has a non-zero current_streak recorded (the
-- app has not yet reset it), is notified once at ~10 AM local.
--
-- The Edge Function's per-send dedup stops it repeating: once notified, the
-- notification_logs entry suppresses further sends within the lookback window,
-- and the streak resets to 1 as soon as the user next views a verse.
-- ============================================================================

BEGIN;

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
    -- Sent mid-morning local time: late enough not to pre-empt the user's own
    -- reading habit, early enough to still recover the day.
    target_local_minutes CONSTANT INTEGER := 10 * 60;
    catch_up_minutes CONSTANT INTEGER := 180;
    -- Only worth nudging about a streak the user had actually built up.
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

        -- Local time is at or past the target, within the catch-up window
        AND (
            (target_total_minutes + unp.timezone_offset_minutes + 1440) % 1440
            BETWEEN target_local_minutes
            AND LEAST(target_local_minutes + catch_up_minutes - 1, 1439)
        )

        -- They had a streak going...
        AND dvs.current_streak >= min_streak_worth_saving

        -- ...and the break happened EXACTLY yesterday, in the user's own local
        -- date. Compared locally, not in UTC, so the day boundary matches what
        -- the user experiences.
        --
        -- Deliberately an equality, not "older than": current_streak is only
        -- reset when the user next opens the app, so a churned user keeps a
        -- stale non-zero streak indefinitely. A ">" comparison would re-send
        -- "your 12-day streak ended" every single day, forever. Matching the
        -- single local day after the break sends it once.
        AND dvs.last_viewed_at IS NOT NULL
        AND DATE(dvs.last_viewed_at + make_interval(mins => unp.timezone_offset_minutes))
            = DATE(NOW() + make_interval(mins => unp.timezone_offset_minutes)) - 2

    ORDER BY unt.user_id, unt.token_updated_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_streak_lost_notification_users(INTEGER, INTEGER) TO service_role;

COMMENT ON FUNCTION get_streak_lost_notification_users IS
    'Returns users whose daily verse streak has broken (missed a full local day with a '
    'streak of 2+) and who should receive the "Streak Reset Motivation" push at ~10 AM '
    'local, with a 3-hour catch-up window. Replaces app-side detection, which could only '
    'fire once the user had already returned. One row per user (most recent device token).';

COMMIT;
