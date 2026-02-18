-- =====================================================
-- Consolidated Migration: Admin Configuration
-- =====================================================
-- Source: Manual merge of admin user and test account migrations
-- Description: Admin user setup, test accounts, and system configuration
--              MUST be last migration (depends on all tables)
-- =====================================================

-- Dependencies: All migrations (0001-0014) must be complete

BEGIN;

-- =====================================================
-- SUMMARY: Migration configures admin users and test accounts
-- Completed 0001-0014 (all schema + seed data), now
-- setting up admin access and test accounts
-- =====================================================

-- =====================================================
-- PART 1: ADMIN USER CONFIGURATION (fennsaji@gmail.com)
-- =====================================================

-- ⚠️ IMPORTANT: fennsaji@gmail.com must sign in via OAuth FIRST
--    This creates the auth.users and user_profiles records
--    Then this migration can grant admin access
--
--    If you get "Access Denied" after DB reset:
--    1. Sign in to admin web with Google OAuth (fennsaji@gmail.com)
--    2. Run: psql <db> -f grant_admin.sql
--    Or use Supabase Studio to set is_admin = true manually

-- Set admin status for fennsaji@gmail.com
-- Note: If user doesn't exist in auth.users, this does nothing
UPDATE user_profiles
SET is_admin = true,
    updated_at = NOW()
WHERE id = (
  SELECT id FROM auth.users WHERE email = 'fennsaji@gmail.com'
);

-- Delete any existing subscription for admin user (clean slate)
DELETE FROM subscriptions
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'fennsaji@gmail.com');

-- Grant admin user premium subscription (effectively unlimited)
INSERT INTO subscriptions (
  user_id,
  provider,
  provider_subscription_id,
  plan_id,
  status,
  current_period_start,
  current_period_end,
  metadata
)
SELECT
  au.id,
  'razorpay',
  'sub_granted_admin_' || gen_random_uuid()::TEXT,
  (SELECT id FROM subscription_plans WHERE plan_code = 'premium'),
  'active',
  NOW(),
  NOW() + INTERVAL '100 years',  -- Effectively unlimited access
  '{"granted": true, "reason": "admin_account"}'::jsonb
FROM auth.users au
WHERE au.email = 'fennsaji@gmail.com';

-- =====================================================
-- PART 2: TEST ACCOUNT CONFIGURATION (Play Store Reviewer)
-- =====================================================

-- Create Play Store reviewer test account
-- PREREQUISITE: auth.users account must exist (created via Supabase Dashboard)
-- Email: app.reviewer@disciplefy.in
-- Password: Set securely in Supabase Dashboard (DO NOT commit passwords)

DO $$
DECLARE
  v_user_id UUID;
  v_email TEXT := 'app.reviewer@disciplefy.in';
BEGIN
  -- Get the user ID
  SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;

  IF v_user_id IS NULL THEN
    RAISE NOTICE 'User % not found in auth.users. Create via Supabase Dashboard first.', v_email;
    RETURN;
  END IF;

  -- Step 1: Create/update user_profiles
  INSERT INTO user_profiles (
    id,
    language_preference,
    theme_preference
  ) VALUES (
    v_user_id,
    'en',
    'light'
  )
  ON CONFLICT (id) DO UPDATE SET
    language_preference = EXCLUDED.language_preference,
    theme_preference = EXCLUDED.theme_preference,
    updated_at = NOW();

  RAISE NOTICE 'Created user_profiles for %', v_email;

  -- Step 2: Remove any existing subscription
  DELETE FROM subscriptions WHERE user_id = v_user_id;

  -- Step 3: Create premium subscription (100-year validity for testing)
  INSERT INTO subscriptions (
    user_id,
    provider,
    provider_subscription_id,
    plan_id,
    status,
    current_period_start,
    current_period_end,
    metadata
  ) VALUES (
    v_user_id,
    'razorpay',
    'sub_playstore_reviewer_' || gen_random_uuid()::TEXT,
    (SELECT id FROM subscription_plans WHERE plan_code = 'premium'),
    'active',
    NOW(),
    NOW() + INTERVAL '100 years',
    '{"granted": true, "reason": "playstore_review_account"}'::jsonb
  );

  RAISE NOTICE 'Created premium subscription for %', v_email;

  -- Step 4: Premium tokens initialized automatically by get_or_create_user_tokens()
  RAISE NOTICE 'Play Store reviewer account setup complete for %', v_email;
END $$;

-- NOTE: system_config table and entries moved to 20260214000001_system_config_features.sql
--       for better logical separation

-- =====================================================
-- PART 3: ADMIN ACTIONS AUDIT TRAIL
-- =====================================================

-- Create admin_actions table for tracking administrative actions
CREATE TABLE IF NOT EXISTS admin_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL, -- 'adjust_tokens', 'update_issue', etc.
  target_user_id TEXT, -- User ID or identifier affected
  details JSONB, -- Action-specific details
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_admin_actions_admin ON admin_actions(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_actions_type ON admin_actions(action_type);
CREATE INDEX IF NOT EXISTS idx_admin_actions_target ON admin_actions(target_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_actions_created_at ON admin_actions(created_at DESC);

-- Enable RLS
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Only admins can view admin actions
DROP POLICY IF EXISTS "Admins can view all admin actions" ON admin_actions;
CREATE POLICY "Admins can view all admin actions"
  ON admin_actions
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

-- Only admins can insert admin actions
DROP POLICY IF EXISTS "Admins can insert admin actions" ON admin_actions;
CREATE POLICY "Admins can insert admin actions"
  ON admin_actions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

COMMENT ON TABLE admin_actions IS 'Audit trail for administrative actions performed by admin users';
COMMENT ON COLUMN admin_actions.action_type IS 'Type of administrative action (adjust_tokens, update_issue, etc.)';
COMMENT ON COLUMN admin_actions.target_user_id IS 'User ID or identifier affected by the action';
COMMENT ON COLUMN admin_actions.details IS 'JSON object containing action-specific details';

-- =====================================================
-- PART 4: SUBSCRIPTION PRICE AUDIT LOG
-- =====================================================

CREATE TABLE IF NOT EXISTS admin_subscription_price_audit (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  admin_email TEXT,
  plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
  plan_code TEXT NOT NULL,
  plan_provider_id UUID REFERENCES subscription_plan_providers(id) ON DELETE SET NULL,
  provider TEXT NOT NULL CHECK (provider IN ('razorpay', 'google_play', 'apple_appstore')),
  action TEXT NOT NULL CHECK (action IN (
    'razorpay_plan_creation',
    'razorpay_plan_deprecation',
    'iap_price_update',
    'price_sync_verification',
    'manual_price_override'
  )),
  old_price_minor INTEGER,
  new_price_minor INTEGER,
  price_difference_minor INTEGER,
  currency TEXT DEFAULT 'INR',
  old_provider_plan_id TEXT,
  new_provider_plan_id TEXT,
  affected_active_subscriptions INTEGER DEFAULT 0,
  affected_trial_subscriptions INTEGER DEFAULT 0,
  migration_strategy TEXT CHECK (migration_strategy IN ('keep_existing', 'migrate_active', NULL)),
  sync_status_before TEXT,
  sync_status_after TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_price_audit_admin ON admin_subscription_price_audit(admin_user_id);
CREATE INDEX idx_price_audit_plan ON admin_subscription_price_audit(plan_id);
CREATE INDEX idx_price_audit_plan_code ON admin_subscription_price_audit(plan_code);
CREATE INDEX idx_price_audit_provider ON admin_subscription_price_audit(provider);
CREATE INDEX idx_price_audit_action ON admin_subscription_price_audit(action);
CREATE INDEX idx_price_audit_created ON admin_subscription_price_audit(created_at DESC);
CREATE INDEX idx_price_audit_dashboard
  ON admin_subscription_price_audit(created_at DESC, provider, action)
  WHERE action IN ('razorpay_plan_creation', 'iap_price_update');

ALTER TABLE admin_subscription_price_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admins_can_view_price_audit_logs"
  ON admin_subscription_price_audit FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = auth.uid() AND is_admin = true
    )
  );

CREATE POLICY "service_role_full_access_price_audit"
  ON admin_subscription_price_audit FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE OR REPLACE FUNCTION log_subscription_price_change(
  p_admin_user_id UUID,
  p_plan_id UUID,
  p_provider TEXT,
  p_action TEXT,
  p_old_price_minor INTEGER,
  p_new_price_minor INTEGER,
  p_old_provider_plan_id TEXT DEFAULT NULL,
  p_new_provider_plan_id TEXT DEFAULT NULL,
  p_affected_subscriptions INTEGER DEFAULT 0,
  p_notes TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
  v_audit_id UUID;
  v_admin_email TEXT;
  v_plan_code TEXT;
  v_currency TEXT;
  v_price_diff INTEGER;
BEGIN
  SELECT email INTO v_admin_email FROM auth.users WHERE id = p_admin_user_id;
  SELECT plan_code INTO v_plan_code FROM subscription_plans WHERE id = p_plan_id;
  SELECT currency INTO v_currency
  FROM subscription_plan_providers
  WHERE plan_id = p_plan_id AND provider = p_provider
  LIMIT 1;

  v_price_diff := COALESCE(p_new_price_minor, 0) - COALESCE(p_old_price_minor, 0);

  INSERT INTO admin_subscription_price_audit (
    admin_user_id, admin_email, plan_id, plan_code, provider, action,
    old_price_minor, new_price_minor, price_difference_minor, currency,
    old_provider_plan_id, new_provider_plan_id,
    affected_active_subscriptions, notes, metadata
  ) VALUES (
    p_admin_user_id, v_admin_email, p_plan_id, v_plan_code, p_provider, p_action,
    p_old_price_minor, p_new_price_minor, v_price_diff, COALESCE(v_currency, 'INR'),
    p_old_provider_plan_id, p_new_provider_plan_id,
    p_affected_subscriptions, p_notes, p_metadata
  ) RETURNING id INTO v_audit_id;

  RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION log_subscription_price_change IS
  'Helper function to log subscription price changes with full context';

CREATE OR REPLACE VIEW admin_price_change_history AS
SELECT
  a.id, a.created_at, a.admin_email, a.plan_code, a.provider, a.action,
  CONCAT(a.currency, ' ', ROUND(a.old_price_minor::numeric / 100, 2)) AS old_price_formatted,
  CONCAT(a.currency, ' ', ROUND(a.new_price_minor::numeric / 100, 2)) AS new_price_formatted,
  CONCAT(
    CASE
      WHEN a.price_difference_minor > 0 THEN '+'
      WHEN a.price_difference_minor < 0 THEN '-'
      ELSE ''
    END,
    a.currency, ' ', ROUND(ABS(a.price_difference_minor)::numeric / 100, 2)
  ) AS price_change_formatted,
  a.affected_active_subscriptions, a.old_provider_plan_id, a.new_provider_plan_id,
  a.notes, sp.plan_name
FROM admin_subscription_price_audit a
JOIN subscription_plans sp ON a.plan_id = sp.id
ORDER BY a.created_at DESC;

COMMENT ON VIEW admin_price_change_history IS
  'Formatted view of price changes for admin dashboard display';

GRANT SELECT ON admin_price_change_history TO authenticated;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

COMMIT;

-- Verification queries (system_config removed - created in later migration)
SELECT
  'Migration 0015 Complete' as status,
  (SELECT COUNT(*) FROM user_profiles WHERE is_admin = TRUE) as admin_count,
  (SELECT COUNT(*) FROM subscriptions WHERE metadata->>'granted' = 'true') as granted_subscriptions,
  (SELECT COUNT(*) FROM admin_actions) as admin_actions_count;

-- Display admin users
SELECT
  u.email,
  up.language_preference,
  up.is_admin,
  s.status as subscription_status,
  sp.plan_name
FROM auth.users u
JOIN user_profiles up ON u.id = up.id
LEFT JOIN subscriptions s ON u.id = s.user_id
LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
WHERE up.is_admin = TRUE OR u.email LIKE '%reviewer%disciplefy%';
