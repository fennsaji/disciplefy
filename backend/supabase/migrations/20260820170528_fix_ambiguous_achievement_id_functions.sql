-- Fix 42702 "column reference achievement_id is ambiguous" errors.
--
-- check_study_achievements was already fixed (table alias + ON CONFLICT ON
-- CONSTRAINT) in 20260119000700_gamification.sql. These three sibling
-- functions still use the unqualified INSERT ... ON CONFLICT (user_id,
-- achievement_id) form, which Postgres can't disambiguate from the
-- RETURNS TABLE (achievement_id TEXT, ...) output column of the same name.

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
BEGIN
    -- Get current study streak
    SELECT current_streak INTO v_current_streak
    FROM user_study_streaks
    WHERE user_id = p_user_id;

    IF v_current_streak IS NULL THEN
        v_current_streak := 0;
    END IF;

    -- Check each streak achievement
    FOR v_achievement IN
        SELECT a.id, a.name_en, a.xp_reward, a.threshold
        FROM achievements a
        WHERE a.category = 'streak'
        AND a.threshold <= v_current_streak
        ORDER BY a.threshold
    LOOP
        -- Use table alias + constraint name to avoid ambiguity with RETURNS TABLE columns
        INSERT INTO user_achievements AS ua (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT ON CONSTRAINT unique_user_achievement DO NOTHING;

        -- Check if it was newly inserted
        IF FOUND THEN
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
BEGIN
    -- Get completed voice sessions count
    SELECT COUNT(*) INTO v_voice_count
    FROM voice_conversations
    WHERE user_id = p_user_id AND status = 'completed';

    -- Check each voice achievement
    FOR v_achievement IN
        SELECT a.id, a.name_en, a.xp_reward, a.threshold
        FROM achievements a
        WHERE a.category = 'voice'
        AND a.threshold <= v_voice_count
        ORDER BY a.threshold
    LOOP
        INSERT INTO user_achievements AS ua (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT ON CONSTRAINT unique_user_achievement DO NOTHING;

        IF FOUND THEN
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
BEGIN
    -- Get saved guides count
    SELECT COUNT(*) INTO v_saved_count
    FROM user_study_guides
    WHERE user_id = p_user_id AND is_saved = TRUE;

    -- Check each saved achievement
    FOR v_achievement IN
        SELECT a.id, a.name_en, a.xp_reward, a.threshold
        FROM achievements a
        WHERE a.category = 'saved'
        AND a.threshold <= v_saved_count
        ORDER BY a.threshold
    LOOP
        INSERT INTO user_achievements AS ua (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT ON CONSTRAINT unique_user_achievement DO NOTHING;

        IF FOUND THEN
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION check_streak_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_voice_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_saved_achievements(UUID) TO authenticated;

COMMENT ON FUNCTION check_streak_achievements IS 'Checks and awards achievements based on current study streak. Fixed 42702 ambiguous achievement_id (2026-08-20).';
COMMENT ON FUNCTION check_voice_achievements IS 'Checks and awards achievements based on completed voice conversation sessions with AI Study Buddy. Fixed 42702 ambiguous achievement_id (2026-08-20).';
COMMENT ON FUNCTION check_saved_achievements IS 'Checks and awards achievements based on saved guides count. Fixed 42702 ambiguous achievement_id (2026-08-20).';
