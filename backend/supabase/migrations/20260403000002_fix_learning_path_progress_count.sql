-- Fix learning path progress calculation to use actual completed topic count
-- instead of the stored counter in user_learning_path_progress.topics_completed
-- which can go out of sync when topics are completed via fellowship or other flows.

-- Fix 1: get_learning_path_details - compute topics_completed from user_topic_progress
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
    -- This is always accurate regardless of how/when the topic was completed
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

COMMENT ON FUNCTION get_learning_path_details IS 'Returns complete learning path details with topics, progress, recommended_mode, and input_type. Progress is computed from actual user_topic_progress records.';


-- Fix 2: get_available_learning_paths - compute progress_percentage from user_topic_progress
DROP FUNCTION IF EXISTS get_available_learning_paths(UUID, VARCHAR, BOOLEAN, INT, INT, VARCHAR);
DROP FUNCTION IF EXISTS get_available_learning_paths(UUID, VARCHAR, BOOLEAN, INT, INT);
DROP FUNCTION IF EXISTS get_available_learning_paths(UUID, VARCHAR, BOOLEAN);

CREATE OR REPLACE FUNCTION get_available_learning_paths(
  p_user_id      UUID    DEFAULT NULL,
  p_language     VARCHAR DEFAULT 'en',
  p_include_enrolled BOOLEAN DEFAULT true,
  p_limit        INT     DEFAULT 10,
  p_offset       INT     DEFAULT 0,
  p_category     VARCHAR DEFAULT NULL
)
RETURNS TABLE(
  path_id            UUID,
  slug               VARCHAR,
  title              TEXT,
  description        TEXT,
  icon_name          VARCHAR,
  color              VARCHAR,
  total_xp           INTEGER,
  estimated_days     INTEGER,
  disciple_level     VARCHAR,
  recommended_mode   TEXT,
  is_featured        BOOLEAN,
  total_topics       INTEGER,
  is_enrolled        BOOLEAN,
  progress_percentage INTEGER,
  category           VARCHAR
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    lp.id                                     AS path_id,
    lp.slug,
    COALESCE(lpt.title, lp.title)             AS title,
    COALESCE(lpt.description, lp.description) AS description,
    lp.icon_name,
    lp.color,
    lp.total_xp,
    lp.estimated_days,
    lp.disciple_level,
    lp.recommended_mode,
    lp.is_featured,
    (SELECT COUNT(*)
       FROM learning_path_topics
      WHERE learning_path_id = lp.id)          AS total_topics,
    CASE WHEN p_user_id IS NOT NULL THEN
      EXISTS(
        SELECT 1 FROM user_learning_path_progress
         WHERE user_id = p_user_id AND learning_path_id = lp.id
      )
    ELSE false END                              AS is_enrolled,
    -- Compute progress from actual user_topic_progress records (not stale counter)
    CASE WHEN p_user_id IS NOT NULL THEN
      COALESCE(
        (SELECT (
          COUNT(CASE WHEN utp.completed_at IS NOT NULL THEN 1 END) * 100
          / GREATEST(
              (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id),
              1)
        )::INTEGER
        FROM learning_path_topics lpt_inner
        LEFT JOIN user_topic_progress utp
               ON utp.topic_id = lpt_inner.topic_id AND utp.user_id = p_user_id
        WHERE lpt_inner.learning_path_id = lp.id
        ),
        0
      )
    ELSE 0 END                                  AS progress_percentage,
    lp.category
  FROM learning_paths lp
  LEFT JOIN learning_path_translations lpt
         ON lpt.learning_path_id = lp.id AND lpt.lang_code = p_language
  WHERE lp.is_active = true
    AND (p_include_enrolled OR NOT EXISTS(
      SELECT 1 FROM user_learning_path_progress
       WHERE user_id = p_user_id AND learning_path_id = lp.id
    ))
    AND (p_category IS NULL OR lp.category = p_category)
  ORDER BY
    -- Completed paths always last
    CASE WHEN p_user_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM user_learning_path_progress ulpp_c
       WHERE ulpp_c.user_id          = p_user_id
         AND ulpp_c.learning_path_id = lp.id
         AND ulpp_c.completed_at     IS NOT NULL
    ) THEN 1 ELSE 0 END,
    -- In-progress first (enrolled + has some completions + not finished)
    CASE WHEN p_user_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM user_learning_path_progress ulpp2
       WHERE ulpp2.user_id           = p_user_id
         AND ulpp2.learning_path_id  = lp.id
         AND ulpp2.completed_at      IS NULL
    ) AND EXISTS(
      SELECT 1 FROM learning_path_topics lpt2
      JOIN user_topic_progress utp2 ON utp2.topic_id = lpt2.topic_id AND utp2.user_id = p_user_id
      WHERE lpt2.learning_path_id = lp.id AND utp2.completed_at IS NOT NULL
    ) THEN 0 ELSE 1 END,
    -- Enrolled-incomplete next
    CASE WHEN p_user_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM user_learning_path_progress ulpp3
       WHERE ulpp3.user_id          = p_user_id
         AND ulpp3.learning_path_id = lp.id
         AND ulpp3.completed_at     IS NULL
    ) THEN 0 ELSE 1 END,
    -- Featured next
    CASE WHEN lp.is_featured THEN 0 ELSE 1 END,
    lp.display_order,
    lp.title
  LIMIT p_limit
  OFFSET p_offset;
$$;

COMMENT ON FUNCTION get_available_learning_paths(UUID, VARCHAR, BOOLEAN, INT, INT, VARCHAR) IS 'Returns paginated learning paths with progress computed from actual user_topic_progress records.';
