-- ============================================================================
-- Migration: Add allow_non_sequential_access to learning_paths
-- Date: 2026-01-07
-- Description: Adds a flag to allow certain learning paths to have all topics
--              unlocked from the start (non-sequential access). This is useful
--              for paths like "Faith & Reason" where users should be able to
--              explore questions in any order.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ADD allow_non_sequential_access COLUMN
-- ============================================================================

ALTER TABLE learning_paths
ADD COLUMN IF NOT EXISTS allow_non_sequential_access BOOLEAN DEFAULT false;

COMMENT ON COLUMN learning_paths.allow_non_sequential_access IS
'When true, all topics in this learning path are unlocked from the start, allowing users to study in any order. When false (default), topics unlock sequentially.';

-- ============================================================================
-- 2. ENABLE NON-SEQUENTIAL ACCESS FOR FAITH & REASON PATH
-- ============================================================================

UPDATE learning_paths
SET allow_non_sequential_access = true
WHERE id = 'aaa00000-0000-0000-0000-000000000010'; -- Faith & Reason

-- ============================================================================
-- 3. UPDATE get_learning_path_details FUNCTION TO RETURN NEW FIELD
-- ============================================================================

-- Drop existing function first (required when changing return type)
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
  allow_non_sequential_access BOOLEAN,  -- ✅ NEW FIELD
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
    lp.recommended_mode,
    lp.allow_non_sequential_access,  -- ✅ NEW FIELD
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

-- ============================================================================
-- 4. VERIFICATION
-- ============================================================================

DO $$
DECLARE
  column_exists BOOLEAN;
  faith_reason_unlocked BOOLEAN;
  test_result RECORD;
BEGIN
  -- Check column was added
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'learning_paths'
      AND column_name = 'allow_non_sequential_access'
  ) INTO column_exists;

  IF NOT column_exists THEN
    RAISE EXCEPTION 'allow_non_sequential_access column was not added';
  END IF;

  -- Check Faith & Reason path was updated
  SELECT allow_non_sequential_access INTO faith_reason_unlocked
  FROM learning_paths
  WHERE id = 'aaa00000-0000-0000-0000-000000000010';

  IF NOT faith_reason_unlocked THEN
    RAISE EXCEPTION 'Faith & Reason path was not set to allow non-sequential access';
  END IF;

  -- Test function returns new field (just check it doesn't error)
  PERFORM * FROM get_learning_path_details('aaa00000-0000-0000-0000-000000000010', NULL, 'en');

  RAISE NOTICE '✓ Migration completed successfully:';
  RAISE NOTICE '  - Added allow_non_sequential_access column to learning_paths';
  RAISE NOTICE '  - Enabled non-sequential access for Faith & Reason path';
  RAISE NOTICE '  - Updated get_learning_path_details function';
END $$;

COMMIT;
