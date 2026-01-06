-- ============================================================================
-- Migration: Revamp Personalization Questionnaire
-- Date: 2026-01-07
-- Description: Complete redesign of questionnaire system with 6 new questions
--              and weighted scoring algorithm for learning path recommendations
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. BACKUP EXISTING DATA (for rollback if needed)
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_personalization_backup AS
SELECT * FROM user_personalization;

-- ============================================================================
-- 2. DROP OLD COLUMNS
-- ============================================================================

ALTER TABLE user_personalization
  DROP COLUMN IF EXISTS faith_journey,
  DROP COLUMN IF EXISTS seeking,
  DROP COLUMN IF EXISTS time_commitment;

-- ============================================================================
-- 3. ADD NEW COLUMNS FOR 6 QUESTIONS
-- ============================================================================

ALTER TABLE user_personalization
  -- Question 1: Faith Stage
  ADD COLUMN faith_stage TEXT
    CHECK (faith_stage IN ('new_believer', 'growing_believer', 'committed_disciple')),

  -- Question 2: Spiritual Goals (multi-select, 1-3 values)
  ADD COLUMN spiritual_goals TEXT[] DEFAULT '{}',

  -- Question 3: Time Availability
  ADD COLUMN time_availability TEXT
    CHECK (time_availability IN ('5_to_10_min', '10_to_20_min', '20_plus_min')),

  -- Question 4: Learning Style
  ADD COLUMN learning_style TEXT
    CHECK (learning_style IN ('practical_application', 'deep_understanding', 'reflection_meditation', 'balanced_approach')),

  -- Question 5: Life Stage Focus
  ADD COLUMN life_stage_focus TEXT
    CHECK (life_stage_focus IN ('personal_foundation', 'family_relationships', 'community_impact', 'intellectual_growth')),

  -- Question 6: Biggest Challenge
  ADD COLUMN biggest_challenge TEXT
    CHECK (biggest_challenge IN ('starting_basics', 'staying_consistent', 'handling_doubts', 'sharing_faith', 'growing_stagnant')),

  -- Store scoring results for analytics
  ADD COLUMN scoring_results JSONB;

-- ============================================================================
-- 4. ADD VALIDATION CONSTRAINT FOR SPIRITUAL GOALS (1-3 selections)
-- ============================================================================

ALTER TABLE user_personalization
  ADD CONSTRAINT spiritual_goals_count_check
  CHECK (array_length(spiritual_goals, 1) BETWEEN 1 AND 3 OR spiritual_goals = '{}');

-- ============================================================================
-- 5. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_user_personalization_faith_stage
  ON user_personalization(faith_stage);

CREATE INDEX IF NOT EXISTS idx_user_personalization_spiritual_goals
  ON user_personalization USING GIN(spiritual_goals);

-- ============================================================================
-- 6. RESET EXISTING USERS TO RETAKE QUESTIONNAIRE
-- ============================================================================

UPDATE user_personalization
SET
  questionnaire_completed = false,
  questionnaire_skipped = false,
  scoring_results = NULL,
  updated_at = NOW();

-- ============================================================================
-- 7. VERIFICATION
-- ============================================================================

DO $$
DECLARE
  new_columns_count INTEGER;
  old_columns_count INTEGER;
BEGIN
  -- Check all new columns exist
  SELECT COUNT(*) INTO new_columns_count
  FROM information_schema.columns
  WHERE table_name = 'user_personalization'
    AND column_name IN ('faith_stage', 'spiritual_goals', 'time_availability', 'learning_style', 'life_stage_focus', 'biggest_challenge', 'scoring_results');

  IF new_columns_count != 7 THEN
    RAISE EXCEPTION 'Expected 7 new columns, found %', new_columns_count;
  END IF;

  -- Check old columns are dropped
  SELECT COUNT(*) INTO old_columns_count
  FROM information_schema.columns
  WHERE table_name = 'user_personalization'
    AND column_name IN ('faith_journey', 'seeking', 'time_commitment');

  IF old_columns_count != 0 THEN
    RAISE EXCEPTION 'Old columns still exist (found %)', old_columns_count;
  END IF;

  RAISE NOTICE '✓ Personalization questionnaire schema updated successfully';
  RAISE NOTICE '  - 7 new fields added (6 questions + scoring_results)';
  RAISE NOTICE '  - 3 old fields removed';
  RAISE NOTICE '  - 2 indexes created';
  RAISE NOTICE '  - All users reset to retake questionnaire';
END $$;

COMMIT;
