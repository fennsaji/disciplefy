-- check_voice_quota: an unauthenticated call is an error, not an allowance.
--
-- Called without a signed-in session (the app skips the token check when it
-- has no session, so the RPC goes out with the anon key), the function
-- answered with a normal-looking payload: limit 0, remaining 0, tier 'free',
-- plus an 'error' key the app ignored. The Discipler tab then showed
-- "0 of 0 left this month" as a red warning and blocked Start talking, even
-- for Standard and Premium users. Raise instead, so the client gets a failure
-- and simply hides the allowance.
--
-- Everything else is unchanged from 20260119000500_voice_system.sql.
-- CREATE OR REPLACE keeps this idempotent.

CREATE OR REPLACE FUNCTION check_voice_quota()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_user_id UUID;
  v_tier TEXT;
  v_quota_limit INTEGER;
  v_monthly_usage INTEGER;
  v_can_start BOOLEAN;
  v_month_start DATE;
  v_month_end DATE;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  v_tier := get_user_subscription_tier(v_user_id);

  -- Monthly limit from subscription_plans.features.voice_conversations_monthly
  -- (-1 unlimited, 0 not in the plan).
  SELECT (features->>'voice_conversations_monthly')::INTEGER
  INTO v_quota_limit
  FROM subscription_plans
  WHERE plan_code = v_tier AND is_active = true;

  v_quota_limit := COALESCE(v_quota_limit, 0);

  v_month_start := DATE_TRUNC('month', CURRENT_DATE)::DATE;
  v_month_end := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

  SELECT COALESCE(SUM(daily_quota_used), 0) INTO v_monthly_usage
  FROM voice_usage_tracking
  WHERE user_id = v_user_id
    AND usage_date >= v_month_start
    AND usage_date <= v_month_end;

  v_can_start := CASE
    WHEN v_quota_limit = -1 THEN TRUE
    WHEN v_quota_limit = 0 THEN FALSE
    ELSE v_monthly_usage < v_quota_limit
  END;

  INSERT INTO voice_usage_tracking (
    user_id, tier_at_time, daily_quota_limit, daily_quota_used
  )
  VALUES (v_user_id, v_tier, v_quota_limit, 0)
  ON CONFLICT (user_id, usage_date) DO NOTHING;

  RETURN jsonb_build_object(
    'can_start', v_can_start,
    'quota_limit', CASE WHEN v_quota_limit = -1 THEN 999999 ELSE v_quota_limit END,
    'quota_used', v_monthly_usage,
    'quota_remaining', CASE
      WHEN v_quota_limit = -1 THEN 999999
      ELSE GREATEST(0, v_quota_limit - v_monthly_usage)
    END,
    'tier', v_tier
  );
END;
$$;

COMMENT ON FUNCTION check_voice_quota() IS
  'Monthly Discipler allowance for the signed-in user (subscription_plans.features.voice_conversations_monthly). Raises 42501 when called without a user.';
