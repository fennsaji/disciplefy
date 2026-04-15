-- =============================================================================
-- Migration: Fix leaderboard XP to include achievement rewards
-- Date: 2026-04-15
-- Description: Leaderboard functions only summed user_topic_progress.xp_earned,
--              ignoring achievement XP rewards. This caused XP mismatch between
--              leaderboard (2400 XP) and progress page (5150 XP).
--              Also fixes rank_data CTE in get_user_gamification_stats which
--              ranked by study XP only instead of total XP.
-- =============================================================================

-- =============================================================================
-- FUNCTION: get_leaderboard (updated)
-- =============================================================================
-- Now includes both study topic XP and achievement XP rewards.

CREATE OR REPLACE FUNCTION get_leaderboard(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    user_id   UUID,
    display_name TEXT,
    total_xp  BIGINT,
    rank      BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH user_xp AS (
        SELECT
            up.id AS uid,
            (
                COALESCE(SUM(utp.xp_earned), 0) +
                COALESCE((
                    SELECT SUM(a.xp_reward)
                    FROM user_achievements ua
                    JOIN achievements a ON a.id = ua.achievement_id
                    WHERE ua.user_id = up.id
                ), 0)
            )::BIGINT AS xp,
            CASE
                WHEN up.first_name IS NOT NULL AND up.last_name IS NOT NULL AND up.last_name <> ''
                    THEN up.first_name || ' ' || LEFT(up.last_name, 1) || '.'
                WHEN up.first_name IS NOT NULL AND up.first_name <> ''
                    THEN up.first_name
                ELSE 'Anonymous'
            END AS dname
        FROM user_profiles up
        LEFT JOIN user_topic_progress utp ON up.id = utp.user_id
        GROUP BY up.id, up.first_name, up.last_name
        HAVING (
            COALESCE(SUM(utp.xp_earned), 0) +
            COALESCE((
                SELECT SUM(a.xp_reward)
                FROM user_achievements ua
                JOIN achievements a ON a.id = ua.achievement_id
                WHERE ua.user_id = up.id
            ), 0)
        ) >= 200
    )
    SELECT
        ux.uid                                             AS user_id,
        ux.dname                                           AS display_name,
        ux.xp                                              AS total_xp,
        ROW_NUMBER() OVER (ORDER BY ux.xp DESC)::BIGINT   AS rank
    FROM user_xp ux
    ORDER BY ux.xp DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION: get_user_xp_rank (updated)
-- =============================================================================
-- Now includes both study topic XP and achievement XP rewards.

CREATE OR REPLACE FUNCTION get_user_xp_rank(p_user_id UUID)
RETURNS TABLE (
    total_xp BIGINT,
    rank     BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH user_xp AS (
        SELECT (
            COALESCE((SELECT SUM(utp.xp_earned) FROM user_topic_progress utp WHERE utp.user_id = p_user_id), 0) +
            COALESCE((SELECT SUM(a.xp_reward) FROM user_achievements ua JOIN achievements a ON a.id = ua.achievement_id WHERE ua.user_id = p_user_id), 0)
        )::BIGINT AS xp
    ),
    ranked_users AS (
        SELECT
            up.id,
            ROW_NUMBER() OVER (ORDER BY (
                COALESCE(SUM(utp.xp_earned), 0) +
                COALESCE((
                    SELECT SUM(a.xp_reward)
                    FROM user_achievements ua
                    JOIN achievements a ON a.id = ua.achievement_id
                    WHERE ua.user_id = up.id
                ), 0)
            ) DESC)::BIGINT AS r
        FROM user_profiles up
        LEFT JOIN user_topic_progress utp ON up.id = utp.user_id
        GROUP BY up.id
        HAVING (
            COALESCE(SUM(utp.xp_earned), 0) +
            COALESCE((
                SELECT SUM(a.xp_reward)
                FROM user_achievements ua
                JOIN achievements a ON a.id = ua.achievement_id
                WHERE ua.user_id = up.id
            ), 0)
        ) >= 200
    )
    SELECT
        ux.xp   AS total_xp,
        ru.r    AS rank
    FROM user_xp ux
    LEFT JOIN ranked_users ru ON ru.id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: get_user_gamification_stats rank_data CTE
-- =============================================================================
-- The rank_data CTE was also ranking by study XP only, not total XP.
-- Must keep the RETURNS TABLE(...) signature from migration 20260410.

CREATE OR REPLACE FUNCTION get_user_gamification_stats(p_user_id UUID)
RETURNS TABLE (
    -- XP & Rank
    total_xp BIGINT,
    leaderboard_rank BIGINT,
    -- Study Streak
    study_current_streak INTEGER,
    study_longest_streak INTEGER,
    study_last_date DATE,
    total_study_days INTEGER,
    -- Verse Streak
    verse_current_streak INTEGER,
    verse_longest_streak INTEGER,
    -- Counts
    total_studies_completed BIGINT,
    total_time_spent_seconds BIGINT,
    total_memory_verses BIGINT,
    total_voice_sessions BIGINT,
    total_saved_guides BIGINT,
    -- Achievements
    achievements_unlocked INTEGER,
    achievements_total INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH study_xp AS (
        SELECT
            COALESCE(SUM(utp.xp_earned), 0)::BIGINT AS xp
        FROM user_topic_progress utp
        WHERE utp.user_id = p_user_id
    ),
    achievement_xp AS (
        SELECT
            COALESCE(SUM(a.xp_reward), 0)::BIGINT AS xp
        FROM user_achievements ua
        JOIN achievements a ON a.id = ua.achievement_id
        WHERE ua.user_id = p_user_id
    ),
    xp_data AS (
        SELECT (sxp.xp + axp.xp)::BIGINT AS xp
        FROM study_xp sxp, achievement_xp axp
    ),
    rank_data AS (
        SELECT r.rank
        FROM (
            SELECT
                up.id,
                ROW_NUMBER() OVER (ORDER BY (
                    COALESCE(SUM(utp.xp_earned), 0) +
                    COALESCE((
                        SELECT SUM(a.xp_reward)
                        FROM user_achievements ua
                        JOIN achievements a ON a.id = ua.achievement_id
                        WHERE ua.user_id = up.id
                    ), 0)
                ) DESC)::BIGINT AS rank
            FROM user_profiles up
            LEFT JOIN user_topic_progress utp ON up.id = utp.user_id
            GROUP BY up.id
            HAVING (
                COALESCE(SUM(utp.xp_earned), 0) +
                COALESCE((
                    SELECT SUM(a.xp_reward)
                    FROM user_achievements ua
                    JOIN achievements a ON a.id = ua.achievement_id
                    WHERE ua.user_id = up.id
                ), 0)
            ) >= 200
        ) r
        WHERE r.id = p_user_id
    ),
    study_streak_data AS (
        SELECT
            COALESCE(s.current_streak, 0) AS current_streak,
            COALESCE(s.longest_streak, 0) AS longest_streak,
            s.last_study_date,
            COALESCE(s.total_study_days, 0) AS total_study_days
        FROM user_study_streaks s
        WHERE s.user_id = p_user_id
    ),
    verse_streak_data AS (
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
$$ LANGUAGE plpgsql SECURITY DEFINER;
