-- Migration: Fix ambiguous column reference in get_or_create_study_streak
-- Created: 2025-12-13
-- Purpose: Fix PGRST202 error due to RETURNS TABLE column name conflicting with table column

BEGIN;

-- =============================================================================
-- FIX: get_or_create_study_streak - user_id in RETURNS TABLE conflicts with table column
-- Solution: Drop and recreate with renamed return columns to avoid ambiguity
-- =============================================================================

-- First drop the existing function
DROP FUNCTION IF EXISTS get_or_create_study_streak(UUID);

-- Recreate with disambiguated return column names
CREATE FUNCTION get_or_create_study_streak(p_user_id UUID)
RETURNS TABLE (
    streak_id UUID,
    streak_user_id UUID,
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
    RETURNING 
        user_study_streaks.id,
        user_study_streaks.user_id,
        user_study_streaks.current_streak,
        user_study_streaks.longest_streak,
        user_study_streaks.last_study_date,
        user_study_streaks.total_study_days,
        user_study_streaks.created_at,
        user_study_streaks.updated_at;

    -- If INSERT was skipped due to conflict, fetch existing row
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            s.id,
            s.user_id,
            s.current_streak,
            s.longest_streak,
            s.last_study_date,
            s.total_study_days,
            s.created_at,
            s.updated_at
        FROM user_study_streaks s
        WHERE s.user_id = p_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
