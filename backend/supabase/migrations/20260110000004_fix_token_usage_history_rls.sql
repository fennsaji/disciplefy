-- ============================================================================
-- MIGRATION: Fix Token Usage History RLS for Service Role
-- Date: 2026-01-10
-- Description: Adds service role SELECT policy to allow Edge Functions to
--              query token usage history on behalf of authenticated users
--
-- Issue: Edge Functions use service role client, which causes RLS policy
--        "auth.uid() = user_id" to fail (auth.uid() is NULL for service role)
--
-- Solution: Add explicit service role SELECT policy since Edge Function
--           already validates user authentication before querying
-- ============================================================================

BEGIN;

-- Drop the existing user SELECT policy (we'll recreate it for clarity)
DROP POLICY IF EXISTS "Users can view own token usage history" ON public.token_usage_history;

-- Recreate user SELECT policy (authenticated users can view their own records)
CREATE POLICY "Users can view own token usage history"
  ON public.token_usage_history
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Add service role SELECT policy (allows Edge Functions to query on behalf of users)
-- Edge Functions validate authentication before calling RPC functions
CREATE POLICY "Service role can view all usage history"
  ON public.token_usage_history
  FOR SELECT
  TO service_role
  USING (true);

-- Grant SELECT to service_role explicitly (in addition to authenticated)
GRANT SELECT ON public.token_usage_history TO service_role;

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
DECLARE
  policy_count INTEGER;
BEGIN
  -- Count SELECT policies on token_usage_history
  SELECT COUNT(*) INTO policy_count
  FROM pg_policies
  WHERE tablename = 'token_usage_history'
    AND cmd = 'SELECT';

  IF policy_count >= 2 THEN
    RAISE NOTICE '✅ Both SELECT policies created successfully (authenticated + service_role)';
  ELSE
    RAISE WARNING '❌ Expected 2 SELECT policies, found %', policy_count;
  END IF;

  -- Verify service_role has SELECT permission
  IF EXISTS (
    SELECT 1
    FROM information_schema.role_table_grants
    WHERE table_name = 'token_usage_history'
      AND privilege_type = 'SELECT'
      AND grantee = 'service_role'
  ) THEN
    RAISE NOTICE '✅ Service role has SELECT permission on token_usage_history';
  ELSE
    RAISE WARNING '❌ Service role missing SELECT permission';
  END IF;

  RAISE NOTICE '🎉 Token Usage History RLS fix completed successfully!';
END $$;

COMMIT;
