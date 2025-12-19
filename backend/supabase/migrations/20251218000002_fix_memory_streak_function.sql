-- Migration: Fix Memory Verse Streak Function Ambiguity
-- Created: 2025-12-18
-- Purpose: Fix ambiguous column reference in get_or_create_memory_streak function

BEGIN;

-- =============================================================================
-- FUNCTION: Get or Create Memory Verse Streak (Fixed)
-- =============================================================================

CREATE OR REPLACE FUNCTION get_or_create_memory_streak(p_user_id UUID)
RETURNS TABLE (
    user_id UUID,
    current_streak INTEGER,
    longest_streak INTEGER,
    last_practice_date DATE,
    total_practice_days INTEGER,
    freeze_days_available INTEGER,
    freeze_days_used INTEGER,
    milestone_10_date TIMESTAMPTZ,
    milestone_30_date TIMESTAMPTZ,
    milestone_100_date TIMESTAMPTZ,
    milestone_365_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
) AS $$
DECLARE
    v_result RECORD;
BEGIN
    -- Try to insert first (atomic, prevents race conditions)
    INSERT INTO memory_verse_streaks (user_id)
    VALUES (p_user_id)
    ON CONFLICT ON CONSTRAINT memory_verse_streaks_pkey DO NOTHING;

    -- Fetch the record (whether just created or already existed)
    SELECT 
        s.user_id,
        s.current_streak,
        s.longest_streak,
        s.last_practice_date,
        s.total_practice_days,
        s.freeze_days_available,
        s.freeze_days_used,
        s.milestone_10_date,
        s.milestone_30_date,
        s.milestone_100_date,
        s.milestone_365_date,
        s.created_at,
        s.updated_at
    INTO v_result
    FROM memory_verse_streaks s
    WHERE s.user_id = p_user_id;

    RETURN QUERY
    SELECT 
        v_result.user_id,
        v_result.current_streak,
        v_result.longest_streak,
        v_result.last_practice_date,
        v_result.total_practice_days,
        v_result.freeze_days_available,
        v_result.freeze_days_used,
        v_result.milestone_10_date,
        v_result.milestone_30_date,
        v_result.milestone_100_date,
        v_result.milestone_365_date,
        v_result.created_at,
        v_result.updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_or_create_memory_streak IS 'Gets or atomically creates a memory verse streak record for a user (fixed ambiguous column references)';

COMMIT;
