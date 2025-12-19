-- Migration: Fix ambiguous column reference in check_memory_achievements
-- Created: 2025-12-20
-- Purpose: Rename output columns to avoid ambiguity with table columns

-- =============================================================================
-- FIX: check_memory_achievements function with renamed output columns
-- =============================================================================
-- The issue is that 'achievement_id' is both an output column and a table column
-- in user_achievements, causing PostgreSQL error 42702.

-- Drop existing function first (required to change return type)
DROP FUNCTION IF EXISTS check_memory_achievements(UUID);

CREATE OR REPLACE FUNCTION check_memory_achievements(p_user_id UUID)
RETURNS TABLE (
    out_achievement_id TEXT,
    out_achievement_name TEXT,
    out_xp_reward INTEGER,
    out_is_new BOOLEAN
) AS $$
DECLARE
    v_memory_count INTEGER;
    v_perfect_recalls INTEGER;
    v_current_streak INTEGER;
    v_modes_tried INTEGER;
    v_intermediate_mastery_count INTEGER;
    v_advanced_mastery_count INTEGER;
    v_expert_mastery_count INTEGER;
    v_daily_goals_completed INTEGER;
    v_challenges_completed INTEGER;
    v_collections_count INTEGER;
    v_mode_master_count INTEGER;
    v_achievement RECORD;
BEGIN
    -- Get memory verses count
    SELECT COUNT(*) INTO v_memory_count
    FROM memory_verses mv
    WHERE mv.user_id = p_user_id;

    -- Get perfect recalls count (quality = 5)
    SELECT COUNT(*) INTO v_perfect_recalls
    FROM review_sessions rs
    WHERE rs.user_id = p_user_id AND rs.quality_rating = 5;

    -- Get current practice streak
    SELECT COALESCE(mvs.current_streak, 0) INTO v_current_streak
    FROM memory_verse_streaks mvs
    WHERE mvs.user_id = p_user_id
    LIMIT 1;

    IF NOT FOUND THEN
        v_current_streak := 0;
    END IF;

    -- Get number of different practice modes tried
    SELECT COUNT(DISTINCT mpm.mode_type) INTO v_modes_tried
    FROM memory_practice_modes mpm
    WHERE mpm.user_id = p_user_id AND mpm.times_practiced > 0;

    IF NOT FOUND THEN
        v_modes_tried := 0;
    END IF;

    -- Get verses at intermediate mastery or higher
    SELECT COUNT(*) INTO v_intermediate_mastery_count
    FROM memory_verse_mastery mvm
    WHERE mvm.user_id = p_user_id
    AND mvm.mastery_level IN ('intermediate', 'advanced', 'expert', 'master');

    IF NOT FOUND THEN
        v_intermediate_mastery_count := 0;
    END IF;

    -- Get verses at advanced mastery or higher
    SELECT COUNT(*) INTO v_advanced_mastery_count
    FROM memory_verse_mastery mvm
    WHERE mvm.user_id = p_user_id
    AND mvm.mastery_level IN ('advanced', 'expert', 'master');

    IF NOT FOUND THEN
        v_advanced_mastery_count := 0;
    END IF;

    -- Get verses at expert mastery or higher
    SELECT COUNT(*) INTO v_expert_mastery_count
    FROM memory_verse_mastery mvm
    WHERE mvm.user_id = p_user_id
    AND mvm.mastery_level IN ('expert', 'master');

    IF NOT FOUND THEN
        v_expert_mastery_count := 0;
    END IF;

    -- Get daily goals completed count
    SELECT COUNT(*) INTO v_daily_goals_completed
    FROM memory_daily_goals mdg
    WHERE mdg.user_id = p_user_id AND mdg.goal_achieved = TRUE;

    IF NOT FOUND THEN
        v_daily_goals_completed := 0;
    END IF;

    -- Get completed challenges count
    SELECT COUNT(*) INTO v_challenges_completed
    FROM user_challenge_progress ucp
    WHERE ucp.user_id = p_user_id AND ucp.is_completed = TRUE;

    IF NOT FOUND THEN
        v_challenges_completed := 0;
    END IF;

    -- Get verse collections count
    SELECT COUNT(*) INTO v_collections_count
    FROM memory_verse_collections mvc
    WHERE mvc.user_id = p_user_id;

    IF NOT FOUND THEN
        v_collections_count := 0;
    END IF;

    -- Get modes with 80%+ success rate
    SELECT COUNT(*) INTO v_mode_master_count
    FROM memory_practice_modes mpm
    WHERE mpm.user_id = p_user_id
    AND mpm.success_rate >= 80.0
    AND mpm.times_practiced >= 10;

    IF NOT FOUND THEN
        v_mode_master_count := 0;
    END IF;

    -- Check memory count achievements (1, 5, 25, 50, 100)
    FOR v_achievement IN
        SELECT a.id, a.name_en, a.xp_reward, a.threshold
        FROM achievements a
        WHERE a.category = 'memory'
        AND a.id IN ('memory_first_verse', 'memory_5', 'memory_25', 'memory_50', 'memory_100')
        AND a.threshold <= v_memory_count
        ORDER BY a.threshold
    LOOP
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            out_achievement_id := v_achievement.id;
            out_achievement_name := v_achievement.name_en;
            out_xp_reward := v_achievement.xp_reward;
            out_is_new := TRUE;
            RETURN NEXT;
        END IF;
    END LOOP;

    -- Check perfect recall achievements (1, 50)
    FOR v_achievement IN
        SELECT a.id, a.name_en, a.xp_reward, a.threshold
        FROM achievements a
        WHERE a.category = 'memory'
        AND a.id IN ('memory_perfect_recall', 'memory_perfect_recalls_50')
        AND a.threshold <= v_perfect_recalls
        ORDER BY a.threshold
    LOOP
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            out_achievement_id := v_achievement.id;
            out_achievement_name := v_achievement.name_en;
            out_xp_reward := v_achievement.xp_reward;
            out_is_new := TRUE;
            RETURN NEXT;
        END IF;
    END LOOP;

    -- Check practice streak achievements (3, 7, 30, 100)
    FOR v_achievement IN
        SELECT a.id, a.name_en, a.xp_reward, a.threshold
        FROM achievements a
        WHERE a.category = 'memory'
        AND a.id IN ('memory_practice_streak_3', 'memory_practice_streak_7',
                     'memory_practice_streak_30', 'memory_practice_streak_100')
        AND a.threshold <= v_current_streak
        ORDER BY a.threshold
    LOOP
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            out_achievement_id := v_achievement.id;
            out_achievement_name := v_achievement.name_en;
            out_xp_reward := v_achievement.xp_reward;
            out_is_new := TRUE;
            RETURN NEXT;
        END IF;
    END LOOP;

    -- Check practice mode variety achievements (3, 5)
    FOR v_achievement IN
        SELECT a.id, a.name_en, a.xp_reward, a.threshold
        FROM achievements a
        WHERE a.category = 'memory'
        AND a.id IN ('memory_modes_3', 'memory_modes_5')
        AND a.threshold <= v_modes_tried
        ORDER BY a.threshold
    LOOP
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            out_achievement_id := v_achievement.id;
            out_achievement_name := v_achievement.name_en;
            out_xp_reward := v_achievement.xp_reward;
            out_is_new := TRUE;
            RETURN NEXT;
        END IF;
    END LOOP;

    -- Check mastery level achievements (3 intermediate, 5 advanced, 10 expert)
    IF v_intermediate_mastery_count >= 3 THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, 'memory_mastery_intermediate_3')
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            SELECT a.id, a.name_en, a.xp_reward INTO v_achievement
            FROM achievements a
            WHERE a.id = 'memory_mastery_intermediate_3';

            out_achievement_id := v_achievement.id;
            out_achievement_name := v_achievement.name_en;
            out_xp_reward := v_achievement.xp_reward;
            out_is_new := TRUE;
            RETURN NEXT;
        END IF;
    END IF;

    IF v_advanced_mastery_count >= 5 THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, 'memory_mastery_advanced_5')
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            SELECT a.id, a.name_en, a.xp_reward INTO v_achievement
            FROM achievements a
            WHERE a.id = 'memory_mastery_advanced_5';

            out_achievement_id := v_achievement.id;
            out_achievement_name := v_achievement.name_en;
            out_xp_reward := v_achievement.xp_reward;
            out_is_new := TRUE;
            RETURN NEXT;
        END IF;
    END IF;

    IF v_expert_mastery_count >= 10 THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, 'memory_mastery_expert_10')
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            SELECT a.id, a.name_en, a.xp_reward INTO v_achievement
            FROM achievements a
            WHERE a.id = 'memory_mastery_expert_10';

            out_achievement_id := v_achievement.id;
            out_achievement_name := v_achievement.name_en;
            out_xp_reward := v_achievement.xp_reward;
            out_is_new := TRUE;
            RETURN NEXT;
        END IF;
    END IF;

    -- Check daily goal achievement (5)
    IF v_daily_goals_completed >= 5 THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, 'memory_daily_goal_5')
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            SELECT a.id, a.name_en, a.xp_reward INTO v_achievement
            FROM achievements a
            WHERE a.id = 'memory_daily_goal_5';

            out_achievement_id := v_achievement.id;
            out_achievement_name := v_achievement.name_en;
            out_xp_reward := v_achievement.xp_reward;
            out_is_new := TRUE;
            RETURN NEXT;
        END IF;
    END IF;

    -- Check challenge completion achievement (5)
    IF v_challenges_completed >= 5 THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, 'memory_challenge_champion')
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            SELECT a.id, a.name_en, a.xp_reward INTO v_achievement
            FROM achievements a
            WHERE a.id = 'memory_challenge_champion';

            out_achievement_id := v_achievement.id;
            out_achievement_name := v_achievement.name_en;
            out_xp_reward := v_achievement.xp_reward;
            out_is_new := TRUE;
            RETURN NEXT;
        END IF;
    END IF;

    -- Check collections achievement (5)
    IF v_collections_count >= 5 THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, 'memory_collections_5')
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            SELECT a.id, a.name_en, a.xp_reward INTO v_achievement
            FROM achievements a
            WHERE a.id = 'memory_collections_5';

            out_achievement_id := v_achievement.id;
            out_achievement_name := v_achievement.name_en;
            out_xp_reward := v_achievement.xp_reward;
            out_is_new := TRUE;
            RETURN NEXT;
        END IF;
    END IF;

    -- Check mode master achievement (80%+ in 3 modes)
    IF v_mode_master_count >= 3 THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, 'memory_mode_master')
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            SELECT a.id, a.name_en, a.xp_reward INTO v_achievement
            FROM achievements a
            WHERE a.id = 'memory_mode_master';

            out_achievement_id := v_achievement.id;
            out_achievement_name := v_achievement.name_en;
            out_xp_reward := v_achievement.xp_reward;
            out_is_new := TRUE;
            RETURN NEXT;
        END IF;
    END IF;

EXCEPTION
    WHEN undefined_table THEN
        -- If tables don't exist yet, silently continue with basic achievements only
        NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION check_memory_achievements(UUID) TO authenticated;

COMMENT ON FUNCTION check_memory_achievements IS 'Comprehensive memory achievement checking with fixed output column names to avoid ambiguity. Supports all 20 tiers (Beginner through Expert).';
