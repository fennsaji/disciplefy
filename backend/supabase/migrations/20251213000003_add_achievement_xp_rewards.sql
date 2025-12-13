-- Migration: Add Achievement XP Rewards to User Totals
-- Created: 2025-12-13
-- Purpose: Fix bug where achievement XP rewards are returned but never actually awarded
-- 
-- Problem: check_*_achievements functions return xp_reward but never add it to user totals
-- Solution: Add achievement_xp column to user_study_streaks and update functions to award XP

BEGIN;

-- =============================================================================
-- SCHEMA CHANGE: Add achievement_xp column to user_study_streaks
-- =============================================================================

ALTER TABLE user_study_streaks 
ADD COLUMN IF NOT EXISTS achievement_xp INTEGER NOT NULL DEFAULT 0 
CHECK (achievement_xp >= 0);

COMMENT ON COLUMN user_study_streaks.achievement_xp IS 'Total XP earned from achievement unlocks';

-- =============================================================================
-- FIX: check_study_achievements - Award XP when unlocking
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
    v_was_inserted BOOLEAN;
BEGIN
    -- Get total completed studies count (use table aliases)
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
        IF NOT EXISTS (
            SELECT 1 FROM user_achievements ua 
            WHERE ua.user_id = p_user_id AND ua.achievement_id = v_achievement.aid
        ) THEN
            -- Insert the achievement
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (p_user_id, v_achievement.aid);
            
            -- Award XP to user's achievement_xp total
            UPDATE user_study_streaks uss
            SET achievement_xp = uss.achievement_xp + v_achievement.axp,
                updated_at = NOW()
            WHERE uss.user_id = p_user_id;
            
            -- If user doesn't have a streak record yet, create one with the XP
            IF NOT FOUND THEN
                INSERT INTO user_study_streaks (user_id, achievement_xp)
                VALUES (p_user_id, v_achievement.axp)
                ON CONFLICT (user_id) DO UPDATE
                SET achievement_xp = user_study_streaks.achievement_xp + v_achievement.axp,
                    updated_at = NOW();
            END IF;
            
            RETURN QUERY SELECT v_achievement.aid, v_achievement.name_en, v_achievement.axp, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: check_streak_achievements - Award XP when unlocking
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
        IF NOT EXISTS (
            SELECT 1 FROM user_achievements ua 
            WHERE ua.user_id = p_user_id AND ua.achievement_id = v_achievement.aid
        ) THEN
            -- Insert the achievement
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (p_user_id, v_achievement.aid);
            
            -- Award XP to user's achievement_xp total
            UPDATE user_study_streaks uss
            SET achievement_xp = uss.achievement_xp + v_achievement.axp,
                updated_at = NOW()
            WHERE uss.user_id = p_user_id;
            
            RETURN QUERY SELECT v_achievement.aid, v_achievement.name_en, v_achievement.axp, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: check_memory_achievements - Award XP when unlocking
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
        IF NOT EXISTS (
            SELECT 1 FROM user_achievements ua 
            WHERE ua.user_id = p_user_id AND ua.achievement_id = v_achievement.aid
        ) THEN
            -- Insert the achievement
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (p_user_id, v_achievement.aid);
            
            -- Award XP to user's achievement_xp total
            -- Need to ensure user has a streak record first
            INSERT INTO user_study_streaks (user_id, achievement_xp)
            VALUES (p_user_id, v_achievement.axp)
            ON CONFLICT (user_id) DO UPDATE
            SET achievement_xp = user_study_streaks.achievement_xp + v_achievement.axp,
                updated_at = NOW();
            
            RETURN QUERY SELECT v_achievement.aid, v_achievement.name_en, v_achievement.axp, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: check_voice_achievements - Award XP when unlocking
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
        IF NOT EXISTS (
            SELECT 1 FROM user_achievements ua 
            WHERE ua.user_id = p_user_id AND ua.achievement_id = v_achievement.aid
        ) THEN
            -- Insert the achievement
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (p_user_id, v_achievement.aid);
            
            -- Award XP to user's achievement_xp total
            INSERT INTO user_study_streaks (user_id, achievement_xp)
            VALUES (p_user_id, v_achievement.axp)
            ON CONFLICT (user_id) DO UPDATE
            SET achievement_xp = user_study_streaks.achievement_xp + v_achievement.axp,
                updated_at = NOW();
            
            RETURN QUERY SELECT v_achievement.aid, v_achievement.name_en, v_achievement.axp, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: check_saved_achievements - Award XP when unlocking
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
        IF NOT EXISTS (
            SELECT 1 FROM user_achievements ua 
            WHERE ua.user_id = p_user_id AND ua.achievement_id = v_achievement.aid
        ) THEN
            -- Insert the achievement
            INSERT INTO user_achievements (user_id, achievement_id)
            VALUES (p_user_id, v_achievement.aid);
            
            -- Award XP to user's achievement_xp total
            INSERT INTO user_study_streaks (user_id, achievement_xp)
            VALUES (p_user_id, v_achievement.axp)
            ON CONFLICT (user_id) DO UPDATE
            SET achievement_xp = user_study_streaks.achievement_xp + v_achievement.axp,
                updated_at = NOW();
            
            RETURN QUERY SELECT v_achievement.aid, v_achievement.name_en, v_achievement.axp, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: get_user_gamification_stats - Include achievement_xp in total
-- =============================================================================

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
    WITH xp_data AS (
        SELECT 
            COALESCE(SUM(utp.xp_earned), 0)::BIGINT + 
            COALESCE((SELECT uss.achievement_xp FROM user_study_streaks uss WHERE uss.user_id = p_user_id), 0)::BIGINT AS xp
        FROM user_topic_progress utp
        WHERE utp.user_id = p_user_id
    ),
    rank_data AS (
        SELECT r.rank
        FROM (
            SELECT 
                up.id,
                ROW_NUMBER() OVER (
                    ORDER BY (
                        COALESCE(SUM(utp.xp_earned), 0) + 
                        COALESCE((SELECT uss.achievement_xp FROM user_study_streaks uss WHERE uss.user_id = up.id), 0)
                    ) DESC
                )::BIGINT AS rank
            FROM user_profiles up
            LEFT JOIN user_topic_progress utp ON up.id = utp.user_id
            GROUP BY up.id
            HAVING (
                COALESCE(SUM(utp.xp_earned), 0) + 
                COALESCE((SELECT uss.achievement_xp FROM user_study_streaks uss WHERE uss.user_id = up.id), 0)
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

-- =============================================================================
-- FIX: get_leaderboard - Include achievement_xp in ranking
-- =============================================================================

CREATE OR REPLACE FUNCTION get_leaderboard(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    user_id UUID,
    display_name TEXT,
    total_xp BIGINT,
    rank BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        up.id AS user_id,
        COALESCE(up.first_name || ' ' || LEFT(up.last_name, 1) || '.', 'Anonymous') AS display_name,
        (COALESCE(SUM(utp.xp_earned), 0) + 
         COALESCE((SELECT uss.achievement_xp FROM user_study_streaks uss WHERE uss.user_id = up.id), 0))::BIGINT AS total_xp,
        ROW_NUMBER() OVER (
            ORDER BY (
                COALESCE(SUM(utp.xp_earned), 0) + 
                COALESCE((SELECT uss.achievement_xp FROM user_study_streaks uss WHERE uss.user_id = up.id), 0)
            ) DESC
        )::BIGINT AS rank
    FROM user_profiles up
    LEFT JOIN user_topic_progress utp ON up.id = utp.user_id
    GROUP BY up.id, up.first_name, up.last_name
    HAVING (
        COALESCE(SUM(utp.xp_earned), 0) + 
        COALESCE((SELECT uss.achievement_xp FROM user_study_streaks uss WHERE uss.user_id = up.id), 0)
    ) >= 200
    ORDER BY total_xp DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FIX: get_user_xp_rank - Include achievement_xp in total
-- =============================================================================

CREATE OR REPLACE FUNCTION get_user_xp_rank(p_user_id UUID)
RETURNS TABLE (
    total_xp BIGINT,
    rank BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH user_xp_totals AS (
        SELECT
            up.id,
            (COALESCE(SUM(utp.xp_earned), 0) + 
             COALESCE((SELECT uss.achievement_xp FROM user_study_streaks uss WHERE uss.user_id = up.id), 0))::BIGINT AS xp
        FROM user_profiles up
        LEFT JOIN user_topic_progress utp ON up.id = utp.user_id
        GROUP BY up.id
    ),
    ranked AS (
        SELECT
            uxt.id,
            uxt.xp,
            ROW_NUMBER() OVER (ORDER BY uxt.xp DESC)::BIGINT AS user_rank
        FROM user_xp_totals uxt
        WHERE uxt.xp >= 200
    )
    SELECT
        COALESCE((SELECT uxt2.xp FROM user_xp_totals uxt2 WHERE uxt2.id = p_user_id), 0) AS total_xp,
        (SELECT r.user_rank FROM ranked r WHERE r.id = p_user_id) AS rank;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- BACKFILL: Award XP for already-unlocked achievements
-- =============================================================================
-- This one-time update ensures existing users who have achievements get their XP

-- First, ensure all users with achievements have a study streak record
INSERT INTO user_study_streaks (user_id, achievement_xp)
SELECT DISTINCT ua.user_id, 0
FROM user_achievements ua
WHERE NOT EXISTS (
    SELECT 1 FROM user_study_streaks uss WHERE uss.user_id = ua.user_id
)
ON CONFLICT (user_id) DO NOTHING;

-- Now update achievement_xp for all users based on their unlocked achievements
UPDATE user_study_streaks uss
SET achievement_xp = (
    SELECT COALESCE(SUM(a.xp_reward), 0)
    FROM user_achievements ua
    JOIN achievements a ON ua.achievement_id = a.id
    WHERE ua.user_id = uss.user_id
),
updated_at = NOW()
WHERE EXISTS (
    SELECT 1 FROM user_achievements ua WHERE ua.user_id = uss.user_id
);

-- =============================================================================
-- GRANT PERMISSIONS (ensure they exist)
-- =============================================================================

GRANT EXECUTE ON FUNCTION check_study_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_streak_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_memory_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_voice_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_saved_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_gamification_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_leaderboard(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_xp_rank(UUID) TO authenticated;

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON FUNCTION check_study_achievements IS 'Check and award study count achievements with XP';
COMMENT ON FUNCTION check_streak_achievements IS 'Check and award study streak achievements with XP';
COMMENT ON FUNCTION check_memory_achievements IS 'Check and award memory verse achievements with XP';
COMMENT ON FUNCTION check_voice_achievements IS 'Check and award voice session achievements with XP';
COMMENT ON FUNCTION check_saved_achievements IS 'Check and award saved guides achievements with XP';
COMMENT ON FUNCTION get_user_gamification_stats IS 'Returns all gamification data including achievement XP';
COMMENT ON FUNCTION get_leaderboard IS 'Returns top users with total XP (study + achievement XP combined)';
COMMENT ON FUNCTION get_user_xp_rank IS 'Returns user total XP (study + achievement) and leaderboard rank';

COMMIT;
