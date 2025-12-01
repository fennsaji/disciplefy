-- Add topics_completed_in_path to Continue Learning response
-- This shows how many topics the user has completed in the learning path
-- instead of showing the topic's position which was confusing

BEGIN;

-- =============================================================================
-- FUNCTION: get_in_progress_topics (ENHANCED with topics_completed_in_path)
-- =============================================================================
-- Now includes topics_completed_in_path to show user's actual progress

DROP FUNCTION IF EXISTS get_in_progress_topics(UUID, INTEGER);

CREATE OR REPLACE FUNCTION get_in_progress_topics(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 5
)
RETURNS TABLE(
  topic_id UUID,
  topic_title TEXT,
  topic_description TEXT,
  topic_category TEXT,
  started_at TIMESTAMPTZ,
  time_spent_seconds INTEGER,
  xp_value INTEGER,
  learning_path_id UUID,
  learning_path_name TEXT,
  position_in_path INTEGER,
  total_topics_in_path INTEGER,
  topics_completed_in_path INTEGER
) AS $$
BEGIN
  RETURN QUERY
  WITH in_progress AS (
    -- Get topics user has started but not completed
    SELECT
      rt.id AS topic_id,
      rt.title AS topic_title,
      rt.description AS topic_description,
      rt.category::TEXT AS topic_category,
      utp.started_at,
      utp.time_spent_seconds,
      COALESCE(rt.xp_value, 50) AS xp_value,
      utp.updated_at
    FROM user_topic_progress utp
    JOIN recommended_topics rt ON rt.id = utp.topic_id
    WHERE utp.user_id = p_user_id
      AND utp.completed_at IS NULL
      AND rt.is_active = true
  ),
  next_in_path AS (
    -- Get the next topic from learning paths where user completed a topic
    -- but hasn't started the next one yet
    SELECT DISTINCT ON (lp.id)
      rt.id AS topic_id,
      rt.title AS topic_title,
      rt.description AS topic_description,
      rt.category::TEXT AS topic_category,
      ulpp.last_activity_at AS started_at,
      0 AS time_spent_seconds,
      COALESCE(rt.xp_value, 50) AS xp_value,
      ulpp.last_activity_at AS updated_at,
      lp.id AS learning_path_id,
      lp.title AS learning_path_name,
      lpt.position + 1 AS position_in_path,
      (SELECT COUNT(*)::INTEGER FROM learning_path_topics lpt2 WHERE lpt2.learning_path_id = lp.id) AS total_topics_in_path,
      ulpp.topics_completed AS topics_completed_in_path
    FROM user_learning_path_progress ulpp
    JOIN learning_paths lp ON lp.id = ulpp.learning_path_id
    JOIN learning_path_topics lpt ON lpt.learning_path_id = lp.id
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    WHERE ulpp.user_id = p_user_id
      AND ulpp.completed_at IS NULL  -- Path not completed
      AND lp.is_active = true
      AND rt.is_active = true
      -- Topic is the next one after current position
      AND lpt.position = ulpp.current_topic_position
      -- User hasn't started this topic yet
      AND NOT EXISTS (
        SELECT 1 FROM user_topic_progress utp
        WHERE utp.user_id = p_user_id
          AND utp.topic_id = rt.id
      )
    ORDER BY lp.id, ulpp.last_activity_at DESC
  ),
  in_progress_with_path AS (
    -- Add learning path info to in-progress topics
    SELECT
      ip.topic_id,
      ip.topic_title,
      ip.topic_description,
      ip.topic_category,
      ip.started_at,
      ip.time_spent_seconds,
      ip.xp_value,
      ip.updated_at,
      lp.id AS learning_path_id,
      lp.title AS learning_path_name,
      lpt.position + 1 AS position_in_path,  -- 1-based for display
      (SELECT COUNT(*)::INTEGER FROM learning_path_topics lpt2 WHERE lpt2.learning_path_id = lp.id) AS total_topics_in_path,
      COALESCE(ulpp.topics_completed, 0)::INTEGER AS topics_completed_in_path
    FROM in_progress ip
    LEFT JOIN learning_path_topics lpt ON lpt.topic_id = ip.topic_id
    LEFT JOIN learning_paths lp ON lp.id = lpt.learning_path_id AND lp.is_active = true
    -- Only include learning path if user is enrolled
    LEFT JOIN user_learning_path_progress ulpp ON ulpp.learning_path_id = lp.id AND ulpp.user_id = p_user_id
    WHERE lp.id IS NULL OR ulpp.id IS NOT NULL  -- Either no path or user is enrolled
  ),
  combined AS (
    -- Combine in-progress topics with next-in-path topics
    SELECT
      ipwp.topic_id,
      ipwp.topic_title,
      ipwp.topic_description,
      ipwp.topic_category,
      ipwp.started_at,
      ipwp.time_spent_seconds,
      ipwp.xp_value,
      ipwp.updated_at,
      ipwp.learning_path_id,
      ipwp.learning_path_name,
      ipwp.position_in_path,
      ipwp.total_topics_in_path,
      ipwp.topics_completed_in_path,
      1 AS priority  -- In-progress topics have higher priority
    FROM in_progress_with_path ipwp

    UNION ALL

    SELECT
      nip.topic_id,
      nip.topic_title,
      nip.topic_description,
      nip.topic_category,
      nip.started_at,
      nip.time_spent_seconds,
      nip.xp_value,
      nip.updated_at,
      nip.learning_path_id,
      nip.learning_path_name,
      nip.position_in_path,
      nip.total_topics_in_path,
      nip.topics_completed_in_path,
      2 AS priority  -- Next topics have lower priority
    FROM next_in_path nip
    WHERE NOT EXISTS (
      SELECT 1 FROM in_progress_with_path ipwp
      WHERE ipwp.topic_id = nip.topic_id
    )
  )
  SELECT DISTINCT ON (c.topic_id)
    c.topic_id,
    c.topic_title,
    c.topic_description,
    c.topic_category,
    c.started_at,
    c.time_spent_seconds,
    c.xp_value,
    c.learning_path_id,
    c.learning_path_name,
    c.position_in_path,
    c.total_topics_in_path,
    c.topics_completed_in_path
  FROM combined c
  ORDER BY c.topic_id, c.priority, c.updated_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comments for documentation
COMMENT ON FUNCTION get_in_progress_topics IS 'Returns in-progress topics for Continue Learning section, including learning path information, position, and topics completed count';

COMMIT;
