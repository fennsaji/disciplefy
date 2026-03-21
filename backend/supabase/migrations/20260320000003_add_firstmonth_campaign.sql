-- =====================================================
-- Add per-plan offer IDs support + FIRSTMONTH campaign
-- =====================================================
-- razorpay_offer_id (singular, from prev migration) works for campaigns
-- that have a single offer across all plans.
-- razorpay_offer_ids (JSONB) supports per-plan offer IDs within one
-- campaign code, enabling a single promo code to apply the correct
-- Razorpay offer per plan automatically.
--
-- Structure: {"standard": {"offer_id": "...", "discount_pct": 20}, ...}

ALTER TABLE public.promotional_campaigns
  ADD COLUMN IF NOT EXISTS razorpay_offer_ids JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.promotional_campaigns.razorpay_offer_ids IS
  'Per-plan Razorpay offer IDs. JSON map of plan_code → {offer_id, discount_pct}. '
  'Takes precedence over razorpay_offer_id when present for a given plan.';

-- =====================================================
-- Insert FIRSTMONTH campaign
-- =====================================================
-- LIVE (production) offer IDs. DB stores prod IDs as defaults.
-- For local/dev (TEST mode), override via env vars:
--   RAZORPAY_FIRSTMONTH_STANDARD_OFFER_ID
--   RAZORPAY_FIRSTMONTH_PLUS_OFFER_ID
--   RAZORPAY_FIRSTMONTH_PREMIUM_OFFER_ID
--
-- Standard (live): 20% off  → offer_STVuPLky21mATI
-- Plus (live):     30% off  → offer_STW01udBAiwIln
-- Premium (live):  50% off  → offer_STW1AcuuJZrx8R
-- All: Single Use (first billing cycle only), valid until 01-Apr-2027

INSERT INTO public.promotional_campaigns (
  campaign_code,
  campaign_name,
  description,
  discount_type,
  discount_value,
  applicable_plans,
  applicable_providers,
  valid_from,
  valid_until,
  max_uses_per_user,
  is_active,
  razorpay_offer_ids
) VALUES (
  'FIRSTMONTH',
  'First Month Discount',
  'Get up to 50% off your first month. Standard: 20% off, Plus: 30% off, Premium: 50% off.',
  'percentage',
  50,   -- max discount value (fallback); actual per-plan discount comes from razorpay_offer_ids
  ARRAY['standard', 'plus', 'premium'],
  ARRAY['razorpay'],
  NOW(),
  '2027-04-01 23:59:00+00',
  1,    -- each user can redeem once
  true,
  '{
    "standard": {"offer_id": "offer_STVuPLky21mATI", "discount_pct": 20},
    "plus":     {"offer_id": "offer_STW01udBAiwIln", "discount_pct": 30},
    "premium":  {"offer_id": "offer_STW1AcuuJZrx8R", "discount_pct": 50}
  }'::jsonb
);
