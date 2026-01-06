-- Migration: Fix duplicate column assignment in topic completion trigger
-- Purpose: Consolidate all column updates into single UPDATE to avoid duplicate assignment error
-- Issue: Trigger was doing two separate UPDATEs to same row, both modifying total_xp_earned
-- Fix: Combine all logic into one UPDATE statement

DROP TRIGGER IF EXISTS trigger_update_learning_path_on_topic_complete ON user_topic_progress;
DROP FUNCTION IF EXISTS update_learning_path_progress_on_topic_complete();

-- Create fixed trigger function with single UPDATE per path
CREATE OR REPLACE FUNCTION update_learning_path_progress_on_topic_complete()
RETURNS TRIGGER AS $$
DECLARE
  v_path_id UUID;
  v_path_position INTEGER;
  v_total_topics INTEGER;
  v_completed_in_path INTEGER;
  v_recommended_mode TEXT;
  v_is_milestone BOOLEAN;
  v_topic_xp INTEGER;
  v_bonus_xp INTEGER := 0;
  v_is_recommended_mode BOOLEAN;
  v_new_streak INTEGER;
  v_total_path_xp INTEGER;
  v_completion_bonus INTEGER := 0;
BEGIN
  -- Only process on completion (when completed_at changes from NULL to non-NULL)
  IF OLD.completed_at IS NULL AND NEW.completed_at IS NOT NULL THEN
    -- Find all learning paths that contain this topic
    FOR v_path_id, v_path_position, v_recommended_mode, v_is_milestone IN
      SELECT
        lpt.learning_path_id,
        lpt.position,
        lp.recommended_mode,
        lpt.is_milestone
      FROM learning_path_topics lpt
      JOIN learning_paths lp ON lp.id = lpt.learning_path_id
      WHERE lpt.topic_id = NEW.topic_id
    LOOP
      -- Get topic's base XP value with robust NULL handling
      SELECT xp_value INTO v_topic_xp
      FROM recommended_topics
      WHERE id = NEW.topic_id;

      -- Default to 50 if row not found or xp_value is NULL
      IF NOT FOUND OR v_topic_xp IS NULL THEN
        v_topic_xp := 50;
      END IF;

      -- Check if using recommended mode
      v_is_recommended_mode := (NEW.generation_mode IS NOT NULL AND NEW.generation_mode = v_recommended_mode);

      -- Calculate per-topic bonus XP
      v_bonus_xp := 0;
      IF v_is_recommended_mode THEN
        IF v_is_milestone THEN
          -- 50% bonus for milestone topics in recommended mode
          v_bonus_xp := FLOOR(v_topic_xp * 0.5);
        ELSE
          -- 25% bonus for regular topics in recommended mode
          v_bonus_xp := FLOOR(v_topic_xp * 0.25);
        END IF;
      END IF;

      -- Calculate new streak value
      IF v_is_recommended_mode THEN
        -- Increment streak (we'll read current value in UPDATE)
        v_new_streak := NULL; -- Signal to increment
      ELSE
        -- Reset streak
        v_new_streak := 0;
      END IF;

      -- Count total topics in path
      SELECT COUNT(*) INTO v_total_topics
      FROM learning_path_topics
      WHERE learning_path_id = v_path_id;

      -- Count completed topics in path for this user (including this one)
      SELECT COUNT(*) INTO v_completed_in_path
      FROM learning_path_topics lpt
      JOIN user_topic_progress utp ON utp.topic_id = lpt.topic_id
      WHERE lpt.learning_path_id = v_path_id
        AND utp.user_id = NEW.user_id
        AND utp.completed_at IS NOT NULL;

      -- Get current total_xp_earned for completion bonus calculation
      SELECT COALESCE(total_xp_earned, 0) INTO v_total_path_xp
      FROM user_learning_path_progress
      WHERE user_id = NEW.user_id AND learning_path_id = v_path_id;

      -- Calculate completion bonus (50% of total path XP if ALL topics in recommended mode)
      v_completion_bonus := 0;
      IF v_completed_in_path >= v_total_topics THEN
        -- Path is complete - check if all topics were in recommended mode
        -- This is true if new streak (current + 1) equals total topics
        IF v_is_recommended_mode THEN
          SELECT recommended_mode_streak + 1 INTO v_new_streak
          FROM user_learning_path_progress
          WHERE user_id = NEW.user_id AND learning_path_id = v_path_id;

          IF v_new_streak >= v_total_topics THEN
            -- Calculate 50% bonus of (current total + new topic XP + new per-topic bonus)
            v_completion_bonus := FLOOR((v_total_path_xp + COALESCE(NEW.xp_earned, 0) + v_bonus_xp) * 0.5);
          END IF;
        END IF;
      END IF;

      -- SINGLE UPDATE with all changes consolidated
      UPDATE user_learning_path_progress
      SET
        -- Topic progress tracking
        topics_completed = v_completed_in_path,
        current_topic_position = GREATEST(current_topic_position, v_path_position + 1),

        -- Streak tracking
        recommended_mode_streak = CASE
          WHEN v_is_recommended_mode THEN recommended_mode_streak + 1
          ELSE 0
        END,

        -- Completion tracking
        completed_at = CASE
          WHEN v_completed_in_path >= v_total_topics THEN NOW()
          ELSE completed_at
        END,
        completed_in_recommended_mode = CASE
          WHEN v_completed_in_path >= v_total_topics
            THEN (CASE WHEN v_is_recommended_mode THEN recommended_mode_streak + 1 ELSE 0 END) >= v_total_topics
          ELSE completed_in_recommended_mode
        END,

        -- XP tracking - ALL updates to total_xp_earned in ONE expression
        total_xp_earned = total_xp_earned + COALESCE(NEW.xp_earned, 0) + v_bonus_xp + v_completion_bonus,

        -- Bonus tracking
        bonus_xp_awarded = bonus_xp_awarded + v_bonus_xp + v_completion_bonus,

        -- Timestamps
        last_activity_at = NOW(),
        updated_at = NOW()

      WHERE user_id = NEW.user_id AND learning_path_id = v_path_id;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate trigger
CREATE TRIGGER trigger_update_learning_path_on_topic_complete
  AFTER UPDATE ON user_topic_progress
  FOR EACH ROW
  EXECUTE FUNCTION update_learning_path_progress_on_topic_complete();

-- Add function comment for documentation
COMMENT ON FUNCTION update_learning_path_progress_on_topic_complete() IS
'Trigger function that updates learning path progress when topics are completed.
Automatically calculates and awards bonus XP:
- 25% bonus for regular topics completed in recommended mode
- 50% bonus for milestone topics completed in recommended mode
- 50% completion bonus if ALL topics in path completed in recommended mode
Tracks recommended_mode_streak and breaks it if non-recommended mode used.

FIXED: Consolidated all column updates into single UPDATE to avoid duplicate column assignment error.';
