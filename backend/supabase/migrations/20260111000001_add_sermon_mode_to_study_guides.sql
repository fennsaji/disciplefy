-- ============================================================================
-- Migration: Add Sermon Mode to Study Guides
-- Version: 1.0
-- Date: 2026-01-11
-- Description:
--   - Adds 'sermon' to study_mode constraint in study_guides table
--   - Adds 'sermon' to study_mode constraint in study_reflections table
--   - Updates comments to reflect new mode
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. UPDATE STUDY_GUIDES TABLE CONSTRAINT
-- ============================================================================

-- Drop old constraint
ALTER TABLE public.study_guides
DROP CONSTRAINT IF EXISTS study_guides_study_mode_check;

-- Add new constraint including 'sermon'
ALTER TABLE public.study_guides
ADD CONSTRAINT study_guides_study_mode_check
CHECK (study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon'));

-- Update comment
COMMENT ON COLUMN public.study_guides.study_mode IS
'Study mode used to generate this guide: quick (3 min), standard (10 min), deep (25 min), lectio (15 min), sermon (55 min)';

-- ============================================================================
-- 2. UPDATE STUDY_REFLECTIONS TABLE CONSTRAINT
-- ============================================================================

-- Drop old constraint
ALTER TABLE public.study_reflections
DROP CONSTRAINT IF EXISTS study_reflections_study_mode_check;

-- Add new constraint including 'sermon'
ALTER TABLE public.study_reflections
ADD CONSTRAINT study_reflections_study_mode_check
CHECK (study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon'));

-- ============================================================================
-- 3. UPDATE USER_PREFERENCES DEFAULT_STUDY_MODE CONSTRAINT
-- ============================================================================

-- Drop old constraint
ALTER TABLE public.user_preferences
DROP CONSTRAINT IF EXISTS user_preferences_default_study_mode_check;

-- Add new constraint including 'sermon'
ALTER TABLE public.user_preferences
ADD CONSTRAINT user_preferences_default_study_mode_check
CHECK (default_study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon'));

COMMENT ON COLUMN public.user_preferences.default_study_mode IS
'User preferred default study mode for new study guides: quick, standard, deep, lectio, or sermon';

-- ============================================================================
-- 4. UPDATE USER_PROFILES DEFAULT_STUDY_MODE CONSTRAINT (if exists)
-- ============================================================================

-- Check if column exists and update constraint
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'user_profiles'
    AND column_name = 'default_study_mode'
  ) THEN
    -- Drop old constraint
    ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_default_study_mode_check;

    -- Add new constraint
    ALTER TABLE public.user_profiles
    ADD CONSTRAINT user_profiles_default_study_mode_check
    CHECK (default_study_mode IS NULL OR default_study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon', 'recommended'));
  END IF;
END $$;

COMMIT;
