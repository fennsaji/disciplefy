-- Add allow_non_sequential_access column to learning_paths
-- Controls whether users can access topics out of order
ALTER TABLE learning_paths
ADD COLUMN IF NOT EXISTS allow_non_sequential_access BOOLEAN NOT NULL DEFAULT false;

-- Update get_learning_path_details to return allow_non_sequential_access
DROP FUNCTION IF EXISTS get_learning_path_details(UUID, UUID, VARCHAR);

CREATE OR REPLACE FUNCTION get_learning_path_details(
  p_path_id UUID,
  p_user_id UUID DEFAULT NULL,
  p_language VARCHAR DEFAULT 'en'
)
RETURNS TABLE(
  path_id UUID,
  slug VARCHAR,
  title TEXT,
  description TEXT,
  icon_name VARCHAR,
  color VARCHAR,
  total_xp INTEGER,
  estimated_days INTEGER,
  disciple_level VARCHAR,
  recommended_mode TEXT,
  allow_non_sequential_access BOOLEAN,
  is_enrolled BOOLEAN,
  progress_percentage INTEGER,
  topics_completed INTEGER,
  enrolled_at TIMESTAMPTZ,
  topics JSON
) AS $$
DECLARE
  v_topics JSON;
  v_is_enrolled BOOLEAN;
  v_progress_percentage INTEGER;
  v_topics_completed INTEGER;
  v_enrolled_at TIMESTAMPTZ;
  v_total_topics INTEGER;
BEGIN
  -- Get enrollment status
  IF p_user_id IS NOT NULL THEN
    SELECT true, ulpp.enrolled_at
    INTO v_is_enrolled, v_enrolled_at
    FROM user_learning_path_progress ulpp
    WHERE ulpp.user_id = p_user_id AND ulpp.learning_path_id = p_path_id;

    -- Count actual completed topics directly from user_topic_progress
    SELECT COUNT(*)::INTEGER
    INTO v_topics_completed
    FROM learning_path_topics lpt
    JOIN user_topic_progress utp ON utp.topic_id = lpt.topic_id
    WHERE lpt.learning_path_id = p_path_id
      AND utp.user_id = p_user_id
      AND utp.completed_at IS NOT NULL;
  END IF;

  v_is_enrolled := COALESCE(v_is_enrolled, false);
  v_topics_completed := COALESCE(v_topics_completed, 0);

  -- Get topics with progress (including input_type)
  SELECT json_agg(topic_data ORDER BY topic_data.position)
  INTO v_topics
  FROM (
    SELECT
      lpt.position,
      lpt.is_milestone,
      rt.id AS topic_id,
      COALESCE(rtt.title, rt.title) AS title,
      COALESCE(rtt.description, rt.description) AS description,
      COALESCE(rtt.category, rt.category) AS category,
      COALESCE(rt.input_type, 'topic') AS input_type,
      COALESCE(rt.xp_value, 50) AS xp_value,
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(SELECT 1 FROM user_topic_progress utp WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NOT NULL)
      ELSE false END AS is_completed,
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(SELECT 1 FROM user_topic_progress utp WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NULL)
      ELSE false END AS is_in_progress
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    LEFT JOIN recommended_topics_translations rtt ON rtt.topic_id = rt.id AND rtt.language_code = p_language
    WHERE lpt.learning_path_id = p_path_id
      AND rt.is_active = true
  ) topic_data;

  -- Calculate progress percentage from actual count
  SELECT COUNT(*)::INTEGER INTO v_total_topics
  FROM learning_path_topics
  WHERE learning_path_id = p_path_id;

  v_progress_percentage := CASE
    WHEN v_total_topics = 0 THEN 0
    ELSE (v_topics_completed * 100 / v_total_topics)::INTEGER
  END;

  RETURN QUERY
  SELECT
    lp.id AS path_id,
    lp.slug,
    COALESCE(lptt.title, lp.title) AS title,
    COALESCE(lptt.description, lp.description) AS description,
    lp.icon_name,
    lp.color,
    lp.total_xp,
    lp.estimated_days,
    lp.disciple_level,
    lp.recommended_mode,
    lp.allow_non_sequential_access,
    v_is_enrolled AS is_enrolled,
    v_progress_percentage AS progress_percentage,
    v_topics_completed AS topics_completed,
    v_enrolled_at AS enrolled_at,
    v_topics AS topics
  FROM learning_paths lp
  LEFT JOIN learning_path_translations lptt ON lptt.learning_path_id = lp.id AND lptt.lang_code = p_language
  WHERE lp.id = p_path_id AND lp.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_learning_path_details IS 'Returns complete learning path details with topics, progress, recommended_mode, input_type, and allow_non_sequential_access.';
