-- ============================================================================
-- Unify Plan Resolution — Single Source of Truth
-- ============================================================================
-- All plan/tier resolution now flows through get_user_plan_with_subscription.
-- Previously there were 4 divergent implementations:
--   1. get_user_plan_with_subscription  (subscription_system migration — most complete)
--   2. get_user_subscription_tier       (voice_system migration — missing admin/trial/grace)
--   3. is_feature_enabled_for_user      (feature_flags migration — used raw plan_type, broken)
--   4. AuthService.getUserPlan          (TypeScript — missing global trial & grace period)
--
-- After this migration:
--   • get_user_plan_with_subscription   canonical function (enhanced below)
--   • get_user_subscription_tier        thin wrapper → delegates to canonical
--   • is_feature_enabled_for_user       calls canonical function
--   • AuthService.getUserPlan           calls RPC get_user_plan_with_subscription
-- ============================================================================

-- ============================================================================
-- 1. Canonical function: get_user_plan_with_subscription (enhanced)
--    Enhancements vs previous version:
--      - Added 'authenticated' and 'in_progress' to status set (was missing)
--      - Added current_period_end expiry guard to each subscription check
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_plan_with_subscription(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_is_in_premium_trial BOOLEAN;
  v_has_premium_subscription BOOLEAN;
  v_has_plus_subscription BOOLEAN;
  v_has_standard_subscription BOOLEAN;
  v_trial_active BOOLEAN;
  v_in_grace_period BOOLEAN;
  v_was_eligible BOOLEAN;
BEGIN
  -- 1. Admin users always get premium access
  SELECT COALESCE(is_admin, FALSE) INTO v_is_admin FROM user_profiles WHERE id = p_user_id;
  IF v_is_admin THEN RETURN 'premium'; END IF;

  -- 2. Active premium trial (7-day new-user trial)
  v_is_in_premium_trial := is_in_premium_trial(p_user_id);
  IF v_is_in_premium_trial THEN RETURN 'premium'; END IF;

  -- Status set used for ALL subscription checks:
  --   active              = fully paid/active
  --   trial               = in trial period (subscription row exists)
  --   authenticated       = Razorpay mandate authenticated, awaiting first payment
  --   in_progress         = Razorpay billing cycle in progress
  --   pending_cancellation = cancellation requested, still within paid period
  -- current_period_end guard prevents granting access to expired subscriptions whose
  -- status hasn't been updated yet by webhooks.

  -- 3. Premium subscription
  SELECT EXISTS(
    SELECT 1 FROM subscriptions s
    LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
    WHERE s.user_id = p_user_id
      AND s.status IN ('active', 'trial', 'authenticated', 'in_progress', 'pending_cancellation')
      AND (s.current_period_end IS NULL OR s.current_period_end > NOW())
      AND (sp.plan_code = 'premium' OR s.plan_type LIKE 'premium%')
  ) INTO v_has_premium_subscription;
  IF v_has_premium_subscription THEN RETURN 'premium'; END IF;

  -- 4. Plus subscription
  SELECT EXISTS(
    SELECT 1 FROM subscriptions s
    LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
    WHERE s.user_id = p_user_id
      AND s.status IN ('active', 'trial', 'authenticated', 'in_progress', 'pending_cancellation')
      AND (s.current_period_end IS NULL OR s.current_period_end > NOW())
      AND (sp.plan_code = 'plus' OR s.plan_type LIKE 'plus%')
  ) INTO v_has_plus_subscription;
  IF v_has_plus_subscription THEN RETURN 'plus'; END IF;

  -- 5. Standard subscription
  SELECT EXISTS(
    SELECT 1 FROM subscriptions s
    LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
    WHERE s.user_id = p_user_id
      AND s.status IN ('active', 'trial', 'authenticated', 'in_progress', 'pending_cancellation')
      AND (s.current_period_end IS NULL OR s.current_period_end > NOW())
      AND (sp.plan_code = 'standard' OR s.plan_type LIKE 'standard%')
  ) INTO v_has_standard_subscription;
  IF v_has_standard_subscription THEN RETURN 'standard'; END IF;

  -- 6. Explicit free subscription (admin override — skips global trial)
  --    If admin explicitly downgraded a user to free, honour it before falling
  --    through to the global trial fallback.
  IF EXISTS(
    SELECT 1 FROM subscriptions s
    LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
    WHERE s.user_id = p_user_id
      AND s.status IN ('active', 'trial', 'authenticated', 'in_progress', 'pending_cancellation')
      AND (s.current_period_end IS NULL OR s.current_period_end > NOW())
      AND (sp.plan_code = 'free' OR s.plan_type LIKE 'free%')
  ) THEN RETURN 'free'; END IF;

  -- 7. Global standard trial (all users get standard during app launch period)
  v_trial_active := is_standard_trial_active();
  IF v_trial_active THEN RETURN 'standard'; END IF;

  -- 8. Grace period after global trial ends
  v_was_eligible := was_eligible_for_trial(p_user_id);
  IF v_was_eligible THEN
    v_in_grace_period := is_in_grace_period();
    IF v_in_grace_period THEN RETURN 'standard'; END IF;
    RETURN 'free';
  END IF;

  RETURN 'free';
END;
$$;

-- ============================================================================
-- 2. get_user_subscription_tier — thin wrapper (single source of truth)
--    Previous implementation duplicated tier logic without admin/trial/grace.
--    Now simply delegates to the canonical function.
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_subscription_tier(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
BEGIN
  RETURN get_user_plan_with_subscription(p_user_id);
END;
$$;

-- ============================================================================
-- 3. is_feature_enabled_for_user — fixed to use canonical tier code
--    Previous implementation read raw plan_type (e.g. 'premium_monthly') and
--    compared it against enabled_for_plans values (e.g. 'premium') — always FALSE.
--    Now calls get_user_plan_with_subscription which returns the canonical tier.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.is_feature_enabled_for_user(
  p_feature_key TEXT,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_enabled BOOLEAN;
  v_user_plan TEXT;
BEGIN
  -- Canonical plan resolution — single source of truth
  v_user_plan := get_user_plan_with_subscription(p_user_id);

  -- Check feature is globally enabled AND user's plan is in the allowed list
  SELECT f.is_enabled AND (v_user_plan = ANY(f.enabled_for_plans))
  INTO v_is_enabled
  FROM public.feature_flags f
  WHERE f.feature_key = p_feature_key;

  RETURN COALESCE(v_is_enabled, false);
END;
$$;

-- Re-grant permissions (CREATE OR REPLACE does not reset grants)
GRANT EXECUTE ON FUNCTION get_user_plan_with_subscription(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_user_subscription_tier(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.is_feature_enabled_for_user(TEXT, UUID) TO authenticated;
