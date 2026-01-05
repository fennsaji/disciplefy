-- ============================================================================
-- Migration: Make fennsaji@gmail.com Admin and Premium User
-- Version: 1.1
-- Date: 2026-01-04
-- Description: Sets fennsaji@gmail.com as admin and grants premium subscription
--              Replaces the previous admin-only migration (20251128000005)
--              If user doesn't exist yet, this migration does nothing.
-- ============================================================================

-- Set admin status
UPDATE user_profiles
SET is_admin = true
WHERE id = (
  SELECT id FROM auth.users WHERE email = 'fennsaji@gmail.com'
);

-- Delete any existing subscription for this user first, then insert fresh
DELETE FROM subscriptions
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'fennsaji@gmail.com');

-- Insert premium subscription for the user (if they exist)
INSERT INTO subscriptions (
  user_id,
  razorpay_subscription_id,
  razorpay_plan_id,
  status,
  plan_type,
  current_period_start,
  current_period_end,
  amount_paise,
  currency
)
SELECT
  id,
  'sub_granted_admin_' || gen_random_uuid()::TEXT,
  'plan_premium_granted',
  'active',
  'premium',
  NOW(),
  NOW() + INTERVAL '100 years',  -- Effectively unlimited
  1,  -- 1 paise (minimal amount to satisfy constraint)
  'INR'
FROM auth.users
WHERE email = 'fennsaji@gmail.com';
