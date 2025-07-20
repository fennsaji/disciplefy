-- Migration: Remove unused tables
-- Date: 2025-07-14
-- Description: Remove tables that are not referenced in the codebase and have no data

-- Remove unused tables (confirmed through code analysis and database statistics)

-- 1. admin_logs - No code references, no data (0 rows)
DROP TABLE IF EXISTS public.admin_logs CASCADE;

-- 2. donations - No code references, no data (0 rows)
-- Razorpay integration not implemented yet
DROP TABLE IF EXISTS public.donations CASCADE;

-- 3. recommended_guide_sessions - No code references, no data (0 rows) 
-- Jeff Reed methodology not implemented in current version
DROP TABLE IF EXISTS public.recommended_guide_sessions CASCADE;

-- 4. anonymous_study_guides (legacy) - Superseded by anonymous_study_guides_new
-- Note: This should have been removed by previous migrations but may still exist
DROP TABLE IF EXISTS public.anonymous_study_guides CASCADE;

-- 5. anonymous_study_guides_new - No code references, no data (0 rows)
-- This table was created for a feature that is not needed
DROP TABLE IF EXISTS public.anonymous_study_guides_new CASCADE;

-- Drop any orphaned policies that might reference these tables
DO $$
BEGIN
    -- Clean up any RLS policies that might reference dropped tables
    DROP POLICY IF EXISTS "admin_logs_select_policy" ON public.admin_logs;
    DROP POLICY IF EXISTS "admin_logs_insert_policy" ON public.admin_logs;
    DROP POLICY IF EXISTS "donations_select_policy" ON public.donations;
    DROP POLICY IF EXISTS "donations_insert_policy" ON public.donations;
    DROP POLICY IF EXISTS "recommended_guide_sessions_select_policy" ON public.recommended_guide_sessions;
    DROP POLICY IF EXISTS "anonymous_study_guides_select_policy" ON public.anonymous_study_guides;
    DROP POLICY IF EXISTS "anonymous_study_guides_new_select_policy" ON public.anonymous_study_guides_new;
    
    -- Note: Some policies may not exist, which is fine
EXCEPTION
    WHEN OTHERS THEN
        -- Ignore errors for policies that don't exist
        NULL;
END $$;

-- Log the cleanup
INSERT INTO public.analytics_events (
    event_type,
    event_data,
    created_at
) VALUES (
    'database_cleanup',
    jsonb_build_object(
        'action', 'remove_unused_tables',
        'tables_removed', ARRAY['admin_logs', 'donations', 'recommended_guide_sessions', 'anonymous_study_guides'],
        'migration_version', '20250714220000',
        'reason', 'No code references and no data'
    ),
    NOW()
);

-- Verify remaining tables
SELECT 
    tablename,
    tableowner
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;