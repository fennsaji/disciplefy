-- Extend standard trial end date by 1 year: 2026-03-31 → 2027-03-31
-- Unify config: system_config is the single source of truth.
-- SQL functions now read from system_config (same as TypeScript Edge Functions).
-- subscription_config trial keys are removed to eliminate duplication.

-- 1. Update system_config (single source of truth)
UPDATE public.system_config
SET value = '2027-03-31T23:59:59+05:30',
    updated_at = NOW()
WHERE key = 'standard_trial_end_date';

-- 2. Remove trial date keys from subscription_config (no longer the source)
DELETE FROM public.subscription_config
WHERE key IN ('standard_trial_end_date', 'grace_period_end_date');

-- 3. Extend existing user trial subscriptions so they don't expire tomorrow
UPDATE public.subscriptions
SET current_period_end = '2027-03-31T23:59:59+05:30',
    updated_at = NOW()
WHERE status = 'trial'
  AND plan_type = 'standard_trial'
  AND current_period_end <= '2026-03-31T23:59:59+05:30';

-- 4. Recreate SQL functions to read from system_config (unified source)
--    Grace period end is computed dynamically from standard_trial_end_date + grace_period_days
--    matching the same logic used by the TypeScript getDynamicTrialConfig().
--    Raises exception if DB value is missing — no hardcoded fallbacks.

CREATE OR REPLACE FUNCTION get_standard_trial_end_date()
RETURNS TIMESTAMPTZ LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_trial_end_date TIMESTAMPTZ;
BEGIN
  SELECT value::TIMESTAMPTZ INTO v_trial_end_date
  FROM public.system_config
  WHERE key = 'standard_trial_end_date' AND is_active = true;
  IF v_trial_end_date IS NULL THEN
    RAISE EXCEPTION 'standard_trial_end_date missing from system_config';
  END IF;
  RETURN v_trial_end_date;
END; $$;

CREATE OR REPLACE FUNCTION get_grace_period_end_date()
RETURNS TIMESTAMPTZ LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_trial_end_date TIMESTAMPTZ;
  v_grace_days INTEGER;
BEGIN
  SELECT value::TIMESTAMPTZ INTO v_trial_end_date
  FROM public.system_config
  WHERE key = 'standard_trial_end_date' AND is_active = true;
  IF v_trial_end_date IS NULL THEN
    RAISE EXCEPTION 'standard_trial_end_date missing from system_config';
  END IF;

  SELECT value::INTEGER INTO v_grace_days
  FROM public.system_config
  WHERE key = 'grace_period_days' AND is_active = true;

  RETURN v_trial_end_date + INTERVAL '1 day' * COALESCE(v_grace_days, 7);
END; $$;
