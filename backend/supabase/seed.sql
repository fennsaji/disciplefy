-- ============================================================================
-- Supabase Seed Data - Admin Configuration
-- ============================================================================
-- This file runs automatically after migrations when you run:
--   supabase db reset
--
-- Purpose: Set up admin access for local development
-- ============================================================================

-- ============================================================================
-- ADMIN CONFIGURATION
-- ============================================================================
-- Configure admin emails - users with these emails get auto-admin access on login
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '🔧 Setting up admin configuration...';
END $$;

-- Insert or update admin_emails in system_config
INSERT INTO system_config (key, value, description)
VALUES (
  'admin_emails',
  'fennsaji@gmail.com,admin@disciplefy.in',  -- 👈 Add your admin email(s) here (comma-separated for multiple)
  'Comma-separated list of emails that should have admin access to the admin panel'
)
ON CONFLICT (key)
DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();

DO $$
BEGIN
  RAISE NOTICE '✅ Admin emails configured: fennsaji@gmail.com';
END $$;

-- ============================================================================
-- AUTO-GRANT ADMIN ACCESS (if user already exists)
-- ============================================================================
-- This handles the case where you've already logged in before running reset
-- It will automatically grant admin access to any existing user with admin email
-- ============================================================================

DO $$
DECLARE
  admin_email TEXT;
  admin_emails_list TEXT;
  user_record RECORD;
  admin_count INTEGER := 0;
BEGIN
  RAISE NOTICE '🔍 Checking for existing users with admin emails...';

  -- Get admin emails from system_config
  SELECT value INTO admin_emails_list
  FROM system_config
  WHERE key = 'admin_emails';

  IF admin_emails_list IS NULL THEN
    RAISE NOTICE '⚠️  No admin emails configured in system_config';
    RETURN;
  END IF;

  -- Loop through each admin email (comma-separated)
  FOREACH admin_email IN ARRAY string_to_array(admin_emails_list, ',')
  LOOP
    admin_email := trim(admin_email);

    -- Check if user exists in auth.users
    SELECT id, email INTO user_record
    FROM auth.users
    WHERE email = admin_email
    LIMIT 1;

    IF FOUND THEN
      RAISE NOTICE '👤 Found existing user: %', admin_email;

      -- Create or update user profile with admin access
      INSERT INTO user_profiles (
        id,
        first_name,
        last_name,
        language_preference,
        theme_preference,
        is_admin
      )
      VALUES (
        user_record.id,
        'Admin',
        'User',
        'en',
        'light',
        true
      )
      ON CONFLICT (id)
      DO UPDATE SET
        is_admin = true,
        updated_at = now();

      admin_count := admin_count + 1;
      RAISE NOTICE '✅ Granted admin access to: %', admin_email;
    ELSE
      RAISE NOTICE '📧 No existing auth user for: % (will auto-grant on first login)', admin_email;
    END IF;
  END LOOP;

  IF admin_count > 0 THEN
    RAISE NOTICE '🎉 Successfully granted admin access to % existing user(s)', admin_count;
  ELSE
    RAISE NOTICE 'ℹ️  No existing users found - admin access will be granted automatically on first login';
  END IF;
END $$;

-- ============================================================================
-- BACKFILL TRIAL SUBSCRIPTIONS
-- ============================================================================
-- Create trial subscription records for existing users without subscriptions
-- ============================================================================

DO $$
DECLARE
  v_standard_plan_id UUID;
  v_trial_end_date TIMESTAMPTZ;
  v_grace_end_date TIMESTAMPTZ;
  v_records_created INTEGER;
BEGIN
  RAISE NOTICE '🔄 Backfilling trial subscriptions for existing users...';

  -- Get trial configuration
  SELECT value::TIMESTAMPTZ INTO v_trial_end_date
  FROM subscription_config
  WHERE key = 'standard_trial_end_date';

  SELECT value::TIMESTAMPTZ INTO v_grace_end_date
  FROM subscription_config
  WHERE key = 'grace_period_end_date';

  -- Default values if not configured
  v_trial_end_date := COALESCE(v_trial_end_date, '2026-03-31T23:59:59+05:30'::TIMESTAMPTZ);
  v_grace_end_date := COALESCE(v_grace_end_date, '2026-04-07T23:59:59+05:30'::TIMESTAMPTZ);

  -- Get standard plan ID
  SELECT id INTO v_standard_plan_id
  FROM subscription_plans
  WHERE plan_code = 'standard'
  LIMIT 1;

  -- Create trial subscriptions for eligible users
  WITH inserted AS (
    INSERT INTO subscriptions (
      user_id,
      plan_id,
      plan_type,
      status,
      provider,
      provider_subscription_id,
      current_period_start,
      current_period_end,
      created_at
    )
    SELECT
      u.id,
      v_standard_plan_id,
      'standard_trial',
      'trial',
      'trial',
      'trial_' || u.id::text,
      COALESCE(up.created_at, u.created_at),
      CASE
        -- If still in trial period, use trial end date
        WHEN NOW() <= v_trial_end_date THEN v_trial_end_date
        -- If in grace period, use grace end date
        WHEN NOW() <= v_grace_end_date THEN v_grace_end_date
        -- Otherwise already expired, but create record for history
        ELSE v_grace_end_date
      END,
      NOW()
    FROM auth.users u
    LEFT JOIN user_profiles up ON u.id = up.id
    LEFT JOIN subscriptions s ON u.id = s.user_id
    WHERE s.id IS NULL  -- No existing subscription
      AND COALESCE(up.created_at, u.created_at) <= v_trial_end_date  -- Created before trial ended
      AND COALESCE(up.is_admin, false) = false  -- Not admin
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
    RETURNING id
  )
  SELECT COUNT(*) INTO v_records_created FROM inserted;

  RAISE NOTICE '✅ Created % trial subscription records for existing users', v_records_created;
END $$;

-- ============================================================================
-- SEED COMPLETE
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '╔════════════════════════════════════════════╗';
  RAISE NOTICE '║  ✅ SEED DATA LOADED SUCCESSFULLY         ║';
  RAISE NOTICE '╚════════════════════════════════════════════╝';
  RAISE NOTICE '';
  RAISE NOTICE '📧 Admin emails: Check system_config table';
  RAISE NOTICE '👑 Admin access: Auto-granted on login';
  RAISE NOTICE '🔐 OAuth callback: Automatically checks admin_emails';
  RAISE NOTICE '';
END $$;
