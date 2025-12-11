-- ============================================================================
-- Migration: Extend Standard Trial to March 31, 2026
-- Version: 1.0
-- Date: 2025-12-11
--
-- Description:
-- Extends the Standard plan free trial period from March 31, 2025 to March 31, 2026.
-- All new users signing up will get free Standard plan access until March 31, 2026.
-- After that date, users will need to subscribe to Standard (Rs.50/month) to continue.
--
-- Changes:
-- 1. Update standard_trial_end_date to 2026-03-31
-- 2. Update grace_period_end_date to 2026-04-07
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. UPDATE TRIAL END DATE TO MARCH 31, 2026
-- ============================================================================

UPDATE subscription_config 
SET 
  value = '2026-03-31T23:59:59+05:30',
  description = 'Standard plan trial period end date. All users get free Standard access until this date.',
  updated_at = NOW()
WHERE key = 'standard_trial_end_date';

-- Insert if doesn't exist (for fresh installs)
INSERT INTO subscription_config (key, value, description)
VALUES (
  'standard_trial_end_date',
  '2026-03-31T23:59:59+05:30',
  'Standard plan trial period end date. All users get free Standard access until this date.'
)
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- 2. UPDATE GRACE PERIOD END DATE TO APRIL 7, 2026
-- ============================================================================

UPDATE subscription_config 
SET 
  value = '2026-04-07T23:59:59+05:30',
  description = 'End date for grace period after trial ends. Users keep Standard access for 7 days after trial.',
  updated_at = NOW()
WHERE key = 'grace_period_end_date';

-- Insert if doesn't exist (for fresh installs)
INSERT INTO subscription_config (key, value, description)
VALUES (
  'grace_period_end_date',
  '2026-04-07T23:59:59+05:30',
  'End date for grace period after trial ends. Users keep Standard access for 7 days after trial.'
)
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- 3. VERIFY THE UPDATES
-- ============================================================================

DO $$
DECLARE
  v_trial_end TEXT;
  v_grace_end TEXT;
BEGIN
  SELECT value INTO v_trial_end FROM subscription_config WHERE key = 'standard_trial_end_date';
  SELECT value INTO v_grace_end FROM subscription_config WHERE key = 'grace_period_end_date';
  
  RAISE NOTICE 'Standard Trial Extended:';
  RAISE NOTICE '  - Trial End Date: %', v_trial_end;
  RAISE NOTICE '  - Grace Period End: %', v_grace_end;
  RAISE NOTICE 'All new users will get free Standard plan until March 31, 2026.';
END $$;

COMMIT;
