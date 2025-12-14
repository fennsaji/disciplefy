-- ============================================================================
-- Migration: Add Standard Subscription Trial System
-- Version: 1.0
-- Date: 2025-12-06
--
-- Description: 
-- Implements Standard plan subscription with trial period until March 31st, 2025.
-- After trial ends, Standard users must subscribe at Rs.50/month.
-- Includes 7-day grace period before downgrade to Free.
--
-- Changes:
-- 1. Add subscription_plan column to properly distinguish standard/premium
-- 2. Add index for plan-based queries
-- 3. Update get_user_plan_with_subscription to handle Standard trial
-- 4. Create is_standard_trial_active() helper function
-- 5. Create get_subscription_status() function for frontend
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ADD SUBSCRIPTION_PLAN COLUMN (distinct from plan_type which is legacy)
-- ============================================================================

-- Add subscription_plan column if it doesn't exist
-- This column stores 'standard' or 'premium' to distinguish plan types
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'subscriptions' 
    AND column_name = 'subscription_plan'
  ) THEN
    ALTER TABLE public.subscriptions
    ADD COLUMN subscription_plan TEXT DEFAULT 'premium'
    CHECK (subscription_plan IN ('standard', 'premium'));
    
    -- Update existing subscriptions to premium (they're all premium currently)
    UPDATE public.subscriptions SET subscription_plan = 'premium' WHERE subscription_plan IS NULL;
  END IF;
END $$;

-- Add index for subscription_plan queries
CREATE INDEX IF NOT EXISTS idx_subscriptions_subscription_plan
ON public.subscriptions(subscription_plan);

COMMENT ON COLUMN subscriptions.subscription_plan IS 'Subscription plan type: standard (Rs.50/mo) or premium (Rs.100/mo)';

-- ============================================================================
-- 2. STANDARD TRIAL PERIOD CONFIGURATION
-- ============================================================================

-- Create a configuration table for subscription settings (if not exists)
CREATE TABLE IF NOT EXISTS subscription_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert trial end date configuration
INSERT INTO subscription_config (key, value, description)
VALUES (
  'standard_trial_end_date',
  '2025-03-31T23:59:59+05:30',
  'Standard plan trial period end date. All Standard users get free access until this date.'
)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

INSERT INTO subscription_config (key, value, description)
VALUES (
  'grace_period_days',
  '7',
  'Number of days users keep access after subscription cancellation/failure'
)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- ============================================================================
-- 3. HELPER FUNCTION: CHECK IF STANDARD TRIAL IS ACTIVE
-- ============================================================================

CREATE OR REPLACE FUNCTION public.is_standard_trial_active()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_trial_end_date TIMESTAMPTZ;
BEGIN
  -- Get trial end date from config
  SELECT value::TIMESTAMPTZ INTO v_trial_end_date
  FROM subscription_config
  WHERE key = 'standard_trial_end_date';
  
  -- Default to March 31, 2025 if not configured
  IF v_trial_end_date IS NULL THEN
    v_trial_end_date := '2025-03-31T23:59:59+05:30'::TIMESTAMPTZ;
  END IF;
  
  RETURN NOW() <= v_trial_end_date;
END;
$$;

COMMENT ON FUNCTION public.is_standard_trial_active() IS 
'Returns true if the Standard plan trial period is still active (before March 31, 2025)';

-- ============================================================================
-- 4. HELPER FUNCTION: GET DAYS UNTIL TRIAL END
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_days_until_trial_end()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_trial_end_date TIMESTAMPTZ;
  v_days INTEGER;
BEGIN
  -- Get trial end date from config
  SELECT value::TIMESTAMPTZ INTO v_trial_end_date
  FROM subscription_config
  WHERE key = 'standard_trial_end_date';
  
  -- Default to March 31, 2025 if not configured
  IF v_trial_end_date IS NULL THEN
    v_trial_end_date := '2025-03-31T23:59:59+05:30'::TIMESTAMPTZ;
  END IF;
  
  -- Calculate total days difference using epoch (total seconds / 86400)
  v_days := CEIL(EXTRACT(EPOCH FROM (v_trial_end_date - NOW())) / 86400)::INTEGER;

  RETURN GREATEST(0, v_days);
END;
$$;

COMMENT ON FUNCTION public.get_days_until_trial_end() IS 
'Returns number of days until Standard trial ends (0 if already ended)';

-- ============================================================================
-- 5. UPDATE GET_USER_PLAN_WITH_SUBSCRIPTION FOR TRIAL LOGIC
-- ============================================================================

-- Drop existing function to recreate with new logic
DROP FUNCTION IF EXISTS public.get_user_plan_with_subscription(UUID);

CREATE OR REPLACE FUNCTION public.get_user_plan_with_subscription(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_plan_from_prefs TEXT;
  v_has_premium_subscription BOOLEAN;
  v_has_standard_subscription BOOLEAN;
  v_trial_active BOOLEAN;
  v_grace_period_days INTEGER;
  v_in_grace_period BOOLEAN;
BEGIN
  -- Check if admin (admins always get premium)
  SELECT COALESCE(is_admin, FALSE) INTO v_is_admin
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_is_admin THEN
    RETURN 'premium';
  END IF;

  -- Get user's preferred plan from preferences
  SELECT preferred_plan INTO v_plan_from_prefs
  FROM user_preferences
  WHERE user_id = p_user_id;

  -- Check for active premium subscription
  SELECT EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE user_id = p_user_id
    AND subscription_plan = 'premium'
    AND status IN ('active', 'authenticated', 'created', 'pending_cancellation')
  ) INTO v_has_premium_subscription;

  IF v_has_premium_subscription THEN
    RETURN 'premium';
  END IF;

  -- Check if Standard trial is active
  v_trial_active := is_standard_trial_active();

  -- If user prefers premium but has no premium subscription
  IF v_plan_from_prefs = 'premium' THEN
    -- Fall back to standard if trial active or has standard subscription
    SELECT EXISTS (
      SELECT 1 FROM public.subscriptions
      WHERE user_id = p_user_id
      AND subscription_plan = 'standard'
      AND status IN ('active', 'authenticated', 'created', 'pending_cancellation')
    ) INTO v_has_standard_subscription;

    IF v_has_standard_subscription OR v_trial_active THEN
      RETURN 'standard';
    ELSE
      RETURN 'free';
    END IF;
  END IF;

  -- If user prefers standard
  IF v_plan_from_prefs = 'standard' THEN
    -- During trial period, all standard users get access
    IF v_trial_active THEN
      RETURN 'standard';
    END IF;

    -- After trial, check for active standard subscription
    SELECT EXISTS (
      SELECT 1 FROM public.subscriptions
      WHERE user_id = p_user_id
      AND subscription_plan = 'standard'
      AND status IN ('active', 'authenticated', 'created', 'pending_cancellation')
    ) INTO v_has_standard_subscription;

    IF v_has_standard_subscription THEN
      RETURN 'standard';
    END IF;

    -- Check grace period (7 days after subscription cancelled)
    SELECT COALESCE(value::INTEGER, 7) INTO v_grace_period_days
    FROM subscription_config
    WHERE key = 'grace_period_days';

    SELECT EXISTS (
      SELECT 1 FROM public.subscriptions
      WHERE user_id = p_user_id
      AND subscription_plan = 'standard'
      AND status = 'cancelled'
      AND updated_at >= NOW() - (v_grace_period_days || ' days')::INTERVAL
    ) INTO v_in_grace_period;

    IF v_in_grace_period THEN
      RETURN 'standard';  -- Still in grace period
    END IF;

    -- No subscription and trial ended - downgrade to free
    RETURN 'free';
  END IF;

  -- Default: return preferred plan or 'free'
  RETURN COALESCE(v_plan_from_prefs, 'free');
END;
$$;

COMMENT ON FUNCTION public.get_user_plan_with_subscription(UUID) IS 
'Returns user effective plan considering:
- Admin status (always premium)
- Active premium subscription
- Standard trial period (free until March 31, 2025)
- Active standard subscription (Rs.50/month after trial)
- Grace period (7 days after cancellation)
- Preferred plan from user preferences';

-- ============================================================================
-- 6. CREATE GET_SUBSCRIPTION_STATUS FOR FRONTEND
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_subscription_status(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_plan TEXT;
  v_subscription RECORD;
  v_trial_active BOOLEAN;
  v_days_until_trial_end INTEGER;
  v_grace_period_days INTEGER;
  v_in_grace_period BOOLEAN;
  v_grace_days_remaining INTEGER;
BEGIN
  -- Get current effective plan
  v_current_plan := get_user_plan_with_subscription(p_user_id);
  
  -- Get trial status
  v_trial_active := is_standard_trial_active();
  v_days_until_trial_end := get_days_until_trial_end();
  
  -- Get grace period config
  SELECT COALESCE(value::INTEGER, 7) INTO v_grace_period_days
  FROM subscription_config
  WHERE key = 'grace_period_days';

  -- Get active subscription if any
  SELECT * INTO v_subscription
  FROM public.subscriptions
  WHERE user_id = p_user_id
  AND status IN ('active', 'authenticated', 'created', 'pending_cancellation')
  ORDER BY 
    CASE subscription_plan WHEN 'premium' THEN 1 ELSE 2 END,
    created_at DESC
  LIMIT 1;

  -- Check if in grace period (for cancelled subscriptions)
  SELECT EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE user_id = p_user_id
    AND status = 'cancelled'
    AND updated_at >= NOW() - (v_grace_period_days || ' days')::INTERVAL
  ) INTO v_in_grace_period;

  -- Calculate grace days remaining if applicable
  IF v_in_grace_period THEN
    SELECT v_grace_period_days - FLOOR(EXTRACT(EPOCH FROM (NOW() - updated_at)) / 86400)::INTEGER
    INTO v_grace_days_remaining
    FROM public.subscriptions
    WHERE user_id = p_user_id
    AND status = 'cancelled'
    ORDER BY updated_at DESC
    LIMIT 1;

    v_grace_days_remaining := GREATEST(0, v_grace_days_remaining);
  END IF;

  RETURN jsonb_build_object(
    'current_plan', v_current_plan,
    'is_trial_active', v_trial_active,
    'days_until_trial_end', v_days_until_trial_end,
    'trial_end_date', '2025-03-31',
    'has_subscription', v_subscription IS NOT NULL,
    'subscription_plan', v_subscription.subscription_plan,
    'subscription_status', v_subscription.status,
    'subscription_id', v_subscription.id,
    'current_period_end', v_subscription.current_period_end,
    'next_billing_at', v_subscription.next_billing_at,
    'cancel_at_cycle_end', v_subscription.cancel_at_cycle_end,
    'in_grace_period', v_in_grace_period,
    'grace_days_remaining', v_grace_days_remaining
  );
END;
$$;

COMMENT ON FUNCTION public.get_subscription_status(UUID) IS 
'Returns comprehensive subscription status for frontend including:
- Current effective plan
- Trial status and days remaining
- Active subscription details
- Grace period status';

-- ============================================================================
-- 7. UPDATE GET_USER_SUBSCRIPTION_TIER TO USE NEW LOGIC
-- ============================================================================

-- Drop and recreate to use the new plan logic
DROP FUNCTION IF EXISTS get_user_subscription_tier(UUID);

CREATE OR REPLACE FUNCTION get_user_subscription_tier(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_is_anonymous BOOLEAN;
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

  -- Use the comprehensive plan logic
  RETURN get_user_plan_with_subscription(p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_subscription_tier IS 
'Gets the subscription tier for a user:
- Anonymous users → free
- Authenticated users → uses get_user_plan_with_subscription logic';

-- ============================================================================
-- 8. CREATE FUNCTION TO CHECK IF USER NEEDS SUBSCRIPTION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.user_needs_standard_subscription(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_plan_from_prefs TEXT;
  v_trial_active BOOLEAN;
  v_has_subscription BOOLEAN;
BEGIN
  -- Get user's preferred plan
  SELECT preferred_plan INTO v_plan_from_prefs
  FROM user_preferences
  WHERE user_id = p_user_id;

  -- Only applies to users who selected Standard plan
  IF v_plan_from_prefs != 'standard' THEN
    RETURN FALSE;
  END IF;

  -- Check if trial is still active
  v_trial_active := is_standard_trial_active();
  
  -- If trial is active, no subscription needed yet
  IF v_trial_active THEN
    RETURN FALSE;
  END IF;

  -- Check for active subscription
  SELECT EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE user_id = p_user_id
    AND subscription_plan = 'standard'
    AND status IN ('active', 'authenticated', 'created', 'pending_cancellation')
  ) INTO v_has_subscription;

  -- Needs subscription if trial ended and no active subscription
  RETURN NOT v_has_subscription;
END;
$$;

COMMENT ON FUNCTION public.user_needs_standard_subscription(UUID) IS 
'Returns true if user selected Standard plan, trial has ended, and has no active subscription';

COMMIT;
