-- Fix create_trial_subscription to not use ON CONFLICT (user_id)
--
-- Migration 20260301000001 replaced the full unique index on subscriptions(user_id)
-- with a partial unique index (WHERE status NOT IN ('cancelled', 'expired', ...)).
-- This broke ON CONFLICT (user_id) because PostgreSQL requires a full unique
-- constraint (not a partial index) for that syntax.
--
-- This migration rewrites the function to use a SELECT-then-INSERT pattern:
-- 1. Check if a non-terminal subscription already exists for the user
-- 2. If yes, return its ID
-- 3. If no, insert a new subscription row

CREATE OR REPLACE FUNCTION create_trial_subscription(p_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_subscription_id UUID;
  v_standard_plan_id UUID;
  v_free_plan_id UUID;
  v_trial_end_date TIMESTAMPTZ;
  v_trial_active BOOLEAN;
BEGIN
  -- Get trial configuration from subscription_config
  v_trial_end_date := get_standard_trial_end_date();
  v_trial_active := is_standard_trial_active();

  -- Get plan IDs
  SELECT id INTO v_standard_plan_id
  FROM subscription_plans
  WHERE plan_code = 'standard'
  LIMIT 1;

  SELECT id INTO v_free_plan_id
  FROM subscription_plans
  WHERE plan_code = 'free'
  LIMIT 1;

  -- Check if a non-terminal subscription already exists for this user
  -- (covers any status that the partial unique index enforces uniqueness for)
  SELECT id INTO v_subscription_id
  FROM subscriptions
  WHERE user_id = p_user_id
    AND status NOT IN ('cancelled', 'expired', 'paused', 'completed')
  LIMIT 1;

  -- If user already has an active subscription, return it
  IF FOUND THEN
    RETURN v_subscription_id;
  END IF;

  -- If trial is active, create a trial subscription
  IF v_trial_active THEN
    INSERT INTO subscriptions (
      user_id,
      plan_id,
      plan_type,
      status,
      provider,
      provider_subscription_id,
      current_period_start,
      current_period_end
    ) VALUES (
      p_user_id,
      v_standard_plan_id,
      'standard_trial',
      'trial',
      'trial',
      'trial_' || p_user_id::text,
      NOW(),
      v_trial_end_date
    )
    RETURNING id INTO v_subscription_id;

  ELSE
    -- Trial expired, create a free subscription
    INSERT INTO subscriptions (
      user_id,
      plan_id,
      plan_type,
      status,
      provider,
      provider_subscription_id,
      current_period_start,
      current_period_end
    ) VALUES (
      p_user_id,
      v_free_plan_id,
      'free_tier',
      'active',
      'system',
      'free_' || p_user_id::text,
      NOW(),
      NOW() + INTERVAL '100 years'
    )
    RETURNING id INTO v_subscription_id;
  END IF;

  RETURN v_subscription_id;
END;
$$;

COMMENT ON FUNCTION create_trial_subscription(UUID) IS
  'Creates trial subscription if trial active, otherwise creates free subscription. Called on user signup. Uses SELECT-then-INSERT to avoid ON CONFLICT issues with partial unique index.';
