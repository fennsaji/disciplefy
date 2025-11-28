-- ============================================================================
-- Migration: Fix Voice Quota to Use Monthly Calculation
-- Version: 1.0
-- Date: 2025-11-28
-- Description: Updates check_voice_quota() to calculate monthly usage instead
--              of daily usage to match the Edge Function behavior.
--              This fixes the sync issue between frontend display and backend
--              enforcement where:
--              - Frontend was showing daily quota (3/10 per day)
--              - Backend Edge Function was enforcing monthly quota (10 per month)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. UPDATE CHECK_VOICE_QUOTA TO USE MONTHLY CALCULATION
-- ============================================================================

-- Drop the existing function first
DROP FUNCTION IF EXISTS check_voice_quota();

-- Create new function that calculates MONTHLY quota (matching Edge Function)
CREATE OR REPLACE FUNCTION check_voice_quota()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_tier TEXT;
  v_quota_limit INTEGER;
  v_monthly_usage INTEGER;
  v_can_start BOOLEAN;
  v_month_start DATE;
  v_month_end DATE;
BEGIN
  -- Get current user ID from auth context
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'User not authenticated',
      'can_start', false,
      'quota_limit', 0,
      'quota_used', 0,
      'quota_remaining', 0,
      'tier', 'free'
    );
  END IF;

  -- Get user's subscription tier
  v_tier := get_user_subscription_tier(v_user_id);

  -- Determine MONTHLY quota based on tier
  -- These limits match the Edge Function (voice-conversation/index.ts lines 26-31)
  v_quota_limit := CASE
    WHEN v_tier = 'free' THEN 0      -- Free users cannot access voice conversations
    WHEN v_tier = 'standard' THEN 10  -- 10 per month
    WHEN v_tier = 'premium' THEN -1   -- Unlimited (represented as -1)
    ELSE 0
  END;

  -- Calculate current month boundaries
  v_month_start := DATE_TRUNC('month', CURRENT_DATE)::DATE;
  v_month_end := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

  -- Sum up all usage for the current month (matching Edge Function lines 122-131)
  SELECT COALESCE(SUM(daily_quota_used), 0) INTO v_monthly_usage
  FROM voice_usage_tracking
  WHERE user_id = v_user_id
    AND usage_date >= v_month_start
    AND usage_date <= v_month_end;

  -- Check if can start new conversation
  -- Premium users (limit = -1) can always start
  -- Free users (limit = 0) can never start
  -- Standard users check against monthly limit
  v_can_start := CASE
    WHEN v_quota_limit = -1 THEN TRUE  -- Premium: unlimited
    WHEN v_quota_limit = 0 THEN FALSE  -- Free: not available
    ELSE v_monthly_usage < v_quota_limit
  END;

  -- Ensure today's tracking record exists (for increment_voice_usage to work)
  INSERT INTO voice_usage_tracking (user_id, tier_at_time, daily_quota_limit, daily_quota_used)
  VALUES (v_user_id, v_tier, v_quota_limit, 0)
  ON CONFLICT (user_id, usage_date) DO NOTHING;

  RETURN jsonb_build_object(
    'can_start', v_can_start,
    'quota_limit', CASE WHEN v_quota_limit = -1 THEN 999999 ELSE v_quota_limit END,
    'quota_used', v_monthly_usage,
    'quota_remaining', CASE 
      WHEN v_quota_limit = -1 THEN 999999  -- Premium: show as unlimited
      ELSE GREATEST(0, v_quota_limit - v_monthly_usage)
    END,
    'tier', v_tier
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION check_voice_quota() IS 'Checks if authenticated user can start a new voice conversation based on MONTHLY tier quota. Free=0/month, Standard=10/month, Premium=unlimited';

-- ============================================================================
-- 2. UPDATE INCREMENT_VOICE_USAGE TO ALSO TRACK MONTHLY CONTEXT
-- ============================================================================

-- The existing increment_voice_usage function is fine as it tracks daily usage
-- which is then summed for monthly calculation. No changes needed.

COMMIT;
