-- =====================================================
-- Update real Razorpay plan IDs for all subscription plans
-- =====================================================
-- LIVE (production) Razorpay plan IDs created on 2026-03-20.
-- These are the defaults stored in the DB for production use.
--
-- For local/dev (TEST mode), override via env vars:
--   RAZORPAY_PLUS_PLAN_ID, RAZORPAY_STANDARD_PLAN_ID, RAZORPAY_PREMIUM_PLAN_ID
-- The Edge Function (create-subscription-v2) prefers env vars over DB values.
--
--   Plus (live):     plan_STUG3w878ioVTt  (₹149/month)
--   Standard (live): plan_STUJSJekdifoS0  (₹99/month)
--   Premium (live):  plan_STUJqwDef6XAH8  (₹299/month)

-- Plus
UPDATE subscription_plan_providers
SET
  provider_plan_id = COALESCE(
    current_setting('app.razorpay_plus_plan_id', true),
    'plan_STUG3w878ioVTt'
  ),
  updated_at = NOW()
WHERE
  provider = 'razorpay'
  AND plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'plus');

-- Standard
UPDATE subscription_plan_providers
SET
  provider_plan_id = COALESCE(
    current_setting('app.razorpay_standard_plan_id', true),
    'plan_STUJSJekdifoS0'
  ),
  updated_at = NOW()
WHERE
  provider = 'razorpay'
  AND plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'standard');

-- Premium
UPDATE subscription_plan_providers
SET
  provider_plan_id = COALESCE(
    current_setting('app.razorpay_premium_plan_id', true),
    'plan_STUJqwDef6XAH8'
  ),
  updated_at = NOW()
WHERE
  provider = 'razorpay'
  AND plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'premium');
