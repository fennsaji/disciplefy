-- Fix RLS policies for study_guides_cache table
-- Edge Functions need INSERT permissions for caching

BEGIN;

-- Add INSERT policy for study_guides_cache to allow Edge Functions to insert
CREATE POLICY "Service role can insert cached content" ON study_guides_cache
  FOR INSERT TO service_role
  WITH CHECK (true);

-- Add UPDATE policy for study_guides_cache to allow Edge Functions to update
CREATE POLICY "Service role can update cached content" ON study_guides_cache
  FOR UPDATE TO service_role
  USING (true);

-- Allow authenticated users to also insert/update through service role
CREATE POLICY "Edge functions can manage cached content" ON study_guides_cache
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- Drop the restrictive policy and create a more permissive one
DROP POLICY IF EXISTS "Anyone can read cached content" ON study_guides_cache;

-- Create comprehensive policy for cached content
CREATE POLICY "Cached content access" ON study_guides_cache
  FOR ALL USING (true)
  WITH CHECK (true);

COMMIT;