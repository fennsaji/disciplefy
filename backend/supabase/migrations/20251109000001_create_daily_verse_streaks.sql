-- Migration: Daily Verse Streaks Table
-- Created: 2025-11-09
-- Purpose: Track user engagement with daily verses through consecutive day streaks

-- Create daily_verse_streaks table
CREATE TABLE IF NOT EXISTS daily_verse_streaks (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak INTEGER NOT NULL DEFAULT 0 CHECK (current_streak >= 0),
    longest_streak INTEGER NOT NULL DEFAULT 0 CHECK (longest_streak >= 0),
    last_viewed_at TIMESTAMP WITH TIME ZONE,
    total_views INTEGER NOT NULL DEFAULT 0 CHECK (total_views >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT unique_user_streak UNIQUE(user_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_daily_verse_streaks_user_id
    ON daily_verse_streaks(user_id);

CREATE INDEX IF NOT EXISTS idx_daily_verse_streaks_current_streak
    ON daily_verse_streaks(current_streak DESC);

-- Add RLS (Row Level Security) policies
ALTER TABLE daily_verse_streaks ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own streak data
CREATE POLICY "Users can read own streak data"
    ON daily_verse_streaks FOR SELECT
    USING (auth.uid() = user_id);

-- Allow users to insert their own streak data
CREATE POLICY "Users can insert own streak data"
    ON daily_verse_streaks FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own streak data
CREATE POLICY "Users can update own streak data"
    ON daily_verse_streaks FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Allow service role full access
CREATE POLICY "Service role has full access to streaks"
    ON daily_verse_streaks FOR ALL
    USING (auth.role() = 'service_role');

-- Create trigger for updated_at timestamp
CREATE OR REPLACE FUNCTION update_daily_verse_streak_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_daily_verse_streak_updated_at_trigger
    BEFORE UPDATE ON daily_verse_streaks
    FOR EACH ROW
    EXECUTE FUNCTION update_daily_verse_streak_updated_at();

-- Create function to get or initialize user streak
CREATE OR REPLACE FUNCTION get_or_create_user_streak(p_user_id UUID)
RETURNS TABLE (
    id BIGINT,
    user_id UUID,
    current_streak INTEGER,
    longest_streak INTEGER,
    last_viewed_at TIMESTAMP WITH TIME ZONE,
    total_views INTEGER,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Try to get existing streak
    RETURN QUERY
    SELECT s.id, s.user_id, s.current_streak, s.longest_streak,
           s.last_viewed_at, s.total_views, s.created_at, s.updated_at
    FROM daily_verse_streaks s
    WHERE s.user_id = p_user_id;

    -- If no streak exists, create one
    IF NOT FOUND THEN
        RETURN QUERY
        INSERT INTO daily_verse_streaks (user_id)
        VALUES (p_user_id)
        RETURNING *;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add helpful comments
COMMENT ON TABLE daily_verse_streaks IS 'Tracks user engagement through consecutive daily verse viewing streaks';
COMMENT ON COLUMN daily_verse_streaks.user_id IS 'User ID from auth.users table';
COMMENT ON COLUMN daily_verse_streaks.current_streak IS 'Current consecutive days of verse viewing';
COMMENT ON COLUMN daily_verse_streaks.longest_streak IS 'Personal best streak record';
COMMENT ON COLUMN daily_verse_streaks.last_viewed_at IS 'Timestamp of last daily verse view';
COMMENT ON COLUMN daily_verse_streaks.total_views IS 'Lifetime count of daily verse views';
COMMENT ON FUNCTION get_or_create_user_streak(UUID) IS 'Gets existing streak or creates a new one for the user';
