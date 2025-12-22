-- Migration: Add Comprehensive Mastery Tracking (v2.0 - Stricter Criteria)
-- Date: 2025-01-22
-- Version: 2.0
-- Description: Adds is_fully_mastered column and calculation logic to track
--              comprehensive mastery with stricter criteria to ensure true long-term retention

-- ============================================================================
-- Step 1: Add Column to memory_verses Table
-- ============================================================================

ALTER TABLE memory_verses
ADD COLUMN IF NOT EXISTS is_fully_mastered BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN memory_verses.is_fully_mastered IS
'TRUE if verse meets comprehensive mastery v2.0 (stricter criteria):
- 20+ total practice sessions
- 15+ successful reviews (75%+ success rate)
- 8 consecutive successful reviews (repetitions >= 8)
- 21+ day interval (3+ weeks spacing)
- 6+ modes mastered (80%+ over 8+ practices each)
- 2 hard modes mastered (both Audio AND Type It Out)
- 60+ days since verse was added (2+ months elapsed)';

-- ============================================================================
-- Step 2: Create Index for Performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_memory_verses_fully_mastered
ON memory_verses(user_id, is_fully_mastered)
WHERE is_fully_mastered = TRUE;

COMMENT ON INDEX idx_memory_verses_fully_mastered IS
'Optimizes queries for counting/filtering fully mastered verses per user';

-- ============================================================================
-- Step 3: Create Function to Calculate Comprehensive Mastery
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_comprehensive_mastery(verse_id_param UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  verse_record RECORD;
  total_reviews_count INTEGER;
  successful_reviews_count INTEGER;
  mastered_modes_count INTEGER;
  hard_modes_mastered_count INTEGER;
  days_since_added INTEGER;
BEGIN
  -- Get verse SM-2 data and creation date
  SELECT
    repetitions,
    interval_days,
    total_reviews,
    added_date
  INTO verse_record
  FROM memory_verses
  WHERE id = verse_id_param;

  -- Return FALSE if verse not found
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Criterion 1: Consecutive successful reviews (must have 8+ repetitions)
  -- This ensures the last 8 reviews were all successful (quality >= 3)
  IF verse_record.repetitions < 8 THEN
    RETURN FALSE;
  END IF;

  -- Criterion 2: Review interval (reviews must be spaced over at least 21 days / 3 weeks)
  -- This prevents cramming and ensures proper spaced repetition
  IF verse_record.interval_days < 21 THEN
    RETURN FALSE;
  END IF;

  -- Criterion 3: Total practice sessions (must have at least 20 total reviews)
  -- Uses total_reviews from memory_verses table for performance
  IF verse_record.total_reviews < 20 THEN
    RETURN FALSE;
  END IF;

  -- Criterion 4: Weighted success rate (at least 15 successful out of 20+ total)
  -- Count successful reviews from review_sessions table (quality_rating >= 3)
  SELECT COUNT(*)
  INTO successful_reviews_count
  FROM review_sessions
  WHERE memory_verse_id = verse_id_param
    AND quality_rating >= 3;

  IF successful_reviews_count < 15 THEN
    RETURN FALSE;
  END IF;

  -- Criterion 5: Count unique mastered modes (80%+ success rate over 8+ practices each)
  -- Increased from 5+ to 8+ practices per mode for more rigorous validation
  SELECT COUNT(DISTINCT mode_type)
  INTO mastered_modes_count
  FROM memory_practice_modes
  WHERE memory_verse_id = verse_id_param
    AND times_practiced >= 8
    AND success_rate >= 80.0;

  IF mastered_modes_count < 6 THEN
    RETURN FALSE;
  END IF;

  -- Criterion 6: Both hard modes mastered (audio AND type_it_out)
  -- Ensures user has demonstrated mastery in challenging recall scenarios
  SELECT COUNT(DISTINCT mode_type)
  INTO hard_modes_mastered_count
  FROM memory_practice_modes
  WHERE memory_verse_id = verse_id_param
    AND times_practiced >= 8
    AND success_rate >= 80.0
    AND mode_type IN ('audio', 'type_it_out');

  IF hard_modes_mastered_count < 2 THEN
    RETURN FALSE;
  END IF;

  -- Criterion 7: Time elapsed since verse was added (at least 60 days / 2 months)
  -- Prevents "instant mastery" and ensures long-term retention verification
  days_since_added := EXTRACT(DAY FROM (NOW() - verse_record.added_date));

  IF days_since_added < 60 THEN
    RETURN FALSE;
  END IF;

  -- All criteria met - verse is fully mastered
  RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION calculate_comprehensive_mastery(UUID) IS
'Calculates whether a verse meets comprehensive mastery criteria v2.0 (stricter):
1. repetitions >= 8 (8 consecutive successful SM-2 reviews)
2. interval_days >= 21 (spaced over at least 3 weeks)
3. total_reviews >= 20 (at least 20 total practice sessions)
4. successful_reviews >= 15 (75%+ success rate from review_sessions)
5. 6+ different practice modes mastered (80%+ success rate over 8+ practices each)
6. 2 hard modes mastered (both audio AND type_it_out with 80%+ over 8+ practices)
7. 60+ days since verse was added (minimum 2 months elapsed)

This stricter criteria ensures true long-term retention and prevents gaming the system.';

-- ============================================================================
-- Step 4: Create Trigger Function to Auto-Update Mastery Status
-- ============================================================================

CREATE OR REPLACE FUNCTION update_verse_mastery_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  target_verse_id UUID;
BEGIN
  -- Determine which verse ID to update based on trigger context
  IF TG_TABLE_NAME = 'memory_practice_modes' THEN
    target_verse_id := NEW.memory_verse_id;
  ELSIF TG_TABLE_NAME = 'memory_verses' THEN
    target_verse_id := NEW.id;
  ELSE
    RAISE EXCEPTION 'Unexpected trigger table: %', TG_TABLE_NAME;
  END IF;

  -- Update is_fully_mastered flag
  UPDATE memory_verses
  SET is_fully_mastered = calculate_comprehensive_mastery(target_verse_id),
      updated_at = NOW()
  WHERE id = target_verse_id;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION update_verse_mastery_status() IS
'Trigger function that recalculates and updates is_fully_mastered when:
- Practice mode stats change (memory_practice_modes)
- Verse SM-2 data changes (memory_verses)';

-- ============================================================================
-- Step 5: Create Triggers on Relevant Tables
-- ============================================================================

-- Trigger on memory_practice_modes table
DROP TRIGGER IF EXISTS trg_update_mastery_on_practice ON memory_practice_modes;
CREATE TRIGGER trg_update_mastery_on_practice
AFTER INSERT OR UPDATE ON memory_practice_modes
FOR EACH ROW
EXECUTE FUNCTION update_verse_mastery_status();

COMMENT ON TRIGGER trg_update_mastery_on_practice ON memory_practice_modes IS
'Recalculates comprehensive mastery when practice mode stats change';

-- Trigger on memory_verses table (when SM-2 data changes)
DROP TRIGGER IF EXISTS trg_update_mastery_on_review ON memory_verses;
CREATE TRIGGER trg_update_mastery_on_review
AFTER UPDATE ON memory_verses
FOR EACH ROW
WHEN (
  OLD.repetitions IS DISTINCT FROM NEW.repetitions OR
  OLD.interval_days IS DISTINCT FROM NEW.interval_days
)
EXECUTE FUNCTION update_verse_mastery_status();

COMMENT ON TRIGGER trg_update_mastery_on_review ON memory_verses IS
'Recalculates comprehensive mastery when SM-2 repetitions or interval changes';

-- ============================================================================
-- Step 6: Backfill Existing Data
-- ============================================================================

-- Update all existing verses with comprehensive mastery status
-- This may take a while for large datasets
UPDATE memory_verses
SET is_fully_mastered = calculate_comprehensive_mastery(id),
    updated_at = NOW()
WHERE is_fully_mastered = FALSE; -- Only update verses not already marked

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- To verify the migration worked, run:
-- SELECT
--   COUNT(*) as total_verses,
--   COUNT(*) FILTER (WHERE repetitions >= 5) as basic_mastered,
--   COUNT(*) FILTER (WHERE is_fully_mastered = TRUE) as fully_mastered_v2
-- FROM memory_verses;

-- Detailed verification - show verses that meet each criterion:
-- SELECT
--   id,
--   verse_reference,
--   repetitions >= 8 as has_8_reps,
--   interval_days >= 21 as has_21_day_interval,
--   total_reviews >= 20 as has_20_reviews,
--   EXTRACT(DAY FROM (NOW() - added_date)) >= 60 as has_60_days_elapsed,
--   is_fully_mastered
-- FROM memory_verses
-- WHERE repetitions >= 5
-- ORDER BY is_fully_mastered DESC, repetitions DESC;
