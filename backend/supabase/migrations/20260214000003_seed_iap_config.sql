-- Seed IAP Configuration Placeholders
-- Purpose: Initialize IAP configuration entries for Google Play and Apple App Store
-- Status: All entries are inactive until actual credentials are added via admin UI

-- ============================================================================
-- 1. Google Play Store Configuration (Production)
-- ============================================================================

INSERT INTO iap_config (provider, environment, config_key, config_value, is_active)
VALUES
  (
    'google_play',
    'production',
    'service_account_email',
    'your-service-account@your-project.iam.gserviceaccount.com',
    false
  ),
  (
    'google_play',
    'production',
    'service_account_key',
    'PLACEHOLDER_ENCRYPTED_KEY_WILL_BE_STORED_HERE',
    false
  ),
  (
    'google_play',
    'production',
    'package_name',
    'com.disciplefy.app',
    false
  )
ON CONFLICT (provider, environment, config_key) DO NOTHING;

-- ============================================================================
-- 2. Google Play Store Configuration (Sandbox)
-- ============================================================================

INSERT INTO iap_config (provider, environment, config_key, config_value, is_active)
VALUES
  (
    'google_play',
    'sandbox',
    'service_account_email',
    'your-test-service-account@your-project.iam.gserviceaccount.com',
    false
  ),
  (
    'google_play',
    'sandbox',
    'service_account_key',
    'PLACEHOLDER_ENCRYPTED_TEST_KEY_WILL_BE_STORED_HERE',
    false
  ),
  (
    'google_play',
    'sandbox',
    'package_name',
    'com.disciplefy.app.test',
    false
  )
ON CONFLICT (provider, environment, config_key) DO NOTHING;

-- ============================================================================
-- 3. Apple App Store Configuration (Production)
-- ============================================================================

INSERT INTO iap_config (provider, environment, config_key, config_value, is_active)
VALUES
  (
    'apple_appstore',
    'production',
    'shared_secret',
    'PLACEHOLDER_SHARED_SECRET_WILL_BE_STORED_HERE',
    false
  ),
  (
    'apple_appstore',
    'production',
    'bundle_id',
    'com.disciplefy.app',
    false
  )
ON CONFLICT (provider, environment, config_key) DO NOTHING;

-- ============================================================================
-- 4. Apple App Store Configuration (Sandbox)
-- ============================================================================

INSERT INTO iap_config (provider, environment, config_key, config_value, is_active)
VALUES
  (
    'apple_appstore',
    'sandbox',
    'shared_secret',
    'PLACEHOLDER_SANDBOX_SHARED_SECRET_WILL_BE_STORED_HERE',
    false
  ),
  (
    'apple_appstore',
    'sandbox',
    'bundle_id',
    'com.disciplefy.app',
    false
  )
ON CONFLICT (provider, environment, config_key) DO NOTHING;

-- ============================================================================
-- 5. Verification
-- ============================================================================

DO $$
DECLARE
  v_google_prod_count INTEGER;
  v_google_sandbox_count INTEGER;
  v_apple_prod_count INTEGER;
  v_apple_sandbox_count INTEGER;
  v_total_count INTEGER;
BEGIN
  -- Count configuration entries by provider and environment
  SELECT COUNT(*) INTO v_google_prod_count
  FROM iap_config
  WHERE provider = 'google_play' AND environment = 'production';

  SELECT COUNT(*) INTO v_google_sandbox_count
  FROM iap_config
  WHERE provider = 'google_play' AND environment = 'sandbox';

  SELECT COUNT(*) INTO v_apple_prod_count
  FROM iap_config
  WHERE provider = 'apple_appstore' AND environment = 'production';

  SELECT COUNT(*) INTO v_apple_sandbox_count
  FROM iap_config
  WHERE provider = 'apple_appstore' AND environment = 'sandbox';

  SELECT COUNT(*) INTO v_total_count FROM iap_config;

  RAISE NOTICE '✅ IAP configuration placeholders seeded successfully';
  RAISE NOTICE '   - Google Play Production configs: %', v_google_prod_count;
  RAISE NOTICE '   - Google Play Sandbox configs: %', v_google_sandbox_count;
  RAISE NOTICE '   - Apple App Store Production configs: %', v_apple_prod_count;
  RAISE NOTICE '   - Apple App Store Sandbox configs: %', v_apple_sandbox_count;
  RAISE NOTICE '   - Total IAP config entries: %', v_total_count;
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  All entries are INACTIVE (is_active=false)';
  RAISE NOTICE '   - Update credentials via Admin UI to activate';
  RAISE NOTICE '   - Production credentials should be encrypted before storage';
END $$;

-- Display current IAP configuration
SELECT
  provider,
  environment,
  config_key,
  CASE
    WHEN config_key IN ('service_account_key', 'shared_secret') THEN '***ENCRYPTED***'
    ELSE config_value
  END AS config_value_display,
  is_active,
  created_at
FROM iap_config
ORDER BY provider, environment, config_key;

-- ============================================================================
-- Migration Complete
-- ============================================================================

COMMENT ON TABLE iap_config IS
  'IAP provider configuration with encrypted credentials.
   SECURITY: Never expose raw service_account_key or shared_secret values.
   UPDATE: Use Admin UI to set actual credentials and activate (is_active=true).';
