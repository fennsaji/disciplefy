-- ============================================================================
-- Migration: Make mustafabadchurch@gmail.com Premium User
-- Version: 1.0
-- Date: 2025-11-28
-- Description: Creates a premium subscription for mustafabadchurch@gmail.com
--              If user doesn't exist yet, this migration does nothing.
--              The subscription will be created when deployed to production
--              where the user exists.
-- ============================================================================

-- Delete any existing subscription for this user first, then insert fresh
DELETE FROM subscriptions 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mustafabadchurch@gmail.com');

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
  'sub_granted_' || gen_random_uuid()::TEXT,
  'plan_premium_granted',
  'active',
  'premium',
  NOW(),
  NOW() + INTERVAL '100 years',  -- Effectively unlimited
  0,
  'INR'
FROM auth.users 
WHERE email = 'mustafabadchurch@gmail.com';
