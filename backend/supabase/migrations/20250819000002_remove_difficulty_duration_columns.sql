-- Remove difficulty_level and estimated_duration columns from recommended_topics
-- This migration focuses solely on schema changes for better maintainability

BEGIN;

-- ============================================================================
-- DEPENDENCY CLEANUP FIRST
-- ============================================================================

-- Drop functions that reference the columns being removed
DROP FUNCTION IF EXISTS get_recommended_topics(TEXT, TEXT, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS get_recommended_topics_count(TEXT, TEXT);

-- ============================================================================
-- REMOVE COLUMNS AND RELATED OBJECTS
-- ============================================================================

-- Drop indexes that reference the columns being removed
DROP INDEX IF EXISTS idx_recommended_topics_difficulty;

-- Remove the columns
ALTER TABLE recommended_topics DROP COLUMN IF EXISTS difficulty_level;
ALTER TABLE recommended_topics DROP COLUMN IF EXISTS estimated_duration;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify columns are removed
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'recommended_topics' 
        AND column_name = 'difficulty_level' 
        AND table_schema = 'public'
    ) THEN
        RAISE NOTICE 'VERIFIED: difficulty_level column successfully removed';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: difficulty_level column still exists';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'recommended_topics' 
        AND column_name = 'estimated_duration' 
        AND table_schema = 'public'
    ) THEN
        RAISE NOTICE 'VERIFIED: estimated_duration column successfully removed';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: estimated_duration column still exists';
    END IF;
    
    -- Verify index is removed
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_recommended_topics_difficulty' 
        AND schemaname = 'public'
    ) THEN
        RAISE NOTICE 'VERIFIED: idx_recommended_topics_difficulty index successfully removed';
    ELSE
        RAISE EXCEPTION 'VERIFICATION FAILED: idx_recommended_topics_difficulty index still exists';
    END IF;
END;
$$;

SELECT 
  'COLUMN REMOVAL COMPLETED SUCCESSFULLY' as status,
  NOW() as completed_at,
  'Removed difficulty_level and estimated_duration columns and related objects' as summary;

COMMIT;