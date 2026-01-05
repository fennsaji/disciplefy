-- ============================================================================
-- Migration: Add 'recommended' option to default_study_mode constraint
-- Version: 1.0
-- Date: 2026-01-04
-- Description:
--   Updates default_study_mode CHECK constraint to allow 'recommended' value
--   which enables automatic mode selection based on input type:
--   - scripture → deep
--   - topic → standard
--   - question → standard
-- ============================================================================

BEGIN;

-- Drop the existing constraint
ALTER TABLE public.user_profiles
DROP CONSTRAINT IF EXISTS user_profiles_default_study_mode_check;

-- Add updated constraint with 'recommended' option
ALTER TABLE public.user_profiles
ADD CONSTRAINT user_profiles_default_study_mode_check
CHECK (default_study_mode IS NULL OR default_study_mode IN ('quick', 'standard', 'deep', 'lectio', 'recommended'));

-- Update comment for documentation
COMMENT ON COLUMN public.user_profiles.default_study_mode IS
'User preferred default study mode for new study guides.
NULL = ask every time
recommended = use recommended mode based on input type (scripture→deep, topic/question→standard)
quick/standard/deep/lectio = always use specific mode';

-- Validation
DO $$
DECLARE
  constraint_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE table_name = 'user_profiles'
    AND constraint_name = 'user_profiles_default_study_mode_check'
  ) INTO constraint_exists;

  IF NOT constraint_exists THEN
    RAISE EXCEPTION 'user_profiles.default_study_mode_check constraint was not created';
  END IF;

  RAISE NOTICE 'Migration completed successfully:';
  RAISE NOTICE '  - Updated default_study_mode constraint to allow "recommended" value';
END $$;

COMMIT;
