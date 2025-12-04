-- ============================================================================
-- Migration: Make fennsaji@gmail.com Admin
-- Version: 1.0
-- Date: 2025-11-28
-- Description: Sets is_admin = true for fennsaji@gmail.com user profile
-- ============================================================================

UPDATE user_profiles
SET is_admin = true
WHERE id = (
  SELECT id FROM auth.users WHERE email = 'fennsaji@gmail.com'
);
