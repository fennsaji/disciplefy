-- Fix Google Play product IDs to match Play Console
--
-- Previous migration (20260228000001) set incorrect product IDs with 'bible_study' in the
-- middle segment. Play Console product IDs are:
--   com.disciplefy.standard_monthly
--   com.disciplefy.plus_monthly
--   com.disciplefy.premium_monthly
--
-- This migration corrects all three plans and removes the incorrectly-inserted yearly row.

-- ============================================================================
-- 1. Correct monthly product IDs for all three plans
-- ============================================================================

UPDATE subscription_plan_providers
SET
  provider_plan_id = 'com.disciplefy.standard_monthly',
  product_id       = 'com.disciplefy.standard_monthly',
  updated_at       = NOW()
WHERE plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'standard')
  AND provider = 'google_play'
  AND region = 'IN';

UPDATE subscription_plan_providers
SET
  provider_plan_id = 'com.disciplefy.plus_monthly',
  product_id       = 'com.disciplefy.plus_monthly',
  updated_at       = NOW()
WHERE plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'plus')
  AND provider = 'google_play'
  AND region = 'IN';

UPDATE subscription_plan_providers
SET
  provider_plan_id = 'com.disciplefy.premium_monthly',
  product_id       = 'com.disciplefy.premium_monthly',
  updated_at       = NOW()
WHERE plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'premium')
  AND provider = 'google_play'
  AND region = 'IN';

-- ============================================================================
-- 2. Verify (informational — shows what was updated)
-- ============================================================================

-- Expected output after this migration:
--   plan_code  | provider    | product_id
--   -----------+-------------+-------------------------------
--   standard   | google_play | com.disciplefy.standard_monthly
--   plus       | google_play | com.disciplefy.plus_monthly
--   premium    | google_play | com.disciplefy.premium_monthly
