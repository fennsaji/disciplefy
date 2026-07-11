-- =====================================================
-- Migration: Fix achievement progress display for multi-metric categories
-- =====================================================
-- get_user_achievements previously returned no per-achievement progress,
-- so the frontend fell back to one blanket count per category (e.g. total
-- memory verses) applied to every achievement in that category. This is
-- correct for single-metric categories (study/streak/voice/saved) but wrong
-- for 'memory', which packs several distinct metrics (mastery level counts,
-- practice streak, daily goals, weekly challenges, collections, perfect
-- recalls, modes tried) under one category. Users saw misleading progress
-- like "24/5" (raw verse count) on achievements that actually track a
-- different, unmet metric.
--
-- Fix: compute the real current_progress per achievement_id (same queries
-- used by check_memory_achievements) and return it from get_user_achievements.
-- NULL is returned for achievements where the category-blanket stat is
-- already the correct metric, so the frontend's existing fallback still works.

BEGIN;

DROP FUNCTION IF EXISTS get_user_achievements(UUID, TEXT);

CREATE OR REPLACE FUNCTION get_user_achievements(p_user_id UUID, p_language TEXT DEFAULT 'en')
RETURNS TABLE (
    achievement_id TEXT,
    name TEXT,
    description TEXT,
    icon TEXT,
    xp_reward INTEGER,
    category TEXT,
    threshold INTEGER,
    unlocked_at TIMESTAMPTZ,
    is_unlocked BOOLEAN,
    current_progress INTEGER
) AS $$
DECLARE
    v_memory_count INTEGER;
    v_perfect_recalls INTEGER;
    v_practice_streak INTEGER;
    v_modes_tried INTEGER;
    v_intermediate_mastery_count INTEGER;
    v_advanced_mastery_count INTEGER;
    v_expert_mastery_count INTEGER;
    v_daily_goals_completed INTEGER;
    v_challenges_completed INTEGER;
    v_collections_count INTEGER;
    v_mode_master_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_memory_count
    FROM memory_verses mv WHERE mv.user_id = p_user_id;

    SELECT COUNT(*) INTO v_perfect_recalls
    FROM review_sessions ps
    WHERE ps.user_id = p_user_id AND ps.quality_rating = 5;

    SELECT COALESCE(mvs.current_streak, 0) INTO v_practice_streak
    FROM memory_verse_streaks mvs
    WHERE mvs.user_id = p_user_id
    LIMIT 1;
    v_practice_streak := COALESCE(v_practice_streak, 0);

    SELECT COUNT(DISTINCT mpm.mode_type) INTO v_modes_tried
    FROM memory_practice_modes mpm
    WHERE mpm.user_id = p_user_id AND mpm.times_practiced > 0;
    v_modes_tried := COALESCE(v_modes_tried, 0);

    SELECT COUNT(*) INTO v_intermediate_mastery_count
    FROM memory_verse_mastery mvm
    WHERE mvm.user_id = p_user_id
    AND mvm.mastery_level IN ('intermediate', 'advanced', 'expert', 'master');
    v_intermediate_mastery_count := COALESCE(v_intermediate_mastery_count, 0);

    SELECT COUNT(*) INTO v_advanced_mastery_count
    FROM memory_verse_mastery mvm
    WHERE mvm.user_id = p_user_id
    AND mvm.mastery_level IN ('advanced', 'expert', 'master');
    v_advanced_mastery_count := COALESCE(v_advanced_mastery_count, 0);

    SELECT COUNT(*) INTO v_expert_mastery_count
    FROM memory_verse_mastery mvm
    WHERE mvm.user_id = p_user_id
    AND mvm.mastery_level IN ('expert', 'master');
    v_expert_mastery_count := COALESCE(v_expert_mastery_count, 0);

    SELECT COUNT(*) INTO v_daily_goals_completed
    FROM memory_daily_goals mdg
    WHERE mdg.user_id = p_user_id AND mdg.goal_achieved = TRUE;
    v_daily_goals_completed := COALESCE(v_daily_goals_completed, 0);

    SELECT COUNT(*) INTO v_challenges_completed
    FROM user_challenge_progress ucp
    WHERE ucp.user_id = p_user_id AND ucp.is_completed = TRUE;
    v_challenges_completed := COALESCE(v_challenges_completed, 0);

    SELECT COUNT(*) INTO v_collections_count
    FROM memory_verse_collections mvc
    WHERE mvc.user_id = p_user_id;
    v_collections_count := COALESCE(v_collections_count, 0);

    SELECT COUNT(*) INTO v_mode_master_count
    FROM memory_practice_modes mpm
    WHERE mpm.user_id = p_user_id
    AND mpm.success_rate >= 80.0
    AND mpm.times_practiced >= 10;
    v_mode_master_count := COALESCE(v_mode_master_count, 0);

    RETURN QUERY
    SELECT
        a.id AS achievement_id,
        CASE p_language
            WHEN 'hi' THEN a.name_hi
            WHEN 'ml' THEN a.name_ml
            ELSE a.name_en
        END AS name,
        CASE p_language
            WHEN 'hi' THEN a.description_hi
            WHEN 'ml' THEN a.description_ml
            ELSE a.description_en
        END AS description,
        a.icon,
        a.xp_reward,
        a.category,
        a.threshold,
        ua.unlocked_at,
        (ua.id IS NOT NULL) AS is_unlocked,
        CASE a.id
            WHEN 'memory_first_verse' THEN v_memory_count
            WHEN 'memory_5' THEN v_memory_count
            WHEN 'memory_25' THEN v_memory_count
            WHEN 'memory_50' THEN v_memory_count
            WHEN 'memory_100' THEN v_memory_count
            WHEN 'memory_perfect_recall' THEN v_perfect_recalls
            WHEN 'memory_perfect_recalls_50' THEN v_perfect_recalls
            WHEN 'memory_practice_streak_3' THEN v_practice_streak
            WHEN 'memory_practice_streak_7' THEN v_practice_streak
            WHEN 'memory_practice_streak_30' THEN v_practice_streak
            WHEN 'memory_practice_streak_100' THEN v_practice_streak
            WHEN 'memory_modes_3' THEN v_modes_tried
            WHEN 'memory_modes_5' THEN v_mode_master_count
            WHEN 'memory_mastery_intermediate_3' THEN v_intermediate_mastery_count
            WHEN 'memory_mastery_advanced_5' THEN v_advanced_mastery_count
            WHEN 'memory_mastery_expert_10' THEN v_expert_mastery_count
            WHEN 'memory_daily_goal_5' THEN v_daily_goals_completed
            WHEN 'memory_challenge_champion' THEN v_challenges_completed
            WHEN 'memory_collections_5' THEN v_collections_count
            ELSE NULL
        END AS current_progress
    FROM achievements a
    LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = p_user_id
    ORDER BY a.sort_order, a.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_user_achievements(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION get_user_achievements IS 'Returns all achievements with unlock status and real per-achievement current_progress for a user in specified language (en/hi/ml). current_progress is NULL for single-metric categories where the frontend category-blanket stat is already correct.';

COMMIT;
