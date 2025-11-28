-- ============================================================================
-- Migration: Unify User Plan Logic Across All Features
-- Version: 1.0
-- Date: 2025-11-28
-- Description: Updates get_user_subscription_tier() to match the authService.getUserPlan()
--              logic used in Edge Functions. This ensures consistent plan determination:
--              
--              - Anonymous users → 'free' (cannot access voice, limited tokens)
--              - Authenticated users with is_admin = true → 'premium'
--              - Authenticated users with active subscription → 'premium'
--              - Authenticated users without subscription → 'standard' (NOT 'free'!)
--              
--              This fixes the inconsistency where:
--              - Study guide generation gave authenticated users 'standard' tier
--              - Voice conversation gave authenticated users 'free' tier (blocking access)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. UPDATE GET_USER_SUBSCRIPTION_TIER TO MATCH AUTH SERVICE LOGIC
-- ============================================================================

-- Drop the existing function first
DROP FUNCTION IF EXISTS get_user_subscription_tier(UUID);

-- Create new function that matches authService.getUserPlan() logic
CREATE OR REPLACE FUNCTION get_user_subscription_tier(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_tier TEXT;
  v_is_anonymous BOOLEAN;
  v_is_admin BOOLEAN;
BEGIN
  -- Check if user is anonymous from auth.users
  SELECT 
    COALESCE(raw_app_meta_data->>'provider', '') = 'anonymous'
  INTO v_is_anonymous
  FROM auth.users
  WHERE id = p_user_id;

  -- If user not found or is anonymous, return 'free'
  IF NOT FOUND OR v_is_anonymous THEN
    RETURN 'free';
  END IF;

  -- Check if user is admin from user_profiles
  SELECT COALESCE(is_admin, FALSE)
  INTO v_is_admin
  FROM user_profiles
  WHERE id = p_user_id;

  -- Admin users get premium access
  IF v_is_admin THEN
    RETURN 'premium';
  END IF;

  -- Check for active subscription
  -- Match the authService logic: check for active, authenticated, pending_cancellation, or cancelled-but-still-active
  SELECT
    CASE
      -- Active subscriptions
      WHEN s.status IN ('active', 'authenticated', 'pending_cancellation') THEN 'premium'
      -- Cancelled but still within period
      WHEN s.status = 'cancelled' 
           AND s.cancel_at_cycle_end = TRUE 
           AND s.current_period_end > NOW() THEN 'premium'
      ELSE NULL
    END INTO v_tier
  FROM subscriptions s
  WHERE s.user_id = p_user_id
    AND s.status IN ('active', 'authenticated', 'pending_cancellation', 'cancelled')
  ORDER BY
    -- Prioritize premium subscriptions
    CASE
      WHEN s.plan_type = 'premium' THEN 1
      WHEN s.plan_type = 'standard' THEN 2
      ELSE 3
    END,
    -- Then by most recent
    s.created_at DESC
  LIMIT 1;

  -- If found an active subscription, return premium
  IF v_tier = 'premium' THEN
    RETURN 'premium';
  END IF;

  -- DEFAULT FOR AUTHENTICATED USERS: 'standard' (NOT 'free'!)
  -- This matches authService.getUserPlan() which gives authenticated users
  -- standard tier access even without a subscription
  RETURN 'standard';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_subscription_tier IS 
'Gets the subscription tier for a user matching authService.getUserPlan() logic:
- Anonymous users → free
- Authenticated admins → premium  
- Authenticated with active subscription → premium
- Authenticated without subscription → standard (NOT free!)';

-- ============================================================================
-- 2. NO CHANGES NEEDED TO CHECK_VOICE_QUOTA
-- ============================================================================
-- The check_voice_quota function already calls get_user_subscription_tier()
-- so it will automatically pick up the new logic.

COMMIT;
