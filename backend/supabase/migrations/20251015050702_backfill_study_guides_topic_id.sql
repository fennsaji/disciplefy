-- Migration: Backfill study_guides.topic_id from existing data
-- Created: 2025-10-15
-- Purpose: Match existing study guides with recommended topics to enable accurate exclusion logic

-- ============================================================================
-- CRITICAL: This backfill must run before the new topic-selector logic
-- ============================================================================
-- Without this backfill, users with pre-migration study guides will bypass
-- the "recently studied" guard and receive duplicate topic recommendations.

-- ============================================================================
-- Step 1: Create helper function for fuzzy title matching
-- ============================================================================

CREATE OR REPLACE FUNCTION normalize_text_for_matching(text_input TEXT)
RETURNS TEXT AS $$
BEGIN
  -- Normalize text: lowercase, trim whitespace, remove punctuation
  RETURN LOWER(TRIM(REGEXP_REPLACE(text_input, '[[:punct:]]', '', 'g')));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- Step 2: Backfill topic_id for study guides with input_type = 'topic'
-- ============================================================================

DO $$
DECLARE
  updated_count INTEGER := 0;
  skipped_count INTEGER := 0;
  total_count INTEGER;
BEGIN
  -- Count total guides needing backfill
  SELECT COUNT(*) INTO total_count
  FROM study_guides
  WHERE input_type = 'topic' AND topic_id IS NULL;

  RAISE NOTICE 'Starting backfill for % study guides with input_type = topic', total_count;

  -- Update study guides by matching input_value with English topic titles
  WITH matched_topics AS (
    SELECT
      sg.id AS study_guide_id,
      rt.id AS matched_topic_id,
      sg.input_value,
      rt.title AS matched_title
    FROM study_guides sg
    INNER JOIN recommended_topics rt
      ON normalize_text_for_matching(sg.input_value) = normalize_text_for_matching(rt.title)
    WHERE sg.input_type = 'topic'
      AND sg.topic_id IS NULL
      AND rt.is_active = true
  ),
  -- Also match against translations
  matched_translations AS (
    SELECT
      sg.id AS study_guide_id,
      rtt.topic_id AS matched_topic_id,
      sg.input_value,
      rtt.title AS matched_title
    FROM study_guides sg
    INNER JOIN recommended_topics_translations rtt
      ON normalize_text_for_matching(sg.input_value) = normalize_text_for_matching(rtt.title)
    WHERE sg.input_type = 'topic'
      AND sg.topic_id IS NULL
      AND sg.id NOT IN (SELECT study_guide_id FROM matched_topics) -- Avoid duplicates
  ),
  -- Combine both matches
  all_matches AS (
    SELECT * FROM matched_topics
    UNION ALL
    SELECT * FROM matched_translations
  )
  -- Perform the update
  UPDATE study_guides
  SET topic_id = all_matches.matched_topic_id
  FROM all_matches
  WHERE study_guides.id = all_matches.study_guide_id;

  GET DIAGNOSTICS updated_count = ROW_COUNT;

  -- Calculate skipped count
  SELECT COUNT(*) INTO skipped_count
  FROM study_guides
  WHERE input_type = 'topic' AND topic_id IS NULL;

  RAISE NOTICE 'Backfill complete: % guides updated, % guides could not be matched', updated_count, skipped_count;

  -- Log skipped guides for manual review
  IF skipped_count > 0 THEN
    RAISE WARNING 'The following study guides could not be matched to recommended topics:';
    DECLARE
      guide RECORD;
    BEGIN
      FOR guide IN
        SELECT id, input_value, created_at
        FROM study_guides
        WHERE input_type = 'topic' AND topic_id IS NULL
        LIMIT 10
      LOOP
        RAISE WARNING 'ID: %, Input: %, Created: %', guide.id, guide.input_value, guide.created_at;
      END LOOP;
    END;
  END IF;
END $$;

-- ============================================================================
-- Step 3: Create index for efficient matching (if not exists)
-- ============================================================================

-- Index for normalized English title matching
CREATE INDEX IF NOT EXISTS idx_recommended_topics_normalized_title
  ON recommended_topics (normalize_text_for_matching(title))
  WHERE is_active = true;

-- Index for normalized translation title matching
CREATE INDEX IF NOT EXISTS idx_topics_translations_normalized_title
  ON recommended_topics_translations (normalize_text_for_matching(title));

-- ============================================================================
-- Step 4: Verify backfill results
-- ============================================================================

DO $$
DECLARE
  total_topics INTEGER;
  backfilled_topics INTEGER;
  remaining_nulls INTEGER;
  success_rate NUMERIC;
BEGIN
  -- Count statistics
  SELECT
    COUNT(*) FILTER (WHERE input_type = 'topic') AS total,
    COUNT(*) FILTER (WHERE input_type = 'topic' AND topic_id IS NOT NULL) AS backfilled,
    COUNT(*) FILTER (WHERE input_type = 'topic' AND topic_id IS NULL) AS remaining
  INTO total_topics, backfilled_topics, remaining_nulls
  FROM study_guides;

  -- Calculate success rate
  IF total_topics > 0 THEN
    success_rate := (backfilled_topics::NUMERIC / total_topics::NUMERIC) * 100;
  ELSE
    success_rate := 0;
  END IF;

  RAISE NOTICE '=== Backfill Verification ===';
  RAISE NOTICE 'Total topic-type guides: %', total_topics;
  RAISE NOTICE 'Successfully backfilled: % (%.2f%%)', backfilled_topics, success_rate;
  RAISE NOTICE 'Could not match: %', remaining_nulls;
  RAISE NOTICE '============================';
END $$;

-- ============================================================================
-- Step 5: Add helpful comments
-- ============================================================================

COMMENT ON FUNCTION normalize_text_for_matching(TEXT) IS
  'Normalizes text for fuzzy matching: lowercase, trim whitespace, remove punctuation. Used for backfilling study_guides.topic_id.';

COMMENT ON INDEX idx_recommended_topics_normalized_title IS
  'Speeds up backfill matching between study guide input_value and recommended topic titles';

COMMENT ON INDEX idx_topics_translations_normalized_title IS
  'Speeds up backfill matching between study guide input_value and translated topic titles';
