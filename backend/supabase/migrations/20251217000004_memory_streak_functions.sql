-- Migration: Memory Verse Streak Management Functions
-- Created: 2025-12-17
-- Purpose: RPC functions for memory verse streak tracking and milestone management

BEGIN;

-- =============================================================================
-- FUNCTION: Get or Create Memory Verse Streak
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
BEGIN
    -- Try to insert first with ON CONFLICT DO NOTHING (atomic, prevents race conditions)
    RETURN QUERY
    INSERT INTO memory_verse_streaks (user_id)
    VALUES (p_user_id)
    ON CONFLICT (user_id) DO NOTHING
    RETURNING *;

    -- If INSERT was skipped due to conflict, fetch existing row
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT s.user_id, s.current_streak, s.longest_streak,
               s.last_practice_date, s.total_practice_days,
               s.freeze_days_available, s.freeze_days_used,
               s.milestone_10_date, s.milestone_30_date,
               s.milestone_100_date, s.milestone_365_date,
               s.created_at, s.updated_at
        FROM memory_verse_streaks s
        WHERE s.user_id = p_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION: Update Memory Verse Streak
-- =============================================================================

CREATE OR REPLACE FUNCTION update_memory_streak(p_user_id UUID)
RETURNS TABLE (
    current_streak INTEGER,
    longest_streak INTEGER,
    streak_increased BOOLEAN,
    is_new_record BOOLEAN,
    milestone_reached INTEGER
) AS $$
DECLARE
    v_today DATE := CURRENT_DATE;
    v_last_date DATE;
    v_current INTEGER;
    v_longest INTEGER;
    v_total_days INTEGER;
    v_freeze_available INTEGER;
    v_streak_increased BOOLEAN := FALSE;
    v_is_new_record BOOLEAN := FALSE;
    v_milestone_reached INTEGER := NULL;
    v_milestone_10 TIMESTAMPTZ;
    v_milestone_30 TIMESTAMPTZ;
    v_milestone_100 TIMESTAMPTZ;
    v_milestone_365 TIMESTAMPTZ;
BEGIN
    -- Get or create streak record
    PERFORM get_or_create_memory_streak(p_user_id);

    -- Get current values
    SELECT s.last_practice_date, s.current_streak, s.longest_streak,
           s.total_practice_days, s.freeze_days_available,
           s.milestone_10_date, s.milestone_30_date,
           s.milestone_100_date, s.milestone_365_date
    INTO v_last_date, v_current, v_longest, v_total_days, v_freeze_available,
         v_milestone_10, v_milestone_30, v_milestone_100, v_milestone_365
    FROM memory_verse_streaks s
    WHERE s.user_id = p_user_id;

    -- Only process if not already practiced today
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

        -- Increment total practice days
        v_total_days := v_total_days + 1;

        -- Award freeze days (1 per week of consistent practice)
        -- Check if practiced 5+ days in last 7 days
        IF v_current >= 5 AND v_current % 7 = 0 AND v_freeze_available < 5 THEN
            v_freeze_available := v_freeze_available + 1;
        END IF;

        -- Check and set milestones
        IF v_current >= 10 AND v_milestone_10 IS NULL THEN
            v_milestone_10 := NOW();
            v_milestone_reached := 10;
        END IF;

        IF v_current >= 30 AND v_milestone_30 IS NULL THEN
            v_milestone_30 := NOW();
            v_milestone_reached := 30;
        END IF;

        IF v_current >= 100 AND v_milestone_100 IS NULL THEN
            v_milestone_100 := NOW();
            v_milestone_reached := 100;
        END IF;

        IF v_current >= 365 AND v_milestone_365 IS NULL THEN
            v_milestone_365 := NOW();
            v_milestone_reached := 365;
        END IF;

        -- Update the record
        UPDATE memory_verse_streaks
        SET
            current_streak = v_current,
            longest_streak = v_longest,
            last_practice_date = v_today,
            total_practice_days = v_total_days,
            freeze_days_available = v_freeze_available,
            milestone_10_date = v_milestone_10,
            milestone_30_date = v_milestone_30,
            milestone_100_date = v_milestone_100,
            milestone_365_date = v_milestone_365,
            updated_at = NOW()
        WHERE memory_verse_streaks.user_id = p_user_id;
    END IF;

    RETURN QUERY SELECT v_current, v_longest, v_streak_increased, v_is_new_record, v_milestone_reached;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION: Use Streak Freeze
-- =============================================================================

CREATE OR REPLACE FUNCTION use_streak_freeze(p_user_id UUID, p_freeze_date DATE)
RETURNS TABLE (
    success BOOLEAN,
    freeze_days_remaining INTEGER,
    message TEXT
) AS $$
DECLARE
    v_freeze_available INTEGER;
    v_last_practice DATE;
    v_current_streak INTEGER;
    v_today DATE := CURRENT_DATE;
    v_yesterday DATE := CURRENT_DATE - 1;
BEGIN
    -- Get streak data
    SELECT freeze_days_available, last_practice_date, current_streak
    INTO v_freeze_available, v_last_practice, v_current_streak
    FROM memory_verse_streaks
    WHERE user_id = p_user_id;

    -- Validate freeze days available
    IF v_freeze_available <= 0 THEN
        RETURN QUERY SELECT FALSE, 0, 'No freeze days available'::TEXT;
        RETURN;
    END IF;

    -- Validate freeze date (can only protect yesterday or today)
    IF p_freeze_date NOT IN (v_yesterday, v_today) THEN
        RETURN QUERY SELECT FALSE, v_freeze_available, 'Can only protect yesterday or today'::TEXT;
        RETURN;
    END IF;

    -- Check if streak is actually at risk
    IF v_last_practice = v_today THEN
        RETURN QUERY SELECT FALSE, v_freeze_available, 'Already practiced today'::TEXT;
        RETURN;
    END IF;

    -- Apply freeze
    UPDATE memory_verse_streaks
    SET
        freeze_days_used = freeze_days_used + 1,
        freeze_days_available = freeze_days_available - 1,
        last_practice_date = p_freeze_date, -- Mark the freeze date as "practiced"
        updated_at = NOW()
    WHERE memory_verse_streaks.user_id = p_user_id;

    RETURN QUERY SELECT TRUE, v_freeze_available - 1, 'Streak protected successfully'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION: Check Streak Milestones
-- =============================================================================

CREATE OR REPLACE FUNCTION check_streak_milestones(p_user_id UUID)
RETURNS TABLE (
    milestone_10_reached BOOLEAN,
    milestone_30_reached BOOLEAN,
    milestone_100_reached BOOLEAN,
    milestone_365_reached BOOLEAN,
    next_milestone INTEGER,
    days_until_next INTEGER
) AS $$
DECLARE
    v_current_streak INTEGER;
    v_m10 TIMESTAMPTZ;
    v_m30 TIMESTAMPTZ;
    v_m100 TIMESTAMPTZ;
    v_m365 TIMESTAMPTZ;
    v_next_milestone INTEGER := NULL;
    v_days_until INTEGER := NULL;
BEGIN
    -- Get streak and milestone data
    SELECT current_streak, milestone_10_date, milestone_30_date,
           milestone_100_date, milestone_365_date
    INTO v_current_streak, v_m10, v_m30, v_m100, v_m365
    FROM memory_verse_streaks
    WHERE user_id = p_user_id;

    -- Handle no streak record
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, FALSE, FALSE, FALSE, 10, 10;
        RETURN;
    END IF;

    -- Determine next milestone
    IF v_current_streak < 10 THEN
        v_next_milestone := 10;
        v_days_until := 10 - v_current_streak;
    ELSIF v_current_streak < 30 THEN
        v_next_milestone := 30;
        v_days_until := 30 - v_current_streak;
    ELSIF v_current_streak < 100 THEN
        v_next_milestone := 100;
        v_days_until := 100 - v_current_streak;
    ELSIF v_current_streak < 365 THEN
        v_next_milestone := 365;
        v_days_until := 365 - v_current_streak;
    END IF;

    RETURN QUERY SELECT
        (v_m10 IS NOT NULL),
        (v_m30 IS NOT NULL),
        (v_m100 IS NOT NULL),
        (v_m365 IS NOT NULL),
        v_next_milestone,
        v_days_until;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION get_or_create_memory_streak(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_memory_streak(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION use_streak_freeze(UUID, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION check_streak_milestones(UUID) TO authenticated;

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON FUNCTION get_or_create_memory_streak IS 'Gets or atomically creates a memory verse streak record for a user';
COMMENT ON FUNCTION update_memory_streak IS 'Updates memory verse streak when user completes a practice session. Handles consecutive days, broken streaks, milestones, and freeze days.';
COMMENT ON FUNCTION use_streak_freeze IS 'Applies a streak freeze day to protect streak on a missed day (yesterday or today only)';
COMMENT ON FUNCTION check_streak_milestones IS 'Returns milestone achievement status and progress toward next milestone';

COMMIT;
