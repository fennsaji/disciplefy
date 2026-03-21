-- =====================================================
-- Add razorpay_offer_id to promotional_campaigns
-- =====================================================
-- Razorpay Offers API: create an offer in the Razorpay dashboard,
-- then store its offer_id here. When a user subscribes with this
-- promo code, the offer_id is passed to the subscription creation
-- API so Razorpay applies the discount natively on its checkout page.
--
-- If razorpay_offer_id is NULL the backend falls back to recording
-- the discount in our DB only (no actual Razorpay-side discount).

ALTER TABLE public.promotional_campaigns
  ADD COLUMN IF NOT EXISTS razorpay_offer_id TEXT;

COMMENT ON COLUMN public.promotional_campaigns.razorpay_offer_id IS
  'Razorpay Offer ID (e.g. offer_JHD834hjJH6Xn) — passed as offer_id when creating a Razorpay subscription to apply the discount on Razorpay checkout';
