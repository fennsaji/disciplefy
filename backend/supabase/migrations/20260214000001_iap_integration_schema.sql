-- IAP Integration Schema Migration
-- Creates tables, indexes, RLS policies, and functions for In-App Purchase support
-- Supports both Google Play Store and Apple App Store

-- ============================================================================
-- 1. IAP Configuration Table
-- Store IAP configuration (credentials, secrets, environment)
-- ============================================================================

CREATE TABLE iap_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL CHECK (provider IN ('google_play', 'apple_appstore')),
  environment TEXT NOT NULL CHECK (environment IN ('sandbox', 'production')),
  config_key TEXT NOT NULL,
  config_value TEXT NOT NULL,  -- Encrypted using Supabase Vault
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(provider, environment, config_key)
);

-- Example entries:
-- Google Play Production: service_account_email, service_account_key
-- Apple Production: shared_secret, bundle_id
-- Google Play Sandbox: service_account_email, service_account_key
-- Apple Sandbox: shared_secret, bundle_id

COMMENT ON TABLE iap_config IS 'IAP provider configuration (credentials encrypted via Supabase Vault)';
COMMENT ON COLUMN iap_config.config_value IS 'Encrypted credential stored in Supabase Vault';

-- ============================================================================
-- 2. IAP Receipts Table
-- Store purchase receipts for verification and audit
-- ============================================================================

CREATE TABLE iap_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
  provider TEXT NOT NULL CHECK (provider IN ('google_play', 'apple_appstore')),

  -- Receipt data
  receipt_data TEXT NOT NULL,  -- Encrypted raw receipt
  product_id TEXT NOT NULL,    -- e.g., 'com.disciplefy.premium_monthly'
  transaction_id TEXT NOT NULL UNIQUE,  -- Unique transaction ID from store

  -- Validation status
  validation_status TEXT NOT NULL DEFAULT 'pending' CHECK (
    validation_status IN ('pending', 'valid', 'invalid', 'expired', 'refunded', 'cancelled')
  ),
  validation_response JSONB,  -- Full response from Google/Apple
  validated_at TIMESTAMPTZ,

  -- Purchase details
  purchase_date TIMESTAMPTZ NOT NULL,
  expiry_date TIMESTAMPTZ,  -- For subscriptions
  is_trial BOOLEAN DEFAULT false,
  is_intro_offer BOOLEAN DEFAULT false,

  -- Metadata
  environment TEXT NOT NULL DEFAULT 'production' CHECK (environment IN ('sandbox', 'production')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for iap_receipts
CREATE INDEX idx_iap_receipts_user_id ON iap_receipts(user_id);
CREATE INDEX idx_iap_receipts_subscription_id ON iap_receipts(subscription_id);
CREATE INDEX idx_iap_receipts_transaction_id ON iap_receipts(transaction_id);
CREATE INDEX idx_iap_receipts_validation_status ON iap_receipts(validation_status);
CREATE INDEX idx_iap_receipts_expiry_date ON iap_receipts(expiry_date);

COMMENT ON TABLE iap_receipts IS 'Purchase receipts from Google Play and Apple App Store';
COMMENT ON COLUMN iap_receipts.receipt_data IS 'Encrypted receipt data from store';
COMMENT ON COLUMN iap_receipts.validation_response IS 'Full JSON response from receipt validation';

-- ============================================================================
-- 3. IAP Verification Logs Table
-- Audit trail for all receipt verification attempts
-- ============================================================================

CREATE TABLE iap_verification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_id UUID NOT NULL REFERENCES iap_receipts(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('google_play', 'apple_appstore')),

  -- Verification details
  verification_method TEXT NOT NULL CHECK (
    verification_method IN ('api', 'webhook', 'manual')
  ),
  verification_result TEXT NOT NULL CHECK (
    verification_result IN ('success', 'failure', 'error')
  ),

  -- Request/Response
  request_payload JSONB,
  response_payload JSONB,
  error_message TEXT,
  http_status_code INTEGER,

  -- Metadata
  verified_by UUID REFERENCES auth.users(id),  -- NULL for automatic verifications
  verified_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for iap_verification_logs
CREATE INDEX idx_iap_verification_logs_receipt_id ON iap_verification_logs(receipt_id);
CREATE INDEX idx_iap_verification_logs_verified_at ON iap_verification_logs(verified_at);

COMMENT ON TABLE iap_verification_logs IS 'Audit trail for all IAP receipt verification attempts';

-- ============================================================================
-- 4. IAP Webhook Events Table
-- Store webhook notifications from Google Play and Apple App Store
-- ============================================================================

CREATE TABLE iap_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL CHECK (provider IN ('google_play', 'apple_appstore')),

  -- Event details
  event_type TEXT NOT NULL,  -- e.g., 'SUBSCRIPTION_PURCHASED', 'SUBSCRIPTION_RENEWED'
  notification_id TEXT,  -- Unique ID from store (for deduplication)

  -- Payload
  raw_payload JSONB NOT NULL,
  parsed_data JSONB,

  -- Processing status
  processing_status TEXT NOT NULL DEFAULT 'pending' CHECK (
    processing_status IN ('pending', 'processing', 'processed', 'failed')
  ),
  processed_at TIMESTAMPTZ,
  error_message TEXT,

  -- Related records
  transaction_id TEXT,
  receipt_id UUID REFERENCES iap_receipts(id),
  subscription_id UUID REFERENCES subscriptions(id),

  -- Metadata
  received_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  UNIQUE(provider, notification_id)  -- Prevent duplicate processing
);

-- Indexes for iap_webhook_events
CREATE INDEX idx_iap_webhook_events_transaction_id ON iap_webhook_events(transaction_id);
CREATE INDEX idx_iap_webhook_events_processing_status ON iap_webhook_events(processing_status);
CREATE INDEX idx_iap_webhook_events_received_at ON iap_webhook_events(received_at);

COMMENT ON TABLE iap_webhook_events IS 'Webhook notifications from Google Play and Apple App Store';
COMMENT ON COLUMN iap_webhook_events.notification_id IS 'Unique notification ID for deduplication';

-- ============================================================================
-- 5. Update Subscriptions Table
-- Add IAP-specific columns to existing subscriptions table
-- ============================================================================

ALTER TABLE subscriptions
  ADD COLUMN IF NOT EXISTS iap_receipt_id UUID REFERENCES iap_receipts(id),
  ADD COLUMN IF NOT EXISTS iap_product_id TEXT,  -- e.g., 'com.disciplefy.premium_monthly'
  ADD COLUMN IF NOT EXISTS iap_original_transaction_id TEXT,  -- For subscription renewals
  ADD COLUMN IF NOT EXISTS is_iap_subscription BOOLEAN DEFAULT false;

-- Indexes for subscriptions IAP columns
CREATE INDEX IF NOT EXISTS idx_subscriptions_iap_receipt_id ON subscriptions(iap_receipt_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_iap_original_transaction_id ON subscriptions(iap_original_transaction_id);

COMMENT ON COLUMN subscriptions.iap_receipt_id IS 'Link to IAP receipt if purchased via Google Play or App Store';
COMMENT ON COLUMN subscriptions.iap_original_transaction_id IS 'Original transaction ID for tracking subscription renewals';

-- ============================================================================
-- 6. RLS Policies
-- ============================================================================

-- Enable RLS on all IAP tables
ALTER TABLE iap_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE iap_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE iap_verification_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE iap_webhook_events ENABLE ROW LEVEL SECURITY;

-- IAP Config: Only service role can access
CREATE POLICY "Only service role can access IAP config"
  ON iap_config FOR ALL
  USING (auth.role() = 'service_role');

-- IAP Receipts: Users can only read their own receipts
CREATE POLICY "Users can view own IAP receipts"
  ON iap_receipts FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage IAP receipts"
  ON iap_receipts FOR ALL
  USING (auth.role() = 'service_role');

-- IAP Verification Logs: Users can view logs for their receipts
CREATE POLICY "Users can view verification logs for their receipts"
  ON iap_verification_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM iap_receipts
      WHERE iap_receipts.id = iap_verification_logs.receipt_id
        AND iap_receipts.user_id = auth.uid()
    )
  );

CREATE POLICY "Service role can manage verification logs"
  ON iap_verification_logs FOR ALL
  USING (auth.role() = 'service_role');

-- IAP Webhook Events: Only service role can access
CREATE POLICY "Only service role can access webhook events"
  ON iap_webhook_events FOR ALL
  USING (auth.role() = 'service_role');

-- ============================================================================
-- 7. Database Functions
-- ============================================================================

-- Function to get decrypted IAP config
CREATE OR REPLACE FUNCTION get_iap_config(
  p_provider TEXT,
  p_environment TEXT,
  p_config_key TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_config_value TEXT;
BEGIN
  SELECT config_value INTO v_config_value
  FROM iap_config
  WHERE provider = p_provider
    AND environment = p_environment
    AND config_key = p_config_key
    AND is_active = true;

  -- Decrypt using Supabase Vault (implementation depends on Supabase version)
  -- TODO: Integrate with Supabase Vault for encryption/decryption
  -- RETURN pgsodium.decrypt(v_config_value::bytea, vault_key);

  RETURN v_config_value;  -- Placeholder until Vault integration
END;
$$;

COMMENT ON FUNCTION get_iap_config IS 'Retrieve decrypted IAP configuration value';

-- Function to validate IAP receipt ownership
CREATE OR REPLACE FUNCTION validate_iap_receipt_ownership(
  p_receipt_id UUID,
  p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_owner_id UUID;
BEGIN
  SELECT user_id INTO v_owner_id
  FROM iap_receipts
  WHERE id = p_receipt_id;

  RETURN v_owner_id = p_user_id;
END;
$$;

COMMENT ON FUNCTION validate_iap_receipt_ownership IS 'Verify that a receipt belongs to the specified user';

-- Function to get active IAP subscription for user
CREATE OR REPLACE FUNCTION get_active_iap_subscription(p_user_id UUID)
RETURNS TABLE (
  subscription_id UUID,
  plan_code TEXT,
  provider TEXT,
  expiry_date TIMESTAMPTZ,
  auto_renew BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    s.plan_type,
    ir.provider,
    ir.expiry_date,
    s.cancel_at_cycle_end = false AS auto_renew
  FROM subscriptions s
  INNER JOIN iap_receipts ir ON ir.id = s.iap_receipt_id
  WHERE s.user_id = p_user_id
    AND s.status IN ('active', 'authenticated')
    AND s.is_iap_subscription = true
    AND ir.validation_status = 'valid'
    AND (ir.expiry_date IS NULL OR ir.expiry_date > NOW())
  ORDER BY s.created_at DESC
  LIMIT 1;
END;
$$;

COMMENT ON FUNCTION get_active_iap_subscription IS 'Get the active IAP subscription for a user';

-- ============================================================================
-- Migration Complete
-- ============================================================================

-- Add migration metadata
INSERT INTO public.schema_version (version, description, applied_at)
VALUES (
  '20260214000001',
  'IAP Integration Schema - Tables, indexes, RLS policies, and functions',
  NOW()
)
ON CONFLICT (version) DO NOTHING;
