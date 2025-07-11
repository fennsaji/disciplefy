-- Rename study_guides_cache to study_guides
-- This migration finalizes the table naming by renaming the cache table to the standard name

BEGIN;

-- Check if study_guides_cache exists and study_guides doesn't exist yet
DO $$
BEGIN
  -- Only proceed if study_guides_cache exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'study_guides_cache') THEN
    
    -- If study_guides already exists, drop it first (it should be the old table)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'study_guides') THEN
      RAISE NOTICE 'Dropping existing study_guides table (old structure)';
      DROP TABLE study_guides CASCADE;
    END IF;
    
    -- Rename study_guides_cache to study_guides
    RAISE NOTICE 'Renaming study_guides_cache to study_guides';
    ALTER TABLE study_guides_cache RENAME TO study_guides;
    
    -- Update any constraints that reference the old table name
    -- Note: Foreign key constraints automatically update with table rename
    
    -- Update comments if they exist
    COMMENT ON TABLE study_guides IS 'Study guide content cache with deduplication - primary content storage';
    
    RAISE NOTICE 'Successfully renamed study_guides_cache to study_guides';
    
  ELSE
    RAISE NOTICE 'study_guides_cache table does not exist, skipping rename';
  END IF;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error during table rename: %', SQLERRM;
END
$$;

-- Update any indexes that might have been created with the old table name
-- (Most indexes should automatically update with table rename)

-- Update any views or functions that reference the old table name
-- Note: These will be updated in the code changes

-- Verify the rename was successful
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'study_guides') THEN
    RAISE NOTICE 'Verification: study_guides table exists';
  ELSE
    RAISE EXCEPTION 'Verification failed: study_guides table does not exist';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'study_guides_cache') THEN
    RAISE NOTICE 'Verification: study_guides_cache table no longer exists';
  ELSE
    RAISE NOTICE 'Warning: study_guides_cache table still exists';
  END IF;
END
$$;

COMMIT;