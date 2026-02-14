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

-- =====================================================
-- PART 3: SYSTEM CONFIGURATION
-- =====================================================

-- Create system_config table if not exists (for feature flags, settings)
CREATE TABLE IF NOT EXISTS system_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on system_config
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;

-- Policy: Public read access
CREATE POLICY "Allow public read access to system config"
  ON system_config
  FOR SELECT
  TO public
  USING (true);

-- Policy: Only service role can write
CREATE POLICY "Only service role can modify system config"
  ON system_config
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Insert default system configuration
INSERT INTO system_config (key, value, description) VALUES
  ('app_version', '1.0.0', 'Current application version'),
  ('maintenance_mode', 'false', 'Enable maintenance mode (true/false)'),
  ('trial_period_days', '7', 'Free trial period in days'),
  ('max_free_guides_per_day', '3', 'Maximum free study guides per day'),
  ('feature_voice_buddy', 'true', 'Enable voice conversation feature'),
  ('feature_learning_paths', 'true', 'Enable learning paths feature'),
  ('feature_memory_verses', 'true', 'Enable memory verses feature'),
  ('admin_emails', 'fennsaji@gmail.com', 'Comma-separated list of admin emails (server-side only)')
ON CONFLICT (key) DO NOTHING;

-- =====================================================
-- PART 4: ADMIN ACTIONS AUDIT TRAIL
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
-- PART 5: COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON TABLE system_config IS
  'System-wide configuration and feature flags.
   Used for maintenance mode, versioning, and feature toggles.';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

COMMIT;

-- Verification queries
SELECT
  'Migration 0015 Complete' as status,
  (SELECT COUNT(*) FROM user_profiles WHERE is_admin = TRUE) as admin_count,
  (SELECT COUNT(*) FROM subscriptions WHERE metadata->>'granted' = 'true') as granted_subscriptions,
  (SELECT COUNT(*) FROM system_config) as config_entries;

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
