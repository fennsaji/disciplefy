-- =====================================================
-- Migration: Fix check_memory_achievements column names
-- =====================================================
-- The check_memory_achievements function returns columns with 'out_' prefix
-- (out_achievement_id, out_achievement_name, out_xp_reward, out_is_new)
-- but all callers (both backend TypeScript and frontend Dart) expect
-- non-prefixed names (achievement_id, achievement_name, xp_reward, is_new),
-- matching check_voice_achievements and check_saved_achievements.
-- This mismatch causes all memory achievements to silently fail.

BEGIN;

-- Must DROP first because the existing function has different OUT parameter names
-- (out_achievement_id, etc.) and PostgreSQL cannot change return type with CREATE OR REPLACE
DROP FUNCTION IF EXISTS check_memory_achievements(UUID);

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
    FROM memory_verses mv
    WHERE mv.user_id = p_user_id;

    -- Get perfect recalls count (quality = 5)
    SELECT COUNT(*) INTO v_perfect_recalls
    FROM review_sessions ps
    WHERE ps.user_id = p_user_id AND ps.quality_rating = 5;

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
            achievement_id := v_achievement.id;
            achievement_name := v_achievement.name_en;
            xp_reward := v_achievement.xp_reward;
            is_new := TRUE;
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
            achievement_id := v_achievement.id;
            achievement_name := v_achievement.name_en;
            xp_reward := v_achievement.xp_reward;
            is_new := TRUE;
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
            achievement_id := v_achievement.id;
            achievement_name := v_achievement.name_en;
            xp_reward := v_achievement.xp_reward;
            is_new := TRUE;
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
            achievement_id := v_achievement.id;
            achievement_name := v_achievement.name_en;
            xp_reward := v_achievement.xp_reward;
            is_new := TRUE;
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

            achievement_id := v_achievement.id;
            achievement_name := v_achievement.name_en;
            xp_reward := v_achievement.xp_reward;
            is_new := TRUE;
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

            achievement_id := v_achievement.id;
            achievement_name := v_achievement.name_en;
            xp_reward := v_achievement.xp_reward;
            is_new := TRUE;
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

            achievement_id := v_achievement.id;
            achievement_name := v_achievement.name_en;
            xp_reward := v_achievement.xp_reward;
            is_new := TRUE;
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

            achievement_id := v_achievement.id;
            achievement_name := v_achievement.name_en;
            xp_reward := v_achievement.xp_reward;
            is_new := TRUE;
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

            achievement_id := v_achievement.id;
            achievement_name := v_achievement.name_en;
            xp_reward := v_achievement.xp_reward;
            is_new := TRUE;
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

            achievement_id := v_achievement.id;
            achievement_name := v_achievement.name_en;
            xp_reward := v_achievement.xp_reward;
            is_new := TRUE;
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

            achievement_id := v_achievement.id;
            achievement_name := v_achievement.name_en;
            xp_reward := v_achievement.xp_reward;
            is_new := TRUE;
            RETURN NEXT;
        END IF;
    END IF;

EXCEPTION
    WHEN undefined_table THEN
        -- If tables don't exist yet, silently continue with basic achievements only
        NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION check_memory_achievements IS 'Comprehensive memory achievement checking. Fixed column names to match check_voice_achievements and check_saved_achievements (no out_ prefix).';

-- =====================================================
-- Fix get_user_gamification_stats to include achievement XP
-- =====================================================
-- Previously total_xp only summed user_topic_progress.xp_earned (study topics).
-- Now it also adds XP rewards from unlocked achievements.

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
                ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(utp.xp_earned), 0) DESC)::BIGINT AS rank
            FROM user_profiles up
            LEFT JOIN user_topic_progress utp ON up.id = utp.user_id
            GROUP BY up.id
            HAVING COALESCE(SUM(utp.xp_earned), 0) >= 200
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

COMMENT ON FUNCTION get_user_gamification_stats IS 'Returns all gamification data for stats dashboard: XP (study + achievement), rank, streaks, counts, achievements. Single comprehensive query for frontend display.';

COMMIT;
