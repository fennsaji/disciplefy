-- Migration: Memory Verses Gamification Schema
-- Created: 2025-12-17
-- Purpose: Create comprehensive gamification system for memory verses with practice modes,
--          streaks, mastery levels, daily goals, challenges, and collections

BEGIN;

-- =============================================================================
-- TABLE: memory_practice_modes
-- =============================================================================
-- Tracks performance per practice mode per verse

CREATE TABLE IF NOT EXISTS memory_practice_modes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,
    mode_type TEXT NOT NULL CHECK (mode_type IN (
        'flip_card', 'typing', 'cloze', 'first_letter',
        'progressive', 'word_scramble', 'word_order', 'audio'
    )),
    times_practiced INTEGER DEFAULT 0 CHECK (times_practiced >= 0),
    success_rate DECIMAL(5,2) DEFAULT 0.0 CHECK (success_rate >= 0.0 AND success_rate <= 100.0),
    average_time_seconds INTEGER CHECK (average_time_seconds >= 0),
    is_favorite BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_user_verse_mode UNIQUE(user_id, memory_verse_id, mode_type)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_user_id
    ON memory_practice_modes(user_id);

CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_verse_id
    ON memory_practice_modes(memory_verse_id);

CREATE INDEX IF NOT EXISTS idx_memory_practice_modes_mode_type
    ON memory_practice_modes(mode_type);

-- Enable RLS
ALTER TABLE memory_practice_modes ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can read own practice modes" ON memory_practice_modes;
DROP POLICY IF EXISTS "Users can insert own practice modes" ON memory_practice_modes;
DROP POLICY IF EXISTS "Users can update own practice modes" ON memory_practice_modes;
DROP POLICY IF EXISTS "Users can delete own practice modes" ON memory_practice_modes;

CREATE POLICY "Users can read own practice modes"
    ON memory_practice_modes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own practice modes"
    ON memory_practice_modes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own practice modes"
    ON memory_practice_modes FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own practice modes"
    ON memory_practice_modes FOR DELETE
    USING (auth.uid() = user_id);

-- =============================================================================
-- TABLE: memory_verse_streaks
-- =============================================================================
-- Separate streak system for memory practice

CREATE TABLE IF NOT EXISTS memory_verse_streaks (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak INTEGER DEFAULT 0 CHECK (current_streak >= 0),
    longest_streak INTEGER DEFAULT 0 CHECK (longest_streak >= 0),
    last_practice_date DATE,
    total_practice_days INTEGER DEFAULT 0 CHECK (total_practice_days >= 0),
    freeze_days_available INTEGER DEFAULT 0 CHECK (freeze_days_available >= 0),
    freeze_days_used INTEGER DEFAULT 0 CHECK (freeze_days_used >= 0),
    milestone_10_date TIMESTAMPTZ,
    milestone_30_date TIMESTAMPTZ,
    milestone_100_date TIMESTAMPTZ,
    milestone_365_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_memory_verse_streaks_current_streak
    ON memory_verse_streaks(current_streak DESC);

CREATE INDEX IF NOT EXISTS idx_memory_verse_streaks_last_practice
    ON memory_verse_streaks(last_practice_date DESC);

-- Enable RLS
ALTER TABLE memory_verse_streaks ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can read own memory streak" ON memory_verse_streaks;
DROP POLICY IF EXISTS "Users can insert own memory streak" ON memory_verse_streaks;
DROP POLICY IF EXISTS "Users can update own memory streak" ON memory_verse_streaks;

CREATE POLICY "Users can read own memory streak"
    ON memory_verse_streaks FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own memory streak"
    ON memory_verse_streaks FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own memory streak"
    ON memory_verse_streaks FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- TABLE: memory_verse_mastery
-- =============================================================================
-- Tracks progression through mastery levels

CREATE TABLE IF NOT EXISTS memory_verse_mastery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    memory_verse_id UUID NOT NULL REFERENCES memory_verses(id) ON DELETE CASCADE,
    mastery_level TEXT NOT NULL DEFAULT 'beginner' CHECK (
        mastery_level IN ('beginner', 'intermediate', 'advanced', 'expert', 'master')
    ),
    mastery_percentage DECIMAL(5,2) DEFAULT 0.0 CHECK (mastery_percentage >= 0.0 AND mastery_percentage <= 100.0),
    modes_mastered INTEGER DEFAULT 0 CHECK (modes_mastered >= 0),
    perfect_recalls INTEGER DEFAULT 0 CHECK (perfect_recalls >= 0),
    confidence_rating DECIMAL(3,1) CHECK (confidence_rating >= 0.0 AND confidence_rating <= 5.0),
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_user_verse_mastery UNIQUE(user_id, memory_verse_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_user_id
    ON memory_verse_mastery(user_id);

CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_verse_id
    ON memory_verse_mastery(memory_verse_id);

CREATE INDEX IF NOT EXISTS idx_memory_verse_mastery_level
    ON memory_verse_mastery(mastery_level);

-- Enable RLS
ALTER TABLE memory_verse_mastery ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can read own mastery" ON memory_verse_mastery;
DROP POLICY IF EXISTS "Users can insert own mastery" ON memory_verse_mastery;
DROP POLICY IF EXISTS "Users can update own mastery" ON memory_verse_mastery;
DROP POLICY IF EXISTS "Users can delete own mastery" ON memory_verse_mastery;

CREATE POLICY "Users can read own mastery"
    ON memory_verse_mastery FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own mastery"
    ON memory_verse_mastery FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own mastery"
    ON memory_verse_mastery FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own mastery"
    ON memory_verse_mastery FOR DELETE
    USING (auth.uid() = user_id);

-- =============================================================================
-- TABLE: memory_daily_goals
-- =============================================================================
-- Daily practice targets

CREATE TABLE IF NOT EXISTS memory_daily_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    goal_date DATE NOT NULL,
    target_reviews INTEGER DEFAULT 5 CHECK (target_reviews >= 0),
    completed_reviews INTEGER DEFAULT 0 CHECK (completed_reviews >= 0),
    target_new_verses INTEGER DEFAULT 1 CHECK (target_new_verses >= 0),
    added_new_verses INTEGER DEFAULT 0 CHECK (added_new_verses >= 0),
    goal_achieved BOOLEAN DEFAULT FALSE,
    bonus_xp_awarded INTEGER DEFAULT 0 CHECK (bonus_xp_awarded >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT unique_user_goal_date UNIQUE(user_id, goal_date)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_user_id
    ON memory_daily_goals(user_id);

CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_date
    ON memory_daily_goals(goal_date DESC);

CREATE INDEX IF NOT EXISTS idx_memory_daily_goals_achieved
    ON memory_daily_goals(goal_achieved) WHERE goal_achieved = TRUE;

-- Enable RLS
ALTER TABLE memory_daily_goals ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can read own daily goals" ON memory_daily_goals;
DROP POLICY IF EXISTS "Users can insert own daily goals" ON memory_daily_goals;
DROP POLICY IF EXISTS "Users can update own daily goals" ON memory_daily_goals;

CREATE POLICY "Users can read own daily goals"
    ON memory_daily_goals FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own daily goals"
    ON memory_daily_goals FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own daily goals"
    ON memory_daily_goals FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- TABLE: memory_challenges
-- =============================================================================
-- Weekly/monthly challenges

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

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_memory_challenges_active
    ON memory_challenges(is_active) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_memory_challenges_dates
    ON memory_challenges(start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_memory_challenges_type
    ON memory_challenges(challenge_type);

-- Enable RLS
ALTER TABLE memory_challenges ENABLE ROW LEVEL SECURITY;

-- RLS Policies - Challenges are public read-only
DROP POLICY IF EXISTS "Everyone can read active challenges" ON memory_challenges;

CREATE POLICY "Everyone can read active challenges"
    ON memory_challenges FOR SELECT
    USING (is_active = TRUE);

-- =============================================================================
-- TABLE: user_challenge_progress
-- =============================================================================
-- Tracks user progress on challenges

CREATE TABLE IF NOT EXISTS user_challenge_progress (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    challenge_id UUID REFERENCES memory_challenges(id) ON DELETE CASCADE,
    current_progress INTEGER DEFAULT 0 CHECK (current_progress >= 0),
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    xp_claimed BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (user_id, challenge_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_user_id
    ON user_challenge_progress(user_id);

CREATE INDEX IF NOT EXISTS idx_user_challenge_progress_completed
    ON user_challenge_progress(is_completed) WHERE is_completed = TRUE;

-- Enable RLS
ALTER TABLE user_challenge_progress ENABLE ROW LEVEL SECURITY;

-- RLS Policies
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

-- =============================================================================
-- TABLE: memory_verse_collections
-- =============================================================================
-- Topical verse groupings

CREATE TABLE IF NOT EXISTS memory_verse_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT CHECK (category IN (
        'comfort', 'wisdom', 'promises', 'commands',
        'prophecy', 'gospel', 'prayer', 'custom'
    )),
    description TEXT,
    icon TEXT,
    color TEXT,
    verse_count INTEGER DEFAULT 0 CHECK (verse_count >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_memory_verse_collections_user_id
    ON memory_verse_collections(user_id);

CREATE INDEX IF NOT EXISTS idx_memory_verse_collections_category
    ON memory_verse_collections(category);

-- Enable RLS
ALTER TABLE memory_verse_collections ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can read own collections" ON memory_verse_collections;
DROP POLICY IF EXISTS "Users can insert own collections" ON memory_verse_collections;
DROP POLICY IF EXISTS "Users can update own collections" ON memory_verse_collections;
DROP POLICY IF EXISTS "Users can delete own collections" ON memory_verse_collections;

CREATE POLICY "Users can read own collections"
    ON memory_verse_collections FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own collections"
    ON memory_verse_collections FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own collections"
    ON memory_verse_collections FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own collections"
    ON memory_verse_collections FOR DELETE
    USING (auth.uid() = user_id);

-- =============================================================================
-- TABLE: memory_verse_collection_items
-- =============================================================================
-- Many-to-many for collections

CREATE TABLE IF NOT EXISTS memory_verse_collection_items (
    collection_id UUID REFERENCES memory_verse_collections(id) ON DELETE CASCADE,
    memory_verse_id UUID REFERENCES memory_verses(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    PRIMARY KEY (collection_id, memory_verse_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_collection_items_collection_id
    ON memory_verse_collection_items(collection_id);

CREATE INDEX IF NOT EXISTS idx_collection_items_verse_id
    ON memory_verse_collection_items(memory_verse_id);

-- Enable RLS
ALTER TABLE memory_verse_collection_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies - Access controlled through collection ownership
DROP POLICY IF EXISTS "Users can read own collection items" ON memory_verse_collection_items;
DROP POLICY IF EXISTS "Users can insert own collection items" ON memory_verse_collection_items;
DROP POLICY IF EXISTS "Users can delete own collection items" ON memory_verse_collection_items;

CREATE POLICY "Users can read own collection items"
    ON memory_verse_collection_items FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM memory_verse_collections
            WHERE id = collection_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own collection items"
    ON memory_verse_collection_items FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM memory_verse_collections
            WHERE id = collection_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete own collection items"
    ON memory_verse_collection_items FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM memory_verse_collections
            WHERE id = collection_id AND user_id = auth.uid()
        )
    );

-- =============================================================================
-- EXTEND EXISTING TABLES
-- =============================================================================

-- Extend review_sessions table
ALTER TABLE review_sessions
    ADD COLUMN IF NOT EXISTS practice_mode TEXT,
    ADD COLUMN IF NOT EXISTS confidence_rating INTEGER CHECK (confidence_rating BETWEEN 1 AND 5),
    ADD COLUMN IF NOT EXISTS accuracy_percentage DECIMAL(5,2) CHECK (accuracy_percentage >= 0.0 AND accuracy_percentage <= 100.0),
    ADD COLUMN IF NOT EXISTS hints_used INTEGER DEFAULT 0 CHECK (hints_used >= 0);

-- Extend memory_verses table
ALTER TABLE memory_verses
    ADD COLUMN IF NOT EXISTS preferred_practice_mode TEXT,
    ADD COLUMN IF NOT EXISTS mastery_level TEXT DEFAULT 'beginner',
    ADD COLUMN IF NOT EXISTS times_perfectly_recalled INTEGER DEFAULT 0 CHECK (times_perfectly_recalled >= 0);

-- =============================================================================
-- TRIGGERS: Updated At
-- =============================================================================

CREATE OR REPLACE FUNCTION update_memory_tables_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Practice modes trigger
DROP TRIGGER IF EXISTS update_memory_practice_modes_updated_at ON memory_practice_modes;
CREATE TRIGGER update_memory_practice_modes_updated_at
    BEFORE UPDATE ON memory_practice_modes
    FOR EACH ROW
    EXECUTE FUNCTION update_memory_tables_updated_at();

-- Streaks trigger
DROP TRIGGER IF EXISTS update_memory_verse_streaks_updated_at ON memory_verse_streaks;
CREATE TRIGGER update_memory_verse_streaks_updated_at
    BEFORE UPDATE ON memory_verse_streaks
    FOR EACH ROW
    EXECUTE FUNCTION update_memory_tables_updated_at();

-- Mastery trigger
DROP TRIGGER IF EXISTS update_memory_verse_mastery_updated_at ON memory_verse_mastery;
CREATE TRIGGER update_memory_verse_mastery_updated_at
    BEFORE UPDATE ON memory_verse_mastery
    FOR EACH ROW
    EXECUTE FUNCTION update_memory_tables_updated_at();

-- Collections trigger
DROP TRIGGER IF EXISTS update_memory_verse_collections_updated_at ON memory_verse_collections;
CREATE TRIGGER update_memory_verse_collections_updated_at
    BEFORE UPDATE ON memory_verse_collections
    FOR EACH ROW
    EXECUTE FUNCTION update_memory_tables_updated_at();

-- =============================================================================
-- TRIGGER: Update Collection Verse Count
-- =============================================================================

CREATE OR REPLACE FUNCTION update_collection_verse_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE memory_verse_collections
        SET verse_count = verse_count + 1
        WHERE id = NEW.collection_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE memory_verse_collections
        SET verse_count = verse_count - 1
        WHERE id = OLD.collection_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_collection_verse_count_trigger ON memory_verse_collection_items;
CREATE TRIGGER update_collection_verse_count_trigger
    AFTER INSERT OR DELETE ON memory_verse_collection_items
    FOR EACH ROW
    EXECUTE FUNCTION update_collection_verse_count();

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON TABLE memory_practice_modes IS 'Tracks performance statistics for each practice mode per verse (typing, cloze, first-letter, etc.)';
COMMENT ON TABLE memory_verse_streaks IS 'Separate streak system for memory verse practice with freeze days and milestones';
COMMENT ON TABLE memory_verse_mastery IS 'Tracks mastery progression from beginner to master level for each verse';
COMMENT ON TABLE memory_daily_goals IS 'Daily practice targets with review and new verse goals';
COMMENT ON TABLE memory_challenges IS 'Weekly/monthly challenges with XP rewards and time bounds';
COMMENT ON TABLE user_challenge_progress IS 'Tracks individual user progress on active challenges';
COMMENT ON TABLE memory_verse_collections IS 'User-created topical collections of memory verses (comfort, wisdom, promises, etc.)';
COMMENT ON TABLE memory_verse_collection_items IS 'Many-to-many relationship between collections and verses';

COMMIT;
