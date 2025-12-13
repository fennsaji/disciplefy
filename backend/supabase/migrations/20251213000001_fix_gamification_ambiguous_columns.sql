-- Migration: Fix ambiguous column references in gamification functions
-- Created: 2025-12-13
-- Purpose: Fix PGRST202 errors due to ambiguous column references

BEGIN;

-- =============================================================================
-- FIX: update_study_streak - ambiguous user_id reference
-- =============================================================================

CREATE OR REPLACE FUNCTION update_study_streak(p_user_id UUID)
RETURNS TABLE (
    current_streak INTEGER,
    longest_streak INTEGER,
    streak_increased BOOLEAN,
    is_new_record BOOLEAN
) AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_last_date DATE;
    v_current INTEGER;
    v_longest INTEGER;
    v_streak_increased BOOLEAN := FALSE;
    v_is_new_record BOOLEAN := FALSE;
BEGIN
    -- Get or create streak record
    PERFORM get_or_create_study_streak(p_user_id);

    -- Get current values (use table alias to avoid ambiguity)
    SELECT uss.last_study_date, uss.current_streak, uss.longest_streak
    INTO v_last_date, v_current, v_longest
    FROM user_study_streaks uss
    WHERE uss.user_id = p_user_id;

    -- Only process if not already studied today
    IF v_last_date IS NULL OR v_last_date < v_today THEN
        IF v_last_date IS NULL OR v_last_date = v_today - 1 THEN
            -- Consecutive day - increment streak
            v_current := v_current + 1;
            v_streak_increased := TRUE;
        ELSIF v_last_date < v_today - 1 THEN
            -- Streak broken - reset to 1
            v_current := 1;
            v_streak_increased := TRUE;
        END IF;

        -- Check for new record
        IF v_current > v_longest THEN
            v_longest := v_current;
            v_is_new_record := TRUE;
        END IF;

        -- Update the record (use table alias)
        UPDATE user_study_streaks uss
        SET 
            current_streak = v_current,
            longest_streak = v_longest,
            last_study_date = v_today,
            total_study_days = uss.total_study_days + 1,
            updated_at = NOW()
        WHERE uss.user_id = p_user_id;
    END IF;

    RETURN QUERY SELECT v_current, v_longest, v_streak_increased, v_is_new_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: check_study_achievements - ambiguous achievement_id reference
-- =============================================================================

CREATE OR REPLACE FUNCTION check_study_achievements(p_user_id UUID)
RETURNS TABLE (
    achievement_id TEXT,
    achievement_name TEXT,
    xp_reward INTEGER,
    is_new BOOLEAN
) AS $$
DECLARE
    v_study_count INTEGER;
    v_achievement RECORD;
    v_inserted BOOLEAN;
BEGIN
    -- Get total completed studies count
    SELECT COUNT(*) INTO v_study_count
    FROM user_topic_progress utp
    WHERE utp.user_id = p_user_id AND utp.completed_at IS NOT NULL;

    -- Also count user-generated study guides
    v_study_count := v_study_count + (
        SELECT COUNT(*) FROM user_study_guides usg
        WHERE usg.user_id = p_user_id AND usg.completed_at IS NOT NULL
    );

    -- Check each study achievement
    FOR v_achievement IN 
        SELECT a.id AS aid, a.name_en, a.xp_reward AS axp, a.threshold
        FROM achievements a
        WHERE a.category = 'study'
        AND a.threshold <= v_study_count
        ORDER BY a.threshold
    LOOP
        -- Check if achievement already exists
        SELECT EXISTS(
            SELECT 1 FROM user_achievements ua 
            WHERE ua.user_id = p_user_id AND ua.achievement_id = v_achievement.aid
        ) INTO v_inserted;

        -- If not exists, insert it
        IF NOT v_inserted THEN
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (p_user_id, v_achievement.aid);
            
            RETURN QUERY SELECT v_achievement.aid, v_achievement.name_en, v_achievement.axp, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: check_streak_achievements - ambiguous references
-- =============================================================================

CREATE OR REPLACE FUNCTION check_streak_achievements(p_user_id UUID)
RETURNS TABLE (
    achievement_id TEXT,
    achievement_name TEXT,
    xp_reward INTEGER,
    is_new BOOLEAN
) AS $$
DECLARE
    v_current_streak INTEGER;
    v_achievement RECORD;
    v_inserted BOOLEAN;
BEGIN
    -- Get current study streak (use table alias)
    SELECT uss.current_streak INTO v_current_streak
    FROM user_study_streaks uss
    WHERE uss.user_id = p_user_id;

    IF v_current_streak IS NULL THEN
        v_current_streak := 0;
    END IF;

    -- Check each streak achievement
    FOR v_achievement IN 
        SELECT a.id AS aid, a.name_en, a.xp_reward AS axp, a.threshold
        FROM achievements a
        WHERE a.category = 'streak'
        AND a.threshold <= v_current_streak
        ORDER BY a.threshold
    LOOP
        -- Check if achievement already exists
        SELECT EXISTS(
            SELECT 1 FROM user_achievements ua 
            WHERE ua.user_id = p_user_id AND ua.achievement_id = v_achievement.aid
        ) INTO v_inserted;

        -- If not exists, insert it
        IF NOT v_inserted THEN
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (p_user_id, v_achievement.aid);
            
            RETURN QUERY SELECT v_achievement.aid, v_achievement.name_en, v_achievement.axp, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: check_memory_achievements - ambiguous references
-- =============================================================================

CREATE OR REPLACE FUNCTION check_memory_achievements(p_user_id UUID)
RETURNS TABLE (
    achievement_id TEXT,
    achievement_name TEXT,
    xp_reward INTEGER,
    is_new BOOLEAN
) AS $$
DECLARE
    v_memory_count INTEGER;
    v_achievement RECORD;
    v_inserted BOOLEAN;
BEGIN
    -- Get memory verses count (use table alias)
    SELECT COUNT(*) INTO v_memory_count
    FROM memory_verses mv
    WHERE mv.user_id = p_user_id;

    -- Check each memory achievement
    FOR v_achievement IN 
        SELECT a.id AS aid, a.name_en, a.xp_reward AS axp, a.threshold
        FROM achievements a
        WHERE a.category = 'memory'
        AND a.threshold <= v_memory_count
        ORDER BY a.threshold
    LOOP
        -- Check if achievement already exists
        SELECT EXISTS(
            SELECT 1 FROM user_achievements ua 
            WHERE ua.user_id = p_user_id AND ua.achievement_id = v_achievement.aid
        ) INTO v_inserted;

        -- If not exists, insert it
        IF NOT v_inserted THEN
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (p_user_id, v_achievement.aid);
            
            RETURN QUERY SELECT v_achievement.aid, v_achievement.name_en, v_achievement.axp, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: check_voice_achievements - ambiguous references
-- =============================================================================

CREATE OR REPLACE FUNCTION check_voice_achievements(p_user_id UUID)
RETURNS TABLE (
    achievement_id TEXT,
    achievement_name TEXT,
    xp_reward INTEGER,
    is_new BOOLEAN
) AS $$
DECLARE
    v_voice_count INTEGER;
    v_achievement RECORD;
    v_inserted BOOLEAN;
BEGIN
    -- Get completed voice sessions count (use table alias)
    SELECT COUNT(*) INTO v_voice_count
    FROM voice_conversations vc
    WHERE vc.user_id = p_user_id AND vc.status = 'completed';

    -- Check each voice achievement
    FOR v_achievement IN 
        SELECT a.id AS aid, a.name_en, a.xp_reward AS axp, a.threshold
        FROM achievements a
        WHERE a.category = 'voice'
        AND a.threshold <= v_voice_count
        ORDER BY a.threshold
    LOOP
        -- Check if achievement already exists
        SELECT EXISTS(
            SELECT 1 FROM user_achievements ua 
            WHERE ua.user_id = p_user_id AND ua.achievement_id = v_achievement.aid
        ) INTO v_inserted;

        -- If not exists, insert it
        IF NOT v_inserted THEN
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (p_user_id, v_achievement.aid);
            
            RETURN QUERY SELECT v_achievement.aid, v_achievement.name_en, v_achievement.axp, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: check_saved_achievements - ambiguous references
-- =============================================================================

CREATE OR REPLACE FUNCTION check_saved_achievements(p_user_id UUID)
RETURNS TABLE (
    achievement_id TEXT,
    achievement_name TEXT,
    xp_reward INTEGER,
    is_new BOOLEAN
) AS $$
DECLARE
    v_saved_count INTEGER;
    v_achievement RECORD;
    v_inserted BOOLEAN;
BEGIN
    -- Get saved guides count (use table alias)
    SELECT COUNT(*) INTO v_saved_count
    FROM user_study_guides usg
    WHERE usg.user_id = p_user_id AND usg.is_saved = TRUE;

    -- Check each saved achievement
    FOR v_achievement IN 
        SELECT a.id AS aid, a.name_en, a.xp_reward AS axp, a.threshold
        FROM achievements a
        WHERE a.category = 'saved'
        AND a.threshold <= v_saved_count
        ORDER BY a.threshold
    LOOP
        -- Check if achievement already exists
        SELECT EXISTS(
            SELECT 1 FROM user_achievements ua 
            WHERE ua.user_id = p_user_id AND ua.achievement_id = v_achievement.aid
        ) INTO v_inserted;

        -- If not exists, insert it
        IF NOT v_inserted THEN
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (p_user_id, v_achievement.aid);
            
            RETURN QUERY SELECT v_achievement.aid, v_achievement.name_en, v_achievement.axp, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
