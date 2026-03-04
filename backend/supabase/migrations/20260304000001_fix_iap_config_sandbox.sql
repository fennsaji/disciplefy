-- Fix iap_config sandbox rows.
--
-- The initial seed (20260214000003) used 'com.disciplefy.app.test' as the sandbox
-- package name. Update it to match the actual application ID used in Play Console.
-- The 20260228 migration already did this with UPDATE statements, but those only
-- fire if the rows exist. This migration is idempotent and uses ON CONFLICT.
--
-- IMPORTANT: All rows stay is_active=false until real credentials are provided.
-- To activate for internal test track testing:
--   1. Obtain Google Play service account JSON key (Android Publisher API scope)
--   2. UPDATE iap_config SET config_value='<email>', is_active=true
--      WHERE provider='google_play' AND environment='sandbox' AND config_key='service_account_email';
--   3. UPDATE iap_config SET config_value='<json-key>', is_active=true
--      WHERE provider='google_play' AND environment='sandbox' AND config_key='service_account_key';
--   4. UPDATE iap_config SET is_active=true
--      WHERE provider='google_play' AND environment='sandbox' AND config_key='package_name';
--
-- For local UI testing WITHOUT real credentials:
--   Set USE_MOCK=true in your shell before running `supabase start`.
--   This bypasses iap_config entirely and returns a mock successful validation.
--
-- For internal test track testing WITH real purchases:
--   Set APP_ENVIRONMENT=sandbox in your shell before running `supabase start`,
--   then activate the sandbox rows as described above.

-- Correct the sandbox package name (idempotent)
INSERT INTO iap_config (provider, environment, config_key, config_value, is_active)
VALUES
  ('google_play', 'sandbox', 'package_name', 'com.disciplefy.bible_study', false)
ON CONFLICT (provider, environment, config_key)
  DO UPDATE SET config_value = EXCLUDED.config_value,
                updated_at   = NOW()
  WHERE iap_config.config_value != EXCLUDED.config_value;

-- Correct the production package name too (was seeded as 'com.disciplefy.app')
INSERT INTO iap_config (provider, environment, config_key, config_value, is_active)
VALUES
  ('google_play', 'production', 'package_name', 'com.disciplefy.bible_study', false)
ON CONFLICT (provider, environment, config_key)
  DO UPDATE SET config_value = EXCLUDED.config_value,
                updated_at   = NOW()
  WHERE iap_config.config_value != EXCLUDED.config_value;
