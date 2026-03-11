-- Migration: Add p_search parameter to get_available_learning_paths
-- Enables server-side filtering by title/description via ILIKE.

DROP FUNCTION IF EXISTS get_available_learning_paths(UUID, VARCHAR, BOOLEAN, INT, INT, VARCHAR);
DROP FUNCTION IF EXISTS get_available_learning_paths(UUID, VARCHAR, BOOLEAN, INT, INT, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION get_available_learning_paths(
  p_user_id          UUID    DEFAULT NULL,
  p_language         VARCHAR DEFAULT 'en',
  p_include_enrolled BOOLEAN DEFAULT true,
  p_limit            INT     DEFAULT 10,
  p_offset           INT     DEFAULT 0,
  p_category         VARCHAR DEFAULT NULL,
  p_search           VARCHAR DEFAULT NULL
)
RETURNS TABLE(
  path_id             UUID,
  slug                VARCHAR,
  title               TEXT,
  description         TEXT,
  icon_name           VARCHAR,
  color               VARCHAR,
  total_xp            INTEGER,
  estimated_days      INTEGER,
  disciple_level      VARCHAR,
  recommended_mode    TEXT,
  is_featured         BOOLEAN,
  total_topics        INTEGER,
  is_enrolled         BOOLEAN,
  progress_percentage INTEGER,
  category            VARCHAR
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    lp.id AS path_id,
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
    (SELECT COUNT(*)::INTEGER
       FROM learning_path_topics
      WHERE learning_path_id = lp.id)          AS total_topics,
    CASE WHEN p_user_id IS NOT NULL THEN
      EXISTS(
        SELECT 1 FROM user_learning_path_progress
         WHERE user_id = p_user_id AND learning_path_id = lp.id
      )
    ELSE false END                              AS is_enrolled,
    CASE WHEN p_user_id IS NOT NULL THEN
      COALESCE(
        (SELECT (ulpp.topics_completed * 100
                 / GREATEST(
                     (SELECT COUNT(*) FROM learning_path_topics
                       WHERE learning_path_id = lp.id),
                     1))::INTEGER
           FROM user_learning_path_progress ulpp
          WHERE ulpp.user_id = p_user_id
            AND ulpp.learning_path_id = lp.id),
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
    AND (
      p_search IS NULL
      OR COALESCE(lpt.title, lp.title) ILIKE '%' || p_search || '%'
      OR COALESCE(lpt.description, lp.description) ILIKE '%' || p_search || '%'
    )
  ORDER BY
    -- Completed paths always last
    CASE WHEN p_user_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM user_learning_path_progress ulpp_c
       WHERE ulpp_c.user_id          = p_user_id
         AND ulpp_c.learning_path_id = lp.id
         AND ulpp_c.completed_at     IS NOT NULL
    ) THEN 1 ELSE 0 END,
    -- In-progress first (enrolled + topics > 0 + not finished)
    CASE WHEN p_user_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM user_learning_path_progress ulpp2
       WHERE ulpp2.user_id           = p_user_id
         AND ulpp2.learning_path_id  = lp.id
         AND ulpp2.topics_completed  > 0
         AND ulpp2.completed_at      IS NULL
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_available_learning_paths IS
  'Returns active learning paths with enrollment status and optional search filtering.
   p_search: ILIKE filter on title/description (NULL = no filter).';
