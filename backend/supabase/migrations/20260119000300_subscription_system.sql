-- =====================================================
-- Consolidated Migration: Subscription System
-- =====================================================
-- Source: Manual merge of subscription refactor + promo codes + free plan fixes
-- Tables: 8 (subscription_plans, subscription_plan_providers, subscriptions,
--            subscription_history, subscription_invoices, promotional_campaigns,
--            promotional_redemptions, plus plan data seeding)
-- Description: Complete multi-provider subscription system with promotional campaigns,
--              audit trail, invoice tracking, and provider-agnostic architecture
-- =====================================================

-- Dependencies: 0001_core_schema.sql (auth.users)

BEGIN;

-- =====================================================
-- SUMMARY: Migration creates comprehensive subscription infrastructure
-- Completed 0001 (11 tables), 0002 (6 tables), 0003 (2 tables)
-- Now creating 0004 with subscription system (8 tables: plans, providers,
-- subscriptions, history, invoices, promotional campaigns, redemptions)
-- =====================================================

-- =====================================================
-- PART 1: CREATE NEW TABLES
-- =====================================================

-- -----------------------------------------------------
-- Table: subscription_plans
-- Purpose: Master plan definitions (provider-agnostic)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_code TEXT UNIQUE NOT NULL,  -- 'free', 'standard', 'plus', 'premium'
  plan_name TEXT NOT NULL,
  tier INTEGER NOT NULL CHECK (tier IN (0, 1, 2, 3)),  -- 0=free, 1=standard, 2=plus, 3=premium
  interval TEXT NOT NULL CHECK (interval IN ('monthly', 'yearly')),
  features JSONB NOT NULL DEFAULT '{}'::jsonb,  -- {"daily_tokens": 20, "followups": 5, ...}
  marketing_features JSONB DEFAULT '[]'::jsonb, -- User-facing feature bullets for pricing UI
  is_active BOOLEAN DEFAULT true,
  is_visible BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.subscription_plans IS 'Master subscription plan definitions (provider-agnostic)';
COMMENT ON COLUMN public.subscription_plans.plan_code IS 'Unique plan identifier: free, standard, plus, premium';
COMMENT ON COLUMN public.subscription_plans.tier IS 'Plan tier for ordering: 0=free, 1=standard, 2=plus, 3=premium';
COMMENT ON COLUMN public.subscription_plans.features IS 'JSON object containing plan features and limits';
COMMENT ON COLUMN public.subscription_plans.marketing_features IS 'Array of user-facing feature bullet strings for pricing UI. Updated by marketing without app releases.';

-- Trigger for updated_at
CREATE TRIGGER set_subscription_plans_updated_at
  BEFORE UPDATE ON public.subscription_plans
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- -----------------------------------------------------
-- Table: subscription_plan_providers
-- Purpose: Provider-specific pricing and configuration
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscription_plan_providers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id UUID NOT NULL REFERENCES public.subscription_plans(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('razorpay', 'google_play', 'apple_appstore')),
  provider_plan_id TEXT NOT NULL,  -- Razorpay plan_id, Google SKU, Apple product_id
  base_price_minor INTEGER NOT NULL CHECK (base_price_minor > 0),  -- paise/cents
  currency TEXT NOT NULL DEFAULT 'INR',
  region TEXT DEFAULT 'IN',
  provider_metadata JSONB,  -- Additional provider-specific data
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (plan_id, provider, region)
);

COMMENT ON TABLE public.subscription_plan_providers IS 'Provider-specific pricing and external IDs';
COMMENT ON COLUMN public.subscription_plan_providers.provider IS 'Payment provider: razorpay, google_play, apple_appstore';
COMMENT ON COLUMN public.subscription_plan_providers.provider_plan_id IS 'External plan ID (Razorpay plan_id, Google SKU, Apple product_id)';
COMMENT ON COLUMN public.subscription_plan_providers.base_price_minor IS 'Price in smallest currency unit (paise for INR, cents for USD)';

-- Trigger for updated_at
CREATE TRIGGER set_subscription_plan_providers_updated_at
  BEFORE UPDATE ON public.subscription_plan_providers
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- -----------------------------------------------------
-- Table: promotional_campaigns
-- Purpose: Discount campaigns with eligibility rules
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.promotional_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_code TEXT UNIQUE NOT NULL,  -- 'WELCOME20', 'SAVE50', 'PREMIUM30'
  campaign_name TEXT NOT NULL,
  description TEXT,
  discount_type TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed_amount')),
  discount_value INTEGER NOT NULL CHECK (discount_value > 0),
  applicable_plans TEXT[] NOT NULL,  -- ['standard', 'plus'] or ['*'] for all
  applicable_providers TEXT[] NOT NULL,  -- ['razorpay'] or ['*'] for all
  valid_from TIMESTAMPTZ NOT NULL,
  valid_until TIMESTAMPTZ NOT NULL,
  max_total_uses INTEGER,  -- NULL = unlimited
  max_uses_per_user INTEGER DEFAULT 1,
  current_use_count INTEGER DEFAULT 0,
  new_users_only BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (valid_from < valid_until)
);

COMMENT ON TABLE public.promotional_campaigns IS 'Promotional discount campaigns with eligibility rules';
COMMENT ON COLUMN public.promotional_campaigns.discount_type IS 'percentage (e.g., 50 = 50% off) or fixed_amount (e.g., 1000 = ₹10 off)';
COMMENT ON COLUMN public.promotional_campaigns.applicable_plans IS 'Array of plan codes or [''*''] for all plans';
COMMENT ON COLUMN public.promotional_campaigns.new_users_only IS 'If true, only users who signed up after campaign start can use';

-- Trigger for updated_at
CREATE TRIGGER set_promotional_campaigns_updated_at
  BEFORE UPDATE ON public.promotional_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- -----------------------------------------------------
-- Table: subscriptions
-- Purpose: User subscription records (MUST exist before promotional_redemptions)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Provider Integration (multi-provider support)
  provider TEXT CHECK (provider IN ('trial', 'system', 'razorpay', 'google_play', 'apple_appstore')),
  provider_subscription_id TEXT,
  provider_plan_id TEXT,
  provider_customer_id TEXT,

  -- Subscription Plan Reference
  plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,

  -- Subscription Status
  status TEXT NOT NULL CHECK (status IN (
    'trial',               -- Trial period subscription (NEW)
    'created',              -- Initial state
    'in_progress',        -- Payment in progress
    'active',               -- Active subscription
    'pending_cancellation', -- Cancelled but still in grace period
    'paused',              -- Temporarily paused
    'cancelled',           -- User cancelled
    'completed',           -- Subscription period completed
    'expired'              -- Subscription expired without renewal
  )) DEFAULT 'created',

  -- Plan Type (deprecated - use plan_id instead)
  plan_type TEXT DEFAULT 'premium_monthly',

  -- Billing Cycle Information
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  next_billing_at TIMESTAMPTZ,

  -- Subscription Metadata
  total_count INTEGER,      -- Total billing cycles (e.g., 12 for annual)
  paid_count INTEGER DEFAULT 0,
  remaining_count INTEGER,

  -- Payment Details
  amount_paise INTEGER CHECK (amount_paise > 0),
  currency TEXT DEFAULT 'INR',

  -- Cancellation Information
  cancelled_at TIMESTAMPTZ,
  cancel_at_cycle_end BOOLEAN DEFAULT false,
  cancellation_reason TEXT,

  -- Promotional Campaign Support
  promotional_campaign_id UUID REFERENCES public.promotional_campaigns(id),
  discounted_price_minor INTEGER,

  -- Metadata (provider-specific data, promo codes, etc.)
  metadata JSONB DEFAULT '{}'::jsonb,
  provider_metadata JSONB,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CONSTRAINT valid_plan_type CHECK (
    plan_type IN (
      'free_tier', 'free_monthly',
      'standard_trial', 'standard_monthly', 'standard_yearly',
      'plus_monthly', 'plus_yearly',
      'premium_monthly', 'premium_yearly', 'premium_admin'
    )
  ),
  CONSTRAINT valid_billing_period CHECK (
    current_period_end IS NULL OR
    current_period_start IS NULL OR
    current_period_end > current_period_start
  ),
  CONSTRAINT cancelled_must_have_timestamp CHECK (
    status != 'cancelled' OR cancelled_at IS NOT NULL
  )
);

-- Unique constraint on provider subscription IDs
CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_provider_subscription_id_unique
  ON subscriptions(provider_subscription_id) WHERE provider_subscription_id IS NOT NULL;

-- Indexes for subscriptions
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_provider ON subscriptions(provider);
CREATE INDEX IF NOT EXISTS idx_subscriptions_plan_id ON subscriptions(plan_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_current_period_end ON subscriptions(current_period_end);

-- Index for trial subscriptions (for efficient expiry queries)
CREATE INDEX IF NOT EXISTS idx_subscriptions_trial_status
  ON subscriptions(status, current_period_end)
  WHERE status = 'trial';

-- Remove old partial unique index (if it exists)
DROP INDEX IF EXISTS unique_active_subscription_per_user;
DROP INDEX IF EXISTS idx_subscriptions_active_trial_per_user;

-- Unique constraint: ONE subscription per user (total, not just active)
-- This prevents database clutter and ensures clean subscription history
-- When subscription changes (e.g., active → cancelled), UPDATE the same record
CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_one_per_user
  ON subscriptions(user_id);

-- Comments
COMMENT ON TABLE subscriptions IS
  'User subscription records with multi-provider support (Razorpay, Google Play, Apple App Store)';
COMMENT ON COLUMN subscriptions.provider IS 'Payment provider used for this subscription';
COMMENT ON COLUMN subscriptions.provider_subscription_id IS 'External subscription ID from payment provider';
COMMENT ON COLUMN subscriptions.promotional_campaign_id IS 'Promotional campaign applied (if any)';
COMMENT ON COLUMN subscriptions.discounted_price_minor IS 'Final price after discount (if promo applied)';

-- Trigger for updated_at
CREATE TRIGGER set_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- -----------------------------------------------------
-- Table: subscription_history
-- Purpose: Audit trail for subscription events
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS subscription_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Event Information
  event_type TEXT NOT NULL CHECK (event_type IN (
    'created',
    'in_progress',
    'activated',
    'charged',
    'payment_failed',
    'paused',
    'resumed',
    'cancelled',
    'completed',
    'expired'
  )),

  -- State Snapshot
  old_status TEXT,
  new_status TEXT,

  -- Payment Information
  amount_paise INTEGER,
  currency TEXT,
  payment_id TEXT,

  -- Provider Event Data
  provider TEXT NOT NULL,
  provider_event_id TEXT,
  provider_data JSONB,

  -- Metadata
  notes TEXT,

  -- Timestamps
  event_timestamp TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for subscription_history
CREATE INDEX IF NOT EXISTS idx_subscription_history_subscription_id
  ON subscription_history(subscription_id, event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_subscription_history_user_id
  ON subscription_history(user_id, event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_subscription_history_event_type
  ON subscription_history(event_type);

-- Comments
COMMENT ON TABLE subscription_history IS
  'Audit trail of all subscription events and state changes';

-- -----------------------------------------------------
-- Table: subscription_invoices
-- Purpose: Invoice records for subscription billing
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS subscription_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Invoice Identification
  invoice_number TEXT UNIQUE NOT NULL,
  provider_invoice_id TEXT,

  -- Billing Information
  amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
  currency TEXT NOT NULL DEFAULT 'INR',
  billing_period_start DATE NOT NULL,
  billing_period_end DATE NOT NULL,

  -- Payment Details
  status TEXT NOT NULL CHECK (status IN (
    'pending',
    'paid',
    'failed',
    'refunded',
    'cancelled'
  )) DEFAULT 'pending',
  paid_at TIMESTAMPTZ,
  payment_method TEXT,

  -- Provider Integration
  provider TEXT NOT NULL,
  provider_payment_id TEXT,
  provider_data JSONB,

  -- Timestamps
  issued_at TIMESTAMPTZ DEFAULT NOW(),
  due_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for subscription_invoices
CREATE INDEX IF NOT EXISTS idx_subscription_invoices_subscription_id
  ON subscription_invoices(subscription_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_subscription_invoices_user_id
  ON subscription_invoices(user_id, issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_subscription_invoices_status
  ON subscription_invoices(status);
CREATE INDEX IF NOT EXISTS idx_subscription_invoices_invoice_number
  ON subscription_invoices(invoice_number);

-- Comments
COMMENT ON TABLE subscription_invoices IS
  'Invoice records for subscription billing with payment tracking';

-- Trigger for updated_at
CREATE TRIGGER set_subscription_invoices_updated_at
  BEFORE UPDATE ON subscription_invoices
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- -----------------------------------------------------
-- Table: promotional_redemptions
-- Purpose: Audit trail of promotional code usage
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.promotional_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES public.promotional_campaigns(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_id UUID NOT NULL REFERENCES public.subscriptions(id) ON DELETE CASCADE,
  discount_amount_minor INTEGER NOT NULL,
  original_price_minor INTEGER NOT NULL,
  final_price_minor INTEGER NOT NULL,
  provider TEXT NOT NULL,
  plan_code TEXT NOT NULL,
  redeemed_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.promotional_redemptions IS 'Audit trail of all promotional code redemptions';
COMMENT ON COLUMN public.promotional_redemptions.discount_amount_minor IS 'Actual discount applied in smallest currency unit';

-- =====================================================
-- PART 2: ADD COLUMN COMMENTS (columns defined in CREATE TABLE above)
-- =====================================================

-- Column comments for subscriptions table
COMMENT ON COLUMN public.subscriptions.plan_id IS 'Reference to subscription_plans table';
COMMENT ON COLUMN public.subscriptions.provider IS 'Payment provider used for this subscription';
COMMENT ON COLUMN public.subscriptions.provider_subscription_id IS 'External subscription ID from payment provider';
COMMENT ON COLUMN public.subscriptions.promotional_campaign_id IS 'Promotional campaign applied (if any)';
COMMENT ON COLUMN public.subscriptions.discounted_price_minor IS 'Final price after discount (if promo applied)';

-- =====================================================
-- PART 3: INSERT PLAN DATA (WITH FREE PLAN FIX)
-- =====================================================

-- Insert Free plan
-- CRITICAL FIX: Set practice_modes to 2 (not 8) per specification
-- Source: 20260118000005_fix_free_plan_practice_modes.sql
INSERT INTO public.subscription_plans (plan_code, plan_name, tier, interval, features, marketing_features, sort_order, description)
VALUES (
  'free',
  'Free',
  0,
  'monthly',
  '{
    "daily_tokens": 8,
    "study_modes": ["all"],
    "followups": 0,
    "ai_discipler": 1,
    "memory_verses": 3,
    "practice_modes": 2,
    "practice_limit": 1
  }'::jsonb,
  '[
    "Daily Bible Verse",
    "8 Study Tokens/Day",
    "All Study Modes (Limited Tokens)",
    "Guided Learning Paths",
    "Memorize up to 3 Verses",
    "2 Memory Verse Practice Modes",
    "Follow-Up on Study Guides — Not Included",
    "Disciple AI — Not Included"
  ]'::jsonb,
  0,
  'Free plan with basic features (Flip Card, Type It Out practice modes)'
) ON CONFLICT (plan_code) DO UPDATE
  SET features = EXCLUDED.features,
      marketing_features = EXCLUDED.marketing_features,
      updated_at = NOW();

-- Insert Standard plan
INSERT INTO public.subscription_plans (plan_code, plan_name, tier, interval, features, marketing_features, sort_order, description)
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
  '[
    "Daily Bible Verse",
    "20 Study Tokens/Day",
    "All Study Modes (Limited Tokens)",
    "Guided Learning Paths",
    "Memorize up to 5 Verses",
    "All 8 Memory Verse Practice Modes",
    "5 Follow-Up per Study Guide",
    "Disciple AI — 3 Sessions/Month"
  ]'::jsonb,
  1,
  'Standard plan - 20 daily tokens, 5 follow-ups, 3 AI conversations/month'
) ON CONFLICT (plan_code) DO UPDATE
  SET features = EXCLUDED.features,
      marketing_features = EXCLUDED.marketing_features,
      updated_at = NOW();

-- Insert Plus plan
INSERT INTO public.subscription_plans (plan_code, plan_name, tier, interval, features, marketing_features, sort_order, description)
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
  '[
    "Daily Bible Verse",
    "50 Study Tokens/Day",
    "All Study Modes",
    "Guided Learning Paths",
    "Memorize up to 10 Verses",
    "All 8 Memory Verse Practice Modes",
    "10 Follow-Up per Study Guide",
    "Disciple AI — 10 Sessions/Month"
  ]'::jsonb,
  2,
  'Plus plan - 50 daily tokens, 10 follow-ups, 10 AI conversations/month'
) ON CONFLICT (plan_code) DO UPDATE
  SET features = EXCLUDED.features,
      marketing_features = EXCLUDED.marketing_features,
      updated_at = NOW();

-- Insert Premium plan
INSERT INTO public.subscription_plans (plan_code, plan_name, tier, interval, features, marketing_features, sort_order, description)
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
  '[
    "Daily Bible Verse",
    "Unlimited Study Tokens",
    "All Study Modes",
    "Guided Learning Paths",
    "Memorize Unlimited Verses",
    "All 8 Memory Verse Practice Modes",
    "Unlimited Follow-Up per Study Guide",
    "Disciple AI — Unlimited"
  ]'::jsonb,
  3,
  'Premium plan - Unlimited tokens and features'
) ON CONFLICT (plan_code) DO UPDATE
  SET features = EXCLUDED.features,
      marketing_features = EXCLUDED.marketing_features,
      updated_at = NOW();

-- =====================================================
-- PART 4: INSERT PROVIDER CONFIGURATIONS
-- =====================================================

-- Razorpay configurations (Updated: 2026-01-18)
-- Standard - Razorpay (₹79.00)
INSERT INTO public.subscription_plan_providers (plan_id, provider, provider_plan_id, base_price_minor, currency, region)
VALUES (
  (SELECT id FROM public.subscription_plans WHERE plan_code = 'standard'),
  'razorpay',
  COALESCE(current_setting('app.razorpay_standard_plan_id', true), 'plan_RoJtEiu7dU8Xgz'),
  7900,  -- ₹79.00
  'INR',
  'IN'
) ON CONFLICT (plan_id, provider, region) DO UPDATE
  SET base_price_minor = EXCLUDED.base_price_minor,
      updated_at = NOW();

-- Plus - Razorpay (₹149.00)
INSERT INTO public.subscription_plan_providers (plan_id, provider, provider_plan_id, base_price_minor, currency, region)
VALUES (
  (SELECT id FROM public.subscription_plans WHERE plan_code = 'plus'),
  'razorpay',
  COALESCE(current_setting('app.razorpay_plus_plan_id', true), 'plan_plus_placeholder'),
  14900,  -- ₹149.00
  'INR',
  'IN'
) ON CONFLICT (plan_id, provider, region) DO UPDATE
  SET base_price_minor = EXCLUDED.base_price_minor,
      updated_at = NOW();

-- Premium - Razorpay (₹499.00)
INSERT INTO public.subscription_plan_providers (plan_id, provider, provider_plan_id, base_price_minor, currency, region)
VALUES (
  (SELECT id FROM public.subscription_plans WHERE plan_code = 'premium'),
  'razorpay',
  COALESCE(current_setting('app.razorpay_premium_plan_id', true), 'plan_RcMPwlqIkuiMQb'),
  49900,  -- ₹499.00
  'INR',
  'IN'
) ON CONFLICT (plan_id, provider, region) DO UPDATE
  SET base_price_minor = EXCLUDED.base_price_minor,
      updated_at = NOW();

-- Google Play configurations (placeholder SKUs - to be updated)
INSERT INTO public.subscription_plan_providers (plan_id, provider, provider_plan_id, base_price_minor, currency, region)
VALUES
  ((SELECT id FROM public.subscription_plans WHERE plan_code = 'standard'), 'google_play', 'com.disciplefy.standard.monthly', 7900, 'INR', 'IN'),
  ((SELECT id FROM public.subscription_plans WHERE plan_code = 'plus'), 'google_play', 'com.disciplefy.plus.monthly', 14900, 'INR', 'IN'),
  ((SELECT id FROM public.subscription_plans WHERE plan_code = 'premium'), 'google_play', 'com.disciplefy.premium.monthly', 49900, 'INR', 'IN')
ON CONFLICT (plan_id, provider, region) DO NOTHING;

-- Apple App Store configurations (placeholder product IDs - to be updated)
INSERT INTO public.subscription_plan_providers (plan_id, provider, provider_plan_id, base_price_minor, currency, region)
VALUES
  ((SELECT id FROM public.subscription_plans WHERE plan_code = 'standard'), 'apple_appstore', 'com.disciplefy.standard.monthly', 7900, 'INR', 'IN'),
  ((SELECT id FROM public.subscription_plans WHERE plan_code = 'plus'), 'apple_appstore', 'com.disciplefy.plus.monthly', 14900, 'INR', 'IN'),
  ((SELECT id FROM public.subscription_plans WHERE plan_code = 'premium'), 'apple_appstore', 'com.disciplefy.premium.monthly', 49900, 'INR', 'IN')
ON CONFLICT (plan_id, provider, region) DO NOTHING;

-- =====================================================
-- PART 5: MIGRATE EXISTING SUBSCRIPTION DATA
-- =====================================================

-- NOTE: This section is no longer needed since we removed razorpay_* columns
-- All subscriptions now use the generic provider_* columns from the start

-- =====================================================
-- PART 6: SAMPLE PROMOTIONAL CAMPAIGNS
-- =====================================================
-- Source: 20260118000004_add_sample_promo_codes.sql

-- Insert sample promotional campaigns
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
  max_total_uses,
  max_uses_per_user,
  current_use_count,
  new_users_only,
  is_active
) VALUES
  -- 20% off all plans - Welcome offer for new users
  (
    'WELCOME20',
    'Welcome Discount 20%',
    'Get 20% off on all plans - Welcome offer for new users!',
    'percentage',
    20,
    ARRAY['*'], -- Applies to all plans
    ARRAY['*'], -- Applies to all providers
    NOW() - INTERVAL '1 day',
    NOW() + INTERVAL '30 days',
    1000,
    1,
    0,
    true, -- New users only
    true
  ),
  -- 50% off Standard plan only
  (
    'SAVE50',
    '50% Off Standard Plan',
    'Special 50% discount on Standard plan - Best value!',
    'percentage',
    50,
    ARRAY['standard'], -- Applies only to Standard plan
    ARRAY['razorpay'],
    NOW() - INTERVAL '1 day',
    NOW() + INTERVAL '60 days',
    500,
    1,
    0,
    false,
    true
  ),
  -- 30% off Premium plan
  (
    'PREMIUM30',
    '30% Off Premium Plan',
    'Get 30% off Premium plan - Unlock all features!',
    'percentage',
    30,
    ARRAY['premium'], -- Applies only to Premium plan
    ARRAY['razorpay', 'google_play', 'apple_appstore'],
    NOW() - INTERVAL '1 day',
    NOW() + INTERVAL '15 days',
    100,
    1,
    0,
    false,
    true
  ),
  -- 10% off Plus plan
  (
    'PLUS10',
    '10% Off Plus Plan',
    'Save 10% on Plus plan - Great for regular users!',
    'percentage',
    10,
    ARRAY['plus'], -- Applies only to Plus plan
    ARRAY['razorpay'],
    NOW() - INTERVAL '1 day',
    NOW() + INTERVAL '45 days',
    200,
    1,
    0,
    false,
    true
  )
ON CONFLICT (campaign_code) DO NOTHING;

-- =====================================================
-- PART 7: CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Indexes on subscription_plans
CREATE INDEX IF NOT EXISTS idx_subscription_plans_active ON public.subscription_plans(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_subscription_plans_visible ON public.subscription_plans(is_visible) WHERE is_visible = true;
CREATE INDEX IF NOT EXISTS idx_subscription_plans_tier ON public.subscription_plans(tier);

-- Indexes on subscription_plan_providers
CREATE INDEX IF NOT EXISTS idx_plan_providers_plan ON public.subscription_plan_providers(plan_id);
CREATE INDEX IF NOT EXISTS idx_plan_providers_provider ON public.subscription_plan_providers(provider);
CREATE INDEX IF NOT EXISTS idx_plan_providers_active ON public.subscription_plan_providers(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_plan_providers_region ON public.subscription_plan_providers(region);

-- Indexes on promotional_campaigns
CREATE INDEX IF NOT EXISTS idx_promo_campaigns_active ON public.promotional_campaigns(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_promo_campaigns_validity ON public.promotional_campaigns(valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_promo_campaigns_code ON public.promotional_campaigns(campaign_code);

-- Indexes on promotional_redemptions
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_campaign ON public.promotional_redemptions(campaign_id);
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_user ON public.promotional_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_subscription ON public.promotional_redemptions(subscription_id);

-- Indexes on subscriptions (new columns)
-- COMMENTED OUT: These indexes are already created on lines 200-204 above
-- CREATE INDEX IF NOT EXISTS idx_subscriptions_plan ON public.subscriptions(plan_id);
-- CREATE INDEX IF NOT EXISTS idx_subscriptions_provider ON public.subscriptions(provider);
-- Note: idx_subscriptions_promo is unique and not created elsewhere, keeping active
CREATE INDEX IF NOT EXISTS idx_subscriptions_promo ON public.subscriptions(promotional_campaign_id) WHERE promotional_campaign_id IS NOT NULL;

-- =====================================================
-- PART 8: ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on new tables
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_plan_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotional_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotional_redemptions ENABLE ROW LEVEL SECURITY;

-- Enable RLS on main subscription tables (SECURITY FIX)
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_invoices ENABLE ROW LEVEL SECURITY;

-- subscription_plans: Public read access (all users can see available plans)
CREATE POLICY "Public can view active plans"
  ON public.subscription_plans FOR SELECT
  USING (is_active = true AND is_visible = true);

-- subscription_plan_providers: Public read access (all users can see pricing)
CREATE POLICY "Public can view active provider pricing"
  ON public.subscription_plan_providers FOR SELECT
  USING (is_active = true);

-- promotional_campaigns: Public read for active campaigns
CREATE POLICY "Public can view active campaigns"
  ON public.promotional_campaigns FOR SELECT
  USING (is_active = true AND valid_from <= NOW() AND valid_until >= NOW());

-- promotional_redemptions: Users can only see their own redemptions
CREATE POLICY "Users can view own redemptions"
  ON public.promotional_redemptions FOR SELECT
  USING (auth.uid() = user_id);

-- subscriptions: Users can only view their own subscription
CREATE POLICY "Users can view own subscription"
  ON public.subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- subscriptions: Service role has full access
CREATE POLICY "Service role can manage subscriptions"
  ON public.subscriptions FOR ALL
  USING (auth.role() = 'service_role');

-- subscription_history: Users can only view their own history
CREATE POLICY "Users can view own subscription history"
  ON public.subscription_history FOR SELECT
  USING (auth.uid() = user_id);

-- subscription_history: Service role has full access
CREATE POLICY "Service role can manage subscription history"
  ON public.subscription_history FOR ALL
  USING (auth.role() = 'service_role');

-- subscription_invoices: Users can only view their own invoices
CREATE POLICY "Users can view own invoices"
  ON public.subscription_invoices FOR SELECT
  USING (auth.uid() = user_id);

-- subscription_invoices: Service role has full access
CREATE POLICY "Service role can manage invoices"
  ON public.subscription_invoices FOR ALL
  USING (auth.role() = 'service_role');

-- =====================================================
-- PART 8.5: SUBSCRIPTION CONSTRAINTS AND VALIDATION
-- =====================================================

-- Pre-migration data fixes
-- Fix cancelled subscriptions without cancelled_at timestamp
UPDATE subscriptions
SET cancelled_at = COALESCE(updated_at, NOW())
WHERE status = 'cancelled' AND cancelled_at IS NULL;

-- Fix invalid billing periods (end before start)
WITH invalid_periods AS (
  SELECT id, current_period_start, current_period_end
  FROM subscriptions
  WHERE current_period_end IS NOT NULL
    AND current_period_start IS NOT NULL
    AND current_period_end <= current_period_start
)
UPDATE subscriptions s
SET
  current_period_start = ip.current_period_end,
  current_period_end = ip.current_period_start
FROM invalid_periods ip
WHERE s.id = ip.id;

-- Ensure all subscriptions have a plan_id
UPDATE subscriptions
SET plan_id = (SELECT id FROM subscription_plans WHERE plan_code = 'free' LIMIT 1)
WHERE plan_id IS NULL;

-- Status transition validation function
CREATE OR REPLACE FUNCTION validate_subscription_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Allow service_role to bypass validation
  IF current_setting('role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Cannot reactivate cancelled subscription
  IF OLD.status = 'cancelled' AND NEW.status IN ('active', 'in_progress', 'trial') THEN
    RAISE EXCEPTION 'Cannot reactivate cancelled subscription. Create a new subscription instead.';
  END IF;

  -- Cannot modify completed subscription
  IF OLD.status = 'completed' AND NEW.status != 'completed' THEN
    RAISE EXCEPTION 'Cannot modify completed subscription';
  END IF;

  -- Cannot reactivate expired subscription
  IF OLD.status = 'expired' AND NEW.status NOT IN ('expired', 'cancelled') THEN
    RAISE EXCEPTION 'Cannot reactivate expired subscription. Create a new subscription instead.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_status_transitions ON subscriptions;

CREATE TRIGGER enforce_status_transitions
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION validate_subscription_status();

-- =====================================================
-- PART 9: HELPER FUNCTIONS
-- =====================================================

-- Function to get plan details with pricing
CREATE OR REPLACE FUNCTION public.get_plan_with_pricing(
  p_plan_code TEXT,
  p_provider TEXT DEFAULT 'razorpay',
  p_region TEXT DEFAULT 'IN'
)
RETURNS TABLE (
  plan_id UUID,
  plan_code TEXT,
  plan_name TEXT,
  tier INTEGER,
  features JSONB,
  provider TEXT,
  provider_plan_id TEXT,
  base_price_minor INTEGER,
  currency TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    sp.id AS plan_id,
    sp.plan_code,
    sp.plan_name,
    sp.tier,
    sp.features,
    spp.provider,
    spp.provider_plan_id,
    spp.base_price_minor,
    spp.currency
  FROM public.subscription_plans sp
  INNER JOIN public.subscription_plan_providers spp ON sp.id = spp.plan_id
  WHERE sp.plan_code = p_plan_code
    AND spp.provider = p_provider
    AND spp.region = p_region
    AND sp.is_active = true
    AND spp.is_active = true;
END;
$$;

COMMENT ON FUNCTION public.get_plan_with_pricing IS 'Retrieve plan details with provider-specific pricing';

-- Function to validate promotional code
CREATE OR REPLACE FUNCTION public.validate_promo_code(
  p_campaign_code TEXT,
  p_user_id UUID,
  p_plan_code TEXT DEFAULT NULL
)
RETURNS TABLE (
  valid BOOLEAN,
  campaign_id UUID,
  discount_type TEXT,
  discount_value INTEGER,
  message TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_campaign RECORD;
  v_user_created_at TIMESTAMPTZ;
  v_user_redemption_count INTEGER;
BEGIN
  -- Check if campaign exists and is active
  SELECT * INTO v_campaign
  FROM public.promotional_campaigns
  WHERE campaign_code = p_campaign_code
    AND is_active = true
    AND valid_from <= NOW()
    AND valid_until >= NOW();

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, NULL::INTEGER, 'Invalid or expired promotional code';
    RETURN;
  END IF;

  -- Check total usage limit
  IF v_campaign.max_total_uses IS NOT NULL AND v_campaign.current_use_count >= v_campaign.max_total_uses THEN
    RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, NULL::INTEGER, 'Promotional code usage limit reached';
    RETURN;
  END IF;

  -- Check user-specific usage limit
  SELECT COUNT(*) INTO v_user_redemption_count
  FROM public.promotional_redemptions
  WHERE campaign_id = v_campaign.id AND user_id = p_user_id;

  IF v_user_redemption_count >= v_campaign.max_uses_per_user THEN
    RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, NULL::INTEGER, 'You have already used this promotional code';
    RETURN;
  END IF;

  -- Check new user eligibility
  IF v_campaign.new_users_only THEN
    SELECT created_at INTO v_user_created_at
    FROM auth.users
    WHERE id = p_user_id;

    IF v_user_created_at < v_campaign.valid_from THEN
      RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, NULL::INTEGER, 'This promotion is only for new users';
      RETURN;
    END IF;
  END IF;

  -- Check plan applicability
  IF p_plan_code IS NOT NULL THEN
    IF NOT (v_campaign.applicable_plans @> ARRAY['*'] OR p_plan_code = ANY(v_campaign.applicable_plans)) THEN
      RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, NULL::INTEGER, 'This promotional code is not applicable to the selected plan';
      RETURN;
    END IF;
  END IF;

  -- Valid promotional code
  RETURN QUERY SELECT
    true,
    v_campaign.id,
    v_campaign.discount_type,
    v_campaign.discount_value,
    'Promotional code is valid';
END;
$$;

COMMENT ON FUNCTION public.validate_promo_code IS 'Validate promotional code eligibility for user and plan';

-- Function to apply promotional discount
CREATE OR REPLACE FUNCTION public.apply_promo_discount(
  p_base_price_minor INTEGER,
  p_discount_type TEXT,
  p_discount_value INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_discount_amount INTEGER;
BEGIN
  IF p_discount_type = 'percentage' THEN
    -- Calculate percentage discount
    v_discount_amount := FLOOR((p_base_price_minor * p_discount_value) / 100.0);
  ELSIF p_discount_type = 'fixed_amount' THEN
    -- Use fixed amount (capped at base price)
    v_discount_amount := LEAST(p_discount_value, p_base_price_minor);
  ELSE
    RAISE EXCEPTION 'Invalid discount type: %', p_discount_type;
  END IF;

  -- Return final price (minimum 0)
  RETURN GREATEST(p_base_price_minor - v_discount_amount, 0);
END;
$$;

COMMENT ON FUNCTION public.apply_promo_discount IS 'Calculate final price after applying promotional discount';

-- Function to check if user has active subscription
CREATE OR REPLACE FUNCTION public.has_active_subscription(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.subscriptions
    WHERE user_id = p_user_id
      AND status = 'active'
      AND (end_date IS NULL OR end_date > NOW())
  );
END;
$$;

COMMENT ON FUNCTION public.has_active_subscription IS 'Check if user has an active subscription';

-- =====================================================
-- PART 10: SUBSCRIPTION CONFIG AND USER PREFERENCES
-- =====================================================
-- Source: 20251210000001_post_trial_user_plan_system.sql

CREATE TABLE IF NOT EXISTS public.subscription_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.subscription_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "subscription_config_read_policy" ON public.subscription_config;
CREATE POLICY "subscription_config_read_policy" ON public.subscription_config
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "subscription_config_anon_read_policy" ON public.subscription_config;
CREATE POLICY "subscription_config_anon_read_policy" ON public.subscription_config
  FOR SELECT TO anon USING (true);

INSERT INTO public.subscription_config (key, value, description) VALUES
  ('standard_trial_end_date', '2026-03-31T23:59:59+05:30', 'End date for Standard plan free trial period'),
  ('grace_period_days', '7', 'Number of days grace period after trial ends'),
  ('grace_period_end_date', '2026-04-07T23:59:59+05:30', 'End date for grace period after trial ends')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

CREATE TABLE IF NOT EXISTS public.user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  preferred_plan TEXT DEFAULT 'standard' CHECK (preferred_plan IN ('free', 'standard', 'plus', 'premium')),
  learning_path_study_mode TEXT DEFAULT 'recommended' CHECK (
    learning_path_study_mode IN ('ask', 'recommended', 'quick', 'standard', 'deep', 'lectio', 'sermon')
  ),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

COMMENT ON TABLE public.user_preferences IS
  'User preferences for subscription plans and learning path study modes';
COMMENT ON COLUMN public.user_preferences.learning_path_study_mode IS
  'Preferred study mode for learning path topics: ask, recommended (default), or specific mode';

ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_preferences_select_own" ON public.user_preferences;
CREATE POLICY "user_preferences_select_own" ON public.user_preferences
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_preferences_insert_own" ON public.user_preferences;
CREATE POLICY "user_preferences_insert_own" ON public.user_preferences
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_preferences_update_own" ON public.user_preferences;
CREATE POLICY "user_preferences_update_own" ON public.user_preferences
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION update_user_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS user_preferences_updated_at_trigger ON public.user_preferences;
CREATE TRIGGER user_preferences_updated_at_trigger
  BEFORE UPDATE ON public.user_preferences
  FOR EACH ROW EXECUTE FUNCTION update_user_preferences_updated_at();

-- =====================================================
-- PART 11: TRIAL/GRACE PERIOD HELPER FUNCTIONS
-- =====================================================

CREATE OR REPLACE FUNCTION get_standard_trial_end_date()
RETURNS TIMESTAMPTZ LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_trial_end_date TIMESTAMPTZ;
BEGIN
  SELECT value::TIMESTAMPTZ INTO v_trial_end_date FROM subscription_config WHERE key = 'standard_trial_end_date';
  RETURN COALESCE(v_trial_end_date, '2026-03-31T23:59:59+05:30'::TIMESTAMPTZ);
END; $$;

CREATE OR REPLACE FUNCTION get_grace_period_end_date()
RETURNS TIMESTAMPTZ LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_grace_end_date TIMESTAMPTZ;
BEGIN
  SELECT value::TIMESTAMPTZ INTO v_grace_end_date FROM subscription_config WHERE key = 'grace_period_end_date';
  RETURN COALESCE(v_grace_end_date, '2026-04-07T23:59:59+05:30'::TIMESTAMPTZ);
END; $$;

CREATE OR REPLACE FUNCTION is_standard_trial_active()
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN NOW() <= get_standard_trial_end_date(); END; $$;

CREATE OR REPLACE FUNCTION is_in_grace_period()
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN NOW() > get_standard_trial_end_date() AND NOW() <= get_grace_period_end_date();
END; $$;

CREATE OR REPLACE FUNCTION get_days_until_trial_end()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN GREATEST(EXTRACT(DAY FROM (get_standard_trial_end_date() - NOW())), 0); END; $$;

CREATE OR REPLACE FUNCTION get_grace_days_remaining()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN RETURN GREATEST(EXTRACT(DAY FROM (get_grace_period_end_date() - NOW())), 0); END; $$;

CREATE OR REPLACE FUNCTION was_eligible_for_trial(p_user_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_user_created_at TIMESTAMPTZ;
BEGIN
  SELECT created_at INTO v_user_created_at FROM auth.users WHERE id = p_user_id;
  RETURN v_user_created_at <= get_standard_trial_end_date();
END; $$;

CREATE OR REPLACE FUNCTION get_user_created_at(p_user_id UUID)
RETURNS TIMESTAMPTZ LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_created_at TIMESTAMPTZ;
BEGIN
  SELECT created_at INTO v_created_at FROM auth.users WHERE id = p_user_id;
  RETURN v_created_at;
END; $$;

-- =====================================================
-- PART 12: PREMIUM TRIAL FUNCTIONS
-- =====================================================

CREATE OR REPLACE FUNCTION is_in_premium_trial(p_user_id UUID)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_trial_started_at TIMESTAMPTZ;
  v_trial_end_at TIMESTAMPTZ;
BEGIN
  SELECT premium_trial_started_at, premium_trial_end_at
  INTO v_trial_started_at, v_trial_end_at
  FROM user_profiles WHERE id = p_user_id;

  IF v_trial_started_at IS NULL THEN RETURN FALSE; END IF;
  RETURN NOW() >= v_trial_started_at AND NOW() < v_trial_end_at;
END; $$;

CREATE OR REPLACE FUNCTION get_premium_trial_status(p_user_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_profile RECORD;
  v_is_in_trial BOOLEAN;
  v_days_remaining INTEGER;
  v_has_used_trial BOOLEAN;
  v_can_start_trial BOOLEAN;
  v_has_active_subscription BOOLEAN;
BEGIN
  SELECT premium_trial_started_at, premium_trial_end_at INTO v_profile
  FROM user_profiles WHERE id = p_user_id;

  v_has_used_trial := v_profile.premium_trial_started_at IS NOT NULL;
  v_is_in_trial := is_in_premium_trial(p_user_id);

  IF v_is_in_trial THEN
    v_days_remaining := EXTRACT(DAY FROM (v_profile.premium_trial_end_at - NOW()));
  ELSE
    v_days_remaining := 0;
  END IF;

  SELECT EXISTS(SELECT 1 FROM subscriptions WHERE user_id = p_user_id AND status IN ('active', 'in_progress', 'pending_cancellation'))
  INTO v_has_active_subscription;

  v_can_start_trial := NOT v_has_used_trial AND NOT v_has_active_subscription;

  RETURN json_build_object(
    'is_in_premium_trial', v_is_in_trial,
    'premium_trial_started_at', v_profile.premium_trial_started_at,
    'premium_trial_end_at', v_profile.premium_trial_end_at,
    'premium_trial_days_remaining', v_days_remaining,
    'has_used_premium_trial', v_has_used_trial,
    'can_start_premium_trial', v_can_start_trial
  );
END; $$;

-- =====================================================
-- PART 13: MAIN SUBSCRIPTION STATUS FUNCTIONS
-- =====================================================

CREATE OR REPLACE FUNCTION get_user_plan_with_subscription(p_user_id UUID)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_is_in_premium_trial BOOLEAN;
  v_has_premium_subscription BOOLEAN;
  v_has_plus_subscription BOOLEAN;
  v_has_standard_subscription BOOLEAN;
  v_trial_active BOOLEAN;
  v_in_grace_period BOOLEAN;
  v_was_eligible BOOLEAN;
BEGIN
  SELECT COALESCE(is_admin, FALSE) INTO v_is_admin FROM user_profiles WHERE id = p_user_id;
  IF v_is_admin THEN RETURN 'premium'; END IF;

  v_is_in_premium_trial := is_in_premium_trial(p_user_id);
  IF v_is_in_premium_trial THEN RETURN 'premium'; END IF;

  -- Check for premium subscription (use plan_id JOIN instead of deprecated subscription_plan)
  SELECT EXISTS(
    SELECT 1 FROM subscriptions s
    LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
    WHERE s.user_id = p_user_id
      AND s.status IN ('active', 'trial', 'in_progress', 'pending_cancellation')
      AND (sp.plan_code = 'premium' OR s.plan_type LIKE 'premium%')
  ) INTO v_has_premium_subscription;
  IF v_has_premium_subscription THEN RETURN 'premium'; END IF;

  -- Check for plus subscription
  SELECT EXISTS(
    SELECT 1 FROM subscriptions s
    LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
    WHERE s.user_id = p_user_id
      AND s.status IN ('active', 'trial', 'in_progress', 'pending_cancellation')
      AND (sp.plan_code = 'plus' OR s.plan_type LIKE 'plus%')
  ) INTO v_has_plus_subscription;
  IF v_has_plus_subscription THEN RETURN 'plus'; END IF;

  -- Check for standard subscription
  SELECT EXISTS(
    SELECT 1 FROM subscriptions s
    LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
    WHERE s.user_id = p_user_id
      AND s.status IN ('active', 'trial', 'in_progress', 'pending_cancellation')
      AND (sp.plan_code = 'standard' OR s.plan_type LIKE 'standard%')
  ) INTO v_has_standard_subscription;
  IF v_has_standard_subscription THEN RETURN 'standard'; END IF;

  -- Check for explicit free subscription (admin override — takes priority over global trial)
  -- If admin explicitly assigned a user to free tier, honour it and skip the trial fallback
  IF EXISTS(
    SELECT 1 FROM subscriptions s
    LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
    WHERE s.user_id = p_user_id
      AND s.status IN ('active', 'trial', 'in_progress', 'pending_cancellation')
      AND (sp.plan_code = 'free' OR s.plan_type LIKE 'free%')
  ) THEN RETURN 'free'; END IF;

  v_trial_active := is_standard_trial_active();
  IF v_trial_active THEN RETURN 'standard'; END IF;

  v_was_eligible := was_eligible_for_trial(p_user_id);
  IF v_was_eligible THEN
    v_in_grace_period := is_in_grace_period();
    IF v_in_grace_period THEN RETURN 'standard'; END IF;
    RETURN 'free';
  END IF;

  RETURN 'free';
END; $$;

CREATE OR REPLACE FUNCTION get_subscription_status(p_user_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result JSONB;
  v_current_plan TEXT;
  v_subscription RECORD;
  v_premium_trial_status JSON;
BEGIN
  v_current_plan := get_user_plan_with_subscription(p_user_id);
  v_premium_trial_status := get_premium_trial_status(p_user_id);

  SELECT * INTO v_subscription FROM subscriptions
  WHERE user_id = p_user_id AND status IN ('active', 'in_progress', 'pending_cancellation', 'created')
  ORDER BY created_at DESC LIMIT 1;

  v_result := jsonb_build_object(
    'current_plan', v_current_plan,
    'is_trial_active', is_standard_trial_active(),
    'is_in_grace_period', is_in_grace_period(),
    'days_until_trial_end', get_days_until_trial_end(),
    'grace_days_remaining', get_grace_days_remaining(),
    'was_eligible_for_trial', was_eligible_for_trial(p_user_id),
    'user_created_at', get_user_created_at(p_user_id),
    'trial_end_date', get_standard_trial_end_date(),
    'grace_period_end_date', get_grace_period_end_date(),
    'has_subscription', v_subscription IS NOT NULL,
    'subscription_plan_type', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.plan_type ELSE NULL END,
    'subscription_status', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.status ELSE NULL END,
    'current_period_end', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.current_period_end ELSE NULL END,
    'next_billing_at', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.next_billing_at ELSE NULL END,
    'cancel_at_cycle_end', CASE WHEN v_subscription IS NOT NULL THEN v_subscription.cancel_at_cycle_end ELSE NULL END,
    'is_in_premium_trial', (v_premium_trial_status->>'is_in_premium_trial')::boolean,
    'premium_trial_started_at', v_premium_trial_status->>'premium_trial_started_at',
    'premium_trial_end_at', v_premium_trial_status->>'premium_trial_end_at',
    'premium_trial_days_remaining', (v_premium_trial_status->>'premium_trial_days_remaining')::integer,
    'has_used_premium_trial', (v_premium_trial_status->>'has_used_premium_trial')::boolean,
    'can_start_premium_trial', (v_premium_trial_status->>'can_start_premium_trial')::boolean
  );
  RETURN v_result;
END; $$;

GRANT EXECUTE ON FUNCTION get_standard_trial_end_date() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_grace_period_end_date() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION is_standard_trial_active() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION is_in_grace_period() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_days_until_trial_end() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_grace_days_remaining() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION was_eligible_for_trial(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_user_created_at(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION is_in_premium_trial(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_premium_trial_status(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_user_plan_with_subscription(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_subscription_status(UUID) TO authenticated, anon, service_role;

-- =====================================================
-- PART 13.5: TRIAL SUBSCRIPTION AUTOMATION
-- =====================================================
-- Functions to automatically create trial/free subscriptions
-- for new users and handle trial expiry

-- Function to create trial or free subscription for new users
CREATE OR REPLACE FUNCTION create_trial_subscription(p_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_subscription_id UUID;
  v_standard_plan_id UUID;
  v_free_plan_id UUID;
  v_trial_end_date TIMESTAMPTZ;
  v_trial_active BOOLEAN;
BEGIN
  -- Get trial configuration from subscription_config
  v_trial_end_date := get_standard_trial_end_date();
  v_trial_active := is_standard_trial_active();

  -- Get plan IDs
  SELECT id INTO v_standard_plan_id
  FROM subscription_plans
  WHERE plan_code = 'standard'
  LIMIT 1;

  SELECT id INTO v_free_plan_id
  FROM subscription_plans
  WHERE plan_code = 'free'
  LIMIT 1;

  -- If trial is active, create or update to trial subscription
  IF v_trial_active THEN
    INSERT INTO subscriptions (
      user_id,
      plan_id,
      plan_type,
      status,
      provider,
      provider_subscription_id,
      current_period_start,
      current_period_end
    ) VALUES (
      p_user_id,
      v_standard_plan_id,
      'standard_trial',
      'trial',
      'trial',
      'trial_' || p_user_id::text,
      NOW(),
      v_trial_end_date
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
      plan_id = EXCLUDED.plan_id,
      plan_type = EXCLUDED.plan_type,
      status = EXCLUDED.status,
      provider = EXCLUDED.provider,
      provider_subscription_id = EXCLUDED.provider_subscription_id,
      current_period_start = EXCLUDED.current_period_start,
      current_period_end = EXCLUDED.current_period_end,
      updated_at = NOW()
    RETURNING id INTO v_subscription_id;

  ELSE
    -- Trial expired, create or update to free subscription
    INSERT INTO subscriptions (
      user_id,
      plan_id,
      plan_type,
      status,
      provider,
      provider_subscription_id,
      current_period_start,
      current_period_end
    ) VALUES (
      p_user_id,
      v_free_plan_id,
      'free_tier',
      'active',
      'system',
      'free_' || p_user_id::text,
      NOW(),
      NOW() + INTERVAL '100 years'
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
      plan_id = EXCLUDED.plan_id,
      plan_type = EXCLUDED.plan_type,
      status = EXCLUDED.status,
      provider = EXCLUDED.provider,
      provider_subscription_id = EXCLUDED.provider_subscription_id,
      current_period_start = EXCLUDED.current_period_start,
      current_period_end = EXCLUDED.current_period_end,
      updated_at = NOW()
    RETURNING id INTO v_subscription_id;
  END IF;

  RETURN v_subscription_id;
END;
$$;

COMMENT ON FUNCTION create_trial_subscription(UUID) IS
  'Creates trial subscription if trial active, otherwise creates free subscription. Called on user signup.';

-- Trigger function to auto-create subscriptions on profile creation
CREATE OR REPLACE FUNCTION auto_create_subscription()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only create subscription if user is not admin
  IF COALESCE(NEW.is_admin, false) = false THEN
    PERFORM create_trial_subscription(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger on user_profiles
DROP TRIGGER IF EXISTS create_subscription_on_signup ON user_profiles;

CREATE TRIGGER create_subscription_on_signup
  AFTER INSERT ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION auto_create_subscription();

COMMENT ON TRIGGER create_subscription_on_signup ON user_profiles IS
  'Automatically creates trial or free subscription when new user profile is created (except for admins).';

-- Function to expire trial subscriptions and create free subscriptions
CREATE OR REPLACE FUNCTION expire_trial_subscriptions()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_expired_count INTEGER := 0;
  v_trial_end_date TIMESTAMPTZ;
  v_grace_end_date TIMESTAMPTZ;
  v_free_plan_id UUID;
BEGIN
  -- Get configuration
  v_trial_end_date := get_standard_trial_end_date();
  v_grace_end_date := get_grace_period_end_date();

  -- Get free plan ID
  SELECT id INTO v_free_plan_id
  FROM subscription_plans
  WHERE plan_code = 'free'
  LIMIT 1;

  -- If trial period ended
  IF NOW() > v_trial_end_date THEN

    -- If still in grace period, extend trial subscriptions
    IF NOW() <= v_grace_end_date THEN
      UPDATE subscriptions
      SET current_period_end = v_grace_end_date,
          updated_at = NOW()
      WHERE status = 'trial'
        AND current_period_end = v_trial_end_date;

      RAISE NOTICE 'Extended trial subscriptions to grace period end date';

    ELSE
      -- Grace period ended, transition trial subscriptions to free tier
      -- UPDATE existing subscription records instead of creating new ones

      -- Transition trial subscriptions to free tier (UPDATE, not INSERT)
      WITH transitioned AS (
        UPDATE subscriptions
        SET
          plan_id = v_free_plan_id,
          plan_type = 'free_tier',
          status = 'active',
          provider = 'system',
          provider_subscription_id = 'free_' || user_id::text,
          current_period_start = NOW(),
          current_period_end = NOW() + INTERVAL '100 years',
          updated_at = NOW()
        WHERE status = 'trial'
          AND current_period_end <= NOW()
        RETURNING id, user_id
      )
      SELECT COUNT(*) INTO v_expired_count FROM transitioned;

      RAISE NOTICE 'Transitioned % trial subscriptions to free tier', v_expired_count;
    END IF;
  END IF;

  RETURN v_expired_count;
END;
$$;

COMMENT ON FUNCTION expire_trial_subscriptions() IS
  'Handles trial expiry: extends to grace period or expires to free tier. Meant to be called daily via cron job.';

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION create_trial_subscription(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION expire_trial_subscriptions() TO service_role;

-- =====================================================
-- PART 14: VERIFICATION QUERIES
-- =====================================================

-- Verify plan data
DO $$
DECLARE
  v_plan_count INTEGER;
  v_provider_count INTEGER;
  v_promo_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_plan_count FROM public.subscription_plans;
  SELECT COUNT(*) INTO v_provider_count FROM public.subscription_plan_providers;
  SELECT COUNT(*) INTO v_promo_count FROM public.promotional_campaigns WHERE is_active = true;

  RAISE NOTICE '✅ Migration 0004_subscription_system.sql completed successfully';
  RAISE NOTICE '   - Created % subscription plans', v_plan_count;
  RAISE NOTICE '   - Created % provider configurations', v_provider_count;
  RAISE NOTICE '   - Inserted % active promotional campaigns', v_promo_count;
  RAISE NOTICE '   - Modified subscriptions table with multi-provider support';
  RAISE NOTICE '   - Added trial subscription support (status=trial, provider=trial/system)';
  RAISE NOTICE '   - Created auto-create subscription trigger for new users';
  RAISE NOTICE '   - Created trial expiry function for scheduled execution';
  RAISE NOTICE '   - Applied Free plan practice mode fix (2 modes)';
END $$;

-- Display plan features for verification
SELECT
  plan_code,
  plan_name,
  tier,
  features->>'daily_tokens' AS daily_tokens,
  features->>'practice_modes' AS practice_modes,
  features->>'practice_limit' AS practice_limit,
  description
FROM public.subscription_plans
ORDER BY tier;

-- Display active promotional campaigns
SELECT
  campaign_code,
  campaign_name,
  discount_type,
  discount_value,
  applicable_plans,
  new_users_only,
  valid_until::date AS expires_on
FROM public.promotional_campaigns
WHERE is_active = true
ORDER BY campaign_code;

-- =====================================================
-- PART 12: DATABASE-DRIVEN CONFIGURATION FUNCTIONS
-- =====================================================
-- Purpose: Make subscription config read from database instead of hardcoded
-- Date: 2026-02-13
-- Impact: Admin web updates will be reflected in client apps

-- -----------------------------------------------------
-- 12.1: Helper Function to Get Plan Features
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION get_plan_features(p_plan_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_features JSONB;
BEGIN
  -- Get features from subscription_plans table
  SELECT features INTO v_features
  FROM subscription_plans
  WHERE plan_code = p_plan_code;

  -- Return empty object if plan not found
  IF v_features IS NULL THEN
    v_features := '{}'::jsonb;
  END IF;

  RETURN v_features;
END;
$$;

COMMENT ON FUNCTION get_plan_features IS
  'Get plan features from subscription_plans table. Returns empty object if plan not found.';

-- -----------------------------------------------------
-- 12.2: Helper Function to Get Plan Pricing
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION get_plan_pricing(
  p_plan_code TEXT,
  p_provider TEXT DEFAULT 'razorpay'
)
RETURNS TABLE(
  plan_code TEXT,
  plan_name TEXT,
  provider TEXT,
  provider_plan_id TEXT,
  price_inr INTEGER,
  currency TEXT,
  billing_interval TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
BEGIN
  RETURN QUERY
  SELECT
    sp.plan_code,
    sp.plan_name,
    spp.provider,
    spp.provider_plan_id,
    (spp.base_price_minor / 100)::INTEGER AS price_inr,
    spp.currency,
    sp.interval AS billing_interval
  FROM subscription_plans sp
  LEFT JOIN subscription_plan_providers spp ON sp.id = spp.plan_id
  WHERE sp.plan_code = p_plan_code
    AND (spp.provider = p_provider OR spp.provider IS NULL)
  LIMIT 1;
END;
$$;

COMMENT ON FUNCTION get_plan_pricing IS
  'Get pricing information for a subscription plan from database';

-- -----------------------------------------------------
-- 12.3: View for Quick Plan Access
-- -----------------------------------------------------
CREATE OR REPLACE VIEW subscription_plans_with_pricing AS
SELECT
  sp.id,
  sp.plan_code,
  sp.plan_name,
  sp.tier,
  sp.interval,
  sp.features,
  sp.is_active,
  sp.is_visible,
  sp.description,
  -- Razorpay pricing
  spp_rp.provider_plan_id AS razorpay_plan_id,
  (spp_rp.base_price_minor / 100)::INTEGER AS price_inr,
  -- Google Play pricing
  spp_gp.provider_plan_id AS google_play_sku,
  (spp_gp.base_price_minor / 100)::INTEGER AS price_google_play,
  -- Apple App Store pricing
  spp_ap.provider_plan_id AS apple_product_id,
  (spp_ap.base_price_minor / 100)::INTEGER AS price_apple,
  sp.created_at,
  sp.updated_at
FROM subscription_plans sp
LEFT JOIN subscription_plan_providers spp_rp ON sp.id = spp_rp.plan_id AND spp_rp.provider = 'razorpay'
LEFT JOIN subscription_plan_providers spp_gp ON sp.id = spp_gp.plan_id AND spp_gp.provider = 'google_play'
LEFT JOIN subscription_plan_providers spp_ap ON sp.id = spp_ap.plan_id AND spp_ap.provider = 'apple_appstore';

COMMENT ON VIEW subscription_plans_with_pricing IS
  'View combining subscription plans with pricing from all providers';

-- -----------------------------------------------------
-- 12.4: Add Indexes for Performance
-- -----------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_subscription_plans_plan_code ON subscription_plans(plan_code);
CREATE INDEX IF NOT EXISTS idx_subscription_plan_providers_provider ON subscription_plan_providers(provider);
CREATE INDEX IF NOT EXISTS idx_subscription_plan_providers_plan_provider
ON subscription_plan_providers(plan_id, provider);

-- =====================================================
-- PART 13: SCHEMA CLEANUP (2026-02-14)
-- =====================================================
-- Remove conflicting fields that duplicate feature flag functionality
-- Feature flags control ACCESS, subscription quotas control LIMITS

-- Remove conflicting and unused fields from features JSONB column
UPDATE subscription_plans
SET
  features = features - 'ai_discipler' - 'followups',
  updated_at = NOW()
WHERE
  features ? 'ai_discipler' OR features ? 'followups';

-- Drop unused top-level columns if they exist
DO $$
BEGIN
  -- Check and drop daily_unlocked_modes column
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'subscription_plans'
    AND column_name = 'daily_unlocked_modes'
  ) THEN
    ALTER TABLE subscription_plans DROP COLUMN daily_unlocked_modes;
    RAISE NOTICE 'Dropped column: daily_unlocked_modes';
  END IF;

  -- Check and drop voice_minutes_monthly column
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'subscription_plans'
    AND column_name = 'voice_minutes_monthly'
  ) THEN
    ALTER TABLE subscription_plans DROP COLUMN voice_minutes_monthly;
    RAISE NOTICE 'Dropped column: voice_minutes_monthly';
  END IF;
END $$;

-- Add comment documenting the cleaned schema
COMMENT ON COLUMN subscription_plans.features IS
  'JSONB containing usage quotas/limits only. Access control is handled by feature_flags table.
   Valid keys: daily_tokens, voice_conversations_monthly, memory_verses, practice_modes, practice_limit, study_modes';

-- Verify cleanup
DO $$
DECLARE
  plan_record RECORD;
  has_removed_fields BOOLEAN := FALSE;
BEGIN
  -- Check if any plan still has the removed fields
  FOR plan_record IN
    SELECT plan_code, features
    FROM subscription_plans
  LOOP
    IF plan_record.features ? 'ai_discipler' OR plan_record.features ? 'followups' THEN
      RAISE WARNING 'Plan % still contains removed fields', plan_record.plan_code;
      has_removed_fields := TRUE;
    END IF;
  END LOOP;

  IF NOT has_removed_fields THEN
    RAISE NOTICE '✅ Schema cleanup successful: All conflicting fields removed';
    RAISE NOTICE '✅ Remaining quota fields: daily_tokens, voice_conversations_monthly, memory_verses, practice_modes, practice_limit, study_modes';
  END IF;
END $$;

COMMIT;

-- =====================================================
-- POST-MIGRATION NOTES
-- =====================================================
-- 1. Update Razorpay plan IDs in subscription_plan_providers after creating plans in Razorpay
-- 2. Update Google Play SKUs after app store configuration
-- 3. Update Apple App Store product IDs after app store configuration
-- 4. Promotional campaign validity periods should be updated for production use
-- 5. Free plan now correctly has 2 practice modes (Flip Card, Type It Out)
-- =====================================================
