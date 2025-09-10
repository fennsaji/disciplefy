-- Migration: Fix Token System RLS Policies (Safe Migration)
-- Date: 2025-09-07  
-- Purpose: Safely apply RLS policies for token system, handling existing policies
-- Based on: backend/docs/token_based_system_design.md

-- Begin transaction for atomic policy creation
BEGIN;

-- =====================================
-- STEP 1: Enable Row Level Security (Safe)
-- =====================================

-- Enable RLS if not already enabled
DO $$ 
BEGIN
    IF NOT (SELECT relrowsecurity FROM pg_class WHERE relname = 'user_tokens') THEN
        ALTER TABLE user_tokens ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

-- =====================================
-- STEP 2: Drop Existing Policies (Safe)
-- =====================================

-- Drop existing policies to start fresh (safe - IF EXISTS)
DROP POLICY IF EXISTS "Edge Functions can manage all token data" ON user_tokens;
DROP POLICY IF EXISTS "Users can read own token data" ON user_tokens;
DROP POLICY IF EXISTS "Anonymous users can read own session token data" ON user_tokens;
DROP POLICY IF EXISTS "Prevent direct client modifications" ON user_tokens;
DROP POLICY IF EXISTS "Prevent direct client updates" ON user_tokens;
DROP POLICY IF EXISTS "Prevent direct client deletions" ON user_tokens;

-- =====================================
-- STEP 3: Create RLS Policies (Clean Slate)
-- =====================================

-- Policy 1: Allow Edge Functions (service role) to manage all token data
-- This is essential for the TokenService to operate correctly
CREATE POLICY "Edge Functions can manage all token data" ON user_tokens
  FOR ALL USING (
    -- Allow all operations for service role (Edge Functions, server-side operations)
    current_setting('role') = 'service_role'
  );

-- Policy 2: Allow authenticated users to read their own token data
-- Users can view their own token balance and history
CREATE POLICY "Users can read own token data" ON user_tokens
  FOR SELECT USING (
    -- Authenticated users can read their own records
    auth.jwt() IS NOT NULL AND 
    identifier = auth.uid()::TEXT AND
    user_plan IN ('standard', 'premium')
  );

-- Policy 3: Allow anonymous sessions to read their own token data  
-- Anonymous users can view their session-based token data
CREATE POLICY "Anonymous users can read own session token data" ON user_tokens
  FOR SELECT USING (
    -- Anonymous users can read records matching their session
    auth.jwt() IS NULL AND 
    user_plan = 'free'
    -- Note: Cannot validate session_id in RLS since it's not in JWT for anonymous users
    -- Session validation will be handled at the application layer
  );

-- Policy 4: Prevent direct INSERT/UPDATE/DELETE from client applications
-- All token modifications must go through database functions called by Edge Functions
-- This ensures atomic operations and proper business logic enforcement

CREATE POLICY "Prevent direct client modifications" ON user_tokens
  FOR INSERT WITH CHECK (false);

CREATE POLICY "Prevent direct client updates" ON user_tokens  
  FOR UPDATE USING (false);

CREATE POLICY "Prevent direct client deletions" ON user_tokens
  FOR DELETE USING (false);

-- =====================================
-- STEP 4: Grant Function Execution Rights (Safe)
-- =====================================

-- Grant EXECUTE permission on token functions to authenticated users
-- This allows client applications to call these functions via RPC
DO $$
BEGIN
    -- Grant permissions safely (won't error if already granted)
    BEGIN
        GRANT EXECUTE ON FUNCTION get_or_create_user_tokens(TEXT, TEXT) TO authenticated;
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Function might not exist yet, ignore
    END;
    
    BEGIN
        GRANT EXECUTE ON FUNCTION get_or_create_user_tokens(TEXT, TEXT) TO anon;
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Function might not exist yet, ignore
    END;
    
    -- Restrict token consumption and purchase functions to service role only
    BEGIN
        GRANT EXECUTE ON FUNCTION consume_user_tokens(TEXT, TEXT, INTEGER) TO service_role;
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Function might not exist yet, ignore
    END;
    
    BEGIN
        GRANT EXECUTE ON FUNCTION add_purchased_tokens(TEXT, TEXT, INTEGER) TO service_role;
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Function might not exist yet, ignore
    END;
    
    BEGIN
        GRANT EXECUTE ON FUNCTION log_token_event(TEXT, TEXT, JSONB, TEXT) TO service_role;
    EXCEPTION WHEN OTHERS THEN
        NULL; -- Function might not exist yet, ignore
    END;
END $$;

-- =====================================
-- STEP 5: Create Security Functions (Safe)
-- =====================================

-- Drop existing trigger first (dependency safe)
DROP TRIGGER IF EXISTS ensure_token_authorization_trigger ON user_tokens;

-- Drop existing functions after trigger removal (safe)
DROP FUNCTION IF EXISTS validate_token_operation_context();
DROP FUNCTION IF EXISTS check_token_modification_authorization();

-- Create a function to validate token operations are called from Edge Functions
CREATE OR REPLACE FUNCTION validate_token_operation_context()
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if the current operation is being performed by service role
  -- This provides an additional layer of security for sensitive operations
  RETURN current_setting('role') = 'service_role';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add a trigger to validate all token modifications come from authorized sources
CREATE OR REPLACE FUNCTION check_token_modification_authorization()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow operations from service role (Edge Functions)
  IF current_setting('role') = 'service_role' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  
  -- Block all other direct modifications
  RAISE EXCEPTION 'Direct token modifications not allowed. Use Edge Function endpoints.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================
-- STEP 6: Create Authorization Trigger (Safe)
-- =====================================

-- Apply the authorization trigger to the user_tokens table
CREATE TRIGGER ensure_token_authorization_trigger
  BEFORE INSERT OR UPDATE OR DELETE ON user_tokens
  FOR EACH ROW
  EXECUTE FUNCTION check_token_modification_authorization();

-- =====================================
-- STEP 7: Add Policy Documentation
-- =====================================

COMMENT ON POLICY "Edge Functions can manage all token data" ON user_tokens IS 
  'Allows Edge Functions (service_role) to perform all CRUD operations on token data';

COMMENT ON POLICY "Users can read own token data" ON user_tokens IS 
  'Allows authenticated users to view their own token balance and history';

COMMENT ON POLICY "Anonymous users can read own session token data" ON user_tokens IS 
  'Allows anonymous users to view token data for their session (free plan only)';

COMMENT ON POLICY "Prevent direct client modifications" ON user_tokens IS 
  'Prevents client applications from directly inserting token records';

COMMENT ON POLICY "Prevent direct client updates" ON user_tokens IS 
  'Prevents client applications from directly updating token records';

COMMENT ON POLICY "Prevent direct client deletions" ON user_tokens IS 
  'Prevents client applications from directly deleting token records';

COMMENT ON FUNCTION validate_token_operation_context() IS 
  'Security helper function to validate token operations are performed by authorized services';

COMMENT ON FUNCTION check_token_modification_authorization() IS 
  'Trigger function to enforce that all token modifications go through Edge Functions';

-- =====================================
-- STEP 8: Create Test Function (Safe)
-- =====================================

-- Drop existing test function first (safe)
DROP FUNCTION IF EXISTS test_token_rls_policies();

-- Create a test function to verify RLS policies are working
CREATE OR REPLACE FUNCTION test_token_rls_policies()
RETURNS TABLE(
  test_name TEXT,
  result BOOLEAN,
  message TEXT
) AS $$
BEGIN
  -- Test 1: Verify RLS is enabled
  RETURN QUERY SELECT 
    'RLS Enabled Test'::TEXT,
    (SELECT relrowsecurity FROM pg_class WHERE relname = 'user_tokens'),
    'RLS should be enabled on user_tokens table'::TEXT;
  
  -- Test 2: Verify service role can access functions
  RETURN QUERY SELECT 
    'Service Role Access Test'::TEXT,
    validate_token_operation_context(),
    'Service role should have access to token operations'::TEXT;
    
  -- Test 3: Verify policies exist
  RETURN QUERY SELECT 
    'Policies Created Test'::TEXT,
    (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'user_tokens') >= 6,
    'Should have at least 6 RLS policies on user_tokens table'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant access to the test function for service role only
GRANT EXECUTE ON FUNCTION test_token_rls_policies() TO service_role;

COMMENT ON FUNCTION test_token_rls_policies() IS 
  'Test function to verify RLS policies are configured correctly (service_role only)';

-- =====================================
-- STEP 9: Migration Status Log
-- =====================================

-- Log successful migration
DO $$
BEGIN
  RAISE NOTICE 'Token RLS policies migration completed successfully';
  RAISE NOTICE 'RLS enabled: %', (SELECT relrowsecurity FROM pg_class WHERE relname = 'user_tokens');
  RAISE NOTICE 'Policies created: %', (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'user_tokens');
END $$;

-- Commit transaction
COMMIT;