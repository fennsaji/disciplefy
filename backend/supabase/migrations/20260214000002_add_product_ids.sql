-- Add Product ID Column to Subscription Plan Providers
-- Purpose: Add standardized IAP product ID format for all providers
-- Format: com.disciplefy.{plan_code}_monthly

-- ============================================================================
-- 1. Add product_id Column
-- ============================================================================

-- Add product_id column to subscription_plan_providers
ALTER TABLE subscription_plan_providers
  ADD COLUMN IF NOT EXISTS product_id TEXT;

-- Add index for product_id lookups
CREATE INDEX IF NOT EXISTS idx_subscription_plan_providers_product_id
  ON subscription_plan_providers(product_id);

-- Add comment
COMMENT ON COLUMN subscription_plan_providers.product_id IS
  'Standardized IAP product ID format: com.disciplefy.{plan_code}_monthly';

-- ============================================================================
-- 2. Seed Product IDs for Existing Plans
-- ============================================================================

-- Update product_id for all existing plan providers
-- Format: com.disciplefy.{plan_code}_monthly

-- Standard Plan Product IDs
UPDATE subscription_plan_providers
SET product_id = 'com.disciplefy.standard_monthly'
WHERE plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'standard')
  AND product_id IS NULL;

-- Plus Plan Product IDs
UPDATE subscription_plan_providers
SET product_id = 'com.disciplefy.plus_monthly'
WHERE plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'plus')
  AND product_id IS NULL;

-- Premium Plan Product IDs
UPDATE subscription_plan_providers
SET product_id = 'com.disciplefy.premium_monthly'
WHERE plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'premium')
  AND product_id IS NULL;

-- Free Plan (system-managed, but add for completeness)
UPDATE subscription_plan_providers
SET product_id = 'com.disciplefy.free_monthly'
WHERE plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'free')
  AND product_id IS NULL;

-- ============================================================================
-- 3. Verification
-- ============================================================================

-- Verify product IDs were added correctly
DO $$
DECLARE
  v_count INTEGER;
  v_standard_count INTEGER;
  v_plus_count INTEGER;
  v_premium_count INTEGER;
BEGIN
  -- Count total providers with product_id
  SELECT COUNT(*) INTO v_count
  FROM subscription_plan_providers
  WHERE product_id IS NOT NULL;

  -- Count by plan type
  SELECT COUNT(*) INTO v_standard_count
  FROM subscription_plan_providers spp
  INNER JOIN subscription_plans sp ON spp.plan_id = sp.id
  WHERE sp.plan_code = 'standard' AND spp.product_id IS NOT NULL;

  SELECT COUNT(*) INTO v_plus_count
  FROM subscription_plan_providers spp
  INNER JOIN subscription_plans sp ON spp.plan_id = sp.id
  WHERE sp.plan_code = 'plus' AND spp.product_id IS NOT NULL;

  SELECT COUNT(*) INTO v_premium_count
  FROM subscription_plan_providers spp
  INNER JOIN subscription_plans sp ON spp.plan_id = sp.id
  WHERE sp.plan_code = 'premium' AND spp.product_id IS NOT NULL;

  RAISE NOTICE '✅ Product IDs added successfully';
  RAISE NOTICE '   - Total providers with product_id: %', v_count;
  RAISE NOTICE '   - Standard plan providers: %', v_standard_count;
  RAISE NOTICE '   - Plus plan providers: %', v_plus_count;
  RAISE NOTICE '   - Premium plan providers: %', v_premium_count;
END $$;

-- Display current provider configuration with product IDs
SELECT
  sp.plan_code,
  sp.plan_name,
  spp.provider,
  spp.provider_plan_id,
  spp.product_id,
  spp.base_price_minor / 100 AS price_inr,
  spp.is_active
FROM subscription_plan_providers spp
INNER JOIN subscription_plans sp ON spp.plan_id = sp.id
ORDER BY sp.tier, spp.provider;

-- ============================================================================
-- Migration Complete
-- ============================================================================

-- Add migration metadata
COMMENT ON TABLE subscription_plan_providers IS
  'Provider-specific pricing and external IDs.
   provider_plan_id: Provider-specific ID (Razorpay plan_id, Google SKU, Apple product_id)
   product_id: Standardized IAP format (com.disciplefy.{plan_code}_monthly)';
