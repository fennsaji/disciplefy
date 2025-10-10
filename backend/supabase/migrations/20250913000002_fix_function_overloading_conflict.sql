-- Fix function overloading conflict
-- Migration: 20250913000002_fix_function_overloading_conflict.sql
-- Issue: Two get_or_create_user_tokens functions with different signatures cause PostgreSQL overloading conflict

-- Drop the old TEXT-based function signature
DROP FUNCTION IF EXISTS get_or_create_user_tokens(p_identifier TEXT, p_user_plan TEXT);

-- Keep only the UUID-based function (already exists from previous migration)
-- The UUID-based version is the correct one for modern authentication