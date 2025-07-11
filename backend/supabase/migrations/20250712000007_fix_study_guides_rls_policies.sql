-- Fix RLS policies for study_guides table after rename
-- Ensure Edge Functions can insert into the content cache

BEGIN;

-- First, drop all existing policies on study_guides table to start fresh
DROP POLICY IF EXISTS "Anyone can read cached content" ON study_guides;
DROP POLICY IF EXISTS "Service role can insert cached content" ON study_guides;
DROP POLICY IF EXISTS "Service role can update cached content" ON study_guides;
DROP POLICY IF EXISTS "Edge functions can manage cached content" ON study_guides;
DROP POLICY IF EXISTS "Cached content access" ON study_guides;

-- Ensure RLS is enabled on study_guides table
ALTER TABLE study_guides ENABLE ROW LEVEL SECURITY;

-- Create comprehensive policy allowing service role full access (for Edge Functions)
CREATE POLICY "Service role full access to study_guides" ON study_guides
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- Create policy allowing authenticated users to read cached content
CREATE POLICY "Users can read study_guides" ON study_guides
  FOR SELECT TO authenticated
  USING (true);

-- Create policy allowing anonymous users to read cached content
CREATE POLICY "Anonymous can read study_guides" ON study_guides
  FOR SELECT TO anon
  USING (true);

-- Create policy for public read access (covers both authenticated and anonymous)
CREATE POLICY "Public read access to study_guides" ON study_guides
  FOR SELECT
  USING (true);

-- Create policy allowing authenticated users to insert study guides (for edge functions)
CREATE POLICY "Users can insert study_guides" ON study_guides
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Create policy allowing anonymous users to insert study guides (for edge functions)
CREATE POLICY "Anonymous can insert study_guides" ON study_guides
  FOR INSERT TO anon
  WITH CHECK (true);

-- Log the policy creation
SELECT 'RLS policies for study_guides table have been updated' AS status;

COMMIT;