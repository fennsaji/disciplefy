-- Migration: Google Play Store Reviewer Test Account
-- Created: 2025-12-14
-- Purpose: Grant premium access to the Play Store test reviewer account
--
-- PREREQUISITE: The auth.users account must already exist!
-- Create it first via Supabase Dashboard → Authentication → Add User
-- Email: app.reviewer@disciplefy.in
-- Password: Set securely in Supabase Dashboard (do NOT commit passwords to repo)

BEGIN;

-- Define the test email
DO $$
DECLARE
  v_user_id UUID;
  v_email TEXT := 'app.reviewer@disciplefy.in';
BEGIN
  -- Get the user ID
  SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;

  IF v_user_id IS NULL THEN
    RAISE NOTICE 'User % not found in auth.users. Create the user first via Supabase Auth console.', v_email;
    RETURN;
  END IF;

  -- Step 1: Create/update user_profiles
  INSERT INTO user_profiles (
    id,
    first_name,
    last_name,
    language_preference,
    theme_preference,
    age_group,
    interests
  ) VALUES (
    v_user_id,
    'PlayStore',
    'Reviewer',
    'en',
    'light',
    '18-25',
    ARRAY['bible-study', 'daily-devotion']
  )
  ON CONFLICT (id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    updated_at = NOW();

  RAISE NOTICE 'Created user_profiles for %', v_email;

  -- Step 2: Remove any existing subscription
  DELETE FROM subscriptions WHERE user_id = v_user_id;

  -- Step 3: Create premium subscription (never expires)
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
  ) VALUES (
    v_user_id,
    'sub_playstore_reviewer_' || gen_random_uuid()::TEXT,
    'plan_granted_playstore_review',
    'active',
    'premium',
    NOW(),
    NOW() + INTERVAL '100 years',
    0,
    'INR'
  );

  RAISE NOTICE 'Created premium subscription for %', v_email;

  -- Step 4: Initialize premium tokens (automatic unlimited for premium)
  -- The get_or_create_user_tokens function handles this automatically
  -- Premium users get 999999999 available_tokens

  RAISE NOTICE 'Play Store reviewer account setup complete for %', v_email;
END $$;

COMMIT;
