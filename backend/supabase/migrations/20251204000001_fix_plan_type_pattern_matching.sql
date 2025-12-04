-- ============================================================================
-- Migration: Fix Plan Type Pattern Matching
-- Version: 1.0
-- Date: 2025-12-04
--
-- Description: Updates get_user_subscription_tier() to recognize plan_type
--              variants like 'premium_monthly', 'premium_yearly',
--              'standard_monthly', etc. The previous implementation only
--              matched exact 'premium' or 'standard' strings.
--
--              Correct behavior:
--              - 'premium', 'premium_monthly', 'premium_yearly' → 'premium'
--              - 'standard', 'standard_monthly', 'standard_yearly' → 'standard'
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. UPDATE GET_USER_SUBSCRIPTION_TIER TO USE PATTERN MATCHING
-- ============================================================================

-- Drop the existing function first
DROP FUNCTION IF EXISTS get_user_subscription_tier(UUID);

-- Create new function that uses pattern matching for plan_type
CREATE OR REPLACE FUNCTION get_user_subscription_tier(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_tier TEXT;
  v_is_anonymous BOOLEAN;
  v_is_admin BOOLEAN;
  v_plan_type TEXT;
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

  -- Check for active subscription and get actual plan_type
  SELECT s.plan_type INTO v_plan_type
  FROM subscriptions s
  WHERE s.user_id = p_user_id
    AND (
      -- Active subscriptions
      s.status IN ('active', 'authenticated', 'pending_cancellation')
      OR
      -- Cancelled but still within period
      (s.status = 'cancelled'
       AND s.cancel_at_cycle_end = TRUE
       AND s.current_period_end > NOW())
    )
  ORDER BY
    -- Prioritize premium subscriptions (using pattern match)
    CASE
      WHEN s.plan_type LIKE 'premium%' THEN 1
      WHEN s.plan_type LIKE 'standard%' THEN 2
      ELSE 3
    END,
    -- Then by most recent
    s.created_at DESC
  LIMIT 1;

  -- If found an active subscription, return its tier based on plan_type pattern
  IF v_plan_type IS NOT NULL THEN
    -- Match plan_type patterns:
    -- - 'premium', 'premium_monthly', 'premium_yearly' → 'premium' (unlimited)
    -- - 'standard', 'standard_monthly', 'standard_yearly' → 'standard' (10/month)
    IF v_plan_type LIKE 'premium%' THEN
      RETURN 'premium';
    ELSIF v_plan_type LIKE 'standard%' THEN
      RETURN 'standard';
    END IF;
  END IF;

  -- DEFAULT FOR AUTHENTICATED USERS WITHOUT SUBSCRIPTION: 'standard'
  RETURN 'standard';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_subscription_tier IS
'Gets the subscription tier for a user using pattern matching for plan_type:
- Anonymous users → free
- Authenticated admins → premium
- Authenticated with premium* subscription → premium (unlimited)
- Authenticated with standard* subscription → standard (10/month)
- Authenticated without subscription → standard';

COMMIT;
