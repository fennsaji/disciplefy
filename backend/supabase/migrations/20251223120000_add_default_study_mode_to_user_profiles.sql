-- ============================================================================
-- Migration: Add default_study_mode to user_profiles table
-- Version: 1.0
-- Date: 2025-12-23
-- Description:
--   Adds default_study_mode column to user_profiles table to allow users
--   to save their preferred study mode preference
-- ============================================================================

BEGIN;

-- Add default_study_mode column to user_profiles
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS default_study_mode TEXT DEFAULT NULL
CHECK (default_study_mode IS NULL OR default_study_mode IN ('quick', 'standard', 'deep', 'lectio'));

-- Add comment for documentation
COMMENT ON COLUMN public.user_profiles.default_study_mode IS
'User preferred default study mode for new study guides. NULL means ask every time.';

-- Index for filtering (optional, but useful for analytics)
CREATE INDEX IF NOT EXISTS idx_user_profiles_study_mode
ON public.user_profiles(default_study_mode)
WHERE default_study_mode IS NOT NULL;

-- Validation
DO $$
DECLARE
  column_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'default_study_mode'
  ) INTO column_exists;

  IF NOT column_exists THEN
    RAISE EXCEPTION 'user_profiles.default_study_mode column was not created';
  END IF;

  RAISE NOTICE 'Migration completed successfully:';
  RAISE NOTICE '  - Added default_study_mode column to user_profiles';
END $$;

COMMIT;
