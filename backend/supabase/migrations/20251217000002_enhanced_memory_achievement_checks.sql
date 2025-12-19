-- Migration: Enhanced Memory Achievement Checking
-- Created: 2025-12-17
-- Purpose: Update check_memory_achievements function to support new achievement types

BEGIN;

-- =============================================================================
-- FUNCTION: Enhanced Memory Achievement Checking
-- =============================================================================
-- Supports checking for:
-- - Memory verse count achievements (memory_first_verse, memory_5, memory_25)
-- - Perfect recall achievements (memory_perfect_recall)
-- - Practice streak achievements (memory_practice_streak_3, memory_practice_streak_7)
-- - Practice mode variety achievements (memory_modes_3, memory_modes_5)
-- - Mastery level achievements (memory_mastery_intermediate_3)
-- - Daily goal achievements (memory_daily_goal_5)

CREATE OR REPLACE FUNCTION check_memory_achievements(p_user_id UUID)
RETURNS TABLE (
    achievement_id TEXT,
    achievement_name TEXT,
    xp_reward INTEGER,
    is_new BOOLEAN
) AS $$
DECLARE
    v_memory_count INTEGER;
    v_perfect_recalls INTEGER;
    v_current_streak INTEGER;
    v_modes_tried INTEGER;
    v_intermediate_mastery_count INTEGER;
    v_daily_goals_completed INTEGER;
    v_achievement RECORD;
BEGIN
    -- Get memory verses count
    SELECT COUNT(*) INTO v_memory_count
    FROM memory_verses
    WHERE user_id = p_user_id;

    -- Get perfect recalls count (quality = 5)
    SELECT COUNT(*) INTO v_perfect_recalls
    FROM review_sessions
    WHERE user_id = p_user_id AND quality_rating = 5;

    -- Get current practice streak (if memory_verse_streaks table exists)
    SELECT COALESCE(current_streak, 0) INTO v_current_streak
    FROM memory_verse_streaks
    WHERE user_id = p_user_id
    LIMIT 1;

    -- If table doesn't exist or no record, default to 0
    IF NOT FOUND THEN
        v_current_streak := 0;
    END IF;

    -- Get number of different practice modes tried (if memory_practice_modes table exists)
    SELECT COUNT(DISTINCT mode_type) INTO v_modes_tried
    FROM memory_practice_modes
    WHERE user_id = p_user_id AND times_practiced > 0;

    -- If table doesn't exist or no records, default to 0
    IF NOT FOUND THEN
        v_modes_tried := 0;
    END IF;

    -- Get verses at intermediate mastery or higher (if memory_verse_mastery table exists)
    SELECT COUNT(*) INTO v_intermediate_mastery_count
    FROM memory_verse_mastery
    WHERE user_id = p_user_id
    AND mastery_level IN ('intermediate', 'advanced', 'expert', 'master');

    -- If table doesn't exist or no records, default to 0
    IF NOT FOUND THEN
        v_intermediate_mastery_count := 0;
    END IF;

    -- Get daily goals completed count (if memory_daily_goals table exists)
    SELECT COUNT(*) INTO v_daily_goals_completed
    FROM memory_daily_goals
    WHERE user_id = p_user_id AND goal_achieved = TRUE;

    -- If table doesn't exist or no records, default to 0
    IF NOT FOUND THEN
        v_daily_goals_completed := 0;
    END IF;

    -- Check memory count achievements
    FOR v_achievement IN
        SELECT a.id, a.name_en, a.xp_reward, a.threshold
        FROM achievements a
        WHERE a.category = 'memory'
        AND a.id IN ('memory_first_verse', 'memory_5', 'memory_25')
        AND a.threshold <= v_memory_count
        ORDER BY a.threshold
    LOOP
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END LOOP;

    -- Check perfect recall achievement
    IF v_perfect_recalls >= 1 THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, 'memory_perfect_recall')
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            SELECT a.id, a.name_en, a.xp_reward INTO v_achievement
            FROM achievements a
            WHERE a.id = 'memory_perfect_recall';

            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END IF;

    -- Check practice streak achievements
    FOR v_achievement IN
        SELECT a.id, a.name_en, a.xp_reward, a.threshold
        FROM achievements a
        WHERE a.category = 'memory'
        AND a.id IN ('memory_practice_streak_3', 'memory_practice_streak_7')
        AND a.threshold <= v_current_streak
        ORDER BY a.threshold
    LOOP
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END LOOP;

    -- Check practice mode variety achievements
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
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END LOOP;

    -- Check mastery level achievements
    IF v_intermediate_mastery_count >= 3 THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, 'memory_mastery_intermediate_3')
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            SELECT a.id, a.name_en, a.xp_reward INTO v_achievement
            FROM achievements a
            WHERE a.id = 'memory_mastery_intermediate_3';

            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END IF;

    -- Check daily goal achievements
    IF v_daily_goals_completed >= 5 THEN
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, 'memory_daily_goal_5')
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            SELECT a.id, a.name_en, a.xp_reward INTO v_achievement
            FROM achievements a
            WHERE a.id = 'memory_daily_goal_5';

            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END IF;

EXCEPTION
    WHEN undefined_table THEN
        -- If memory_verse_streaks, memory_practice_modes, memory_verse_mastery,
        -- or memory_daily_goals tables don't exist yet, silently continue with
        -- basic memory count achievements only
        NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION check_memory_achievements(UUID) TO authenticated;

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON FUNCTION check_memory_achievements IS 'Enhanced memory achievement checking supporting verse count, perfect recalls, practice streaks, mode variety, mastery levels, and daily goals. Gracefully handles missing tables for progressive implementation.';

COMMIT;
