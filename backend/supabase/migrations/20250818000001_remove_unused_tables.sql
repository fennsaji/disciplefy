-- Remove Unused Tables Migration
-- 
-- This migration removes tables that have been identified as unused in the current codebase:
-- 1. anonymous_sessions - Referenced in auth-session but code queries non-existent user_sessions instead
-- 2. oauth_states - Created but never used anywhere in the codebase (optional OAuth feature)
--
-- SAFETY FEATURES:
-- - Comprehensive data validation before removal  
-- - Complete rollback capabilities
-- - Detailed logging for audit trail
-- - Foreign key constraint handling

BEGIN;

-- ============================================================================
-- SAFETY VALIDATION: Check for any data that might indicate active usage
-- ============================================================================

-- Check if anonymous_sessions has any recent activity (last 30 days)
DO $$
DECLARE
  recent_sessions_count INTEGER;
  total_sessions_count INTEGER;
BEGIN
  -- Check if the table exists before querying
  IF to_regclass('public.anonymous_sessions') IS NOT NULL THEN
    -- Count total sessions
    SELECT COUNT(*) INTO total_sessions_count FROM public.anonymous_sessions;
    
    -- Count recent sessions (last 30 days)
    SELECT COUNT(*) INTO recent_sessions_count 
    FROM public.anonymous_sessions 
    WHERE created_at > NOW() - INTERVAL '30 days';
    
    RAISE NOTICE 'SAFETY CHECK - anonymous_sessions: total=%, recent_30d=%', 
      total_sessions_count, recent_sessions_count;
    
    -- Warn if there's recent activity
    IF recent_sessions_count > 0 THEN
      RAISE WARNING 'anonymous_sessions contains % recent records from last 30 days', recent_sessions_count;
    END IF;
  ELSE
    RAISE NOTICE 'SAFETY CHECK - anonymous_sessions: table does not exist, skipping data check';
  END IF;
END
$$;

-- Check if oauth_states has any data at all
DO $$
DECLARE
  oauth_states_count INTEGER;
BEGIN
  -- Check if the table exists before querying
  IF to_regclass('public.oauth_states') IS NOT NULL THEN
    SELECT COUNT(*) INTO oauth_states_count FROM public.oauth_states;
    
    RAISE NOTICE 'SAFETY CHECK - oauth_states: total=%', oauth_states_count;
    
    IF oauth_states_count > 0 THEN
      RAISE WARNING 'oauth_states contains % records', oauth_states_count;
    END IF;
  ELSE
    RAISE NOTICE 'SAFETY CHECK - oauth_states: table does not exist, skipping data check';
  END IF;
END
$$;

-- ============================================================================
-- BACKUP CRITICAL DATA (if any exists)
-- ============================================================================

-- Create persistent backup tables for rollback capability (idempotent)
DO $$
DECLARE
  backup_rows INTEGER;
BEGIN
  -- Create persistent backup table for anonymous_sessions only if source table exists
  IF to_regclass('public.anonymous_sessions') IS NOT NULL THEN
    CREATE TABLE IF NOT EXISTS public.backup_anonymous_sessions AS 
    SELECT * FROM public.anonymous_sessions WHERE false; -- Create empty table with same structure
    
    -- Clear any existing backup data first
    DELETE FROM public.backup_anonymous_sessions;
    -- Insert current data
    INSERT INTO public.backup_anonymous_sessions SELECT * FROM public.anonymous_sessions;
    
    SELECT COUNT(*) INTO backup_rows FROM public.backup_anonymous_sessions;
    RAISE NOTICE 'BACKUP: Created persistent backup_anonymous_sessions with % rows', backup_rows;
  ELSE
    RAISE NOTICE 'BACKUP: anonymous_sessions does not exist, skipping backup creation';
  END IF;
  
  -- Create persistent backup table for oauth_states only if source table exists
  IF to_regclass('public.oauth_states') IS NOT NULL THEN
    CREATE TABLE IF NOT EXISTS public.backup_oauth_states AS 
    SELECT * FROM public.oauth_states WHERE false; -- Create empty table with same structure
    
    -- Clear any existing backup data first
    DELETE FROM public.backup_oauth_states;
    -- Insert current data
    INSERT INTO public.backup_oauth_states SELECT * FROM public.oauth_states;
    
    SELECT COUNT(*) INTO backup_rows FROM public.backup_oauth_states;
    RAISE NOTICE 'BACKUP: Created persistent backup_oauth_states with % rows', backup_rows;
  ELSE
    RAISE NOTICE 'BACKUP: oauth_states does not exist, skipping backup creation';
  END IF;
END
$$;

-- ============================================================================
-- FOREIGN KEY DEPENDENCY ANALYSIS
-- ============================================================================

-- Check for foreign key references to anonymous_sessions
DO $$
DECLARE
  fk_count INTEGER;
  constraint_info RECORD;
BEGIN
  -- Find any tables that reference anonymous_sessions
  SELECT COUNT(*) INTO fk_count
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
  JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
  WHERE ccu.table_name = 'anonymous_sessions' 
    AND tc.constraint_type = 'FOREIGN KEY';
  
  RAISE NOTICE 'DEPENDENCY CHECK: % foreign key constraints reference anonymous_sessions', fk_count;
  
  -- Log specific constraints
  FOR constraint_info IN
    SELECT 
      tc.table_name as referencing_table,
      kcu.column_name as referencing_column,
      tc.constraint_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu 
      ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu 
      ON ccu.constraint_name = tc.constraint_name
    WHERE ccu.table_name = 'anonymous_sessions' 
      AND tc.constraint_type = 'FOREIGN KEY'
  LOOP
    RAISE NOTICE 'FK DEPENDENCY: %.% -> anonymous_sessions (constraint: %)',
      constraint_info.referencing_table, 
      constraint_info.referencing_column,
      constraint_info.constraint_name;
  END LOOP;
END
$$;

-- ============================================================================
-- REMOVE UNUSED TABLES
-- ============================================================================

-- 1. Remove oauth_states (no dependencies expected)
DO $$
BEGIN
  RAISE NOTICE 'REMOVING: oauth_states table and related objects...';
END
$$;

-- Drop related function first
DROP FUNCTION IF EXISTS cleanup_expired_oauth_states();

-- Drop the table (CASCADE will remove RLS policies and indexes automatically)
DROP TABLE IF EXISTS oauth_states CASCADE;

DO $$
BEGIN
  RAISE NOTICE 'SUCCESS: oauth_states table removed';
END
$$;

-- 2. Remove anonymous_sessions (may have dependencies)
DO $$
BEGIN
  RAISE NOTICE 'REMOVING: anonymous_sessions table and related objects...';
END
$$;

-- Note: Any foreign key references will be automatically handled by CASCADE
-- But first, let's see what gets affected
DO $$
BEGIN
  -- Check if the table still exists before attempting to drop
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'anonymous_sessions' AND table_schema = 'public') THEN
    -- Drop the table with CASCADE to handle all dependencies
    DROP TABLE anonymous_sessions CASCADE;
    RAISE NOTICE 'SUCCESS: anonymous_sessions table removed with CASCADE';
  ELSE
    RAISE NOTICE 'INFO: anonymous_sessions table does not exist';
  END IF;
END
$$;

-- ============================================================================
-- CLEANUP RELATED OBJECTS
-- ============================================================================

-- Remove any lingering RLS policies (should be handled by CASCADE but being thorough)
DO $$
BEGIN
  -- Only drop policies if tables still exist (they shouldn't after CASCADE)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'anonymous_sessions' AND table_schema = 'public') THEN
    DROP POLICY IF EXISTS "Anonymous sessions are session-scoped" ON anonymous_sessions;
    DROP POLICY IF EXISTS "Anonymous sessions read/write by session" ON anonymous_sessions;
  END IF;
END
$$;

-- Remove any remaining indexes (should be handled by CASCADE)
DROP INDEX IF EXISTS idx_anonymous_sessions_expires_at;
DROP INDEX IF EXISTS idx_anonymous_sessions_device_hash;
DROP INDEX IF EXISTS idx_oauth_states_state;
DROP INDEX IF EXISTS idx_oauth_states_expires_at;
DROP INDEX IF EXISTS idx_oauth_states_used;

-- Remove any views that might reference these tables
DROP VIEW IF EXISTS anonymous_sessions_view CASCADE;
DROP VIEW IF EXISTS oauth_states_view CASCADE;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify tables are removed
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'anonymous_sessions' AND table_schema = 'public') THEN
    RAISE NOTICE 'VERIFIED: anonymous_sessions table successfully removed';
  ELSE
    RAISE EXCEPTION 'VERIFICATION FAILED: anonymous_sessions table still exists';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'oauth_states' AND table_schema = 'public') THEN
    RAISE NOTICE 'VERIFIED: oauth_states table successfully removed';
  ELSE
    RAISE EXCEPTION 'VERIFICATION FAILED: oauth_states table still exists';
  END IF;
END
$$;

-- Log remaining tables for verification
SELECT 'REMAINING TABLES:' as status;
SELECT tablename as remaining_table 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- ============================================================================
-- MIGRATION COMPLETED
-- ============================================================================

SELECT 
  'MIGRATION COMPLETED SUCCESSFULLY' as status,
  NOW() as completed_at,
  'Removed unused tables: anonymous_sessions, oauth_states' as summary;

COMMIT;

-- ============================================================================
-- ROLLBACK INSTRUCTIONS (for manual rollback if needed)
-- ============================================================================

-- To rollback this migration, create these SQL commands:
-- 
-- 1. Recreate anonymous_sessions table:
--    (Copy structure from 20250705000001_initial_schema.sql)
-- 
-- 2. Recreate oauth_states table:
--    (Copy structure from 20250730000001_create_oauth_states_table.sql)
-- 
-- 3. Restore data from persistent backup tables created by this migration:
--    INSERT INTO anonymous_sessions SELECT * FROM public.backup_anonymous_sessions;
--    INSERT INTO oauth_states SELECT * FROM public.backup_oauth_states;
--
-- IMPORTANT: The persistent backup tables created by this migration are:
--    - public.backup_anonymous_sessions (contains backed up data from before removal)
--    - public.backup_oauth_states (contains backed up data from before removal)
--
-- Note: These persistent backup tables remain available after transaction commit
--       Drop them manually when rollback capability is no longer needed:
--       DROP TABLE IF EXISTS public.backup_anonymous_sessions, public.backup_oauth_states;