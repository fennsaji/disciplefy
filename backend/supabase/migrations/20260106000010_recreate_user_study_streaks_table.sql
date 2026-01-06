-- Migration: Recreate user_study_streaks table
-- Purpose: The user_study_streaks table was missing, causing update_study_streak RPC to fail
-- Issue: Table was supposed to be preserved but was dropped at some point
-- Fix: Recreate table with proper schema and RLS policies

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
    achievement_xp INTEGER NOT NULL DEFAULT 0 CHECK (achievement_xp >= 0),
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

-- RLS Policies (use IF NOT EXISTS pattern via DROP POLICY IF EXISTS + CREATE)
DROP POLICY IF EXISTS "Users can read own study streak" ON user_study_streaks;
DROP POLICY IF EXISTS "Users can insert own study streak" ON user_study_streaks;
DROP POLICY IF EXISTS "Users can update own study streak" ON user_study_streaks;
DROP POLICY IF EXISTS "Service role can manage all study streaks" ON user_study_streaks;

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

CREATE POLICY "Service role can manage all study streaks"
    ON user_study_streaks FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Add table and column comments
COMMENT ON TABLE user_study_streaks IS
'Tracks consecutive days of study guide completion for gamification.
Separate from memory verse streaks (memory_verse_streaks) and daily verse streaks (daily_verse_streaks).
Used by update_study_streak() RPC function.';

COMMENT ON COLUMN user_study_streaks.achievement_xp IS
'Total XP earned from achievement unlocks. Awarded when users unlock achievements via check_*_achievements functions.';

COMMIT;
