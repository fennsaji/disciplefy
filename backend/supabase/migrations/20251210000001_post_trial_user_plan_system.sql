-- ============================================================================
-- Migration: Post-Trial User Plan System
-- Description: Implements user plan logic for after the Standard trial ends
--              on March 31, 2025, including 7-day grace period support.
-- ============================================================================

-- ============================================================================
-- 1. Create subscription_config table for trial/grace period settings
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.subscription_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.subscription_config ENABLE ROW LEVEL SECURITY;

-- Allow read access for authenticated users
CREATE POLICY "subscription_config_read_policy" ON public.subscription_config
  FOR SELECT TO authenticated USING (true);

-- Allow read access for anon users
CREATE POLICY "subscription_config_anon_read_policy" ON public.subscription_config
  FOR SELECT TO anon USING (true);

-- Insert configuration values
INSERT INTO public.subscription_config (key, value, description) VALUES
  ('standard_trial_end_date', '2025-03-31T23:59:59+05:30', 'End date for Standard plan free trial period'),
  ('grace_period_days', '7', 'Number of days grace period after trial ends'),
  ('grace_period_end_date', '2025-04-07T23:59:59+05:30', 'End date for grace period after trial ends')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- ============================================================================
-- 2. Create user_preferences table for plan tracking
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  preferred_plan TEXT DEFAULT 'standard' CHECK (preferred_plan IN ('free', 'standard', 'premium')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- Users can only read their own preferences
CREATE POLICY "user_preferences_select_own" ON public.user_preferences
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- Users can insert their own preferences
CREATE POLICY "user_preferences_insert_own" ON public.user_preferences
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own preferences
CREATE POLICY "user_preferences_update_own" ON public.user_preferences
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_user_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_preferences_updated_at_trigger
  BEFORE UPDATE ON public.user_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_user_preferences_updated_at();

-- ============================================================================
-- 3. Helper Functions for Trial/Grace Period Logic
-- ============================================================================

-- Get the standard trial end date from config
CREATE OR REPLACE FUNCTION get_standard_trial_end_date()
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trial_end_date TIMESTAMPTZ;
BEGIN
  SELECT value::TIMESTAMPTZ INTO v_trial_end_date
  FROM subscription_config
  WHERE key = 'standard_trial_end_date';

  -- Fallback to hardcoded date if config not found
  RETURN COALESCE(v_trial_end_date, '2025-03-31T23:59:59+05:30'::TIMESTAMPTZ);
END;
$$;

-- Get the grace period end date from config
CREATE OR REPLACE FUNCTION get_grace_period_end_date()
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_grace_end_date TIMESTAMPTZ;
BEGIN
  SELECT value::TIMESTAMPTZ INTO v_grace_end_date
  FROM subscription_config
  WHERE key = 'grace_period_end_date';

  -- Fallback to hardcoded date if config not found
  RETURN COALESCE(v_grace_end_date, '2025-04-07T23:59:59+05:30'::TIMESTAMPTZ);
END;
$$;

-- Check if Standard trial is currently active (before March 31, 2025)
CREATE OR REPLACE FUNCTION is_standard_trial_active()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN NOW() <= get_standard_trial_end_date();
END;
$$;

-- Check if we're in the grace period (April 1-7, 2025)
CREATE OR REPLACE FUNCTION is_in_grace_period()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trial_end TIMESTAMPTZ;
  v_grace_end TIMESTAMPTZ;
BEGIN
  v_trial_end := get_standard_trial_end_date();
  v_grace_end := get_grace_period_end_date();

  RETURN NOW() > v_trial_end AND NOW() <= v_grace_end;
END;
$$;

-- Get days remaining until trial ends
CREATE OR REPLACE FUNCTION get_days_until_trial_end()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trial_end TIMESTAMPTZ;
  v_diff INTEGER;
BEGIN
  v_trial_end := get_standard_trial_end_date();
  v_diff := EXTRACT(DAY FROM (v_trial_end - NOW()));
  RETURN GREATEST(0, v_diff);
END;
$$;

-- Get days remaining in grace period
CREATE OR REPLACE FUNCTION get_grace_days_remaining()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trial_end TIMESTAMPTZ;
  v_grace_end TIMESTAMPTZ;
  v_diff INTEGER;
BEGIN
  v_trial_end := get_standard_trial_end_date();
  v_grace_end := get_grace_period_end_date();

  -- If still in trial, return full grace period days
  IF NOW() <= v_trial_end THEN
    RETURN 7;
  END IF;

  -- If after grace period, return 0
  IF NOW() > v_grace_end THEN
    RETURN 0;
  END IF;

  -- Calculate remaining days in grace period
  v_diff := CEIL(EXTRACT(EPOCH FROM (v_grace_end - NOW())) / 86400);
  RETURN GREATEST(0, v_diff);
END;
$$;

-- Check if user was eligible for trial (signed up before March 31, 2025)
CREATE OR REPLACE FUNCTION was_eligible_for_trial(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_created_at TIMESTAMPTZ;
  v_trial_end TIMESTAMPTZ;
BEGIN
  -- Get user creation date from user_profiles
  SELECT created_at INTO v_user_created_at
  FROM user_profiles
  WHERE id = p_user_id;

  -- If no profile found, check auth.users
  IF v_user_created_at IS NULL THEN
    SELECT created_at INTO v_user_created_at
    FROM auth.users
    WHERE id = p_user_id;
  END IF;

  -- If still no date found, assume not eligible (new user)
  IF v_user_created_at IS NULL THEN
    RETURN FALSE;
  END IF;

  v_trial_end := get_standard_trial_end_date();
  RETURN v_user_created_at <= v_trial_end;
END;
$$;

-- Get user creation date
CREATE OR REPLACE FUNCTION get_user_created_at(p_user_id UUID)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_created_at TIMESTAMPTZ;
BEGIN
  -- First try user_profiles
  SELECT created_at INTO v_created_at
  FROM user_profiles
  WHERE id = p_user_id;

  -- Fallback to auth.users
  IF v_created_at IS NULL THEN
    SELECT created_at INTO v_created_at
    FROM auth.users
    WHERE id = p_user_id;
  END IF;

  RETURN v_created_at;
END;
$$;

-- ============================================================================
-- 4. Updated get_user_plan_with_subscription function
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_plan_with_subscription(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_has_premium_subscription BOOLEAN;
  v_has_standard_subscription BOOLEAN;
  v_trial_active BOOLEAN;
  v_in_grace_period BOOLEAN;
  v_was_eligible BOOLEAN;
BEGIN
  -- 1. Check if user is admin
  SELECT COALESCE(is_admin, FALSE) INTO v_is_admin
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_is_admin THEN
    RETURN 'premium';
  END IF;

  -- 2. Check for active premium subscription
  SELECT EXISTS(
    SELECT 1 FROM subscriptions
    WHERE user_id = p_user_id
      AND status IN ('active', 'authenticated', 'pending_cancellation')
      AND plan_type LIKE 'premium%'
  ) INTO v_has_premium_subscription;

  IF v_has_premium_subscription THEN
    RETURN 'premium';
  END IF;

  -- 3. Check for active standard subscription
  SELECT EXISTS(
    SELECT 1 FROM subscriptions
    WHERE user_id = p_user_id
      AND status IN ('active', 'authenticated', 'pending_cancellation')
      AND plan_type LIKE 'standard%'
  ) INTO v_has_standard_subscription;

  IF v_has_standard_subscription THEN
    RETURN 'standard';
  END IF;

  -- 4. Check if trial is still active (before March 31, 2025)
  v_trial_active := is_standard_trial_active();
  IF v_trial_active THEN
    RETURN 'standard';
  END IF;

  -- 5. Check trial eligibility (signed up before March 31)
  v_was_eligible := was_eligible_for_trial(p_user_id);

  IF v_was_eligible THEN
    -- 6. Check if in grace period (April 1-7, 2025)
    v_in_grace_period := is_in_grace_period();
    IF v_in_grace_period THEN
      RETURN 'standard';
    END IF;

    -- Trial eligible but grace period ended, no subscription
    RETURN 'free';
  END IF;

  -- 7. New user (signed up after March 31) - free plan
  RETURN 'free';
END;
$$;

-- ============================================================================
-- 5. Updated get_subscription_status function with grace period info
-- ============================================================================

CREATE OR REPLACE FUNCTION get_subscription_status(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSONB;
  v_current_plan TEXT;
  v_trial_active BOOLEAN;
  v_in_grace_period BOOLEAN;
  v_days_until_trial_end INTEGER;
  v_grace_days_remaining INTEGER;
  v_was_eligible BOOLEAN;
  v_user_created_at TIMESTAMPTZ;
  v_subscription RECORD;
BEGIN
  -- Get computed values
  v_current_plan := get_user_plan_with_subscription(p_user_id);
  v_trial_active := is_standard_trial_active();
  v_in_grace_period := is_in_grace_period();
  v_days_until_trial_end := get_days_until_trial_end();
  v_grace_days_remaining := get_grace_days_remaining();
  v_was_eligible := was_eligible_for_trial(p_user_id);
  v_user_created_at := get_user_created_at(p_user_id);

  -- Get active subscription if any
  SELECT * INTO v_subscription
  FROM subscriptions
  WHERE user_id = p_user_id
    AND status IN ('active', 'authenticated', 'pending_cancellation', 'created')
  ORDER BY created_at DESC
  LIMIT 1;

  -- Build result JSON
  v_result := jsonb_build_object(
    'current_plan', v_current_plan,
    'is_trial_active', v_trial_active,
    'is_in_grace_period', v_in_grace_period,
    'days_until_trial_end', v_days_until_trial_end,
    'grace_days_remaining', v_grace_days_remaining,
    'was_eligible_for_trial', v_was_eligible,
    'user_created_at', v_user_created_at,
    'trial_end_date', get_standard_trial_end_date(),
    'grace_period_end_date', get_grace_period_end_date(),
    'has_subscription', v_subscription IS NOT NULL,
    'subscription_plan_type', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.plan_type ELSE NULL END,
    'subscription_status', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.status ELSE NULL END,
    'current_period_end', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.current_period_end ELSE NULL END,
    'next_billing_at', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.next_billing_at ELSE NULL END,
    'cancel_at_cycle_end', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.cancel_at_cycle_end ELSE NULL END
  );

  RETURN v_result;
END;
$$;

-- ============================================================================
-- 6. Grant execute permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION get_standard_trial_end_date() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_grace_period_end_date() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION is_standard_trial_active() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION is_in_grace_period() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_days_until_trial_end() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_grace_days_remaining() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION was_eligible_for_trial(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_user_created_at(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_user_plan_with_subscription(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_subscription_status(UUID) TO authenticated, anon, service_role;
