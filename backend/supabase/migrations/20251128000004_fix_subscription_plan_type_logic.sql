-- ============================================================================
-- Migration: Fix Subscription Plan Type Logic
-- Version: 1.0
-- Date: 2025-11-28
--
-- SUPERSEDES: 20251128000003_unify_user_plan_logic.sql (deleted)
-- REASON: The previous migration incorrectly treated ALL active subscriptions
--         as 'premium' tier, ignoring the actual plan_type. This caused users
--         with 'standard' subscriptions to receive unlimited (premium) access.
--         This migration fixes that bug by returning the actual plan_type.
--
-- NOTE: Consider squashing migrations during a future cleanup pass if
--       migration sequence clarity is desired.
--
-- Description: Updates get_user_subscription_tier() to respect the actual
--              plan_type from subscriptions table instead of treating all
--              active subscriptions as 'premium'.
--              
--              Correct behavior:
--              - Anonymous users → 'free'
--              - Authenticated admins → 'premium'
--              - Authenticated with 'premium' subscription → 'premium' (unlimited)
--              - Authenticated with 'standard' subscription → 'standard' (10/month)
--              - Authenticated without subscription → 'standard'
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. UPDATE GET_USER_SUBSCRIPTION_TIER TO RESPECT PLAN_TYPE
-- ============================================================================

-- Drop the existing function first
DROP FUNCTION IF EXISTS get_user_subscription_tier(UUID);

-- Create new function that respects plan_type
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
    -- Prioritize premium subscriptions
    CASE
      WHEN s.plan_type = 'premium' THEN 1
      WHEN s.plan_type = 'standard' THEN 2
      ELSE 3
    END,
    -- Then by most recent
    s.created_at DESC
  LIMIT 1;

  -- If found an active subscription, return its actual plan_type
  IF v_plan_type IS NOT NULL THEN
    -- Return the actual plan_type from subscription
    -- - 'premium' subscription → 'premium' tier (unlimited)
    -- - 'standard' subscription → 'standard' tier (10/month)
    IF v_plan_type = 'premium' THEN
      RETURN 'premium';
    ELSIF v_plan_type = 'standard' THEN
      RETURN 'standard';
    END IF;
  END IF;

  -- DEFAULT FOR AUTHENTICATED USERS WITHOUT SUBSCRIPTION: 'standard'
  RETURN 'standard';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_subscription_tier IS 
'Gets the subscription tier for a user respecting actual plan_type:
- Anonymous users → free
- Authenticated admins → premium  
- Authenticated with premium subscription → premium (unlimited)
- Authenticated with standard subscription → standard (10/month)
- Authenticated without subscription → standard';

COMMIT;
