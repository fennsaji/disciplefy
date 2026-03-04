-- Google Play Internal Test Track Setup
-- Updates provider_plan_id / product_id for all plans to match Play Console product IDs
-- and corrects the sandbox package_name in iap_config.
--
-- Play Console product IDs (must match exactly what was created under Monetize → Subscriptions):
--   com.disciplefy.standard_monthly
--   com.disciplefy.plus_monthly
--   com.disciplefy.premium_monthly
--
-- Run AFTER uploading an AAB to the Internal Testing track and creating the subscription products.

-- ============================================================================
-- 1. Update Google Play product IDs for all plans
-- ============================================================================

UPDATE subscription_plan_providers
SET
  provider_plan_id = 'com.disciplefy.standard_monthly',
  product_id       = 'com.disciplefy.standard_monthly',
  is_active        = true,
  updated_at       = NOW()
WHERE plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'standard')
  AND provider = 'google_play'
  AND region = 'IN';

UPDATE subscription_plan_providers
SET
  provider_plan_id = 'com.disciplefy.plus_monthly',
  product_id       = 'com.disciplefy.plus_monthly',
  is_active        = true,
  updated_at       = NOW()
WHERE plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'plus')
  AND provider = 'google_play'
  AND region = 'IN';

UPDATE subscription_plan_providers
SET
  provider_plan_id = 'com.disciplefy.premium_monthly',
  product_id       = 'com.disciplefy.premium_monthly',
  is_active        = true,
  updated_at       = NOW()
WHERE plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'premium')
  AND provider = 'google_play'
  AND region = 'IN';

-- ============================================================================
-- 2. Correct sandbox package_name in iap_config
-- ============================================================================
-- The earlier migration seeded 'com.disciplefy.app.test' as the sandbox package name.
-- Update it to match the actual application ID used in Play Console.

UPDATE iap_config
SET config_value = 'com.disciplefy.bible_study',
    updated_at   = NOW()
WHERE provider    = 'google_play'
  AND environment = 'sandbox'
  AND config_key  = 'package_name';

-- Production package name (same application ID)
UPDATE iap_config
SET config_value = 'com.disciplefy.bible_study',
    updated_at   = NOW()
WHERE provider    = 'google_play'
  AND environment = 'production'
  AND config_key  = 'package_name';

-- ============================================================================
-- Notes for DBA / Play Console setup
-- ============================================================================
-- After running this migration:
--
-- 1. Create a Google Cloud service account with Android Publisher API access.
-- 2. Download the JSON key and link the service account in Play Console → Setup → API access.
-- 3. Update iap_config rows:
--      UPDATE iap_config SET config_value = '<email>', is_active = true
--      WHERE provider = 'google_play' AND environment = 'sandbox'
--        AND config_key = 'service_account_email';
--
--      UPDATE iap_config SET config_value = '<json-key>', is_active = true
--      WHERE provider = 'google_play' AND environment = 'sandbox'
--        AND config_key = 'service_account_key';
--
-- 4. Verify: SELECT * FROM subscription_plan_providers WHERE provider = 'google_play';
--            SELECT provider, environment, config_key, is_active FROM iap_config WHERE provider = 'google_play';
