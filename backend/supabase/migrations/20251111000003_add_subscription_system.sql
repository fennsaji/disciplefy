-- =====================================================
-- Migration: Add Premium Subscription System
-- Purpose: Support ₹100/month premium subscriptions via Razorpay
-- Date: 2025-01-11
-- =====================================================

BEGIN;

-- =====================================
-- 1. Subscriptions Table
-- =====================================

CREATE TABLE subscriptions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Razorpay Integration
  razorpay_subscription_id TEXT UNIQUE NOT NULL,
  razorpay_plan_id TEXT NOT NULL,
  razorpay_customer_id TEXT,

  -- Subscription Details
  status TEXT NOT NULL CHECK (status IN (
    'created',        -- Initial state after Razorpay subscription creation
    'authenticated',  -- User authorized recurring payments
    'active',         -- Currently active and billing
    'paused',         -- Temporarily paused (payment failure or admin action)
    'cancelled',      -- User cancelled (may still be active until period end)
    'completed',      -- Reached total_count cycles
    'expired'         -- Grace period ended after cancellation
  )),
  plan_type TEXT NOT NULL DEFAULT 'premium_monthly',

  -- Billing Cycle Information
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  next_billing_at TIMESTAMPTZ,

  -- Subscription Metadata
  total_count INTEGER DEFAULT 12,     -- Total billing cycles (12 months default)
  paid_count INTEGER DEFAULT 0,       -- Number of successful payments
  remaining_count INTEGER DEFAULT 12, -- Remaining billing cycles

  -- Payment Details
  amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
  currency TEXT NOT NULL DEFAULT 'INR',

  -- Cancellation Information
  cancelled_at TIMESTAMPTZ,
  cancel_at_cycle_end BOOLEAN DEFAULT false,
  cancellation_reason TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partial unique index: Only one active subscription per user
-- This allows multiple historical subscriptions but prevents duplicate active ones
CREATE UNIQUE INDEX unique_active_subscription_per_user
  ON subscriptions(user_id)
  WHERE (status IN ('active', 'authenticated'));

-- Indexes for subscriptions table
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_razorpay_id ON subscriptions(razorpay_subscription_id);
CREATE INDEX idx_subscriptions_next_billing ON subscriptions(next_billing_at) WHERE status = 'active';

COMMENT ON TABLE subscriptions IS 'Stores Razorpay premium subscription information for users';
COMMENT ON COLUMN subscriptions.razorpay_subscription_id IS 'Unique Razorpay subscription ID (sub_xxxxx format)';
COMMENT ON COLUMN subscriptions.status IS 'Current subscription status matching Razorpay webhook events';
COMMENT ON COLUMN subscriptions.cancel_at_cycle_end IS 'If true, subscription remains active until current_period_end';

-- =====================================
-- 2. Subscription History Table
-- =====================================

CREATE TABLE subscription_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Event Details
  event_type TEXT NOT NULL CHECK (event_type IN (
    'subscription.created',
    'subscription.authenticated',
    'subscription.activated',
    'subscription.charged',
    'subscription.cancelled',
    'subscription.paused',
    'subscription.resumed',
    'subscription.completed',
    'subscription.pending',
    'subscription.updated'
  )),

  -- State Transition
  previous_status TEXT,
  new_status TEXT NOT NULL,

  -- Payment Information (for charged events)
  payment_id TEXT,
  payment_amount INTEGER,
  payment_status TEXT,

  -- Event Metadata
  event_data JSONB,  -- Full webhook payload for audit
  notes TEXT,

  -- Timestamp
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for subscription_history table
CREATE INDEX idx_subscription_history_subscription ON subscription_history(subscription_id);
CREATE INDEX idx_subscription_history_user ON subscription_history(user_id);
CREATE INDEX idx_subscription_history_event_type ON subscription_history(event_type);
CREATE INDEX idx_subscription_history_created_at ON subscription_history(created_at DESC);

COMMENT ON TABLE subscription_history IS 'Audit log of all subscription lifecycle events from Razorpay webhooks';
COMMENT ON COLUMN subscription_history.event_data IS 'Full webhook payload stored as JSONB for debugging and audit';

-- =====================================
-- 3. Subscription Invoices Table
-- =====================================

CREATE TABLE subscription_invoices (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Razorpay Payment Details
  razorpay_payment_id TEXT UNIQUE NOT NULL,
  razorpay_invoice_id TEXT,

  -- Invoice Details
  invoice_number TEXT UNIQUE,  -- Auto-generated format: INV-YYYYMMDD-XXXXX
  amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
  currency TEXT NOT NULL DEFAULT 'INR',

  -- Billing Period
  billing_period_start TIMESTAMPTZ NOT NULL,
  billing_period_end TIMESTAMPTZ NOT NULL,

  -- Status
  status TEXT NOT NULL CHECK (status IN ('paid', 'failed', 'pending', 'refunded')),

  -- Payment Method
  payment_method TEXT,  -- 'card', 'upi', 'netbanking', 'wallet', etc.

  -- Timestamps
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for subscription_invoices table
CREATE INDEX idx_invoices_subscription_id ON subscription_invoices(subscription_id);
CREATE INDEX idx_invoices_user_id ON subscription_invoices(user_id);
CREATE INDEX idx_invoices_status ON subscription_invoices(status);
CREATE INDEX idx_invoices_billing_period ON subscription_invoices(billing_period_start, billing_period_end);
CREATE INDEX idx_invoices_razorpay_payment_id ON subscription_invoices(razorpay_payment_id);

COMMENT ON TABLE subscription_invoices IS 'Monthly billing records for premium subscriptions';
COMMENT ON COLUMN subscription_invoices.invoice_number IS 'Human-readable invoice number for customer records';

-- =====================================
-- 4. Update user_profiles Table
-- =====================================

-- Add subscription-related columns to user_profiles
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS subscription_started_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS subscription_ends_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS auto_renew BOOLEAN DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_user_profiles_subscription_status
  ON user_profiles(subscription_status) WHERE subscription_status IS NOT NULL;

COMMENT ON COLUMN user_profiles.subscription_status IS 'Denormalized current subscription status (synced from subscriptions table)';
COMMENT ON COLUMN user_profiles.subscription_started_at IS 'Timestamp when user first activated premium subscription';
COMMENT ON COLUMN user_profiles.subscription_ends_at IS 'Current subscription period end date';
COMMENT ON COLUMN user_profiles.auto_renew IS 'Whether subscription should auto-renew (user preference)';

-- =====================================
-- 5. Row Level Security Policies
-- =====================================

-- Subscriptions RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own subscriptions"
  ON subscriptions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage all subscriptions"
  ON subscriptions FOR ALL
  USING (auth.role() = 'service_role');

-- Subscription History RLS
ALTER TABLE subscription_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own subscription history"
  ON subscription_history FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage all subscription history"
  ON subscription_history FOR ALL
  USING (auth.role() = 'service_role');

-- Subscription Invoices RLS
ALTER TABLE subscription_invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own invoices"
  ON subscription_invoices FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage all invoices"
  ON subscription_invoices FOR ALL
  USING (auth.role() = 'service_role');

-- =====================================
-- 6. Database Functions
-- =====================================

-- Function: Check if user has active subscription
CREATE OR REPLACE FUNCTION has_active_subscription(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_has_active BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM subscriptions
    WHERE user_id = p_user_id
      AND status IN ('active', 'authenticated')
      AND (current_period_end IS NULL OR current_period_end > NOW())
  ) INTO v_has_active;

  RETURN v_has_active;
END;
$$;

COMMENT ON FUNCTION has_active_subscription(UUID) IS
  'Returns true if user has an active subscription (status active/authenticated and not expired)';

-- Function: Get user plan with subscription logic
CREATE OR REPLACE FUNCTION get_user_plan_with_subscription(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_admin BOOLEAN;
  v_has_subscription BOOLEAN;
BEGIN
  -- Check if admin
  SELECT is_admin INTO v_is_admin
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_is_admin THEN
    RETURN 'premium';
  END IF;

  -- Check for active subscription
  SELECT has_active_subscription(p_user_id) INTO v_has_subscription;

  IF v_has_subscription THEN
    RETURN 'premium';
  END IF;

  -- Default to standard for authenticated users
  RETURN 'standard';
END;
$$;

COMMENT ON FUNCTION get_user_plan_with_subscription(UUID) IS
  'Returns user plan: premium (if admin or active subscription), otherwise standard';

-- Function: Log subscription event
CREATE OR REPLACE FUNCTION log_subscription_event(
  p_subscription_id UUID,
  p_user_id UUID,
  p_event_type TEXT,
  p_previous_status TEXT,
  p_new_status TEXT,
  p_payment_id TEXT DEFAULT NULL,
  p_payment_amount INTEGER DEFAULT NULL,
  p_payment_status TEXT DEFAULT NULL,
  p_event_data JSONB DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_history_id UUID;
BEGIN
  INSERT INTO subscription_history (
    subscription_id,
    user_id,
    event_type,
    previous_status,
    new_status,
    payment_id,
    payment_amount,
    payment_status,
    event_data,
    notes
  ) VALUES (
    p_subscription_id,
    p_user_id,
    p_event_type,
    p_previous_status,
    p_new_status,
    p_payment_id,
    p_payment_amount,
    p_payment_status,
    p_event_data,
    p_notes
  )
  RETURNING id INTO v_history_id;

  RETURN v_history_id;
END;
$$;

COMMENT ON FUNCTION log_subscription_event IS
  'Logs subscription lifecycle events to subscription_history table for audit trail';

-- Function: Generate invoice number
CREATE OR REPLACE FUNCTION generate_invoice_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_date_part TEXT;
  v_sequence INTEGER;
  v_invoice_number TEXT;
BEGIN
  v_date_part := TO_CHAR(NOW(), 'YYYYMMDD');

  -- Get next sequence number for today
  SELECT COUNT(*) + 1 INTO v_sequence
  FROM subscription_invoices
  WHERE invoice_number LIKE 'INV-' || v_date_part || '-%';

  -- Format: INV-YYYYMMDD-00001
  v_invoice_number := 'INV-' || v_date_part || '-' || LPAD(v_sequence::TEXT, 5, '0');

  RETURN v_invoice_number;
END;
$$;

COMMENT ON FUNCTION generate_invoice_number IS
  'Generates unique invoice number in format INV-YYYYMMDD-XXXXX';

-- =====================================
-- 7. Triggers
-- =====================================

-- Trigger: Auto-update subscription status in user_profiles
CREATE OR REPLACE FUNCTION sync_subscription_to_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE user_profiles
  SET
    subscription_status = NEW.status,
    subscription_ends_at = NEW.current_period_end,
    updated_at = NOW()
  WHERE id = NEW.user_id;

  -- Set subscription_started_at on first activation
  IF NEW.status = 'active' AND OLD.status != 'active' THEN
    UPDATE user_profiles
    SET subscription_started_at = NOW()
    WHERE id = NEW.user_id AND subscription_started_at IS NULL;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_sync_subscription_status
  AFTER INSERT OR UPDATE OF status, current_period_end
  ON subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION sync_subscription_to_profile();

COMMENT ON FUNCTION sync_subscription_to_profile IS
  'Automatically syncs subscription status to user_profiles for fast plan lookup';

-- Trigger: Auto-update subscriptions.updated_at
CREATE OR REPLACE FUNCTION update_subscriptions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION update_subscriptions_updated_at();

-- Trigger: Auto-update invoices.updated_at
CREATE OR REPLACE FUNCTION update_invoices_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_invoices_updated_at
  BEFORE UPDATE ON subscription_invoices
  FOR EACH ROW
  EXECUTE FUNCTION update_invoices_updated_at();

-- Trigger: Auto-generate invoice number
CREATE OR REPLACE FUNCTION set_invoice_number()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.invoice_number IS NULL THEN
    NEW.invoice_number := generate_invoice_number();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_set_invoice_number
  BEFORE INSERT ON subscription_invoices
  FOR EACH ROW
  EXECUTE FUNCTION set_invoice_number();

COMMENT ON FUNCTION set_invoice_number IS
  'Automatically generates invoice_number before insert if not provided';

COMMIT;
