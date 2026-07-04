-- Reconcile IAP product IDs to the store-canonical underscore form.
--
-- The app buys the product id sourced from iap_products / the subscription-pricing
-- API, which uses `com.disciplefy.{plan}_monthly` (underscore). This matches what
-- the App Store / Play Console actually issue — confirmed live on iOS: a real
-- StoreKit receipt reports product `com.disciplefy.plus_monthly`.
--
-- But subscription_plan_providers.provider_plan_id was seeded with the DOTTED form
-- `com.disciplefy.{plan}.monthly`. receipt-validation-service.ts derives its
-- expected product id from that column (the C4 PRODUCT_MISMATCH check), so every
-- iOS/Android subscription is rejected:
--   PRODUCT_MISMATCH - Receipt is for product 'com.disciplefy.plus_monthly',
--   not 'com.disciplefy.plus.monthly' — cannot grant 'plus'
--
-- Align provider_plan_id to the underscore form for the store providers. Idempotent:
-- only rows still in the dotted form are touched.

UPDATE subscription_plan_providers
SET provider_plan_id = replace(provider_plan_id, '.monthly', '_monthly'),
    updated_at = NOW()
WHERE provider IN ('apple_appstore', 'google_play')
  AND provider_plan_id LIKE 'com.disciplefy.%.monthly';
