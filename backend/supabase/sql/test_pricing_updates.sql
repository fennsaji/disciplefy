-- ============================================================================
-- Subscription Pricing Update - Testing SQL Queries
-- ============================================================================
-- Use these queries to verify price updates are working correctly
-- Copy/paste into Supabase SQL Editor or psql

-- ============================================================================
-- 1. VIEW CURRENT PRICING (All Providers)
-- ============================================================================

SELECT
  sp.plan_code,
  sp.plan_name,
  spp.provider,
  spp.provider_plan_id,
  spp.product_id,
  spp.base_price_minor,
  spp.currency,
  CONCAT(
    CASE spp.currency
      WHEN 'INR' THEN '₹'
      WHEN 'USD' THEN '$'
      ELSE spp.currency || ' '
    END,
    spp.base_price_minor / 100
  ) AS formatted_price,
  spp.sync_status,
  spp.is_active,
  spp.updated_at
FROM subscription_plan_providers spp
JOIN subscription_plans sp ON spp.plan_id = sp.id
ORDER BY sp.tier, spp.provider;

-- ============================================================================
-- 2. CHECK RAZORPAY PLANS (Web Subscriptions)
-- ============================================================================

SELECT
  sp.plan_code,
  sp.plan_name,
  spp.provider_plan_id AS razorpay_plan_id,
  CONCAT('₹', spp.base_price_minor / 100) AS price,
  spp.updated_at AS last_updated
FROM subscription_plan_providers spp
JOIN subscription_plans sp ON spp.plan_id = sp.id
WHERE spp.provider = 'razorpay'
ORDER BY sp.tier;

-- ============================================================================
-- 3. CHECK IAP PLANS (Google Play + Apple App Store)
-- ============================================================================

SELECT
  sp.plan_code,
  sp.plan_name,
  spp.provider,
  spp.product_id,
  CONCAT('₹', spp.base_price_minor / 100) AS price,
  spp.sync_status,
  spp.last_verified_at,
  spp.updated_at
FROM subscription_plan_providers spp
JOIN subscription_plans sp ON spp.plan_id = sp.id
WHERE spp.provider IN ('google_play', 'apple_appstore')
ORDER BY sp.tier, spp.provider;

-- ============================================================================
-- 4. VIEW RECENT PRICE CHANGES (Last 10)
-- ============================================================================

SELECT
  created_at,
  admin_email,
  plan_code,
  provider,
  action,
  CONCAT(currency, ' ', old_price_minor / 100) AS old_price,
  CONCAT(currency, ' ', new_price_minor / 100) AS new_price,
  CONCAT(
    CASE
      WHEN price_difference_minor > 0 THEN '+'
      WHEN price_difference_minor < 0 THEN '-'
      ELSE ''
    END,
    currency, ' ',
    ABS(price_difference_minor) / 100
  ) AS change,
  old_provider_plan_id,
  new_provider_plan_id,
  notes
FROM admin_subscription_price_audit
ORDER BY created_at DESC
LIMIT 10;

-- ============================================================================
-- 5. FORMATTED PRICE CHANGE HISTORY (Using View)
-- ============================================================================

SELECT
  created_at,
  admin_email,
  plan_code,
  provider,
  action,
  old_price_formatted,
  new_price_formatted,
  price_change_formatted,
  notes
FROM admin_price_change_history
ORDER BY created_at DESC
LIMIT 10;

-- ============================================================================
-- 6. CHECK FOR PRICE MISMATCHES (IAP Sync Status)
-- ============================================================================

SELECT
  sp.plan_code,
  spp.provider,
  spp.product_id,
  CONCAT(spp.currency, ' ', spp.base_price_minor / 100) AS our_price,
  CASE
    WHEN spp.provider_price_minor IS NOT NULL
    THEN CONCAT(spp.currency, ' ', spp.provider_price_minor / 100)
    ELSE 'Not Verified'
  END AS provider_price,
  spp.sync_status,
  spp.last_verified_at,
  CASE
    WHEN spp.sync_status = 'synced' THEN '✅ Synced'
    WHEN spp.sync_status = 'pending_manual_update' THEN '⚠️ Needs Console Update'
    WHEN spp.sync_status = 'mismatch' THEN '❌ Price Mismatch!'
    WHEN spp.sync_status = 'verification_failed' THEN '⚠️ Verification Failed'
    ELSE '⚪ Not Verified'
  END AS status
FROM subscription_plan_providers spp
JOIN subscription_plans sp ON spp.plan_id = sp.id
WHERE spp.provider IN ('google_play', 'apple_appstore')
ORDER BY spp.sync_status DESC NULLS LAST, sp.tier;

-- ============================================================================
-- 7. SIMULATE PRICE UPDATE (Testing Only - Don't Run in Production!)
-- ============================================================================

-- This is a helper to test without going through the UI
-- Replace UUIDs and values with your actual data

/*
DO $$
DECLARE
  v_admin_user_id UUID := 'YOUR_ADMIN_USER_UUID';
  v_plan_id UUID := (SELECT id FROM subscription_plans WHERE plan_code = 'standard');
  v_old_price INTEGER;
  v_new_price INTEGER := 14900; -- ₹149
BEGIN
  -- Get current price
  SELECT base_price_minor INTO v_old_price
  FROM subscription_plan_providers
  WHERE plan_id = v_plan_id AND provider = 'razorpay';

  -- Update price (simulating what Edge Function does)
  UPDATE subscription_plan_providers
  SET
    base_price_minor = v_new_price,
    provider_plan_id = 'plan_TEST' || EXTRACT(EPOCH FROM NOW())::TEXT,
    updated_at = NOW()
  WHERE plan_id = v_plan_id AND provider = 'razorpay';

  -- Log audit entry
  PERFORM log_subscription_price_change(
    v_admin_user_id,
    v_plan_id,
    'razorpay',
    'razorpay_plan_creation',
    v_old_price,
    v_new_price,
    'plan_OLD123',
    'plan_NEW456',
    0,
    'Test price update via SQL'
  );

  RAISE NOTICE 'Price updated from % to %', v_old_price, v_new_price;
END $$;
*/

-- ============================================================================
-- 8. GET PLAN PROVIDER ID FOR TESTING
-- ============================================================================

-- Use this to get the plan_provider_id needed for API calls

SELECT
  spp.id AS plan_provider_id,
  sp.plan_code,
  sp.plan_name,
  spp.provider,
  CONCAT('₹', spp.base_price_minor / 100) AS current_price,
  spp.provider_plan_id,
  spp.product_id
FROM subscription_plan_providers spp
JOIN subscription_plans sp ON spp.plan_id = sp.id
ORDER BY sp.tier, spp.provider;

-- Copy a plan_provider_id from the results to use in your API tests

-- ============================================================================
-- 9. VERIFY EDGE FUNCTION FILTER (No Deprecated Plans)
-- ============================================================================

-- This query shows what the subscription-pricing Edge Function should return
-- (Matches the filter: is_active = true AND deprecated_at IS NULL)

SELECT
  spp.provider,
  sp.plan_code,
  spp.base_price_minor,
  spp.currency
FROM subscription_plan_providers spp
JOIN subscription_plans sp ON spp.plan_id = sp.id
WHERE spp.is_active = true
  AND spp.deprecated_at IS NULL  -- Future-proof filter
ORDER BY spp.provider, sp.tier;

-- ============================================================================
-- 10. CLEANUP TEST DATA (Use with Caution!)
-- ============================================================================

-- Delete test audit entries (if you created any during testing)
/*
DELETE FROM admin_subscription_price_audit
WHERE notes LIKE '%test%' OR notes LIKE '%Test%';
*/

-- Reset prices to original values (example)
/*
UPDATE subscription_plan_providers
SET base_price_minor = CASE
  WHEN plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'standard') THEN 7900
  WHEN plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'plus') THEN 14900
  WHEN plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'premium') THEN 49900
  ELSE base_price_minor
END
WHERE provider = 'razorpay';
*/

-- ============================================================================
-- QUICK REFERENCE: Common Queries
-- ============================================================================

-- View all pricing:
-- SELECT * FROM subscription_plan_providers ORDER BY provider;

-- Recent audit logs:
-- SELECT * FROM admin_price_change_history LIMIT 5;

-- Get plan_provider_id for Standard Razorpay:
-- SELECT id FROM subscription_plan_providers
-- WHERE plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'standard')
--   AND provider = 'razorpay';

-- Check if price update worked:
-- SELECT base_price_minor, updated_at, provider_plan_id
-- FROM subscription_plan_providers
-- WHERE id = 'YOUR_PLAN_PROVIDER_ID';

-- ============================================================================
-- END OF TESTING QUERIES
-- ============================================================================
