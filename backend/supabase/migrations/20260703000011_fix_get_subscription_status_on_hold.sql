-- F17: Include on_hold subscriptions in get_subscription_status.
--
-- A Google Play on_hold subscription is a real paid subscription that was
-- temporarily suspended due to payment failure. The function previously excluded
-- on_hold rows, so affected users saw has_subscription:false and the UI showed
-- "No subscription" / upgrade prompts instead of a "fix your payment" prompt.
--
-- has_subscription is still true for on_hold (user has a subscription, just
-- suspended). current_plan is resolved via get_user_plan_with_subscription which
-- correctly returns 'free' for on_hold (access denied), so feature gating remains
-- correct. Only the UI-facing status fields needed this fix.

CREATE OR REPLACE FUNCTION get_subscription_status(p_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result JSONB;
  v_current_plan TEXT;
  v_subscription RECORD;
  v_premium_trial_status JSON;
BEGIN
  v_current_plan := get_user_plan_with_subscription(p_user_id);
  v_premium_trial_status := get_premium_trial_status(p_user_id);

  SELECT * INTO v_subscription FROM subscriptions
  WHERE user_id = p_user_id AND status IN ('active', 'in_progress', 'pending_cancellation', 'created', 'on_hold', 'trial')
  ORDER BY created_at DESC LIMIT 1;

  v_result := jsonb_build_object(
    'current_plan', v_current_plan,
    'is_trial_active', is_standard_trial_active(),
    'is_in_grace_period', is_in_grace_period(),
    'days_until_trial_end', get_days_until_trial_end(),
    'grace_days_remaining', get_grace_days_remaining(),
    'was_eligible_for_trial', was_eligible_for_trial(p_user_id),
    'user_created_at', get_user_created_at(p_user_id),
    'trial_end_date', get_standard_trial_end_date(),
    'grace_period_end_date', get_grace_period_end_date(),
    'has_subscription', v_subscription IS NOT NULL,
    'subscription_plan_type', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.plan_type ELSE NULL END,
    'subscription_status', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.status ELSE NULL END,
    'current_period_end', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.current_period_end ELSE NULL END,
    'next_billing_at', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.next_billing_at ELSE NULL END,
    'cancel_at_cycle_end', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.cancel_at_cycle_end ELSE NULL END,
    'is_in_premium_trial', (v_premium_trial_status->>'is_in_premium_trial')::boolean,
    'premium_trial_started_at', v_premium_trial_status->>'premium_trial_started_at',
    'premium_trial_end_at', v_premium_trial_status->>'premium_trial_end_at',
    'premium_trial_days_remaining', (v_premium_trial_status->>'premium_trial_days_remaining')::integer,
    'has_used_premium_trial', (v_premium_trial_status->>'has_used_premium_trial')::boolean,
    'can_start_premium_trial', (v_premium_trial_status->>'can_start_premium_trial')::boolean
  );
  RETURN v_result;
END; $$;
