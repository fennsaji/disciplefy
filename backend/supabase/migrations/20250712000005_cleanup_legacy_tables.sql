-- Remove legacy study_guides table and related objects
-- This migration removes the old study_guides table structure after successful migration to cached architecture

BEGIN;

-- Drop legacy tables if they exist (these were renamed during migration)
DROP TABLE IF EXISTS study_guides_old CASCADE;
DROP TABLE IF EXISTS anonymous_study_guides_old CASCADE;

-- Drop any remaining legacy indexes that might exist
DROP INDEX IF EXISTS idx_study_guides_user_id;
DROP INDEX IF EXISTS idx_study_guides_created_at;
DROP INDEX IF EXISTS idx_study_guides_input_type;
DROP INDEX IF EXISTS idx_study_guides_language;
DROP INDEX IF EXISTS idx_study_guides_saved;

-- Drop legacy anonymous study guides indexes
DROP INDEX IF EXISTS idx_anonymous_guides_session;
DROP INDEX IF EXISTS idx_anonymous_guides_expiry;

-- Drop any legacy functions that might reference old tables
DROP FUNCTION IF EXISTS update_study_guides_updated_at();
DROP FUNCTION IF EXISTS cleanup_expired_anonymous_guides();

-- Drop legacy triggers if they exist
DROP TRIGGER IF EXISTS update_study_guides_updated_at ON study_guides;
DROP TRIGGER IF EXISTS trigger_update_study_guides_updated_at ON study_guides;

-- Drop legacy views if they exist
DROP VIEW IF EXISTS authenticated_study_guides CASCADE;
DROP VIEW IF EXISTS anonymous_study_guides_view CASCADE;

-- Note: RLS policies are automatically dropped when tables are dropped with CASCADE

-- Log the cleanup
SELECT 'Legacy study_guides table structure cleanup completed' AS cleanup_status;

COMMIT;