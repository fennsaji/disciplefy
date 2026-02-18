-- =====================================================
-- Consolidated Migration: Seed Data
-- =====================================================
-- Source: Extracted from various seed data migrations
-- Description: Essential seed data for subscription plans,
--              provider configurations, and system defaults
-- =====================================================

-- Dependencies: 0004_subscription_system.sql (subscription_plans table must exist)

BEGIN;

-- =====================================================
-- SUMMARY: Migration seeds essential data
-- Completed 0001-0013 (schema + indexes), now seeding
-- subscription plans and provider configurations
-- =====================================================

-- =====================================================
-- PART 1: SUBSCRIPTION PLANS (4 TIERS)
-- =====================================================

-- Plan: Free (Tier 0)
-- Features: 3 daily tokens, limited study modes, no follow-ups
INSERT INTO subscription_plans (plan_code, plan_name, tier, interval, features, sort_order, description)
VALUES (
  'free',
  'Free Plan',
  0,
  'monthly',
  '{
    "daily_tokens": 3,
    "study_modes": ["quick"],
    "followups": 0,
    "ai_discipler": 0,
    "memory_verses": 2,
    "practice_modes": 4,
    "practice_limit": 1
  }'::jsonb,
  0,
  'Free plan with basic features'
) ON CONFLICT (plan_code) DO NOTHING;

-- Plan: Standard (Tier 1)
-- Features: 20 daily tokens, all study modes, 5 follow-ups, 3 AI conversations
INSERT INTO subscription_plans (plan_code, plan_name, tier, interval, features, sort_order, description)
VALUES (
  'standard',
  'Standard Monthly',
  1,
  'monthly',
  '{
    "daily_tokens": 20,
    "study_modes": ["all"],
    "followups": 5,
    "ai_discipler": 3,
    "memory_verses": 5,
    "practice_modes": 8,
    "practice_limit": 2
  }'::jsonb,
  1,
  'Standard plan - 20 daily tokens, 5 follow-ups, 3 AI conversations/month'
) ON CONFLICT (plan_code) DO NOTHING;

-- Plan: Plus (Tier 2)
-- Features: 50 daily tokens, all study modes, 10 follow-ups, 10 AI conversations
INSERT INTO subscription_plans (plan_code, plan_name, tier, interval, features, sort_order, description)
VALUES (
  'plus',
  'Plus Monthly',
  2,
  'monthly',
  '{
    "daily_tokens": 50,
    "study_modes": ["all"],
    "followups": 10,
    "ai_discipler": 10,
    "memory_verses": 10,
    "practice_modes": 8,
    "practice_limit": 3
  }'::jsonb,
  2,
  'Plus plan - 50 daily tokens, 10 follow-ups, 10 AI conversations/month'
) ON CONFLICT (plan_code) DO NOTHING;

-- Plan: Premium (Tier 3)
-- Features: Unlimited tokens and all features (-1 = unlimited)
INSERT INTO subscription_plans (plan_code, plan_name, tier, interval, features, sort_order, description)
VALUES (
  'premium',
  'Premium Monthly',
  3,
  'monthly',
  '{
    "daily_tokens": -1,
    "study_modes": ["all"],
    "followups": -1,
    "ai_discipler": -1,
    "memory_verses": -1,
    "practice_modes": 8,
    "practice_limit": -1
  }'::jsonb,
  3,
  'Premium plan - Unlimited tokens and features'
) ON CONFLICT (plan_code) DO NOTHING;

-- =====================================================
-- PART 2: PROVIDER CONFIGURATIONS (RAZORPAY)
-- =====================================================

-- Standard - Razorpay (₹79/month)
INSERT INTO subscription_plan_providers (plan_id, provider, provider_plan_id, base_price_minor, currency, region)
VALUES (
  (SELECT id FROM subscription_plans WHERE plan_code = 'standard'),
  'razorpay',
  COALESCE(current_setting('app.razorpay_standard_plan_id', true), 'plan_standard_placeholder'),
  7900,  -- ₹79.00 in paise
  'INR',
  'IN'
) ON CONFLICT (plan_id, provider, region) DO UPDATE
  SET base_price_minor = EXCLUDED.base_price_minor,
      updated_at = NOW();

-- Plus - Razorpay (₹149/month)
INSERT INTO subscription_plan_providers (plan_id, provider, provider_plan_id, base_price_minor, currency, region)
VALUES (
  (SELECT id FROM subscription_plans WHERE plan_code = 'plus'),
  'razorpay',
  COALESCE(current_setting('app.razorpay_plus_plan_id', true), 'plan_plus_placeholder'),
  14900,  -- ₹149.00 in paise
  'INR',
  'IN'
) ON CONFLICT (plan_id, provider, region) DO UPDATE
  SET base_price_minor = EXCLUDED.base_price_minor,
      updated_at = NOW();

-- Premium - Razorpay (₹499/month)
INSERT INTO subscription_plan_providers (plan_id, provider, provider_plan_id, base_price_minor, currency, region)
VALUES (
  (SELECT id FROM subscription_plans WHERE plan_code = 'premium'),
  'razorpay',
  COALESCE(current_setting('app.razorpay_premium_plan_id', true), 'plan_premium_placeholder'),
  49900,  -- ₹499.00 in paise
  'INR',
  'IN'
) ON CONFLICT (plan_id, provider, region) DO UPDATE
  SET base_price_minor = EXCLUDED.base_price_minor,
      updated_at = NOW();

-- =====================================================
-- PART 3: PROVIDER CONFIGURATIONS (GOOGLE PLAY)
-- =====================================================

-- Google Play configurations
-- Note: Product IDs are placeholders - update with actual Google Play SKUs
INSERT INTO subscription_plan_providers (plan_id, provider, provider_plan_id, base_price_minor, currency, region)
VALUES
  ((SELECT id FROM subscription_plans WHERE plan_code = 'standard'), 'google_play', 'com.disciplefy.standard.monthly', 7900, 'INR', 'IN'),
  ((SELECT id FROM subscription_plans WHERE plan_code = 'plus'), 'google_play', 'com.disciplefy.plus.monthly', 14900, 'INR', 'IN'),
  ((SELECT id FROM subscription_plans WHERE plan_code = 'premium'), 'google_play', 'com.disciplefy.premium.monthly', 49900, 'INR', 'IN')
ON CONFLICT (plan_id, provider, region) DO NOTHING;

-- =====================================================
-- PART 4: PROVIDER CONFIGURATIONS (APPLE APP STORE)
-- =====================================================

-- Apple App Store configurations
-- Note: Product IDs are placeholders - update with actual Apple product IDs
INSERT INTO subscription_plan_providers (plan_id, provider, provider_plan_id, base_price_minor, currency, region)
VALUES
  ((SELECT id FROM subscription_plans WHERE plan_code = 'standard'), 'apple_appstore', 'com.disciplefy.standard.monthly', 7900, 'INR', 'IN'),
  ((SELECT id FROM subscription_plans WHERE plan_code = 'plus'), 'apple_appstore', 'com.disciplefy.plus.monthly', 14900, 'INR', 'IN'),
  ((SELECT id FROM subscription_plans WHERE plan_code = 'premium'), 'apple_appstore', 'com.disciplefy.premium.monthly', 49900, 'INR', 'IN')
ON CONFLICT (plan_id, provider, region) DO NOTHING;

-- =====================================================
-- PART 5: COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON TABLE subscription_plans IS
  'Master subscription plan definitions with features and pricing.
   4 tiers: free (0), standard (1), plus (2), premium (3).
   Features stored as JSONB for flexibility.';

COMMENT ON TABLE subscription_plan_providers IS
  'Provider-specific pricing and external IDs for Razorpay, Google Play, Apple.
   Allows different pricing per provider and region.';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

COMMIT;

-- Verification query
SELECT
  'Migration 0014 Complete' as status,
  (SELECT COUNT(*) FROM subscription_plans) as plans_count,
  (SELECT COUNT(*) FROM subscription_plan_providers) as providers_count,
  (SELECT COUNT(DISTINCT provider) FROM subscription_plan_providers) as unique_providers;
