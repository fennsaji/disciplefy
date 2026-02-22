-- =====================================================
-- Migration: Learning Paths — Category API
-- =====================================================
-- 1. Adds category column to learning_paths
-- 2. Seeds categories for all 10 existing paths
-- 3. Creates get_available_learning_paths
--    - offset pagination
--    - optional p_category filter
--    - completed paths sink to bottom
-- 4. Creates get_learning_path_categories
--    - personalisation ordering
--    - completed categories sink to bottom
--    - stable default order via path display_order
-- =====================================================

BEGIN;

-- -------------------------------------------------------
-- 1. Add category column
-- -------------------------------------------------------

ALTER TABLE learning_paths
  ADD COLUMN IF NOT EXISTS category VARCHAR(50) NOT NULL DEFAULT '';

-- -------------------------------------------------------
-- 2. Seed categories for all 10 existing paths
-- -------------------------------------------------------

UPDATE learning_paths SET category = 'Foundations'          WHERE slug = 'new-believer-essentials';
UPDATE learning_paths SET category = 'Foundations'          WHERE slug = 'rooted-in-christ';
UPDATE learning_paths SET category = 'Growth'               WHERE slug = 'growing-in-discipleship';
UPDATE learning_paths SET category = 'Growth'               WHERE slug = 'deepening-your-walk';
UPDATE learning_paths SET category = 'Service & Mission'    WHERE slug = 'serving-and-mission';
UPDATE learning_paths SET category = 'Service & Mission'    WHERE slug = 'heart-for-the-world';
UPDATE learning_paths SET category = 'Apologetics'          WHERE slug = 'defending-your-faith';
UPDATE learning_paths SET category = 'Apologetics'          WHERE slug = 'faith-and-reason';
UPDATE learning_paths SET category = 'Life & Relationships' WHERE slug = 'faith-and-family';
UPDATE learning_paths SET category = 'Theology'             WHERE slug = 'eternal-perspective';

-- -------------------------------------------------------
-- 3. get_available_learning_paths
--    Supports: pagination, category filter, personalised
--    ordering, completed paths always last.
-- -------------------------------------------------------

DROP FUNCTION IF EXISTS get_available_learning_paths(UUID, VARCHAR, BOOLEAN, INT, INT, VARCHAR);
DROP FUNCTION IF EXISTS get_available_learning_paths(UUID, VARCHAR, BOOLEAN, INT, INT);
DROP FUNCTION IF EXISTS get_available_learning_paths(UUID, VARCHAR, BOOLEAN);

CREATE OR REPLACE FUNCTION get_available_learning_paths(
  p_user_id          UUID    DEFAULT NULL,
  p_language         VARCHAR DEFAULT 'en',
  p_include_enrolled BOOLEAN DEFAULT true,
  p_limit            INT     DEFAULT 10,
  p_offset           INT     DEFAULT 0,
  p_category         VARCHAR DEFAULT NULL   -- NULL = all categories
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
  'Returns active paths with optional category filter, enrollment status, and pagination. '
  'Ordering: completed last, then in-progress > enrolled-incomplete > featured > display_order.';

-- -------------------------------------------------------
-- 4. get_learning_path_categories
--    Personalised ordering; completed categories sink to
--    bottom; stable default order via path display_order.
-- -------------------------------------------------------

DROP FUNCTION IF EXISTS get_learning_path_categories(UUID, INT, INT);

CREATE OR REPLACE FUNCTION get_learning_path_categories(
  p_user_id UUID DEFAULT NULL,
  p_limit   INT  DEFAULT 5,
  p_offset  INT  DEFAULT 0
)
RETURNS TABLE(
  category        VARCHAR,
  total_paths     INT,
  has_in_progress BOOLEAN,
  has_enrolled    BOOLEAN,
  is_completed    BOOLEAN   -- true when every enrolled path is finished
) AS $$
BEGIN
  RETURN QUERY
  WITH cat_stats AS (
    SELECT DISTINCT ON (lp.category)
      lp.category,
      (SELECT COUNT(*)::INT
         FROM learning_paths lp2
        WHERE lp2.category = lp.category
          AND lp2.is_active = true)                             AS total_paths,
      -- has_in_progress
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(
          SELECT 1
            FROM user_learning_path_progress ulpp
            JOIN learning_paths lp3 ON ulpp.learning_path_id = lp3.id
           WHERE ulpp.user_id           = p_user_id
             AND lp3.category           = lp.category
             AND ulpp.topics_completed  > 0
             AND ulpp.completed_at      IS NULL
        )
      ELSE false END                                            AS has_in_progress,
      -- has_enrolled
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(
          SELECT 1
            FROM user_learning_path_progress ulpp2
            JOIN learning_paths lp4 ON ulpp2.learning_path_id = lp4.id
           WHERE ulpp2.user_id = p_user_id
             AND lp4.category  = lp.category
        )
      ELSE false END                                            AS has_enrolled,
      -- is_completed: enrolled in category AND no incomplete paths remain
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(
          SELECT 1
            FROM user_learning_path_progress ulpp_any
            JOIN learning_paths lp_any ON ulpp_any.learning_path_id = lp_any.id
           WHERE ulpp_any.user_id = p_user_id
             AND lp_any.category  = lp.category
        )
        AND NOT EXISTS(
          SELECT 1
            FROM user_learning_path_progress ulpp_inc
            JOIN learning_paths lp_inc ON ulpp_inc.learning_path_id = lp_inc.id
           WHERE ulpp_inc.user_id       = p_user_id
             AND lp_inc.category        = lp.category
             AND ulpp_inc.completed_at  IS NULL
        )
      ELSE false END                                            AS is_completed,
      -- priority
      CASE
        -- Priority 4: all enrolled paths completed → sink to bottom
        WHEN p_user_id IS NOT NULL
          AND EXISTS(
            SELECT 1
              FROM user_learning_path_progress ulpp_e
              JOIN learning_paths lp_e ON ulpp_e.learning_path_id = lp_e.id
             WHERE ulpp_e.user_id = p_user_id
               AND lp_e.category  = lp.category
          )
          AND NOT EXISTS(
            SELECT 1
              FROM user_learning_path_progress ulpp_i
              JOIN learning_paths lp_i ON ulpp_i.learning_path_id = lp_i.id
             WHERE ulpp_i.user_id      = p_user_id
               AND lp_i.category       = lp.category
               AND ulpp_i.completed_at IS NULL
          ) THEN 4
        -- Priority 0: has in-progress path
        WHEN p_user_id IS NOT NULL AND EXISTS(
          SELECT 1
            FROM user_learning_path_progress ulpp5
            JOIN learning_paths lp5 ON ulpp5.learning_path_id = lp5.id
           WHERE ulpp5.user_id           = p_user_id
             AND lp5.category            = lp.category
             AND ulpp5.topics_completed  > 0
             AND ulpp5.completed_at      IS NULL
        ) THEN 0
        -- Priority 1: enrolled but not all completed
        WHEN p_user_id IS NOT NULL AND EXISTS(
          SELECT 1
            FROM user_learning_path_progress ulpp6
            JOIN learning_paths lp6 ON ulpp6.learning_path_id = lp6.id
           WHERE ulpp6.user_id = p_user_id
             AND lp6.category  = lp.category
        ) THEN 1
        -- Priority 2: has a featured path
        WHEN EXISTS(
          SELECT 1
            FROM learning_paths lp7
           WHERE lp7.category    = lp.category
             AND lp7.is_featured = true
             AND lp7.is_active   = true
        ) THEN 2
        ELSE 3
      END                                                       AS priority,
      -- min display_order for stable default ordering (not alphabetical)
      (SELECT MIN(lp8.display_order)
         FROM learning_paths lp8
        WHERE lp8.category  = lp.category
          AND lp8.is_active = true)                             AS min_display_order
    FROM learning_paths lp
    WHERE lp.is_active = true
      AND lp.category  <> ''
    ORDER BY lp.category   -- required by DISTINCT ON
  )
  SELECT
    cs.category,
    cs.total_paths,
    cs.has_in_progress,
    cs.has_enrolled,
    cs.is_completed
  FROM cat_stats cs
  ORDER BY
    cs.priority          ASC,
    cs.min_display_order ASC,   -- follows path display_order, not A-Z
    cs.category          ASC    -- stable final tiebreaker
  LIMIT  p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_learning_path_categories IS
  'Returns distinct active categories ordered by personalisation: '
  'in-progress (0) > enrolled-incomplete (1) > featured (2) > default (3) > all-completed (4). '
  'Within the same priority, categories follow their paths'' display_order. '
  'Returns is_completed so the UI can style completed categories differently.';

COMMIT;
