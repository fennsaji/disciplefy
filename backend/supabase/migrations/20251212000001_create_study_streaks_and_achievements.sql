-- Migration: Study Streaks and Achievements System
-- Created: 2025-12-12
-- Purpose: Create gamification tables for study streaks and achievement badges

BEGIN;

-- =============================================================================
-- TABLE: user_study_streaks
-- =============================================================================
-- Tracks consecutive days of study guide completion (separate from verse streaks)

CREATE TABLE IF NOT EXISTS user_study_streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak INTEGER NOT NULL DEFAULT 0 CHECK (current_streak >= 0),
    longest_streak INTEGER NOT NULL DEFAULT 0 CHECK (longest_streak >= 0),
    last_study_date DATE,
    total_study_days INTEGER NOT NULL DEFAULT 0 CHECK (total_study_days >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_user_study_streak UNIQUE(user_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_study_streaks_user_id
    ON user_study_streaks(user_id);

CREATE INDEX IF NOT EXISTS idx_user_study_streaks_current_streak
    ON user_study_streaks(current_streak DESC);

-- Enable RLS
ALTER TABLE user_study_streaks ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can read own study streak" ON user_study_streaks;
DROP POLICY IF EXISTS "Users can insert own study streak" ON user_study_streaks;
DROP POLICY IF EXISTS "Users can update own study streak" ON user_study_streaks;
DROP POLICY IF EXISTS "Service role has full access to study streaks" ON user_study_streaks;

CREATE POLICY "Users can read own study streak"
    ON user_study_streaks FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own study streak"
    ON user_study_streaks FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own study streak"
    ON user_study_streaks FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role has full access to study streaks"
    ON user_study_streaks FOR ALL
    USING (auth.role() = 'service_role');

-- =============================================================================
-- TABLE: achievements
-- =============================================================================
-- Master list of all available achievements

CREATE TABLE IF NOT EXISTS achievements (
    id TEXT PRIMARY KEY,
    name_en TEXT NOT NULL,
    name_hi TEXT NOT NULL,
    name_ml TEXT NOT NULL,
    description_en TEXT NOT NULL,
    description_hi TEXT NOT NULL,
    description_ml TEXT NOT NULL,
    icon TEXT NOT NULL,
    xp_reward INTEGER DEFAULT 0,
    category TEXT NOT NULL CHECK (category IN ('study', 'streak', 'memory', 'voice', 'saved')),
    threshold INTEGER,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- No RLS needed - achievements are public read-only data
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Everyone can read achievements" ON achievements;
CREATE POLICY "Everyone can read achievements"
    ON achievements FOR SELECT
    USING (true);

-- =============================================================================
-- TABLE: user_achievements
-- =============================================================================
-- Tracks which achievements each user has unlocked

CREATE TABLE IF NOT EXISTS user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_id TEXT NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    notified BOOLEAN DEFAULT FALSE,
    CONSTRAINT unique_user_achievement UNIQUE(user_id, achievement_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id
    ON user_achievements(user_id);

CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement_id
    ON user_achievements(achievement_id);

-- Enable RLS
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can read own achievements" ON user_achievements;
DROP POLICY IF EXISTS "Users can insert own achievements" ON user_achievements;
DROP POLICY IF EXISTS "Users can update own achievements" ON user_achievements;
DROP POLICY IF EXISTS "Service role has full access to user achievements" ON user_achievements;

CREATE POLICY "Users can read own achievements"
    ON user_achievements FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own achievements"
    ON user_achievements FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own achievements"
    ON user_achievements FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role has full access to user achievements"
    ON user_achievements FOR ALL
    USING (auth.role() = 'service_role');

-- =============================================================================
-- SEED: Achievement Data
-- =============================================================================

INSERT INTO achievements (id, name_en, name_hi, name_ml, description_en, description_hi, description_ml, icon, xp_reward, category, threshold, sort_order)
VALUES
    -- Study Achievements
    ('first_study', 'First Steps', 'पहला कदम', 'ആദ്യ ചുവട്', 'Complete your first study guide', 'अपनी पहली स्टडी गाइड पूरी करें', 'നിങ്ങളുടെ ആദ്യ സ്റ്റഡി ഗൈഡ് പൂർത്തിയാക്കുക', '🎯', 25, 'study', 1, 1),
    ('studies_10', 'Curious Mind', 'जिज्ञासु मन', 'ജിജ്ഞാസുവായ മനസ്സ്', 'Complete 10 study guides', '10 स्टडी गाइड पूरी करें', '10 സ്റ്റഡി ഗൈഡുകൾ പൂർത്തിയാക്കുക', '🔍', 50, 'study', 10, 2),
    ('studies_25', 'Scholar', 'विद्वान', 'പണ്ഡിതൻ', 'Complete 25 study guides', '25 स्टडी गाइड पूरी करें', '25 സ്റ്റഡി ഗൈഡുകൾ പൂർത്തിയാക്കുക', '📚', 100, 'study', 25, 3),
    ('studies_50', 'Professor', 'प्रोफेसर', 'പ്രൊഫസർ', 'Complete 50 study guides', '50 स्टडी गाइड पूरी करें', '50 സ്റ്റഡി ഗൈഡുകൾ പൂർത്തിയാക്കുക', '🎓', 200, 'study', 50, 4),
    ('studies_100', 'Bible Expert', 'बाइबल विशेषज्ञ', 'ബൈബിൾ വിദഗ്ധൻ', 'Complete 100 study guides', '100 स्टडी गाइड पूरी करें', '100 സ്റ്റഡി ഗൈഡുകൾ പൂർത്തിയാക്കുക', '👑', 500, 'study', 100, 5),

    -- Study Streak Achievements
    ('study_streak_7', 'Week Warrior', 'सप्ताह योद्धा', 'ആഴ്ച യോദ്ധാവ്', '7-day study streak', '7 दिन की स्टडी स्ट्रीक', '7 ദിവസത്തെ സ്റ്റഡി സ്ട്രീക്ക്', '🔥', 75, 'streak', 7, 6),
    ('study_streak_30', 'Monthly Master', 'मासिक मास्टर', 'മാസ മാസ്റ്റർ', '30-day study streak', '30 दिन की स्टडी स्ट्रीक', '30 ദിവസത്തെ സ്റ്റഡി സ്ട്രീക്ക്', '✨', 200, 'streak', 30, 7),
    ('study_streak_100', 'Century Scholar', 'शताब्दी विद्वान', 'നൂറ്റാണ്ട് പണ്ഡിതൻ', '100-day study streak', '100 दिन की स्टडी स्ट्रीक', '100 ദിവസത്തെ സ്റ്റഡി സ്ട്രീക്ക്', '🏆', 500, 'streak', 100, 8),

    -- Memory Verse Achievements
    ('memory_5', 'Memorizer', 'याद करने वाला', 'ഓർമ്മിക്കുന്നവൻ', 'Add 5 memory verses', '5 याद करने के पद जोड़ें', '5 മെമ്മറി വാക്യങ്ങൾ ചേർക്കുക', '🧠', 50, 'memory', 5, 9),
    ('memory_25', 'Scripture Keeper', 'वचन रक्षक', 'തിരുവചന സൂക്ഷിപ്പുകാരൻ', 'Add 25 memory verses', '25 याद करने के पद जोड़ें', '25 മെമ്മറി വാക്യങ്ങൾ ചേർക്കുക', '📖', 150, 'memory', 25, 10),

    -- Voice Discipler Achievements
    ('voice_5', 'Voice Learner', 'वॉयस शिक्षार्थी', 'വോയ്സ് പഠിതാവ്', 'Complete 5 voice sessions', '5 वॉयस सेशन पूरे करें', '5 വോയ്സ് സെഷനുകൾ പൂർത്തിയാക്കുക', '🎙️', 50, 'voice', 5, 11),
    ('voice_25', 'Conversation Master', 'वार्तालाप मास्टर', 'സംഭാഷണ മാസ്റ്റർ', 'Complete 25 voice sessions', '25 वॉयस सेशन पूरे करें', '25 വോയ്സ് സെഷനുകൾ പൂർത്തിയാക്കുക', '🗣️', 150, 'voice', 25, 12),

    -- Saved Guides Achievements
    ('saved_10', 'Bookworm', 'किताबी कीड़ा', 'പുസ്തകപ്പുഴു', 'Save 10 study guides', '10 स्टडी गाइड सेव करें', '10 സ്റ്റഡി ഗൈഡുകൾ സേവ് ചെയ്യുക', '📕', 50, 'saved', 10, 13),
    ('saved_50', 'Library Builder', 'पुस्तकालय निर्माता', 'ലൈബ്രറി നിർമ്മാതാവ്', 'Save 50 study guides', '50 स्टडी गाइड सेव करें', '50 സ്റ്റഡി ഗൈഡുകൾ സേവ് ചെയ്യുക', '📚', 150, 'saved', 50, 14)
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
-- FUNCTIONS: Study Streak Management
-- =============================================================================

-- Function to get or create user study streak
CREATE OR REPLACE FUNCTION get_or_create_study_streak(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    current_streak INTEGER,
    longest_streak INTEGER,
    last_study_date DATE,
    total_study_days INTEGER,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
BEGIN
    -- Try to insert first with ON CONFLICT DO NOTHING (atomic, prevents race conditions)
    RETURN QUERY
    INSERT INTO user_study_streaks (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING
    RETURNING *;

    -- If INSERT was skipped due to conflict, fetch existing row
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT s.id, s.user_id, s.current_streak, s.longest_streak,
               s.last_study_date, s.total_study_days, s.created_at, s.updated_at
        FROM user_study_streaks s
        WHERE s.user_id = p_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update study streak when a study guide is completed
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

    -- Get current values
    SELECT s.last_study_date, s.current_streak, s.longest_streak
    INTO v_last_date, v_current, v_longest
    FROM user_study_streaks s
    WHERE s.user_id = p_user_id;

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

        -- Update the record
        UPDATE user_study_streaks
        SET 
            current_streak = v_current,
            longest_streak = v_longest,
            last_study_date = v_today,
            total_study_days = total_study_days + 1,
            updated_at = NOW()
        WHERE user_study_streaks.user_id = p_user_id;
    END IF;

    RETURN QUERY SELECT v_current, v_longest, v_streak_increased, v_is_new_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTIONS: Achievement Checking
-- =============================================================================

-- Function to check and award study count achievements
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
BEGIN
    -- Get total completed studies count
    SELECT COUNT(*) INTO v_study_count
    FROM user_topic_progress
    WHERE user_id = p_user_id AND completed_at IS NOT NULL;

    -- Also count user-generated study guides
    v_study_count := v_study_count + (
        SELECT COUNT(*) FROM user_study_guides
        WHERE user_id = p_user_id AND completed_at IS NOT NULL
    );

    -- Check each study achievement
    FOR v_achievement IN 
        SELECT a.id, a.name_en, a.xp_reward, a.threshold
        FROM achievements a
        WHERE a.category = 'study'
        AND a.threshold <= v_study_count
        ORDER BY a.threshold
    LOOP
        -- Try to insert the achievement
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        -- Check if it was newly inserted
        IF FOUND THEN
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check and award streak achievements
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
        -- Try to insert the achievement
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        -- Check if it was newly inserted
        IF FOUND THEN
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check memory verse achievements
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
    -- Get memory verses count
    SELECT COUNT(*) INTO v_memory_count
    FROM memory_verses
    WHERE user_id = p_user_id;

    -- Check each memory achievement
    FOR v_achievement IN 
        SELECT a.id, a.name_en, a.xp_reward, a.threshold
        FROM achievements a
        WHERE a.category = 'memory'
        AND a.threshold <= v_memory_count
        ORDER BY a.threshold
    LOOP
        -- Try to insert the achievement
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check voice session achievements
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
        -- Try to insert the achievement
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check saved guides achievements
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
        -- Try to insert the achievement
        INSERT INTO user_achievements (user_id, achievement_id)
        VALUES (p_user_id, v_achievement.id)
        ON CONFLICT (user_id, achievement_id) DO NOTHING;

        IF FOUND THEN
            RETURN QUERY SELECT v_achievement.id, v_achievement.name_en, v_achievement.xp_reward, TRUE;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION: Get User Gamification Stats
-- =============================================================================
-- Single function to get all gamification data for a user

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
            COALESCE(SUM(utp.xp_earned), 0)::BIGINT AS xp
        FROM user_topic_progress utp
        WHERE utp.user_id = p_user_id
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

-- =============================================================================
-- FUNCTION: Get User Achievements
-- =============================================================================

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
    is_unlocked BOOLEAN
) AS $$
BEGIN
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
        (ua.id IS NOT NULL) AS is_unlocked
    FROM achievements a
    LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = p_user_id
    ORDER BY a.sort_order, a.id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- TRIGGER: Updated At for Study Streaks
-- =============================================================================

CREATE OR REPLACE FUNCTION update_study_streak_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_study_streak_updated_at_trigger ON user_study_streaks;
CREATE TRIGGER update_study_streak_updated_at_trigger
    BEFORE UPDATE ON user_study_streaks
    FOR EACH ROW
    EXECUTE FUNCTION update_study_streak_updated_at();

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION get_or_create_study_streak(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_study_streak(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_study_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_streak_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_memory_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_voice_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_saved_achievements(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_gamification_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_achievements(UUID, TEXT) TO authenticated;

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON TABLE user_study_streaks IS 'Tracks consecutive days of study guide completion';
COMMENT ON TABLE achievements IS 'Master list of all available achievement badges';
COMMENT ON TABLE user_achievements IS 'Tracks which achievements each user has unlocked';
COMMENT ON FUNCTION update_study_streak IS 'Updates study streak when user completes a study guide';
COMMENT ON FUNCTION get_user_gamification_stats IS 'Returns all gamification data for stats dashboard';
COMMENT ON FUNCTION get_user_achievements IS 'Returns all achievements with unlock status for a user';

COMMIT;
