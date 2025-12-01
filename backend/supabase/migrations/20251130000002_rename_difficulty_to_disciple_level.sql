-- Migration: Rename difficulty_level to disciple_level
-- Changes: beginner -> believer, intermediate -> disciple, advanced -> leader
-- Adds new level: seeker (for those exploring faith)

BEGIN;

-- =============================================================================
-- STEP 1: Add new column
-- =============================================================================
ALTER TABLE learning_paths
ADD COLUMN disciple_level VARCHAR(20);

-- =============================================================================
-- STEP 2: Migrate existing data
-- =============================================================================
UPDATE learning_paths SET disciple_level =
  CASE difficulty_level
    WHEN 'beginner' THEN 'believer'
    WHEN 'intermediate' THEN 'disciple'
    WHEN 'advanced' THEN 'leader'
    ELSE 'believer'
  END;

-- =============================================================================
-- STEP 3: Set constraints
-- =============================================================================
ALTER TABLE learning_paths
ALTER COLUMN disciple_level SET NOT NULL,
ALTER COLUMN disciple_level SET DEFAULT 'believer';

ALTER TABLE learning_paths
ADD CONSTRAINT disciple_level_check
CHECK (disciple_level IN ('seeker', 'believer', 'disciple', 'leader'));

-- =============================================================================
-- STEP 4: Drop old column
-- =============================================================================
ALTER TABLE learning_paths
DROP COLUMN difficulty_level;

-- =============================================================================
-- STEP 5: Drop existing functions (return type is changing)
-- =============================================================================
DROP FUNCTION IF EXISTS get_user_learning_paths(UUID, VARCHAR);
DROP FUNCTION IF EXISTS get_available_learning_paths(UUID, VARCHAR, BOOLEAN);
DROP FUNCTION IF EXISTS get_learning_path_details(UUID, UUID, VARCHAR);

-- =============================================================================
-- STEP 6: Recreate database functions with disciple_level
-- =============================================================================

-- Function to get user's enrolled learning paths with progress
CREATE FUNCTION get_user_learning_paths(
  p_user_id UUID,
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
  is_featured BOOLEAN,
  topics_count INTEGER,
  topics_completed INTEGER,
  progress_percentage INTEGER,
  enrolled_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  current_topic_position INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    lp.id AS path_id,
    lp.slug,
    COALESCE(lpt.title, lp.title) AS title,
    COALESCE(lpt.description, lp.description) AS description,
    lp.icon_name,
    lp.color,
    lp.total_xp,
    lp.estimated_days,
    lp.disciple_level,
    lp.is_featured,
    (SELECT COUNT(*)::INTEGER FROM learning_path_topics WHERE learning_path_id = lp.id) AS topics_count,
    COALESCE(ulpp.topics_completed, 0) AS topics_completed,
    CASE
      WHEN (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id) = 0 THEN 0
      ELSE (COALESCE(ulpp.topics_completed, 0) * 100 / (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id))::INTEGER
    END AS progress_percentage,
    ulpp.enrolled_at,
    ulpp.started_at,
    ulpp.completed_at,
    COALESCE(ulpp.current_topic_position, 0) AS current_topic_position
  FROM user_learning_path_progress ulpp
  JOIN learning_paths lp ON lp.id = ulpp.learning_path_id
  LEFT JOIN learning_path_translations lpt ON lpt.learning_path_id = lp.id AND lpt.lang_code = p_language
  WHERE ulpp.user_id = p_user_id
    AND lp.is_active = true
  ORDER BY ulpp.last_activity_at DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all available learning paths (for discovery)
CREATE FUNCTION get_available_learning_paths(
  p_user_id UUID DEFAULT NULL,
  p_language VARCHAR DEFAULT 'en',
  p_include_enrolled BOOLEAN DEFAULT true
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
  is_featured BOOLEAN,
  topics_count INTEGER,
  is_enrolled BOOLEAN,
  progress_percentage INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    lp.id AS path_id,
    lp.slug,
    COALESCE(lpt.title, lp.title) AS title,
    COALESCE(lpt.description, lp.description) AS description,
    lp.icon_name,
    lp.color,
    lp.total_xp,
    lp.estimated_days,
    lp.disciple_level,
    lp.is_featured,
    (SELECT COUNT(*)::INTEGER FROM learning_path_topics WHERE learning_path_id = lp.id) AS topics_count,
    CASE WHEN p_user_id IS NULL THEN false
         ELSE EXISTS(SELECT 1 FROM user_learning_path_progress WHERE user_id = p_user_id AND learning_path_id = lp.id)
    END AS is_enrolled,
    CASE
      WHEN p_user_id IS NULL THEN 0
      WHEN (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id) = 0 THEN 0
      ELSE COALESCE(
        (SELECT (ulpp.topics_completed * 100 / (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id))::INTEGER
         FROM user_learning_path_progress ulpp
         WHERE ulpp.user_id = p_user_id AND ulpp.learning_path_id = lp.id),
        0
      )
    END AS progress_percentage
  FROM learning_paths lp
  LEFT JOIN learning_path_translations lpt ON lpt.learning_path_id = lp.id AND lpt.lang_code = p_language
  WHERE lp.is_active = true
    AND (p_include_enrolled OR p_user_id IS NULL OR NOT EXISTS(
      SELECT 1 FROM user_learning_path_progress WHERE user_id = p_user_id AND learning_path_id = lp.id
    ))
  ORDER BY lp.is_featured DESC, lp.display_order ASC, lp.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get learning path details with topics
CREATE FUNCTION get_learning_path_details(
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
BEGIN
  -- Get enrollment status
  IF p_user_id IS NOT NULL THEN
    SELECT
      true,
      ulpp.topics_completed,
      ulpp.enrolled_at
    INTO v_is_enrolled, v_topics_completed, v_enrolled_at
    FROM user_learning_path_progress ulpp
    WHERE ulpp.user_id = p_user_id AND ulpp.learning_path_id = p_path_id;
  END IF;

  v_is_enrolled := COALESCE(v_is_enrolled, false);
  v_topics_completed := COALESCE(v_topics_completed, 0);

  -- Get topics with progress
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
      COALESCE(rt.xp_value, 50) AS xp_value,
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(SELECT 1 FROM user_topic_progress utp WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NOT NULL)
      ELSE false END AS is_completed,
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(SELECT 1 FROM user_topic_progress utp WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NULL)
      ELSE false END AS is_in_progress
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    LEFT JOIN recommended_topics_translations rtt ON rtt.topic_id = rt.id AND rtt.lang_code = p_language
    WHERE lpt.learning_path_id = p_path_id
      AND rt.is_active = true
  ) topic_data;

  -- Calculate progress percentage
  v_progress_percentage := CASE
    WHEN (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = p_path_id) = 0 THEN 0
    ELSE (v_topics_completed * 100 / (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = p_path_id))::INTEGER
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

COMMIT;
