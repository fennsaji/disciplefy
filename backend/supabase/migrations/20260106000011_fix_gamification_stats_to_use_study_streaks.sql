-- Migration: Fix get_user_gamification_stats to use user_study_streaks table
-- Purpose: Update function to read study streaks from user_study_streaks instead of returning 0
-- Also: Include achievement_xp in total XP calculation
-- Issue: Function was returning 0 for study streaks after user_study_streaks table was recreated

DROP FUNCTION IF EXISTS public.get_user_gamification_stats(uuid);

-- Recreate function with proper user_study_streaks integration
CREATE OR REPLACE FUNCTION public.get_user_gamification_stats(p_user_id uuid)
RETURNS TABLE(
    total_xp bigint,
    leaderboard_rank bigint,
    study_current_streak integer,
    study_longest_streak integer,
    study_last_date date,
    total_study_days integer,
    verse_current_streak integer,
    verse_longest_streak integer,
    total_studies_completed bigint,
    total_time_spent_seconds bigint,
    total_memory_verses bigint,
    total_voice_sessions bigint,
    total_saved_guides bigint,
    achievements_unlocked integer,
    achievements_total integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    WITH study_streaks_agg AS (
        -- Precompute achievement_xp per user to eliminate correlated subqueries
        SELECT
            user_id,
            COALESCE(achievement_xp, 0) AS achievement_xp
        FROM user_study_streaks
    ),
    xp_data AS (
        -- Total XP from topic progress + achievement XP
        -- Always returns exactly 1 row, even for users with no data
        SELECT
            (COALESCE(
                (SELECT SUM(xp_earned) FROM user_topic_progress WHERE user_id = p_user_id),
                0
            ) +
            COALESCE(
                (SELECT achievement_xp FROM user_study_streaks WHERE user_id = p_user_id),
                0
            ))::BIGINT AS xp
    ),
    rank_data AS (
        -- Leaderboard rank based on topic XP + achievement XP
        -- JOIN study_streaks_agg to avoid correlated subqueries
        SELECT r.rank
        FROM (
            SELECT
                up.id,
                ROW_NUMBER() OVER (
                    ORDER BY (
                        COALESCE(SUM(utp.xp_earned), 0) +
                        COALESCE(ssa.achievement_xp, 0)
                    ) DESC
                )::BIGINT AS rank
            FROM user_profiles up
            LEFT JOIN user_topic_progress utp ON up.id = utp.user_id
            LEFT JOIN study_streaks_agg ssa ON ssa.user_id = up.id
            GROUP BY up.id, ssa.achievement_xp
            HAVING (
                COALESCE(SUM(utp.xp_earned), 0) +
                COALESCE(ssa.achievement_xp, 0)
            ) >= 200
        ) r
        WHERE r.id = p_user_id
    ),
    study_streak_data AS (
        -- Read study streak from user_study_streaks table
        SELECT
            COALESCE(uss.current_streak, 0) AS current_streak,
            COALESCE(uss.longest_streak, 0) AS longest_streak,
            uss.last_study_date,
            COALESCE(uss.total_study_days, 0) AS total_study_days
        FROM user_study_streaks uss
        WHERE uss.user_id = p_user_id
    ),
    verse_streak_data AS (
        -- Daily verse streak data
        SELECT
            COALESCE(v.current_streak, 0) AS current_streak,
            COALESCE(v.longest_streak, 0) AS longest_streak
        FROM daily_verse_streaks v
        WHERE v.user_id = p_user_id
    ),
    counts AS (
        SELECT
            (SELECT COUNT(*) FROM user_topic_progress WHERE user_id = p_user_id AND completed_at IS NOT NULL) +
            (SELECT COUNT(*) FROM user_study_guides WHERE user_id = p_user_id AND completed_at IS NOT NULL) AS studies,
            (SELECT COALESCE(SUM(time_spent_seconds), 0) FROM user_topic_progress WHERE user_id = p_user_id) +
            (SELECT COALESCE(SUM(time_spent_seconds), 0) FROM user_study_guides WHERE user_id = p_user_id) AS time_spent,
            (SELECT COUNT(*) FROM memory_verses WHERE user_id = p_user_id) AS memory,
            (SELECT COUNT(*) FROM voice_conversations WHERE user_id = p_user_id AND status = 'completed') AS voice,
            (SELECT COUNT(*) FROM user_study_guides WHERE user_id = p_user_id AND is_saved = TRUE) AS saved
    ),
    achievement_counts AS (
        SELECT
            (SELECT COUNT(*) FROM user_achievements WHERE user_id = p_user_id)::INTEGER AS unlocked,
            (SELECT COUNT(*) FROM achievements)::INTEGER AS total
    )
    SELECT
        xd.xp AS total_xp,
        rd.rank AS leaderboard_rank,
        COALESCE(ssd.current_streak, 0) AS study_current_streak,
        COALESCE(ssd.longest_streak, 0) AS study_longest_streak,
        ssd.last_study_date AS study_last_date,
        COALESCE(ssd.total_study_days, 0) AS total_study_days,
        COALESCE(vsd.current_streak, 0) AS verse_current_streak,
        COALESCE(vsd.longest_streak, 0) AS verse_longest_streak,
        c.studies AS total_studies_completed,
        c.time_spent AS total_time_spent_seconds,
        c.memory AS total_memory_verses,
        c.voice AS total_voice_sessions,
        c.saved AS total_saved_guides,
        ac.unlocked AS achievements_unlocked,
        ac.total AS achievements_total
    FROM xp_data xd
    CROSS JOIN counts c
    CROSS JOIN achievement_counts ac
    LEFT JOIN rank_data rd ON TRUE
    LEFT JOIN study_streak_data ssd ON TRUE
    LEFT JOIN verse_streak_data vsd ON TRUE;
END;
$function$;

COMMENT ON FUNCTION public.get_user_gamification_stats IS
'Returns comprehensive gamification statistics for a user.
Updated 2026-01-06: Fixed to read study streaks from user_study_streaks table (no longer returns 0).
Includes achievement XP in total XP calculation.
Daily verse streaks are tracked via daily_verse_streaks table.
Updated 2026-01-07: Optimized rank calculation by precomputing achievement_xp in study_streaks_agg CTE,
eliminating correlated subqueries for improved performance.';
