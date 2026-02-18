-- =============================================================================
-- Migration: Leaderboard Functions
-- Date: 2026-02-18
-- Description: Adds get_leaderboard and get_user_xp_rank RPC functions
--              needed by the frontend leaderboard feature.
-- =============================================================================

-- =============================================================================
-- FUNCTION: get_leaderboard
-- =============================================================================
-- Returns top N users ranked by total XP (from user_topic_progress.xp_earned).
-- Only includes users with >= 200 XP.
-- Display name is first_name + last initial for privacy (e.g. "John D.")
--
-- Returns: user_id, display_name, total_xp, rank

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
            COALESCE(SUM(utp.xp_earned), 0)::BIGINT AS xp,
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
        HAVING COALESCE(SUM(utp.xp_earned), 0) >= 200
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

GRANT EXECUTE ON FUNCTION get_leaderboard(INTEGER) TO authenticated, anon;

COMMENT ON FUNCTION get_leaderboard IS
    'Returns top-N leaderboard entries ranked by total XP. Only users with >= 200 XP are included. Display names are first_name + last initial for privacy.';

-- =============================================================================
-- FUNCTION: get_user_xp_rank
-- =============================================================================
-- Returns a single row with the requesting user's total XP and their rank
-- among all users with >= 200 XP. Rank is NULL if user has < 200 XP.
--
-- Returns: total_xp, rank

CREATE OR REPLACE FUNCTION get_user_xp_rank(p_user_id UUID)
RETURNS TABLE (
    total_xp BIGINT,
    rank     BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH user_xp AS (
        SELECT COALESCE(SUM(utp.xp_earned), 0)::BIGINT AS xp
        FROM user_topic_progress utp
        WHERE utp.user_id = p_user_id
    ),
    ranked_users AS (
        SELECT
            up.id,
            ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(utp.xp_earned), 0) DESC)::BIGINT AS r
        FROM user_profiles up
        LEFT JOIN user_topic_progress utp ON up.id = utp.user_id
        GROUP BY up.id
        HAVING COALESCE(SUM(utp.xp_earned), 0) >= 200
    )
    SELECT
        ux.xp   AS total_xp,
        ru.r    AS rank
    FROM user_xp ux
    LEFT JOIN ranked_users ru ON ru.id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_user_xp_rank(UUID) TO authenticated;

COMMENT ON FUNCTION get_user_xp_rank IS
    'Returns total XP and leaderboard rank for a specific user. Rank is NULL when user has < 200 XP (not eligible for leaderboard).';
