-- Fix: Calculate initial progress when enrolling in a learning path
-- This handles the case where a user completes topics BEFORE enrolling in the learning path

-- Drop and recreate the enroll_in_learning_path function with initial progress calculation
CREATE OR REPLACE FUNCTION public.enroll_in_learning_path(p_user_id uuid, p_learning_path_id uuid)
 RETURNS user_learning_path_progress
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  result user_learning_path_progress;
  v_path_exists BOOLEAN;
  v_already_completed INTEGER;
  v_total_topics INTEGER;
  v_xp_earned INTEGER;
  v_max_position INTEGER;
BEGIN
  -- Check if path exists and is active
  SELECT EXISTS(
    SELECT 1 FROM learning_paths WHERE id = p_learning_path_id AND is_active = true
  ) INTO v_path_exists;

  IF NOT v_path_exists THEN
    RAISE EXCEPTION 'Learning path not found or inactive';
  END IF;

  -- Calculate topics already completed by this user in this learning path
  SELECT 
    COUNT(*),
    COALESCE(SUM(utp.xp_earned), 0),
    COALESCE(MAX(lpt.position), 0)
  INTO v_already_completed, v_xp_earned, v_max_position
  FROM learning_path_topics lpt
  JOIN user_topic_progress utp ON utp.topic_id = lpt.topic_id
  WHERE lpt.learning_path_id = p_learning_path_id
    AND utp.user_id = p_user_id
    AND utp.completed_at IS NOT NULL;

  -- Get total topics count
  SELECT COUNT(*) INTO v_total_topics
  FROM learning_path_topics
  WHERE learning_path_id = p_learning_path_id;

  -- Insert or update enrollment with initial progress
  INSERT INTO user_learning_path_progress (
    user_id,
    learning_path_id,
    enrolled_at,
    started_at,
    topics_completed,
    total_xp_earned,
    current_topic_position,
    completed_at
  )
  VALUES (
    p_user_id,
    p_learning_path_id,
    NOW(),
    NOW(),
    v_already_completed,
    v_xp_earned,
    v_max_position + 1,
    CASE WHEN v_already_completed >= v_total_topics THEN NOW() ELSE NULL END
  )
  ON CONFLICT (user_id, learning_path_id) DO UPDATE
  SET
    started_at = COALESCE(user_learning_path_progress.started_at, NOW()),
    -- Only update progress if it would increase (don't decrease on re-enrollment)
    topics_completed = GREATEST(user_learning_path_progress.topics_completed, v_already_completed),
    total_xp_earned = GREATEST(user_learning_path_progress.total_xp_earned, v_xp_earned),
    current_topic_position = GREATEST(user_learning_path_progress.current_topic_position, v_max_position + 1),
    completed_at = CASE 
      WHEN GREATEST(user_learning_path_progress.topics_completed, v_already_completed) >= v_total_topics 
      THEN COALESCE(user_learning_path_progress.completed_at, NOW())
      ELSE NULL 
    END,
    last_activity_at = NOW(),
    updated_at = NOW()
  RETURNING * INTO result;

  RETURN result;
END;
$function$;

-- Add a helper function to recalculate progress for existing enrollments
-- This can be called to fix any existing records that have incorrect progress
CREATE OR REPLACE FUNCTION public.recalculate_learning_path_progress(p_user_id uuid, p_learning_path_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_completed INTEGER;
  v_total_topics INTEGER;
  v_xp_earned INTEGER;
  v_max_position INTEGER;
BEGIN
  -- Calculate topics completed by this user in this learning path
  SELECT 
    COUNT(*),
    COALESCE(SUM(utp.xp_earned), 0),
    COALESCE(MAX(lpt.position), 0)
  INTO v_completed, v_xp_earned, v_max_position
  FROM learning_path_topics lpt
  JOIN user_topic_progress utp ON utp.topic_id = lpt.topic_id
  WHERE lpt.learning_path_id = p_learning_path_id
    AND utp.user_id = p_user_id
    AND utp.completed_at IS NOT NULL;

  -- Get total topics count
  SELECT COUNT(*) INTO v_total_topics
  FROM learning_path_topics
  WHERE learning_path_id = p_learning_path_id;

  -- Update the progress record
  UPDATE user_learning_path_progress
  SET
    topics_completed = v_completed,
    total_xp_earned = v_xp_earned,
    current_topic_position = v_max_position + 1,
    completed_at = CASE WHEN v_completed >= v_total_topics THEN NOW() ELSE NULL END,
    last_activity_at = NOW(),
    updated_at = NOW()
  WHERE user_id = p_user_id AND learning_path_id = p_learning_path_id;
END;
$function$;

-- Comment explaining the fix
COMMENT ON FUNCTION public.enroll_in_learning_path IS 'Enrolls a user in a learning path and calculates initial progress based on already-completed topics';
COMMENT ON FUNCTION public.recalculate_learning_path_progress IS 'Recalculates progress for a user learning path enrollment based on current topic completions';
