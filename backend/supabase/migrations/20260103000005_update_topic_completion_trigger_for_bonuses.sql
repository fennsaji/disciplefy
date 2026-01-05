-- Migration: Update topic completion trigger to calculate XP bonuses
-- Purpose: Automatically award bonus XP when topics completed in recommended mode
-- Related Feature: Recommended Study Modes for Learning Paths with XP Bonuses

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS trigger_update_learning_path_on_topic_complete ON user_topic_progress;
DROP FUNCTION IF EXISTS update_learning_path_progress_on_topic_complete();

-- Create updated trigger function with bonus XP logic
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
      -- Get topic's base XP value
      SELECT COALESCE(xp_value, 50) INTO v_topic_xp
      FROM recommended_topics
      WHERE id = NEW.topic_id;

      -- Reset bonus for this iteration
      v_bonus_xp := 0;

      -- Calculate bonus XP if using recommended mode
      IF NEW.generation_mode IS NOT NULL AND NEW.generation_mode = v_recommended_mode THEN
        IF v_is_milestone THEN
          -- 50% bonus for milestone topics in recommended mode
          v_bonus_xp := FLOOR(v_topic_xp * 0.5);
        ELSE
          -- 25% bonus for regular topics in recommended mode
          v_bonus_xp := FLOOR(v_topic_xp * 0.25);
        END IF;

        -- Update learning path progress: increment streak and add bonus XP
        UPDATE user_learning_path_progress
        SET 
          recommended_mode_streak = recommended_mode_streak + 1,
          bonus_xp_awarded = bonus_xp_awarded + v_bonus_xp,
          total_xp_earned = total_xp_earned + v_bonus_xp,
          last_activity_at = NOW(),
          updated_at = NOW()
        WHERE user_id = NEW.user_id
          AND learning_path_id = v_path_id;
      ELSE
        -- Break streak if not using recommended mode
        UPDATE user_learning_path_progress
        SET 
          recommended_mode_streak = 0,
          last_activity_at = NOW(),
          updated_at = NOW()
        WHERE user_id = NEW.user_id
          AND learning_path_id = v_path_id;
      END IF;

      -- Count total topics in path
      SELECT COUNT(*) INTO v_total_topics
      FROM learning_path_topics
      WHERE learning_path_id = v_path_id;

      -- Count completed topics in path for this user
      SELECT COUNT(*) INTO v_completed_in_path
      FROM learning_path_topics lpt
      JOIN user_topic_progress utp ON utp.topic_id = lpt.topic_id
      WHERE lpt.learning_path_id = v_path_id
        AND utp.user_id = NEW.user_id
        AND utp.completed_at IS NOT NULL;

      -- Update user's learning path progress (standard fields + check completion)
      UPDATE user_learning_path_progress
      SET
        topics_completed = v_completed_in_path,
        total_xp_earned = total_xp_earned + COALESCE(NEW.xp_earned, 0),
        current_topic_position = GREATEST(current_topic_position, v_path_position + 1),
        last_activity_at = NOW(),
        updated_at = NOW(),
        -- If path is now complete, check for completion bonus
        completed_at = CASE 
          WHEN v_completed_in_path >= v_total_topics THEN NOW() 
          ELSE completed_at 
        END,
        completed_in_recommended_mode = CASE
          WHEN v_completed_in_path >= v_total_topics THEN (recommended_mode_streak >= v_total_topics)
          ELSE completed_in_recommended_mode
        END,
        -- Award 50% completion bonus only if ALL topics done in recommended mode
        bonus_xp_awarded = CASE
          WHEN v_completed_in_path >= v_total_topics AND recommended_mode_streak >= v_total_topics
          THEN bonus_xp_awarded + FLOOR(total_xp_earned * 0.5)
          ELSE bonus_xp_awarded
        END,
        total_xp_earned = CASE
          WHEN v_completed_in_path >= v_total_topics AND recommended_mode_streak >= v_total_topics
          THEN total_xp_earned + FLOOR(total_xp_earned * 0.5)
          ELSE total_xp_earned
        END
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
Tracks recommended_mode_streak and breaks it if non-recommended mode used.';
