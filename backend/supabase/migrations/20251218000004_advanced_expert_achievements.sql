-- Migration: Memory Verses Enhancement - Advanced & Expert Achievement Tiers
-- Created: 2025-12-18
-- Purpose: Add 10 Advanced and Expert tier achievements for memory verses

BEGIN;

-- =============================================================================
-- INSERT: 10 Advanced & Expert Tier Achievements
-- =============================================================================

INSERT INTO achievements (id, name_en, name_hi, name_ml, description_en, description_hi, description_ml, icon, xp_reward, category, threshold, sort_order)
VALUES
    -- Advanced Tier Achievements
    ('memory_practice_streak_30', 'Month of Memory', 'मेमोरी का महीना', 'മെമ്മറിയുടെ മാസം', 'Practice memory verses 30 days in a row', 'लगातार 30 दिन याद के पद का अभ्यास करें', 'തുടർച്ചയായി 30 ദിവസം മെമ്മറി വാക്യങ്ങൾ പരിശീലിക്കുക', '📆', 500, 'memory', 30, 21),

    ('memory_mode_master', 'Mode Master', 'मोड मास्टर', 'മോഡ് മാസ്റ്റർ', '80%+ success rate in 3 practice modes', '3 अभ्यास मोड में 80%+ सफलता दर', '3 പരിശീലന മോഡുകളിൽ 80%+ വിജയ നിരക്ക്', '🎖️', 400, 'memory', 3, 22),

    ('memory_mastery_advanced_5', 'Advanced Scholar', 'उन्नत विद्वान', 'മുന്നേറിയ പണ്ഡിതൻ', 'Reach Advanced mastery on 5 verses', '5 पदों पर उन्नत स्तर की महारत हासिल करें', '5 വാക്യങ്ങളിൽ അഡ്വാൻസ്ഡ് വൈദഗ്ധ്യം നേടുക', '🎓', 500, 'memory', 5, 23),

    ('memory_challenge_champion', 'Challenge Champion', 'चुनौती चैंपियन', 'വെല്ലുവിളി ചാമ്പ്യൻ', 'Complete 5 weekly memory challenges', '5 साप्ताहिक याद चुनौतियाँ पूरी करें', '5 പ്രതിവാര മെമ്മറി വെല്ലുവിളികൾ പൂർത്തിയാക്കുക', '🏆', 400, 'memory', 5, 24),

    ('memory_50', 'Scripture Vault', 'वचन तिजोरी', 'തിരുവചന ഭണ്ഡാരം', 'Memorize 50 verses', '50 पद याद करें', '50 വാക്യങ്ങൾ മനഃപാഠമാക്കുക', '🔐', 600, 'memory', 50, 25),

    -- Expert Tier Achievements
    ('memory_practice_streak_100', 'Century Streak', 'शताब्दी स्ट्रीक', 'നൂറ് ദിവസ സ്ട്രീക്ക്', 'Practice memory verses 100 days in a row', 'लगातार 100 दिन याद के पद का अभ्यास करें', 'തുടർച്ചയായി 100 ദിവസം മെമ്മറി വാക്യങ്ങൾ പരിശീലിക്കുക', '💯', 1000, 'memory', 100, 26),

    ('memory_perfect_recalls_50', 'Perfectionist', 'परफेक्शनिस्ट', 'തികവുള്ളവൻ', 'Achieve 50 perfect recalls (quality 5)', '50 सटीक याद प्राप्त करें', '50 തികഞ്ഞ ഓർമ്മകൾ നേടുക', '💎', 800, 'memory', 50, 27),

    ('memory_mastery_expert_10', 'Expert Memorizer', 'विशेषज्ञ याद करने वाला', 'വിദഗ്ധ മനഃപാഠക്കാരൻ', 'Reach Expert mastery on 10 verses', '10 पदों पर विशेषज्ञ स्तर की महारत हासिल करें', '10 വാക്യങ്ങളിൽ വിദഗ്ധ വൈദഗ്ധ്യം നേടുക', '🏅', 1000, 'memory', 10, 28),

    ('memory_collections_5', 'Collection Curator', 'संग्रह क्यूरेटर', 'ശേഖരണ ക്യൂറേറ്റർ', 'Create 5 verse collections', '5 पद संग्रह बनाएँ', '5 വാക്യ ശേഖരണങ്ങൾ സൃഷ്ടിക്കുക', '📚', 500, 'memory', 5, 29),

    ('memory_100', 'Scripture Library', 'वचन पुस्तकालय', 'തിരുവചന ലൈബ്രറി', 'Memorize 100 verses', '100 पद याद करें', '100 വാക്യങ്ങൾ മനഃപാഠമാക്കുക', '📖', 1200, 'memory', 100, 30)

ON CONFLICT (id) DO UPDATE SET
    name_en = EXCLUDED.name_en,
    name_hi = EXCLUDED.name_hi,
    name_ml = EXCLUDED.name_ml,
    description_en = EXCLUDED.description_en,
    description_hi = EXCLUDED.description_hi,
    description_ml = EXCLUDED.description_ml,
    icon = EXCLUDED.icon,
    xp_reward = EXCLUDED.xp_reward,
    category = EXCLUDED.category,
    threshold = EXCLUDED.threshold,
    sort_order = EXCLUDED.sort_order;

-- =============================================================================
-- UPDATE: Enhanced Achievement Check Function
-- =============================================================================
-- Extend check_memory_achievements to include Advanced/Expert tier checks

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
    FROM memory_verses
    WHERE user_id = p_user_id;

    -- Get perfect recalls count (quality = 5)
    SELECT COUNT(*) INTO v_perfect_recalls
    FROM review_sessions
    WHERE user_id = p_user_id AND quality_rating = 5;

    -- Get current practice streak
    SELECT COALESCE(current_streak, 0) INTO v_current_streak
    FROM memory_verse_streaks
    WHERE user_id = p_user_id
    LIMIT 1;

    IF NOT FOUND THEN
        v_current_streak := 0;
    END IF;

    -- Get number of different practice modes tried
    SELECT COUNT(DISTINCT mode_type) INTO v_modes_tried
    FROM memory_practice_modes
    WHERE user_id = p_user_id AND times_practiced > 0;

    IF NOT FOUND THEN
        v_modes_tried := 0;
    END IF;

    -- Get verses at intermediate mastery or higher
    SELECT COUNT(*) INTO v_intermediate_mastery_count
    FROM memory_verse_mastery
    WHERE user_id = p_user_id
    AND mastery_level IN ('intermediate', 'advanced', 'expert', 'master');

    IF NOT FOUND THEN
        v_intermediate_mastery_count := 0;
    END IF;

    -- Get verses at advanced mastery or higher (NEW)
    SELECT COUNT(*) INTO v_advanced_mastery_count
    FROM memory_verse_mastery
    WHERE user_id = p_user_id
    AND mastery_level IN ('advanced', 'expert', 'master');

    IF NOT FOUND THEN
        v_advanced_mastery_count := 0;
    END IF;

    -- Get verses at expert mastery or higher (NEW)
    SELECT COUNT(*) INTO v_expert_mastery_count
    FROM memory_verse_mastery
    WHERE user_id = p_user_id
    AND mastery_level IN ('expert', 'master');

    IF NOT FOUND THEN
        v_expert_mastery_count := 0;
    END IF;

    -- Get daily goals completed count
    SELECT COUNT(*) INTO v_daily_goals_completed
    FROM memory_daily_goals
    WHERE user_id = p_user_id AND goal_achieved = TRUE;

    IF NOT FOUND THEN
        v_daily_goals_completed := 0;
    END IF;

    -- Get completed challenges count (NEW)
    SELECT COUNT(*) INTO v_challenges_completed
    FROM user_challenge_progress
    WHERE user_id = p_user_id AND is_completed = TRUE;

    IF NOT FOUND THEN
        v_challenges_completed := 0;
    END IF;

    -- Get verse collections count (NEW)
    SELECT COUNT(*) INTO v_collections_count
    FROM memory_verse_collections
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        v_collections_count := 0;
    END IF;

    -- Get modes with 80%+ success rate (NEW)
    SELECT COUNT(*) INTO v_mode_master_count
    FROM memory_practice_modes
    WHERE user_id = p_user_id
    AND success_rate >= 80.0
    AND times_practiced >= 10; -- Minimum 10 attempts for reliability

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
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
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
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
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
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
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
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
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

            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
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

            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
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

            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
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

            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
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

            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
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

            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
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

            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END IF;

EXCEPTION
    WHEN undefined_table THEN
        -- If tables don't exist yet, silently continue with basic achievements only
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

COMMENT ON FUNCTION check_memory_achievements IS 'Comprehensive memory achievement checking supporting all 20 tiers (Beginner through Expert): verse count, perfect recalls, practice streaks, mode variety, mastery levels, daily goals, challenges, and collections. Gracefully handles missing tables for progressive implementation.';

COMMIT;
