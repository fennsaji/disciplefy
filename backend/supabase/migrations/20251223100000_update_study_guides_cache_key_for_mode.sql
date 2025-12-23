-- ============================================================================
-- Migration: Update Study Guides Unique Constraint to Include Study Mode
-- Version: 1.0
-- Date: 2025-12-23
-- Description:
--   Updates the unique constraint on study_guides table to include study_mode.
--   This allows the same input to have different cached content for each mode.
--   e.g., "Philippians 4:13" can have separate cached guides for:
--   - quick mode (3 min version)
--   - standard mode (10 min version)
--   - deep mode (25 min version)
--   - lectio mode (15 min version)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. DROP OLD UNIQUE CONSTRAINT
-- ============================================================================

-- Drop the old constraint that doesn't include study_mode
-- The constraint name comes from the original migration 20250712000001
ALTER TABLE public.study_guides
DROP CONSTRAINT IF EXISTS unique_cached_content;

-- Also drop the index if it exists separately
DROP INDEX IF EXISTS idx_study_guides_input_type_hash_language;

-- ============================================================================
-- 2. CREATE NEW UNIQUE CONSTRAINT WITH STUDY MODE
-- ============================================================================

-- Create new unique constraint including study_mode
-- This allows different modes to have different cached content
ALTER TABLE public.study_guides
ADD CONSTRAINT unique_cached_content_with_mode
UNIQUE(input_type, input_value_hash, language, study_mode);

-- Create index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_study_guides_cache_lookup
ON public.study_guides(input_type, input_value_hash, language, study_mode);

-- ============================================================================
-- 3. DOCUMENTATION
-- ============================================================================

COMMENT ON CONSTRAINT unique_cached_content_with_mode ON public.study_guides IS
'Ensures unique cached content per input type, value hash, language, AND study mode. Allows the same verse/topic to have different content for quick, standard, deep, and lectio modes.';

-- ============================================================================
-- 4. VALIDATION
-- ============================================================================

DO $$
DECLARE
  constraint_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_name = 'study_guides'
    AND constraint_name = 'unique_cached_content_with_mode'
    AND constraint_type = 'UNIQUE'
  ) INTO constraint_exists;

  IF NOT constraint_exists THEN
    RAISE EXCEPTION 'unique_cached_content_with_mode constraint was not created';
  END IF;

  RAISE NOTICE 'Migration completed successfully:';
  RAISE NOTICE '  - Dropped old unique_cached_content constraint';
  RAISE NOTICE '  - Created new unique_cached_content_with_mode constraint (includes study_mode)';
END $$;

COMMIT;
