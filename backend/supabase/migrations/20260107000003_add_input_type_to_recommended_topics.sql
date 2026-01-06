-- ============================================================================
-- Migration: Add input_type to recommended_topics
-- Date: 2026-01-07
-- Description: Adds input_type column to recommended_topics table to support
--              question-based topics that generate AI answers vs traditional
--              verse/topic study guides.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ADD input_type COLUMN
-- ============================================================================

ALTER TABLE recommended_topics
ADD COLUMN IF NOT EXISTS input_type VARCHAR(20) DEFAULT 'topic';

-- Add check constraint to ensure only valid values
ALTER TABLE recommended_topics
ADD CONSTRAINT recommended_topics_input_type_check
CHECK (input_type IN ('topic', 'verse', 'question'));

-- ============================================================================
-- 2. UPDATE THEOLOGICAL QUESTION TOPICS TO USE 'question' INPUT TYPE
-- ============================================================================

UPDATE recommended_topics
SET input_type = 'question'
WHERE id IN (
  'aaa00000-e29b-41d4-a716-446655440001', -- Does God Exist?
  'aaa00000-e29b-41d4-a716-446655440002', -- Why Does God Allow Evil and Suffering?
  'aaa00000-e29b-41d4-a716-446655440003', -- Is Jesus the Only Way to Salvation?
  'aaa00000-e29b-41d4-a716-446655440004', -- What About Those Who Never Hear the Gospel?
  'aaa00000-e29b-41d4-a716-446655440005', -- What is the Trinity?
  'aaa00000-e29b-41d4-a716-446655440006', -- Why Doesn't God Answer My Prayers?
  'aaa00000-e29b-41d4-a716-446655440007', -- Predestination vs. Free Will
  'aaa00000-e29b-41d4-a716-446655440008', -- Why Are There So Many Christian Denominations?
  'aaa00000-e29b-41d4-a716-446655440009'  -- What is My Purpose in Life?
);

-- ============================================================================
-- 3. CREATE INDEX FOR PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_recommended_topics_input_type
ON recommended_topics(input_type)
WHERE is_active = true;

-- ============================================================================
-- 4. VERIFICATION
-- ============================================================================

DO $$
DECLARE
  column_exists BOOLEAN;
  question_topic_count INTEGER;
BEGIN
  -- Check column was added
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'recommended_topics'
      AND column_name = 'input_type'
  ) INTO column_exists;

  IF NOT column_exists THEN
    RAISE EXCEPTION 'input_type column was not added to recommended_topics table';
  END IF;

  -- Check 9 topics were updated to question type
  SELECT COUNT(*) INTO question_topic_count
  FROM recommended_topics
  WHERE input_type = 'question'
    AND id::text LIKE 'aaa00000%';

  IF question_topic_count != 9 THEN
    RAISE EXCEPTION 'Expected 9 question-type topics, found %', question_topic_count;
  END IF;

  RAISE NOTICE '✓ Migration completed successfully:';
  RAISE NOTICE '  - Added input_type column to recommended_topics';
  RAISE NOTICE '  - Updated % theological topics to question type', question_topic_count;
  RAISE NOTICE '  - Created performance index';
END $$;

COMMIT;
