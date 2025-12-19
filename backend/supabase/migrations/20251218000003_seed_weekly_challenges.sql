-- Migration: Seed Weekly Memory Verse Challenges
-- Created: 2025-12-18
-- Purpose: Create recurring weekly challenges for memory verse practice

BEGIN;

-- =============================================================================
-- FUNCTION: Create Weekly Challenges
-- =============================================================================
-- This function creates a new set of weekly challenges
-- Call it at the start of each week (e.g., Monday 00:00 UTC)

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
    (
        'weekly',
        'reviews_count',
        10,
        100,
        'task_alt',
        week_start,
        week_end,
        true
    ),
    -- Challenge 2: Add 3 new verses
    (
        'weekly',
        'new_verses',
        3,
        150,
        'add_circle',
        week_start,
        week_end,
        true
    ),
    -- Challenge 3: Achieve 5 perfect recalls (quality = 5)
    (
        'weekly',
        'perfect_recalls',
        5,
        200,
        'stars',
        week_start,
        week_end,
        true
    ),
    -- Challenge 4: Practice 5 days this week
    (
        'weekly',
        'streak_days',
        5,
        250,
        'local_fire_department',
        week_start,
        week_end,
        true
    ),
    -- Challenge 5: Try 3 different practice modes
    (
        'weekly',
        'modes_tried',
        3,
        150,
        'view_module',
        week_start,
        week_end,
        true
    );

    RAISE NOTICE 'Created weekly challenges from % to %', week_start, week_end;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- FUNCTION: Update Challenge Progress
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

-- =============================================================================
-- FUNCTION: Claim Challenge Reward
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

-- =============================================================================
-- Initial Seed: Create This Week's Challenges
-- =============================================================================

SELECT create_weekly_memory_challenges();

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

GRANT EXECUTE ON FUNCTION create_weekly_memory_challenges() TO authenticated;
GRANT EXECUTE ON FUNCTION update_challenge_progress(UUID, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION claim_challenge_reward(UUID, UUID) TO authenticated;

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON FUNCTION create_weekly_memory_challenges IS 'Creates a new set of weekly challenges (call at start of each week)';
COMMENT ON FUNCTION update_challenge_progress IS 'Updates progress on challenges matching the target type';
COMMENT ON FUNCTION claim_challenge_reward IS 'Claims XP reward for a completed challenge';

COMMIT;
