-- ============================================================================
-- Migration: Update Subscription Status with Premium Trial
-- Description: Updates get_subscription_status and get_user_plan_with_subscription
--              to include Premium trial information
-- ============================================================================

-- ============================================================================
-- 1. Update get_user_plan_with_subscription to check Premium trial
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_plan_with_subscription(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_is_in_premium_trial BOOLEAN;
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

  -- 2. Check for active Premium trial (7-day trial for new users after April 1st)
  v_is_in_premium_trial := public.is_in_premium_trial(p_user_id);
  IF v_is_in_premium_trial THEN
    RETURN 'premium';
  END IF;

  -- 3. Check for active premium subscription
  SELECT EXISTS(
    SELECT 1 FROM subscriptions
    WHERE user_id = p_user_id
      AND status IN ('active', 'authenticated', 'pending_cancellation')
      AND plan_type LIKE 'premium%'
  ) INTO v_has_premium_subscription;

  IF v_has_premium_subscription THEN
    RETURN 'premium';
  END IF;

  -- 4. Check for active standard subscription
  SELECT EXISTS(
    SELECT 1 FROM subscriptions
    WHERE user_id = p_user_id
      AND status IN ('active', 'authenticated', 'pending_cancellation')
      AND plan_type LIKE 'standard%'
  ) INTO v_has_standard_subscription;

  IF v_has_standard_subscription THEN
    RETURN 'standard';
  END IF;

  -- 5. Check if Standard trial is still active (before March 31, 2025)
  v_trial_active := is_standard_trial_active();
  IF v_trial_active THEN
    RETURN 'standard';
  END IF;

  -- 6. Check trial eligibility (signed up before March 31)
  v_was_eligible := was_eligible_for_trial(p_user_id);

  IF v_was_eligible THEN
    -- 7. Check if in grace period (April 1-7, 2025)
    v_in_grace_period := is_in_grace_period();
    IF v_in_grace_period THEN
      RETURN 'standard';
    END IF;

    -- Trial eligible but grace period ended, no subscription
    RETURN 'free';
  END IF;

  -- 8. New user (signed up after March 31) - free plan
  RETURN 'free';
END;
$$;

-- ============================================================================
-- 2. Update get_subscription_status to include Premium trial fields
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
  v_premium_trial_status JSON;
BEGIN
  -- Get computed values
  v_current_plan := get_user_plan_with_subscription(p_user_id);
  v_trial_active := is_standard_trial_active();
  v_in_grace_period := is_in_grace_period();
  v_days_until_trial_end := get_days_until_trial_end();
  v_grace_days_remaining := get_grace_days_remaining();
  v_was_eligible := was_eligible_for_trial(p_user_id);
  v_user_created_at := get_user_created_at(p_user_id);

  -- Get Premium trial status
  v_premium_trial_status := public.get_premium_trial_status(p_user_id);

  -- Get active subscription if any
  SELECT * INTO v_subscription
  FROM subscriptions
  WHERE user_id = p_user_id
    AND status IN ('active', 'authenticated', 'pending_cancellation', 'created')
  ORDER BY created_at DESC
  LIMIT 1;

  -- Build result JSON with Premium trial fields
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
    'cancel_at_cycle_end', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.cancel_at_cycle_end ELSE NULL END,
    -- Premium trial fields
    'is_in_premium_trial', (v_premium_trial_status->>'is_in_premium_trial')::boolean,
    'premium_trial_started_at', v_premium_trial_status->>'premium_trial_started_at',
    'premium_trial_end_at', v_premium_trial_status->>'premium_trial_end_at',
    'premium_trial_days_remaining', (v_premium_trial_status->>'premium_trial_days_remaining')::integer,
    'has_used_premium_trial', (v_premium_trial_status->>'has_used_premium_trial')::boolean,
    'can_start_premium_trial', (v_premium_trial_status->>'can_start_premium_trial')::boolean
  );

  RETURN v_result;
END;
$$;

-- ============================================================================
-- 3. Grant execute permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION get_user_plan_with_subscription(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_subscription_status(UUID) TO authenticated, anon, service_role;
