-- =====================================================
-- Consolidated Migration: Gamification System
-- =====================================================
-- Source: Merge of 18 gamification-related migrations
-- Tables: 5 (achievements, user_achievements, user_study_streaks,
--            memory_challenges, user_challenge_progress)
-- Description: Complete gamification system with achievements, study streaks,
--              weekly challenges, leaderboards, and XP rewards
-- =====================================================
-- Dependencies:
--   - 0001_core_schema.sql (auth.users, user_profiles)
--   - 0002_study_guides.sql (study_guides for study achievements)
--   - 0006_voice_system.sql (voice_conversations for voice achievements)
--   - 0007_memory_system.sql (memory_verses for memory achievements)
-- =====================================================

BEGIN;

-- =====================================================
-- SUMMARY: Gamification system with achievements and challenges
-- Merges:
--   - 20251212000001_create_study_streaks_and_achievements.sql (base)
--   - 20251217000003_memory_verses_gamification_schema.sql (challenges)
--   - 20251218000003_seed_weekly_challenges.sql (challenge functions)
--   - 20251218000004_advanced_expert_achievements.sql (advanced tiers)
--   - 20260117000003_add_calculate_study_streak_function.sql (streak calc)
--   - Plus 13 other bug fixes and enhancements
-- =====================================================

-- =====================================================
-- PART 1: Core Tables
-- =====================================================

-- =============================================================================
-- TABLE: achievements
-- =============================================================================
-- Master list of all available achievement badges with multi-language support

CREATE TABLE IF NOT EXISTS achievements (
    id TEXT PRIMARY KEY,
    name_en TEXT NOT NULL,
    name_hi TEXT NOT NULL,
    name_ml TEXT NOT NULL,
    description_en TEXT NOT NULL,
    description_hi TEXT NOT NULL,
    description_ml TEXT NOT NULL,
    icon TEXT NOT NULL,
    xp_reward INTEGER DEFAULT 0 CHECK (xp_reward >= 0),
    category TEXT NOT NULL CHECK (category IN ('study', 'streak', 'memory', 'voice', 'saved')),
    threshold INTEGER CHECK (threshold IS NULL OR threshold > 0),
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_achievements_category
    ON achievements(category);

CREATE INDEX IF NOT EXISTS idx_achievements_sort_order
    ON achievements(sort_order);

-- Enable RLS (achievements are public read-only data)
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Everyone can read achievements" ON achievements;
CREATE POLICY "Everyone can read achievements"
    ON achievements FOR SELECT
    USING (true);

COMMENT ON TABLE achievements IS 'Master list of all achievement badges with multi-language names and descriptions. Categories: study, streak, memory, voice, saved.';
COMMENT ON COLUMN achievements.threshold IS 'Minimum count required to unlock achievement (e.g., 10 for studies_10 achievement)';
COMMENT ON COLUMN achievements.xp_reward IS 'Experience points awarded when achievement is unlocked';

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

CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id
    ON user_achievements(user_id);

CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement_id
    ON user_achievements(achievement_id);

CREATE INDEX IF NOT EXISTS idx_user_achievements_unlocked_at
    ON user_achievements(unlocked_at DESC);

-- Enable RLS
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own achievements" ON user_achievements;
DROP POLICY IF EXISTS "Users can insert own achievements" ON user_achievements;
DROP POLICY IF EXISTS "Users can update own achievements" ON user_achievements;

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

COMMENT ON TABLE user_achievements IS 'Tracks which achievements each user has unlocked with timestamp and notification status';
COMMENT ON COLUMN user_achievements.notified IS 'Whether user has been shown notification for this achievement unlock';

-- =============================================================================
-- TABLE: user_study_streaks
-- =============================================================================
-- Tracks consecutive days of study guide completion (separate from verse streaks)
-- Source: 20251212000001 + 20260106000010 (schema recreation)

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

CREATE INDEX IF NOT EXISTS idx_user_study_streaks_user_id
    ON user_study_streaks(user_id);

CREATE INDEX IF NOT EXISTS idx_user_study_streaks_current_streak
    ON user_study_streaks(current_streak DESC);

CREATE INDEX IF NOT EXISTS idx_user_study_streaks_last_study_date
    ON user_study_streaks(last_study_date DESC);

-- Enable RLS
ALTER TABLE user_study_streaks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own study streak" ON user_study_streaks;
DROP POLICY IF EXISTS "Users can insert own study streak" ON user_study_streaks;
DROP POLICY IF EXISTS "Users can update own study streak" ON user_study_streaks;

CREATE POLICY "Users can read own study streak"
    ON user_study_streaks FOR SELECT
    USING (auth.uid() = user_study_streaks.user_id);

CREATE POLICY "Users can insert own study streak"
    ON user_study_streaks FOR INSERT
    WITH CHECK (auth.uid() = user_study_streaks.user_id);

CREATE POLICY "Users can update own study streak"
    ON user_study_streaks FOR UPDATE
    USING (auth.uid() = user_study_streaks.user_id)
    WITH CHECK (auth.uid() = user_study_streaks.user_id);

COMMENT ON TABLE user_study_streaks IS 'Tracks consecutive days of study guide completion (Bible study, not memory verses)';
COMMENT ON COLUMN user_study_streaks.current_streak IS 'Number of consecutive days user has completed study guides';
COMMENT ON COLUMN user_study_streaks.longest_streak IS 'Longest streak user has ever achieved';
COMMENT ON COLUMN user_study_streaks.total_study_days IS 'Total number of days user has completed at least one study guide';

-- =============================================================================
-- TABLE: daily_verse_streaks
-- =============================================================================
-- Tracks user engagement with daily verses through consecutive day streaks
-- Source: 20251113000002_create_daily_verse_streaks.sql

CREATE TABLE IF NOT EXISTS daily_verse_streaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak INTEGER NOT NULL DEFAULT 0 CHECK (current_streak >= 0),
    longest_streak INTEGER NOT NULL DEFAULT 0 CHECK (longest_streak >= 0),
    last_viewed_at TIMESTAMPTZ,
    total_views INTEGER NOT NULL DEFAULT 0 CHECK (total_views >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_user_daily_verse_streak UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_daily_verse_streaks_user_id
    ON daily_verse_streaks(user_id);

CREATE INDEX IF NOT EXISTS idx_daily_verse_streaks_current_streak
    ON daily_verse_streaks(current_streak DESC);

-- Enable RLS
ALTER TABLE daily_verse_streaks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own daily verse streak" ON daily_verse_streaks;
DROP POLICY IF EXISTS "Users can insert own daily verse streak" ON daily_verse_streaks;
DROP POLICY IF EXISTS "Users can update own daily verse streak" ON daily_verse_streaks;

CREATE POLICY "Users can read own daily verse streak"
    ON daily_verse_streaks FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own daily verse streak"
    ON daily_verse_streaks FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own daily verse streak"
    ON daily_verse_streaks FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE daily_verse_streaks IS 'Tracks user engagement through consecutive daily verse viewing streaks';
COMMENT ON COLUMN daily_verse_streaks.user_id IS 'User ID from auth.users table';
COMMENT ON COLUMN daily_verse_streaks.current_streak IS 'Current consecutive days of verse viewing';
COMMENT ON COLUMN daily_verse_streaks.longest_streak IS 'Personal best streak record';
COMMENT ON COLUMN daily_verse_streaks.last_viewed_at IS 'Timestamp of last daily verse view';
COMMENT ON COLUMN daily_verse_streaks.total_views IS 'Lifetime count of daily verse views';

-- =============================================================================
-- TABLE: memory_challenges
-- =============================================================================
-- Weekly/monthly challenges with XP rewards and time bounds
-- Source: 20251217000003_memory_verses_gamification_schema.sql

CREATE TABLE IF NOT EXISTS memory_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_type TEXT NOT NULL CHECK (challenge_type IN ('daily', 'weekly', 'monthly')),
    target_type TEXT NOT NULL CHECK (target_type IN (
        'reviews_count', 'new_verses', 'mastery_level',
        'perfect_recalls', 'streak_days', 'modes_tried'
    )),
    target_value INTEGER NOT NULL CHECK (target_value > 0),
    xp_reward INTEGER NOT NULL CHECK (xp_reward > 0),
    badge_icon TEXT,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT valid_challenge_dates CHECK (end_date > start_date)
);

CREATE INDEX IF NOT EXISTS idx_memory_challenges_active
    ON memory_challenges(is_active) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_memory_challenges_dates
    ON memory_challenges(start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_memory_challenges_type
    ON memory_challenges(challenge_type);

-- Enable RLS (challenges are public read-only)
ALTER TABLE memory_challenges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Everyone can read active challenges" ON memory_challenges;

CREATE POLICY "Everyone can read active challenges"
    ON memory_challenges FOR SELECT
    USING (is_active = TRUE);

COMMENT ON TABLE memory_challenges IS 'Weekly/monthly practice challenges with XP rewards. Target types: reviews_count, new_verses, mastery_level, perfect_recalls, streak_days, modes_tried.';
COMMENT ON COLUMN memory_challenges.target_type IS 'Type of metric to track: reviews_count, new_verses, mastery_level, perfect_recalls, streak_days, modes_tried';
COMMENT ON COLUMN memory_challenges.target_value IS 'Threshold to reach for completing the challenge (e.g., 10 reviews, 3 new verses)';
COMMENT ON COLUMN memory_challenges.badge_icon IS 'Material icon name for challenge badge display';

-- =============================================================================
-- TABLE: user_challenge_progress
-- =============================================================================
-- Tracks user progress on active challenges

CREATE TABLE IF NOT EXISTS user_challenge_progress (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    challenge_id UUID REFERENCES memory_challenges(id) ON DELETE CASCADE,
    current_progress INTEGER DEFAULT 0 CHECK (current_progress >= 0),
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    xp_claimed BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, challenge_id)
);

CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_user_id
    ON user_challenge_progress(user_id);

CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_completed
    ON user_challenge_progress(is_completed) WHERE is_completed = TRUE;

-- Enable RLS
ALTER TABLE user_challenge_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own challenge progress" ON user_challenge_progress;
DROP POLICY IF EXISTS "Users can insert own challenge progress" ON user_challenge_progress;
DROP POLICY IF EXISTS "Users can update own challenge progress" ON user_challenge_progress;

CREATE POLICY "Users can read own challenge progress"
    ON user_challenge_progress FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own challenge progress"
    ON user_challenge_progress FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own challenge progress"
    ON user_challenge_progress FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

COMMENT ON TABLE user_challenge_progress IS 'Tracks individual user progress towards completing active challenges';
COMMENT ON COLUMN user_challenge_progress.xp_claimed IS 'Whether user has claimed XP reward for completing this challenge';

-- =====================================================
-- PART 2: Streak Management Functions
-- =====================================================

-- =============================================================================
-- FUNCTION: get_or_create_study_streak
-- =============================================================================
-- Get or create user study streak record (atomic, prevents race conditions)

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
    -- Try to insert first with ON CONFLICT DO NOTHING (atomic)
    -- Use constraint name instead of column to avoid ambiguity with RETURNS TABLE
    RETURN QUERY
    INSERT INTO user_study_streaks AS uss (user_id)
    VALUES (p_user_id)
    ON CONFLICT ON CONSTRAINT unique_user_study_streak DO NOTHING
    RETURNING uss.*;

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

GRANT EXECUTE ON FUNCTION get_or_create_study_streak(UUID) TO authenticated;

COMMENT ON FUNCTION get_or_create_study_streak IS 'Atomically gets or creates study streak record for user. Uses ON CONFLICT to prevent race conditions.';

-- =============================================================================
-- FUNCTION: get_or_create_user_streak (for daily verse streaks)
-- =============================================================================
-- Get or create daily verse streak record (atomic, prevents race conditions)
-- Source: 20251113000002_create_daily_verse_streaks.sql

CREATE OR REPLACE FUNCTION get_or_create_user_streak(p_user_id UUID)
RETURNS TABLE (
    out_id UUID,
    out_user_id UUID,
    out_current_streak INTEGER,
    out_longest_streak INTEGER,
    out_last_viewed_at TIMESTAMPTZ,
    out_total_views INTEGER,
    out_created_at TIMESTAMPTZ,
    out_updated_at TIMESTAMPTZ
) AS $$
BEGIN
    -- Try to insert first with ON CONFLICT DO NOTHING (atomic)
    RETURN QUERY
    INSERT INTO daily_verse_streaks (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING
    RETURNING id, user_id, current_streak, longest_streak,
              last_viewed_at, total_views, created_at, updated_at;

    -- If INSERT was skipped due to conflict, fetch existing row
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT s.id, s.user_id, s.current_streak, s.longest_streak,
               s.last_viewed_at, s.total_views, s.created_at, s.updated_at
        FROM daily_verse_streaks s
        WHERE s.user_id = p_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_or_create_user_streak(UUID) TO authenticated;

COMMENT ON FUNCTION get_or_create_user_streak IS 'Atomically gets or creates daily verse streak record for user. Uses ON CONFLICT to prevent race conditions.';

-- =============================================================================
-- FUNCTION: update_study_streak
-- =============================================================================
-- Update study streak when a study guide is completed

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

GRANT EXECUTE ON FUNCTION update_study_streak(UUID) TO authenticated;

COMMENT ON FUNCTION update_study_streak IS 'Updates study streak when user completes a study guide. Only processes once per day. Returns current streak, longest streak, whether streak increased, and if new record was set.';

-- =============================================================================
-- FUNCTION: calculate_study_streak
-- =============================================================================
-- Calculate consecutive days of study activity for streak display
-- Source: 20260117000003_add_calculate_study_streak_function.sql

CREATE OR REPLACE FUNCTION calculate_study_streak(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_streak_count INTEGER := 0;
  v_check_date DATE := CURRENT_DATE;
  v_has_activity BOOLEAN;
BEGIN
  -- Loop backwards from today to find consecutive days of activity
  LOOP
    -- Check if user has any study activity on this date
    SELECT EXISTS (
      SELECT 1
      FROM user_study_guides
      WHERE user_id = p_user_id
        AND DATE(created_at) = v_check_date
    ) INTO v_has_activity;

    -- If no activity on this date, break the streak
    IF NOT v_has_activity THEN
      EXIT;
    END IF;

    -- Increment streak and check previous day
    v_streak_count := v_streak_count + 1;
    v_check_date := v_check_date - INTERVAL '1 day';

    -- Safety limit: Don't check more than 365 days back
    IF v_streak_count >= 365 THEN
      EXIT;
    END IF;
  END LOOP;

  RETURN v_streak_count;
END;
$$;

GRANT EXECUTE ON FUNCTION calculate_study_streak(UUID) TO authenticated;

COMMENT ON FUNCTION calculate_study_streak IS 'Calculates the number of consecutive days a user has generated study guides. Used for streak tracking in usage stats and soft paywall triggers. Safety limit of 365 days.';

-- =====================================================
-- PART 3: Achievement Checking Functions
-- =====================================================

-- =============================================================================
-- FUNCTION: check_study_achievements
-- =============================================================================
-- Check and award study count achievements

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
    -- Get total completed studies count from multiple sources
    -- 1. Learning path topics completed
    -- 2. User study guides completed (from user_study_guides table, not study_guides)
    v_study_count := (
        SELECT COUNT(*) FROM user_topic_progress
        WHERE user_topic_progress.user_id = p_user_id
        AND completed_at IS NOT NULL
    ) + (
        SELECT COUNT(*) FROM user_study_guides
        WHERE user_study_guides.user_id = p_user_id
        AND completed_at IS NOT NULL
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
        -- Use constraint name to avoid ambiguity with RETURNS TABLE columns
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

GRANT EXECUTE ON FUNCTION check_study_achievements(UUID) TO authenticated;

COMMENT ON FUNCTION check_study_achievements IS 'Checks and awards achievements based on total study guide completions. Includes both learning path topics and user-generated guides.';

-- =============================================================================
-- FUNCTION: check_streak_achievements
-- =============================================================================
-- Check and award streak achievements

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

GRANT EXECUTE ON FUNCTION check_streak_achievements(UUID) TO authenticated;

COMMENT ON FUNCTION check_streak_achievements IS 'Checks and awards achievements based on current study streak length (consecutive days)';

-- =============================================================================
-- FUNCTION: check_memory_achievements
-- =============================================================================
-- Comprehensive memory achievement checking with all 20 tiers
-- Source: 20251220000001_fix (ambiguous column fix) + 20251218000004 (advanced/expert)
-- FIX APPLIED: Output columns renamed to avoid ambiguity (out_achievement_id, etc.)

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

GRANT EXECUTE ON FUNCTION check_memory_achievements(UUID) TO authenticated;

COMMENT ON FUNCTION check_memory_achievements IS 'Comprehensive memory achievement checking with fixed output column names to avoid ambiguity. Supports all 20 tiers (Beginner through Expert): verse count, perfect recalls, practice streaks, mode variety, mastery levels, daily goals, challenges, and collections.';

-- =============================================================================
-- FUNCTION: check_voice_achievements
-- =============================================================================
-- Check and award voice session achievements

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

GRANT EXECUTE ON FUNCTION check_voice_achievements(UUID) TO authenticated;

COMMENT ON FUNCTION check_voice_achievements IS 'Checks and awards achievements based on completed voice conversation sessions with AI Study Buddy';

-- =============================================================================
-- FUNCTION: check_saved_achievements
-- =============================================================================
-- Check and award saved guides achievements

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

GRANT EXECUTE ON FUNCTION check_saved_achievements(UUID) TO authenticated;

COMMENT ON FUNCTION check_saved_achievements IS 'Checks and awards achievements based on number of study guides saved to library';

-- =====================================================
-- PART 4: Challenge Management Functions
-- =====================================================

-- =============================================================================
-- FUNCTION: create_weekly_memory_challenges
-- =============================================================================
-- Creates a new set of weekly challenges (call at start of each week)
-- Source: 20251218000003_seed_weekly_challenges.sql

CREATE OR REPLACE FUNCTION create_weekly_memory_challenges()
RETURNS void AS $$
DECLARE
    week_start TIMESTAMPTZ;
    week_end TIMESTAMPTZ;
BEGIN
    -- Calculate current week (Monday to Sunday)
    week_start := date_trunc('week', NOW()) + INTERVAL '1 day'; -- Monday
    week_end := week_start + INTERVAL '6 days 23 hours 59 minutes'; -- Sunday 23:59

    -- Delete any existing challenges for this week to avoid duplicates
    DELETE FROM memory_challenges
    WHERE challenge_type = 'weekly'
      AND start_date >= week_start
      AND start_date < week_end;

    -- Insert new weekly challenges
    INSERT INTO memory_challenges (
        challenge_type,
        target_type,
        target_value,
        xp_reward,
        badge_icon,
        start_date,
        end_date,
        is_active
    ) VALUES
    -- Challenge 1: Complete 10 reviews this week
    ('weekly', 'reviews_count', 10, 100, 'task_alt', week_start, week_end, true),
    -- Challenge 2: Add 3 new verses
    ('weekly', 'new_verses', 3, 150, 'add_circle', week_start, week_end, true),
    -- Challenge 3: Achieve 5 perfect recalls (quality = 5)
    ('weekly', 'perfect_recalls', 5, 200, 'stars', week_start, week_end, true),
    -- Challenge 4: Practice 5 days this week
    ('weekly', 'streak_days', 5, 250, 'local_fire_department', week_start, week_end, true),
    -- Challenge 5: Try 3 different practice modes
    ('weekly', 'modes_tried', 3, 150, 'view_module', week_start, week_end, true);

    RAISE NOTICE 'Created weekly challenges from % to %', week_start, week_end;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION create_weekly_memory_challenges() TO authenticated;

COMMENT ON FUNCTION create_weekly_memory_challenges IS 'Creates a new set of weekly challenges (call at start of each week via pg_cron). Replaces any existing challenges for the current week.';

-- =============================================================================
-- FUNCTION: update_challenge_progress
-- =============================================================================
-- Called after each practice session to update relevant challenges

CREATE OR REPLACE FUNCTION update_challenge_progress(
    p_user_id UUID,
    p_target_type TEXT,
    p_increment INTEGER DEFAULT 1
)
RETURNS TABLE (
    challenge_id UUID,
    new_progress INTEGER,
    is_newly_completed BOOLEAN,
    xp_reward INTEGER
) AS $$
DECLARE
    v_challenge RECORD;
    v_progress RECORD;
    v_was_completed BOOLEAN;
    v_is_now_completed BOOLEAN;
BEGIN
    -- Authorization check: verify caller can only update their own progress
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized: Cannot update challenge progress for another user'
            USING ERRCODE = '42501'; -- insufficient_privilege
    END IF;

    -- Find active challenges matching the target type
    FOR v_challenge IN
        SELECT id, target_value, xp_reward
        FROM memory_challenges
        WHERE target_type = p_target_type
          AND is_active = true
          AND start_date <= NOW()
          AND end_date >= NOW()
    LOOP
        -- Get or create progress record
        SELECT current_progress, is_completed
        INTO v_progress
        FROM user_challenge_progress
        WHERE user_id = p_user_id
          AND challenge_id = v_challenge.id;

        IF NOT FOUND THEN
            -- Create new progress record
            INSERT INTO user_challenge_progress (user_id, challenge_id, current_progress, is_completed, xp_claimed)
            VALUES (p_user_id, v_challenge.id, 0, false, false)
            RETURNING current_progress, is_completed INTO v_progress;
        END IF;

        v_was_completed := v_progress.is_completed;

        -- Increment progress
        UPDATE user_challenge_progress
        SET current_progress = current_progress + p_increment,
            is_completed = (current_progress + p_increment) >= v_challenge.target_value,
            completed_at = CASE
                WHEN (current_progress + p_increment) >= v_challenge.target_value AND NOT is_completed
                THEN NOW()
                ELSE completed_at
            END
        WHERE user_id = p_user_id
          AND challenge_id = v_challenge.id
        RETURNING current_progress, is_completed INTO v_progress;

        v_is_now_completed := v_progress.is_completed AND NOT v_was_completed;

        -- Return challenge update
        RETURN QUERY SELECT
            v_challenge.id,
            v_progress.current_progress,
            v_is_now_completed,
            v_challenge.xp_reward;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION update_challenge_progress(UUID, TEXT, INTEGER) TO authenticated;

COMMENT ON FUNCTION update_challenge_progress IS 'Updates progress on challenges matching the target type after practice sessions. Creates progress record if needed. Returns challenge updates including newly completed status.';

-- =============================================================================
-- FUNCTION: claim_challenge_reward
-- =============================================================================
-- Marks challenge as XP claimed and returns XP amount

CREATE OR REPLACE FUNCTION claim_challenge_reward(
    p_user_id UUID,
    p_challenge_id UUID
)
RETURNS TABLE (
    success BOOLEAN,
    xp_awarded INTEGER,
    message TEXT
) AS $$
DECLARE
    v_progress RECORD;
    v_challenge RECORD;
BEGIN
    -- Authorization check: verify caller can only claim their own rewards
    IF p_user_id != auth.uid() THEN
        RAISE EXCEPTION 'Unauthorized: Cannot claim challenge reward for another user'
            USING ERRCODE = '42501'; -- insufficient_privilege
    END IF;

    -- Get challenge details
    SELECT xp_reward INTO v_challenge
    FROM memory_challenges
    WHERE id = p_challenge_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 0, 'Challenge not found'::TEXT;
        RETURN;
    END IF;

    -- Get user progress
    SELECT is_completed, xp_claimed INTO v_progress
    FROM user_challenge_progress
    WHERE user_id = p_user_id
      AND challenge_id = p_challenge_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 0, 'No progress found for this challenge'::TEXT;
        RETURN;
    END IF;

    -- Validate challenge is completed
    IF NOT v_progress.is_completed THEN
        RETURN QUERY SELECT false, 0, 'Challenge not completed yet'::TEXT;
        RETURN;
    END IF;

    -- Validate XP not already claimed
    IF v_progress.xp_claimed THEN
        RETURN QUERY SELECT false, 0, 'Reward already claimed'::TEXT;
        RETURN;
    END IF;

    -- Mark as claimed
    UPDATE user_challenge_progress
    SET xp_claimed = true
    WHERE user_id = p_user_id
      AND challenge_id = p_challenge_id;

    -- Return success
    RETURN QUERY SELECT true, v_challenge.xp_reward, 'Reward claimed successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION claim_challenge_reward(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION claim_challenge_reward IS 'Claims XP reward for a completed challenge. Validates completion and prevents double-claiming.';

-- =====================================================
-- PART 5: Stats and Leaderboard Functions
-- =====================================================

-- =============================================================================
-- FUNCTION: get_user_gamification_stats
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

GRANT EXECUTE ON FUNCTION get_user_gamification_stats(UUID) TO authenticated;

COMMENT ON FUNCTION get_user_gamification_stats IS 'Returns all gamification data for stats dashboard: XP, rank, streaks, counts, achievements. Single comprehensive query for frontend display.';

-- =============================================================================
-- FUNCTION: get_user_achievements
-- =============================================================================
-- Get all achievements with unlock status and translations

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

GRANT EXECUTE ON FUNCTION get_user_achievements(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION get_user_achievements IS 'Returns all achievements with unlock status for a user in specified language (en/hi/ml). Includes unlocked_at timestamp and is_unlocked boolean.';

-- =====================================================
-- PART 6: Triggers
-- =====================================================

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

COMMENT ON FUNCTION update_study_streak_updated_at IS 'Trigger function to automatically update updated_at timestamp on user_study_streaks table modifications';

-- =============================================================================
-- TRIGGER: daily_verse_streaks updated_at
-- =============================================================================

CREATE OR REPLACE FUNCTION update_daily_verse_streak_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_daily_verse_streak_updated_at_trigger ON daily_verse_streaks;
CREATE TRIGGER update_daily_verse_streak_updated_at_trigger
    BEFORE UPDATE ON daily_verse_streaks
    FOR EACH ROW
    EXECUTE FUNCTION update_daily_verse_streak_updated_at();

COMMENT ON FUNCTION update_daily_verse_streak_updated_at IS 'Trigger function to automatically update updated_at timestamp on daily_verse_streaks table modifications';

-- =====================================================
-- PART 7: Seed Data - Achievements
-- =====================================================

INSERT INTO achievements (id, name_en, name_hi, name_ml, description_en, description_hi, description_ml, icon, xp_reward, category, threshold, sort_order)
VALUES
    -- Study Achievements (5 tiers)
    ('first_study', 'First Steps', 'पहला कदम', 'ആദ്യ ചുവട്', 'Complete your first study guide', 'अपनी पहली स्टडी गाइड पूरी करें', 'നിങ്ങളുടെ ആദ്യ സ്റ്റഡി ഗൈഡ് പൂർത്തിയാക്കുക', '🎯', 25, 'study', 1, 1),
    ('studies_10', 'Curious Mind', 'जिज्ञासु मन', 'ജിജ്ഞാസുവായ മനസ്സ്', 'Complete 10 study guides', '10 स्टडी गाइड पूरी करें', '10 സ്റ്റഡി ഗൈഡുകൾ പൂർത്തിയാക്കുക', '🔍', 50, 'study', 10, 2),
    ('studies_25', 'Scholar', 'विद्वान', 'പണ്ഡിതൻ', 'Complete 25 study guides', '25 स्टडी गाइड पूरी करें', '25 സ്റ്റഡി ഗൈഡുകൾ പൂർത്തിയാക്കുക', '📚', 100, 'study', 25, 3),
    ('studies_50', 'Professor', 'प्रोफेसर', 'പ്രൊഫസർ', 'Complete 50 study guides', '50 स्टडी गाइड पूरी करें', '50 സ്റ്റഡി ഗൈഡുകൾ പൂർത്തിയാക്കുക', '🎓', 200, 'study', 50, 4),
    ('studies_100', 'Bible Expert', 'बाइबल विशेषज्ञ', 'ബൈബിൾ വിദഗ്ധൻ', 'Complete 100 study guides', '100 स्टडी गाइड पूरी करें', '100 സ്റ്റഡി ഗൈഡുകൾ പൂർത്തിയാക്കുക', '👑', 500, 'study', 100, 5),

    -- Study Streak Achievements (3 tiers)
    ('study_streak_7', 'Week Warrior', 'सप्ताह योद्धा', 'ആഴ്ച യോദ്ധാവ്', '7-day study streak', '7 दिन की स्टडी स्ट्रीक', '7 ദിവസത്തെ സ്റ്റഡി സ്ട്രീക്ക്', '🔥', 75, 'streak', 7, 6),
    ('study_streak_30', 'Monthly Master', 'मासिक मास्टर', 'മാസ മാസ്റ്റർ', '30-day study streak', '30 दिन की स्टडी स्ट्रीक', '30 ദിവസത്തെ സ്റ്റഡി സ്ട്രീക്ക്', '✨', 200, 'streak', 30, 7),
    ('study_streak_100', 'Century Scholar', 'शताब्दी विद्वान', 'നൂറ്റാണ്ട് പണ്ഡിതൻ', '100-day study streak', '100 दिन की स्टडी स्ट्रीक', '100 ദിവസത്തെ സ്റ്റഡി സ്ട്രീക്ക്', '🏆', 500, 'streak', 100, 8),

    -- Memory Verse Achievements - Beginner Tier (5 tiers)
    ('memory_first_verse', 'First Memory', 'पहली याद', 'ആദ്യ ഓർമ്മ', 'Add your first memory verse', 'अपना पहला याद का पद जोड़ें', 'നിങ്ങളുടെ ആദ്യ മെമ്മറി വാക്യം ചേർക്കുക', '🌟', 25, 'memory', 1, 9),
    ('memory_5', 'Memorizer', 'याद करने वाला', 'ഓർമ്മിക്കുന്നവൻ', 'Add 5 memory verses', '5 याद करने के पद जोड़ें', '5 മെമ്മറി വാക്യങ്ങൾ ചേർക്കുക', '🧠', 50, 'memory', 5, 10),
    ('memory_25', 'Scripture Keeper', 'वचन रक्षक', 'തിരുവചന സൂക്ഷിപ്പുകാരൻ', 'Add 25 memory verses', '25 याद करने के पद जोड़ें', '25 മെമ്മറി വാക്യങ്ങൾ ചേർക്കുക', '📖', 150, 'memory', 25, 11),
    ('memory_50', 'Scripture Vault', 'वचन तिजोरी', 'തിരുവചന ഭണ്ഡാരം', 'Memorize 50 verses', '50 पद याद करें', '50 വാക്യങ്ങൾ മനഃപാഠമാക്കുക', '🔐', 600, 'memory', 50, 12),
    ('memory_100', 'Scripture Library', 'वचन पुस्तकालय', 'തിരുവചന ലൈബ്രറി', 'Memorize 100 verses', '100 पद याद करें', '100 വാക്യങ്ങൾ മനഃപാഠമാക്കുക', '📖', 1200, 'memory', 100, 13),

    -- Memory Achievement - Perfect Recalls (2 tiers)
    ('memory_perfect_recall', 'Perfect Recall', 'सटीक याद', 'തികഞ്ഞ ഓർമ്മ', 'Achieve your first perfect recall (quality 5)', 'अपनी पहली सटीक याद प्राप्त करें', 'നിങ്ങളുടെ ആദ്യ തികഞ്ഞ ഓർമ്മ നേടുക', '💫', 50, 'memory', 1, 14),
    ('memory_perfect_recalls_50', 'Perfectionist', 'परफेक्शनिस्ट', 'തികവുള്ളവൻ', 'Achieve 50 perfect recalls (quality 5)', '50 सटीक याद प्राप्त करें', '50 തികഞ്ഞ ഓർമ്മകൾ നേടുക', '💎', 800, 'memory', 50, 15),

    -- Memory Achievement - Practice Streaks (4 tiers)
    ('memory_practice_streak_3', '3-Day Streak', '3 दिन की स्ट्रीक', '3 ദിവസ സ്ട്രീക്ക്', 'Practice memory verses 3 days in a row', 'लगातार 3 दिन याद के पद का अभ्यास करें', 'തുടർച്ചയായി 3 ദിവസം മെമ്മറി വാക്യങ്ങൾ പരിശീലിക്കുക', '🔥', 50, 'memory', 3, 16),
    ('memory_practice_streak_7', 'Week of Practice', 'अभ्यास का सप्ताह', 'പരിശീലനത്തിന്റെ ആഴ്ച', 'Practice memory verses 7 days in a row', 'लगातार 7 दिन याद के पद का अभ्यास करें', 'തുടർച്ചയായി 7 ദിവസം മെമ്മറി വാക്യങ്ങൾ പരിശീലിക്കുക', '📅', 100, 'memory', 7, 17),
    ('memory_practice_streak_30', 'Month of Memory', 'मेमोरी का महीना', 'മെമ്മറിയുടെ മാസം', 'Practice memory verses 30 days in a row', 'लगातार 30 दिन याद के पद का अभ्यास करें', 'തുടർച്ചയായി 30 ദിവസം മെമ്മറി വാക്യങ്ങൾ പരിശീലിക്കുക', '📆', 500, 'memory', 30, 18),
    ('memory_practice_streak_100', 'Century Streak', 'शताब्दी स्ट्रीक', 'നൂറ് ദിവസ സ്ട്രീക്ക്', 'Practice memory verses 100 days in a row', 'लगातार 100 दिन याद के पद का अभ्यास करें', 'തുടർച്ചയായി 100 ദിവസം മെമ്മറി വാക്യങ്ങൾ പരിശീലിക്കുക', '💯', 1000, 'memory', 100, 19),

    -- Memory Achievement - Mode Variety (2 tiers)
    ('memory_modes_3', 'Mode Explorer', 'मोड एक्सप्लोरर', 'മോഡ് എക്സ്പ്ലോറർ', 'Try 3 different practice modes', '3 विभिन्न अभ्यास मोड आज़माएं', '3 വ്യത്യസ്ത പരിശീലന മോഡുകൾ പരീക്ഷിക്കുക', '🎯', 50, 'memory', 3, 20),
    ('memory_modes_5', 'Mode Master', 'मोड मास्टर', 'മോഡ് മാസ്റ്റർ', '80%+ success rate in 3 practice modes', '3 अभ्यास मोड में 80%+ सफलता दर', '3 പരിശീലന മോഡുകളിൽ 80%+ വിജയ നിരക്ക്', '🎖️', 400, 'memory', 3, 21),

    -- Memory Achievement - Mastery Levels (3 tiers)
    ('memory_mastery_intermediate_3', 'Intermediate Master', 'मध्यवर्ती मास्टर', 'ഇന്റർമീഡിയറ്റ് മാസ്റ്റർ', 'Reach Intermediate mastery on 3 verses', '3 पदों पर मध्यवर्ती महारत हासिल करें', '3 വാക്യങ്ങളിൽ ഇന്റർമീഡിയറ്റ് വൈദഗ്ധ്യം നേടുക', '🥉', 200, 'memory', 3, 22),
    ('memory_mastery_advanced_5', 'Advanced Scholar', 'उन्नत विद्वान', 'മുന്നേറിയ പണ്ഡിതൻ', 'Reach Advanced mastery on 5 verses', '5 पदों पर उन്नत स्तर की महारत हासिल करें', '5 വാക്യങ്ങളിൽ അഡ്വാൻസ്ഡ് വൈദഗ്ധ്യം നേടുക', '🎓', 500, 'memory', 5, 23),
    ('memory_mastery_expert_10', 'Expert Memorizer', 'विशेषज्ञ याद करने वाला', 'വിദഗ്ധ മനഃപാഠക്കാരൻ', 'Reach Expert mastery on 10 verses', '10 पदों पर विशेषज्ञ स्तर की महारत हासिल करें', '10 വാക്യങ്ങളിൽ വിദഗ്ധ വൈദഗ്ധ്യം നേടുക', '🏅', 1000, 'memory', 10, 24),

    -- Memory Achievement - Daily Goals & Challenges
    ('memory_daily_goal_5', 'Goal Achiever', 'लक्ष्य साधक', 'ലക്ഷ്യം നേടിയവൻ', 'Complete 5 daily goals', '5 दैनिक लक्ष्य पूरे करें', '5 ദിവസേനയുള്ള ലക്ഷ്യങ്ങൾ പൂർത്തിയാക്കുക', '🎯', 300, 'memory', 5, 25),
    ('memory_challenge_champion', 'Challenge Champion', 'चुनौती चैंपियन', 'വെല്ലുവിളി ചാമ്പ്യൻ', 'Complete 5 weekly memory challenges', '5 साप्ताहिक याद चुनौतियाँ पूरी करें', '5 പ്രതിവാര മെമ്മറി വെല്ലുവിളികൾ പൂർത്തിയാക്കുക', '🏆', 400, 'memory', 5, 26),
    ('memory_collections_5', 'Collection Curator', 'संग्रह क्यूरेटर', 'ശേഖരണ ക്യൂറേറ്റർ', 'Create 5 verse collections', '5 पद संग्रह बनाएँ', '5 വാക്യ ശേഖരണങ്ങൾ സൃഷ്ടിക്കുക', '📚', 500, 'memory', 5, 27),

    -- Voice Discipler Achievements (2 tiers)
    ('voice_5', 'Voice Learner', 'वॉयस शिक्षार्थी', 'വോയ്സ് പഠിതാവ്', 'Complete 5 voice sessions', '5 वॉयस सेशन पूरे करें', '5 വോയ്സ് സെഷനുകൾ പൂർത്തിയാക്കുക', '🎙️', 50, 'voice', 5, 28),
    ('voice_25', 'Conversation Master', 'वार्तालाप मास्टर', 'സംഭാഷണ മാസ്റ്റർ', 'Complete 25 voice sessions', '25 वॉयस सेशन पूरे करें', '25 വോയ്സ് സെഷനുകൾ പൂർത്തിയാക്കുക', '🗣️', 150, 'voice', 25, 29),

    -- Saved Guides Achievements (2 tiers)
    ('saved_10', 'Bookworm', 'किताबी कीड़ा', 'പുസ്തകപ്പുഴു', 'Save 10 study guides', '10 स्टडी गाइड सेव करें', '10 സ്റ്റഡി ഗൈഡുകൾ സേവ് ചെയ്യുക', '📕', 50, 'saved', 10, 30),
    ('saved_50', 'Library Builder', 'पुस्तकालय निर्माता', 'ലൈബ്രറി നിർമ്മാതാവ്', 'Save 50 study guides', '50 स्टडी गाइड सेव करें', '50 സ്റ്റഡി ഗൈഡുകൾ സേവ് ചെയ്യുക', '📚', 150, 'saved', 50, 31)
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

-- =====================================================
-- PART 8: Initial Weekly Challenges
-- =====================================================

-- Create this week's challenges
SELECT create_weekly_memory_challenges();

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Verify table creation
DO $$
DECLARE
    v_achievements_count INTEGER;
    v_user_study_streaks_exists BOOLEAN;
    v_memory_challenges_exists BOOLEAN;
    v_user_challenge_progress_exists BOOLEAN;
    v_function_count INTEGER;
BEGIN
    -- Check achievements seeded
    SELECT COUNT(*) INTO v_achievements_count FROM achievements;
    IF v_achievements_count < 31 THEN
        RAISE WARNING 'Achievement seed data incomplete: expected 31+, got %', v_achievements_count;
    ELSE
        RAISE NOTICE '✓ Achievement seed data complete: % achievements', v_achievements_count;
    END IF;

    -- Check tables exist
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'user_study_streaks'
    ) INTO v_user_study_streaks_exists;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'memory_challenges'
    ) INTO v_memory_challenges_exists;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'user_challenge_progress'
    ) INTO v_user_challenge_progress_exists;

    IF v_user_study_streaks_exists AND v_memory_challenges_exists AND v_user_challenge_progress_exists THEN
        RAISE NOTICE '✓ All gamification tables created successfully';
    ELSE
        RAISE WARNING 'Some gamification tables missing';
    END IF;

    -- Check functions exist
    SELECT COUNT(*) INTO v_function_count
    FROM pg_proc
    WHERE proname IN (
        'get_or_create_study_streak',
        'update_study_streak',
        'calculate_study_streak',
        'check_study_achievements',
        'check_streak_achievements',
        'check_memory_achievements',
        'check_voice_achievements',
        'check_saved_achievements',
        'get_user_gamification_stats',
        'get_user_achievements',
        'create_weekly_memory_challenges',
        'update_challenge_progress',
        'claim_challenge_reward'
    );

    IF v_function_count >= 13 THEN
        RAISE NOTICE '✓ All gamification functions created successfully (% functions)', v_function_count;
    ELSE
        RAISE WARNING 'Some gamification functions missing: expected 13, got %', v_function_count;
    END IF;

    RAISE NOTICE '==================================================';
    RAISE NOTICE 'GAMIFICATION SYSTEM MIGRATION COMPLETE';
    RAISE NOTICE '==================================================';
    RAISE NOTICE '✓ 6 tables created (achievements, user_achievements, user_study_streaks, daily_verse_streaks, memory_challenges, user_challenge_progress)';
    RAISE NOTICE '✓ % functions created', v_function_count;
    RAISE NOTICE '✓ % achievements seeded', v_achievements_count;
    RAISE NOTICE '✓ Initial weekly challenges created';
    RAISE NOTICE '✓ All RLS policies applied';
END $$;

COMMIT;

-- =====================================================
-- POST-MIGRATION NOTES
-- =====================================================

-- IMPORTANT: Set up pg_cron job for weekly challenge creation:
--   SELECT cron.schedule(
--     'create-weekly-challenges',
--     '0 0 * * 1',  -- Every Monday at 00:00 UTC
--     $$SELECT create_weekly_memory_challenges();$$
--   );

-- Functions available:
--   - get_or_create_study_streak(UUID)
--   - get_or_create_user_streak(UUID) [for daily verse streaks]
--   - update_study_streak(UUID)
--   - calculate_study_streak(UUID)
--   - check_study_achievements(UUID)
--   - check_streak_achievements(UUID)
--   - check_memory_achievements(UUID)
--   - check_voice_achievements(UUID)
--   - check_saved_achievements(UUID)
--   - get_user_gamification_stats(UUID)
--   - get_user_achievements(UUID, TEXT)
--   - create_weekly_memory_challenges()
--   - update_challenge_progress(UUID, TEXT, INTEGER)
--   - claim_challenge_reward(UUID, UUID)

-- Edge Function Integration:
--   Call achievement checking functions after:
--   - Study guide completion (check_study_achievements, check_streak_achievements, update_study_streak)
--   - Memory verse addition/practice (check_memory_achievements)
--   - Voice conversation completion (check_voice_achievements)
--   - Guide saved (check_saved_achievements)
--   Call update_challenge_progress after relevant memory verse practice
