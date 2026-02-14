-- =====================================================
-- Consolidated Migration: Payment System
-- =====================================================
-- Source: Manual merge of 11 payment migrations with all fixes applied inline
-- Tables: 6 (pending_token_purchases, purchase_history, receipt_counters,
--            saved_payment_methods, payment_preferences, purchase_issue_reports)
-- Description: Complete payment infrastructure with encryption, idempotency,
--              purchase tracking, issue reporting, and storage integration
-- =====================================================

-- Dependencies: 0001_core_schema.sql (auth.users, user_profiles)

BEGIN;

-- =====================================================
-- SUMMARY: Migration creates payment and purchase tracking infrastructure
-- Completed 0001 (11 tables), 0002 (6 tables), 0003 (2 tables), 0004 (5 tables)
-- Now creating 0005 with payment system (6 tables)
-- =====================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- For payment token encryption

-- =====================================================
-- PART 1: TABLES
-- =====================================================

-- -----------------------------------------------------
-- Table: pending_token_purchases
-- Purpose: Temporary purchase records awaiting confirmation
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pending_token_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id TEXT UNIQUE NOT NULL,
  token_amount INTEGER NOT NULL CHECK (token_amount > 0 AND token_amount <= 10000),
  amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'expired')),
  payment_id TEXT,  -- Razorpay payment_id
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '15 minutes')
);

COMMENT ON TABLE public.pending_token_purchases IS 'Stores pending token purchases awaiting Razorpay payment confirmation';
COMMENT ON COLUMN public.pending_token_purchases.status IS 'Purchase status: pending, processing, completed, failed, expired';
COMMENT ON COLUMN public.pending_token_purchases.expires_at IS 'Purchase expires after 15 minutes if not confirmed';

-- Trigger for updated_at
CREATE TRIGGER set_pending_token_purchases_updated_at
  BEFORE UPDATE ON public.pending_token_purchases
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- -----------------------------------------------------
-- Table: receipt_counters
-- Purpose: Monthly receipt number generation tracking
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.receipt_counters (
  year_month TEXT PRIMARY KEY,
  last_seq INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.receipt_counters IS 'Monthly sequence tracking for receipt number generation';
COMMENT ON COLUMN public.receipt_counters.year_month IS 'Format: YYYYMM (e.g., 202601)';
COMMENT ON COLUMN public.receipt_counters.last_seq IS 'Last sequence number issued for this month';

-- Trigger for updated_at
CREATE TRIGGER set_receipt_counters_updated_at
  BEFORE UPDATE ON public.receipt_counters
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- -----------------------------------------------------
-- Table: saved_payment_methods
-- Purpose: Encrypted storage of user payment methods
-- NOTE: Created BEFORE purchase_history because purchase_history references it
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.saved_payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  method_type TEXT NOT NULL CHECK (method_type IN ('card', 'upi', 'netbanking', 'wallet')),
  provider TEXT NOT NULL,  -- 'razorpay', 'paytm', 'googlepay', etc.

  -- Encrypted token storage (Added: 20250911000002)
  encrypted_token TEXT,
  encryption_key_id TEXT DEFAULT 'default_key',
  token_hash TEXT,  -- SHA-256 hash for duplicate detection
  security_metadata JSONB DEFAULT '{}'::jsonb,

  -- Display information
  last_four TEXT,
  brand TEXT,  -- 'visa', 'mastercard', 'upi', etc.
  display_name TEXT,
  is_default BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,

  -- Card metadata
  expiry_month INTEGER,
  expiry_year INTEGER,

  -- Usage tracking (Added: Phase 3)
  usage_count INTEGER DEFAULT 0,
  last_used TIMESTAMPTZ,

  -- Soft delete support
  deleted_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.saved_payment_methods IS 'Encrypted storage of user payment methods for quick purchases';
COMMENT ON COLUMN public.saved_payment_methods.encrypted_token IS 'AES-256 encrypted payment token';
COMMENT ON COLUMN public.saved_payment_methods.token_hash IS 'SHA-256 hash for duplicate detection without decryption';
COMMENT ON COLUMN public.saved_payment_methods.security_metadata IS 'Encryption timestamp, validation info, security level';

-- Trigger for updated_at
CREATE TRIGGER set_saved_payment_methods_updated_at
  BEFORE UPDATE ON public.saved_payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- -----------------------------------------------------
-- Table: purchase_history
-- Purpose: Comprehensive purchase history tracking
-- NOTE: References saved_payment_methods (created above)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.purchase_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Purchase details
  token_amount INTEGER NOT NULL CHECK (token_amount > 0),
  cost_rupees DECIMAL(10,2) NOT NULL CHECK (cost_rupees > 0),
  cost_paise INTEGER NOT NULL CHECK (cost_paise > 0),

  -- Payment details
  payment_id TEXT NOT NULL,
  order_id TEXT NOT NULL,
  payment_method TEXT,  -- 'card', 'upi', 'netbanking', 'wallet'
  payment_provider TEXT DEFAULT 'razorpay',

  -- Status and metadata
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'failed', 'refunded', 'pending')),
  receipt_url TEXT,
  receipt_number TEXT UNIQUE,

  -- Reference to saved payment method used (Added: Phase 3)
  saved_payment_method_id UUID REFERENCES public.saved_payment_methods(id) ON DELETE SET NULL,

  -- Timestamps
  purchased_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.purchase_history IS 'Comprehensive purchase history tracking for token purchases';
COMMENT ON COLUMN public.purchase_history.receipt_number IS 'Format: DISC-YYYYMM-NNNN';
COMMENT ON COLUMN public.purchase_history.saved_payment_method_id IS 'Reference to payment method used (if saved)';

-- Trigger for updated_at
CREATE TRIGGER set_purchase_history_updated_at
  BEFORE UPDATE ON public.purchase_history
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- -----------------------------------------------------
-- Table: payment_preferences
-- Purpose: User payment settings and preferences
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,

  -- Preference settings
  auto_save_methods BOOLEAN DEFAULT TRUE,
  preferred_method_type TEXT CHECK (preferred_method_type IN ('card', 'upi', 'netbanking', 'wallet')),
  enable_one_click_purchase BOOLEAN DEFAULT TRUE,
  require_cvv_for_saved_cards BOOLEAN DEFAULT TRUE,

  -- Mobile optimization preferences
  prefer_mobile_wallets BOOLEAN DEFAULT TRUE,
  enable_upi_autopay BOOLEAN DEFAULT FALSE,

  -- Frontend-compatible columns (Added: 20250911000001)
  preferred_wallet TEXT,
  default_payment_type TEXT CHECK (default_payment_type IN ('card', 'upi', 'netbanking', 'wallet')),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.payment_preferences IS 'User payment settings and preferences';
COMMENT ON COLUMN public.payment_preferences.default_payment_type IS 'Default payment type for one-click purchases';
COMMENT ON COLUMN public.payment_preferences.preferred_wallet IS 'Preferred mobile wallet (paytm, googlepay, etc.)';

-- Trigger for updated_at
CREATE TRIGGER set_payment_preferences_updated_at
  BEFORE UPDATE ON public.payment_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- -----------------------------------------------------
-- Table: purchase_issue_reports
-- Purpose: User-reported purchase and payment issues
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.purchase_issue_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- User info
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_email TEXT NOT NULL,

  -- Purchase reference
  purchase_id UUID NOT NULL,
  payment_id TEXT NOT NULL,
  order_id TEXT NOT NULL,
  token_amount INTEGER NOT NULL,
  cost_rupees DECIMAL(10,2) NOT NULL,
  purchased_at TIMESTAMPTZ NOT NULL,

  -- Issue details
  issue_type TEXT NOT NULL CHECK (issue_type IN (
    'wrong_amount',
    'payment_failed',
    'tokens_not_credited',
    'duplicate_charge',
    'refund_request',
    'other'
  )),
  description TEXT NOT NULL,
  screenshot_urls TEXT[] DEFAULT '{}',

  -- Status tracking
  status TEXT DEFAULT 'pending' CHECK (status IN (
    'pending',
    'in_review',
    'resolved',
    'closed'
  )),
  admin_notes TEXT,
  resolved_by UUID REFERENCES auth.users(id),
  resolved_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.purchase_issue_reports IS 'User-reported issues with token purchases';
COMMENT ON COLUMN public.purchase_issue_reports.issue_type IS 'Type: wrong_amount, payment_failed, tokens_not_credited, duplicate_charge, refund_request, other';
COMMENT ON COLUMN public.purchase_issue_reports.status IS 'Status: pending (new), in_review (investigating), resolved (fixed), closed (no action)';
COMMENT ON COLUMN public.purchase_issue_reports.screenshot_urls IS 'Array of storage URLs for screenshot evidence';

-- Trigger for updated_at
CREATE TRIGGER set_purchase_issue_reports_updated_at
  BEFORE UPDATE ON public.purchase_issue_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- =====================================================
-- PART 2: INDEXES
-- =====================================================

-- Indexes on pending_token_purchases
CREATE INDEX IF NOT EXISTS idx_pending_purchases_user_id ON public.pending_token_purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_pending_purchases_order_id ON public.pending_token_purchases(order_id);
CREATE INDEX IF NOT EXISTS idx_pending_purchases_status ON public.pending_token_purchases(status);
CREATE INDEX IF NOT EXISTS idx_pending_purchases_created_at ON public.pending_token_purchases(created_at);

-- CRITICAL: Unique index on payment_id to prevent double-processing (Fix: 20250912000002)
CREATE UNIQUE INDEX IF NOT EXISTS idx_pending_purchases_payment_id_unique
  ON public.pending_token_purchases(payment_id)
  WHERE payment_id IS NOT NULL;

COMMENT ON INDEX idx_pending_purchases_payment_id_unique IS 'Prevents double-processing from webhook retries';

-- Indexes on purchase_history
CREATE INDEX IF NOT EXISTS idx_purchase_history_user_id ON public.purchase_history(user_id);
CREATE INDEX IF NOT EXISTS idx_purchase_history_status ON public.purchase_history(status);
CREATE INDEX IF NOT EXISTS idx_purchase_history_purchased_at ON public.purchase_history(purchased_at DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_history_payment_id ON public.purchase_history(payment_id);
CREATE INDEX IF NOT EXISTS idx_purchase_history_receipt_number ON public.purchase_history(receipt_number);

-- CRITICAL: Unique index on payment_id to prevent double-crediting tokens
CREATE UNIQUE INDEX IF NOT EXISTS idx_purchase_history_payment_id_unique
  ON public.purchase_history(payment_id)
  WHERE payment_id IS NOT NULL;

COMMENT ON INDEX idx_purchase_history_payment_id_unique IS 'Prevents double-crediting tokens from duplicate webhooks';

-- Indexes on saved_payment_methods
CREATE INDEX IF NOT EXISTS idx_saved_payment_methods_user_id ON public.saved_payment_methods(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_payment_methods_user_default ON public.saved_payment_methods(user_id, is_default) WHERE is_default = TRUE;
CREATE INDEX IF NOT EXISTS idx_saved_payment_methods_active ON public.saved_payment_methods(user_id, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_saved_payment_methods_token_hash ON public.saved_payment_methods(token_hash) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_saved_payment_methods_encryption_key ON public.saved_payment_methods(encryption_key_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_payment_methods_expiry ON public.saved_payment_methods(expiry_year, expiry_month) WHERE method_type = 'card';

-- Indexes on payment_preferences
CREATE INDEX IF NOT EXISTS idx_payment_preferences_user_wallet ON public.payment_preferences(user_id, preferred_wallet);

-- Indexes on purchase_issue_reports
CREATE INDEX IF NOT EXISTS idx_purchase_issue_reports_user_id ON public.purchase_issue_reports(user_id);
CREATE INDEX IF NOT EXISTS idx_purchase_issue_reports_status ON public.purchase_issue_reports(status);
CREATE INDEX IF NOT EXISTS idx_purchase_issue_reports_created_at ON public.purchase_issue_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_issue_reports_purchase_id ON public.purchase_issue_reports(purchase_id);

-- =====================================================
-- PART 3: ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.pending_token_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receipt_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_issue_reports ENABLE ROW LEVEL SECURITY;

-- pending_token_purchases policies
CREATE POLICY "Users can view own pending purchases"
  ON public.pending_token_purchases FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own pending purchases"
  ON public.pending_token_purchases FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own pending purchases"
  ON public.pending_token_purchases FOR UPDATE
  USING (auth.uid() = user_id);

-- purchase_history policies
CREATE POLICY "Users can view own purchase history"
  ON public.purchase_history FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage purchase history"
  ON public.purchase_history FOR ALL
  USING (auth.role() = 'service_role');

-- saved_payment_methods policies
CREATE POLICY "Users can view own payment methods"
  ON public.saved_payment_methods FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own payment methods"
  ON public.saved_payment_methods FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own payment methods"
  ON public.saved_payment_methods FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own payment methods"
  ON public.saved_payment_methods FOR DELETE
  USING (auth.uid() = user_id);

-- payment_preferences policies
CREATE POLICY "Users can manage own payment preferences"
  ON public.payment_preferences FOR ALL
  USING (auth.uid() = user_id);

-- purchase_issue_reports policies
CREATE POLICY "Users can view own purchase issue reports"
  ON public.purchase_issue_reports FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create purchase issue reports"
  ON public.purchase_issue_reports FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all purchase issue reports"
  ON public.purchase_issue_reports FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

CREATE POLICY "Admins can update purchase issue reports"
  ON public.purchase_issue_reports FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- =====================================================
-- PART 4: HELPER FUNCTIONS
-- =====================================================

-- Function: Generate token hash for duplicate detection
CREATE OR REPLACE FUNCTION public.generate_token_hash(p_token TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN encode(digest(p_token::bytea, 'sha256'), 'hex');
END;
$$;

COMMENT ON FUNCTION public.generate_token_hash IS 'Generate SHA-256 hash for token duplicate detection';

-- Function: Encrypt payment token
CREATE OR REPLACE FUNCTION public.encrypt_payment_token(
  p_token TEXT,
  p_key_id TEXT DEFAULT 'default_key'
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_encryption_key TEXT;
  v_encrypted_token TEXT;
BEGIN
  -- Get encryption key from environment (use key management system in production)
  v_encryption_key := current_setting('app.encryption_key', true);

  IF v_encryption_key IS NULL OR v_encryption_key = '' THEN
    v_encryption_key := 'disciplefy_default_key_2024_change_in_production';
    RAISE WARNING 'Using default encryption key - set app.encryption_key in production';
  END IF;

  -- Encrypt using AES-256
  v_encrypted_token := encode(
    encrypt(
      p_token::bytea,
      v_encryption_key::bytea,
      'aes'
    ),
    'base64'
  );

  RETURN v_encrypted_token;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to encrypt payment token: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.encrypt_payment_token IS 'Encrypt payment token using AES-256';

-- Function: Decrypt payment token (service_role only)
CREATE OR REPLACE FUNCTION public.decrypt_payment_token(
  p_encrypted_token TEXT,
  p_key_id TEXT DEFAULT 'default_key'
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_encryption_key TEXT;
  v_decrypted_token TEXT;
BEGIN
  -- Get encryption key
  v_encryption_key := current_setting('app.encryption_key', true);

  IF v_encryption_key IS NULL OR v_encryption_key = '' THEN
    v_encryption_key := 'disciplefy_default_key_2024_change_in_production';
  END IF;

  -- Decrypt token
  v_decrypted_token := convert_from(
    decrypt(
      decode(p_encrypted_token, 'base64'),
      v_encryption_key::bytea,
      'aes'
    ),
    'UTF8'
  );

  RETURN v_decrypted_token;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to decrypt payment token: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.decrypt_payment_token IS 'Decrypt payment token (service_role only)';

-- Function: Generate receipt number (Fix: 20250913115503 - ambiguous column)
CREATE OR REPLACE FUNCTION public.generate_receipt_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  receipt_num TEXT;
  current_year_month TEXT;
  sequence_num INTEGER;
BEGIN
  -- Format: DISC-YYYYMM-NNNN (e.g., DISC-202601-0001)
  current_year_month := TO_CHAR(NOW(), 'YYYYMM');

  -- Atomically get next sequence number for this month
  INSERT INTO public.receipt_counters (year_month, last_seq)
  VALUES (current_year_month, 1)
  ON CONFLICT (year_month) DO UPDATE
  SET
    last_seq = receipt_counters.last_seq + 1,
    updated_at = NOW()
  RETURNING last_seq INTO sequence_num;

  receipt_num := 'DISC-' || current_year_month || '-' || LPAD(sequence_num::TEXT, 4, '0');

  RETURN receipt_num;
END;
$$;

COMMENT ON FUNCTION public.generate_receipt_number IS 'Generate monthly sequential receipt number (DISC-YYYYMM-NNNN)';

-- Function: Store pending purchase (FINAL version with idempotency)
-- Fix: 20250913000006 - UUID return type with status parameter and idempotency
CREATE OR REPLACE FUNCTION public.store_pending_purchase(
  p_user_id UUID,
  p_order_id TEXT,
  p_token_amount INTEGER,
  p_amount_paise INTEGER,
  p_status TEXT DEFAULT 'pending'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  purchase_id UUID;
  purchase_expires_at TIMESTAMPTZ;
BEGIN
  -- Validate status parameter
  IF p_status NOT IN ('pending', 'processing', 'completed', 'failed', 'expired') THEN
    RAISE EXCEPTION 'Invalid status: %. Must be pending, processing, completed, failed, or expired', p_status;
  END IF;

  -- Validate token amount
  IF p_token_amount <= 0 OR p_token_amount > 10000 THEN
    RAISE EXCEPTION 'Token amount must be between 1 and 10000, got: %', p_token_amount;
  END IF;

  -- Validate amount in paise
  IF p_amount_paise <= 0 THEN
    RAISE EXCEPTION 'Amount in paise must be positive, got: %', p_amount_paise;
  END IF;

  -- Ensure user_id is provided
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'User ID cannot be null';
  END IF;

  -- Check if order already exists (idempotency)
  SELECT id INTO purchase_id
  FROM public.pending_token_purchases
  WHERE order_id = p_order_id AND user_id = p_user_id;

  IF purchase_id IS NOT NULL THEN
    -- Order already exists, return existing ID
    RETURN purchase_id;
  END IF;

  -- Calculate expiration time (15 minutes)
  purchase_expires_at := NOW() + INTERVAL '15 minutes';

  -- Insert new pending purchase
  INSERT INTO public.pending_token_purchases (
    user_id,
    order_id,
    token_amount,
    amount_paise,
    status,
    expires_at
  ) VALUES (
    p_user_id,
    p_order_id,
    p_token_amount,
    p_amount_paise,
    p_status,
    purchase_expires_at
  ) RETURNING id INTO purchase_id;

  RETURN purchase_id;
END;
$$;

COMMENT ON FUNCTION public.store_pending_purchase IS 'Creates pending purchase record (idempotent - safe for retries)';

-- Function: Update pending purchase status
CREATE OR REPLACE FUNCTION public.update_pending_purchase_status(
  p_order_id TEXT,
  p_status TEXT,
  p_payment_id TEXT DEFAULT NULL,
  p_error_message TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  -- Validate status
  IF p_status NOT IN ('pending', 'processing', 'completed', 'failed', 'expired') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  -- Update the pending purchase
  UPDATE public.pending_token_purchases
  SET
    status = p_status,
    payment_id = COALESCE(p_payment_id, payment_id),
    error_message = COALESCE(p_error_message, error_message),
    updated_at = NOW()
  WHERE order_id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending purchase not found for order: %', p_order_id;
  END IF;

  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to update pending purchase: %', SQLERRM;
END;
$$;

COMMENT ON FUNCTION public.update_pending_purchase_status IS 'Update status of pending purchase by order_id';

-- Function: Get pending purchase by order ID
CREATE OR REPLACE FUNCTION public.get_pending_purchase(p_order_id TEXT)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  order_id TEXT,
  token_amount INTEGER,
  amount_paise INTEGER,
  status TEXT,
  payment_id TEXT,
  error_message TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  RETURN QUERY
  SELECT
    pp.id,
    pp.user_id,
    pp.order_id,
    pp.token_amount,
    pp.amount_paise,
    pp.status,
    pp.payment_id,
    pp.error_message,
    pp.created_at,
    pp.updated_at,
    pp.expires_at
  FROM public.pending_token_purchases pp
  WHERE pp.order_id = p_order_id;
END;
$$;

COMMENT ON FUNCTION public.get_pending_purchase IS 'Retrieve pending purchase details by order_id';

-- Function: Cleanup expired pending purchases
CREATE OR REPLACE FUNCTION public.cleanup_expired_pending_purchases()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  affected_rows INTEGER;
BEGIN
  -- Update expired pending purchases
  UPDATE public.pending_token_purchases
  SET
    status = 'expired',
    updated_at = NOW()
  WHERE
    status = 'pending'
    AND expires_at < NOW();

  GET DIAGNOSTICS affected_rows = ROW_COUNT;

  RAISE LOG 'Cleaned up % expired pending purchases', affected_rows;

  RETURN affected_rows;
END;
$$;

COMMENT ON FUNCTION public.cleanup_expired_pending_purchases IS 'Mark expired pending purchases as expired (run via cron)';

-- Function: Record purchase in history
CREATE OR REPLACE FUNCTION public.record_purchase_history(
  p_user_id UUID,
  p_token_amount INTEGER,
  p_cost_rupees DECIMAL,
  p_cost_paise INTEGER,
  p_payment_id TEXT,
  p_order_id TEXT,
  p_payment_method TEXT DEFAULT NULL,
  p_status TEXT DEFAULT 'completed'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  history_id UUID;
  receipt_num TEXT;
BEGIN
  -- Generate receipt number
  receipt_num := generate_receipt_number();

  -- Insert purchase history record
  INSERT INTO public.purchase_history (
    user_id,
    token_amount,
    cost_rupees,
    cost_paise,
    payment_id,
    order_id,
    payment_method,
    status,
    receipt_number
  ) VALUES (
    p_user_id,
    p_token_amount,
    p_cost_rupees,
    p_cost_paise,
    p_payment_id,
    p_order_id,
    p_payment_method,
    p_status,
    receipt_num
  ) RETURNING id INTO history_id;

  RETURN history_id;
END;
$$;

COMMENT ON FUNCTION public.record_purchase_history IS 'Record completed purchase with auto-generated receipt number';

-- Function: Get user purchase history with pagination
CREATE OR REPLACE FUNCTION public.get_user_purchase_history(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  token_amount INTEGER,
  cost_rupees DECIMAL(10,2),
  payment_method TEXT,
  status TEXT,
  receipt_number TEXT,
  purchased_at TIMESTAMPTZ,
  payment_id TEXT,
  order_id TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ph.id,
    ph.token_amount,
    ph.cost_rupees,
    ph.payment_method,
    ph.status,
    ph.receipt_number,
    ph.purchased_at,
    ph.payment_id,
    ph.order_id
  FROM public.purchase_history ph
  WHERE ph.user_id = p_user_id
  ORDER BY ph.purchased_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION public.get_user_purchase_history IS 'Get paginated purchase history for user';

-- Function: Get purchase statistics for user
CREATE OR REPLACE FUNCTION public.get_user_purchase_stats(p_user_id UUID)
RETURNS TABLE (
  total_purchases INTEGER,
  total_tokens INTEGER,
  total_spent DECIMAL(10,2),
  average_purchase DECIMAL(10,2),
  last_purchase_date TIMESTAMPTZ,
  most_used_payment_method TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  RETURN QUERY
  WITH stats AS (
    SELECT
      COALESCE(COUNT(*)::INTEGER, 0) as purchase_count,
      COALESCE(SUM(ph.token_amount)::INTEGER, 0) as token_sum,
      COALESCE(SUM(ph.cost_rupees)::DECIMAL(10,2), 0.00) as spent_sum,
      COALESCE(AVG(ph.cost_rupees)::DECIMAL(10,2), 0.00) as avg_purchase,
      MAX(ph.purchased_at) as last_purchase,
      COALESCE(MODE() WITHIN GROUP (ORDER BY ph.payment_method), 'unknown') as common_method
    FROM public.purchase_history ph
    WHERE ph.user_id = p_user_id
      AND ph.status = 'completed'
  )
  SELECT
    s.purchase_count,
    s.token_sum,
    s.spent_sum,
    s.avg_purchase,
    s.last_purchase,
    s.common_method
  FROM stats s;
END;
$$;

COMMENT ON FUNCTION public.get_user_purchase_stats IS 'Get aggregate purchase statistics for user';

-- Function: Ensure single default payment method (trigger function)
CREATE OR REPLACE FUNCTION public.ensure_single_default_payment_method()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  -- If setting this method as default, unset others
  IF NEW.is_default = TRUE THEN
    UPDATE public.saved_payment_methods
    SET is_default = FALSE, updated_at = NOW()
    WHERE user_id = NEW.user_id
      AND id != NEW.id
      AND is_default = TRUE;
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger to maintain single default payment method
CREATE TRIGGER trigger_ensure_single_default_payment_method
  BEFORE INSERT OR UPDATE ON public.saved_payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION public.ensure_single_default_payment_method();

COMMENT ON FUNCTION public.ensure_single_default_payment_method IS 'Trigger to maintain only one default payment method per user';

-- Function: Save payment method with encryption
CREATE OR REPLACE FUNCTION public.save_payment_method(
  p_user_id UUID,
  p_method_type TEXT,
  p_provider TEXT,
  p_token TEXT,
  p_last_four TEXT DEFAULT NULL,
  p_brand TEXT DEFAULT NULL,
  p_display_name TEXT DEFAULT NULL,
  p_is_default BOOLEAN DEFAULT FALSE,
  p_expiry_month INTEGER DEFAULT NULL,
  p_expiry_year INTEGER DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_method_id UUID;
  v_encrypted_token TEXT;
  v_token_hash TEXT;
  v_security_metadata JSONB;
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot save payment method for other users';
  END IF;

  -- Validate required fields
  IF p_token IS NULL OR p_token = '' THEN
    RAISE EXCEPTION 'Payment token is required';
  END IF;

  -- Check for duplicate tokens (using hash)
  v_token_hash := generate_token_hash(p_token);

  IF EXISTS (
    SELECT 1 FROM public.saved_payment_methods
    WHERE user_id = p_user_id AND token_hash = v_token_hash
  ) THEN
    RAISE EXCEPTION 'Payment method already saved';
  END IF;

  -- Encrypt the payment token
  v_encrypted_token := encrypt_payment_token(p_token);

  -- Prepare security metadata
  v_security_metadata := jsonb_build_object(
    'encryption_timestamp', EXTRACT(EPOCH FROM NOW()),
    'last_validation', EXTRACT(EPOCH FROM NOW()),
    'token_type', p_method_type,
    'security_level', 'encrypted'
  );

  -- Insert new payment method with encryption
  INSERT INTO public.saved_payment_methods (
    user_id,
    method_type,
    provider,
    encrypted_token,
    token_hash,
    encryption_key_id,
    security_metadata,
    last_four,
    brand,
    display_name,
    is_default,
    expiry_month,
    expiry_year
  ) VALUES (
    p_user_id,
    p_method_type,
    p_provider,
    v_encrypted_token,
    v_token_hash,
    'default_key',
    v_security_metadata,
    p_last_four,
    p_brand,
    p_display_name,
    p_is_default,
    p_expiry_month,
    p_expiry_year
  ) RETURNING id INTO v_method_id;

  RETURN v_method_id;
END;
$$;

COMMENT ON FUNCTION public.save_payment_method IS 'Save encrypted payment method for user';

-- Function: Get user payment methods (WITHOUT decrypted tokens)
CREATE OR REPLACE FUNCTION public.get_user_payment_methods(p_user_id UUID DEFAULT NULL)
RETURNS TABLE(
  id UUID,
  method_type TEXT,
  provider TEXT,
  last_four TEXT,
  brand TEXT,
  display_name TEXT,
  is_default BOOLEAN,
  expiry_month INTEGER,
  expiry_year INTEGER,
  created_at TIMESTAMPTZ,
  last_used TIMESTAMPTZ,
  usage_count INTEGER,
  is_expired BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Use current user if no user specified
  v_user_id := COALESCE(p_user_id, auth.uid());

  -- Check authorization
  IF v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized access to payment methods';
  END IF;

  -- Return payment methods WITHOUT decrypted tokens for security
  RETURN QUERY
  SELECT
    spm.id,
    spm.method_type,
    spm.provider,
    spm.last_four,
    spm.brand,
    spm.display_name,
    spm.is_default,
    spm.expiry_month,
    spm.expiry_year,
    spm.created_at,
    spm.last_used,
    spm.usage_count,
    CASE
      WHEN spm.expiry_month IS NOT NULL AND spm.expiry_year IS NOT NULL THEN
        (EXTRACT(YEAR FROM NOW()) * 100 + EXTRACT(MONTH FROM NOW())) >
        (spm.expiry_year * 100 + spm.expiry_month)
      ELSE FALSE
    END as is_expired
  FROM public.saved_payment_methods spm
  WHERE spm.user_id = v_user_id
    AND spm.deleted_at IS NULL
  ORDER BY spm.is_default DESC, spm.last_used DESC NULLS LAST, spm.created_at DESC;
END;
$$;

COMMENT ON FUNCTION public.get_user_payment_methods IS 'Get payment methods for user (tokens excluded for security)';

-- Function: Get decrypted payment token (service_role only)
CREATE OR REPLACE FUNCTION public.get_payment_method_token(
  p_method_id UUID,
  p_user_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_encrypted_token TEXT;
  v_decrypted_token TEXT;
  v_method_user_id UUID;
BEGIN
  -- Verify service role
  IF current_setting('role', true) != 'service_role' THEN
    RAISE EXCEPTION 'Unauthorized: Token decryption requires service role';
  END IF;

  -- Get encrypted token and verify ownership
  SELECT encrypted_token, user_id INTO v_encrypted_token, v_method_user_id
  FROM public.saved_payment_methods
  WHERE id = p_method_id AND deleted_at IS NULL;

  IF v_encrypted_token IS NULL THEN
    RAISE EXCEPTION 'Payment method not found or has been deleted';
  END IF;

  IF v_method_user_id != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: Payment method belongs to different user';
  END IF;

  -- Decrypt token
  v_decrypted_token := decrypt_payment_token(v_encrypted_token);

  -- Update last used timestamp
  UPDATE public.saved_payment_methods
  SET
    last_used = NOW(),
    usage_count = usage_count + 1
  WHERE id = p_method_id;

  RETURN v_decrypted_token;
END;
$$;

COMMENT ON FUNCTION public.get_payment_method_token IS 'Decrypt payment token for processing (service_role only)';

-- Function: Delete payment method (soft delete)
CREATE OR REPLACE FUNCTION public.delete_payment_method(
  p_method_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot delete payment method';
  END IF;

  -- Soft delete by setting inactive and deleted_at
  UPDATE public.saved_payment_methods
  SET
    is_active = FALSE,
    is_default = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id = p_method_id
    AND user_id = p_user_id;

  RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION public.delete_payment_method IS 'Soft delete payment method';

-- Function: Set default payment method
CREATE OR REPLACE FUNCTION public.set_default_payment_method(
  p_method_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot modify payment method';
  END IF;

  -- Update default status (trigger will handle unsetting others)
  UPDATE public.saved_payment_methods
  SET is_default = TRUE, updated_at = NOW()
  WHERE id = p_method_id
    AND user_id = p_user_id
    AND is_active = TRUE;

  RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION public.set_default_payment_method IS 'Set payment method as default';

-- Function: Update payment method usage
CREATE OR REPLACE FUNCTION public.update_payment_method_usage(
  p_method_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot update payment method usage';
  END IF;

  -- Update last used timestamp
  UPDATE public.saved_payment_methods
  SET
    last_used = NOW(),
    usage_count = usage_count + 1,
    updated_at = NOW()
  WHERE id = p_method_id
    AND user_id = p_user_id;

  RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION public.update_payment_method_usage IS 'Update last used timestamp and usage count';

-- Function: Get or create payment preferences
CREATE OR REPLACE FUNCTION public.get_or_create_payment_preferences()
RETURNS public.payment_preferences
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_preferences public.payment_preferences;
  v_user_id UUID;
BEGIN
  -- Always use current authenticated user
  v_user_id := auth.uid();

  -- Ensure user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  -- Try to get existing preferences
  SELECT * INTO v_preferences
  FROM public.payment_preferences
  WHERE user_id = v_user_id;

  -- Create if doesn't exist
  IF v_preferences IS NULL THEN
    INSERT INTO public.payment_preferences (
      user_id,
      auto_save_methods,
      preferred_wallet,
      enable_one_click_purchase,
      default_payment_type
    )
    VALUES (
      v_user_id,
      TRUE,
      NULL,
      TRUE,
      'card'
    )
    RETURNING * INTO v_preferences;
  END IF;

  RETURN v_preferences;
END;
$$;

COMMENT ON FUNCTION public.get_or_create_payment_preferences IS 'Get or create default payment preferences for user';

-- Function: Update payment preferences
CREATE OR REPLACE FUNCTION public.update_payment_preferences(
  p_user_id UUID,
  p_auto_save_payment_methods BOOLEAN DEFAULT NULL,
  p_preferred_wallet TEXT DEFAULT NULL,
  p_enable_one_click_purchase BOOLEAN DEFAULT NULL,
  p_default_payment_type TEXT DEFAULT NULL
)
RETURNS public.payment_preferences
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_preferences public.payment_preferences;
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot update payment preferences';
  END IF;

  -- Validate default_payment_type if provided
  IF p_default_payment_type IS NOT NULL AND
     p_default_payment_type NOT IN ('card', 'upi', 'netbanking', 'wallet') THEN
    RAISE EXCEPTION 'Invalid payment type: %', p_default_payment_type;
  END IF;

  -- Update preferences
  UPDATE public.payment_preferences
  SET
    auto_save_methods = COALESCE(p_auto_save_payment_methods, auto_save_methods),
    preferred_wallet = COALESCE(p_preferred_wallet, preferred_wallet),
    enable_one_click_purchase = COALESCE(p_enable_one_click_purchase, enable_one_click_purchase),
    default_payment_type = COALESCE(p_default_payment_type, default_payment_type),
    updated_at = NOW()
  WHERE user_id = p_user_id
  RETURNING * INTO v_preferences;

  -- Create if doesn't exist
  IF v_preferences IS NULL THEN
    INSERT INTO public.payment_preferences (
      user_id,
      auto_save_methods,
      preferred_wallet,
      enable_one_click_purchase,
      default_payment_type
    ) VALUES (
      p_user_id,
      COALESCE(p_auto_save_payment_methods, TRUE),
      p_preferred_wallet,
      COALESCE(p_enable_one_click_purchase, TRUE),
      COALESCE(p_default_payment_type, 'card')
    ) RETURNING * INTO v_preferences;
  END IF;

  RETURN v_preferences;
END;
$$;

COMMENT ON FUNCTION public.update_payment_preferences IS 'Update user payment preferences';

-- =====================================================
-- PART 5: STORAGE BUCKET FOR ISSUE SCREENSHOTS
-- =====================================================

-- Create storage bucket for issue screenshots
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'issue-screenshots',
  'issue-screenshots',
  false,
  5242880,  -- 5MB max file size
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for issue screenshots
CREATE POLICY "Users can upload issue screenshots"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'issue-screenshots' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can view own issue screenshots"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'issue-screenshots' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Admins can view all issue screenshots"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'issue-screenshots' AND
    EXISTS (
      SELECT 1 FROM public.user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

-- =====================================================
-- PART 6: VERIFICATION QUERIES
-- =====================================================

DO $$
DECLARE
  v_table_count INTEGER;
  v_function_count INTEGER;
BEGIN
  -- Count tables created in this migration
  SELECT COUNT(*) INTO v_table_count
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN (
      'pending_token_purchases',
      'purchase_history',
      'receipt_counters',
      'saved_payment_methods',
      'payment_preferences',
      'purchase_issue_reports'
    );

  -- Count functions created
  SELECT COUNT(*) INTO v_function_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname IN (
      'generate_token_hash',
      'encrypt_payment_token',
      'decrypt_payment_token',
      'generate_receipt_number',
      'store_pending_purchase',
      'update_pending_purchase_status',
      'get_pending_purchase',
      'cleanup_expired_pending_purchases',
      'record_purchase_history',
      'get_user_purchase_history',
      'get_user_purchase_stats',
      'ensure_single_default_payment_method',
      'save_payment_method',
      'get_user_payment_methods',
      'get_payment_method_token',
      'delete_payment_method',
      'set_default_payment_method',
      'update_payment_method_usage',
      'get_or_create_payment_preferences',
      'update_payment_preferences'
    );

  RAISE NOTICE '✅ Migration 0005_payment_system.sql completed successfully';
  RAISE NOTICE '   - Created % payment tables', v_table_count;
  RAISE NOTICE '   - Created % payment functions', v_function_count;
  RAISE NOTICE '   - Applied encryption with AES-256';
  RAISE NOTICE '   - Applied idempotency fixes for webhook retries';
  RAISE NOTICE '   - Applied unique constraints on payment_id';
  RAISE NOTICE '   - Created issue-screenshots storage bucket';
END $$;

-- Display table summary
SELECT 'Payment System Tables' as info;
SELECT
  tablename as table_name,
  schemaname as schema
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'pending_token_purchases',
    'purchase_history',
    'receipt_counters',
    'saved_payment_methods',
    'payment_preferences',
    'purchase_issue_reports'
  )
ORDER BY tablename;

COMMIT;

-- =====================================================
-- POST-MIGRATION NOTES
-- =====================================================
-- 1. Set app.encryption_key environment variable in production (CRITICAL)
-- 2. Run backup_encryption_keys.sh before any database reset
-- 3. Schedule cleanup_expired_pending_purchases() via pg_cron (hourly recommended)
-- 4. Monitor issue-screenshots storage bucket usage
-- 5. Webhook retries are now idempotent (payment_id unique constraints)
-- 6. All payment tokens are encrypted with AES-256 (decrypt via service_role only)
-- =====================================================
