-- Premium Trial System Migration
-- Adds support for 7-day Premium trial for users signing up after April 1st, 2025

-- Add premium trial columns to user_profiles
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS premium_trial_started_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS premium_trial_end_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS has_used_premium_trial BOOLEAN DEFAULT FALSE;

-- Create index for efficient premium trial lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_premium_trial 
ON public.user_profiles (premium_trial_end_at) 
WHERE premium_trial_end_at IS NOT NULL;

-- Add subscription_config entries for premium trial (if table exists)
DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'subscription_config') THEN
    INSERT INTO public.subscription_config (key, value)
    VALUES
      ('premium_trial_start_date', '2025-04-01T00:00:00+05:30'),
      ('premium_trial_days', '7')
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
  END IF;
END $$;

-- Helper function to check if user is in premium trial
CREATE OR REPLACE FUNCTION public.is_in_premium_trial(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_trial_end TIMESTAMPTZ;
BEGIN
  SELECT premium_trial_end_at INTO v_trial_end
  FROM public.user_profiles 
  WHERE id = p_user_id;

  RETURN v_trial_end IS NOT NULL AND NOW() < v_trial_end;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user can start premium trial
-- User must have signed up after April 1st, 2025 and not used trial before
CREATE OR REPLACE FUNCTION public.can_start_premium_trial(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_user_created_at TIMESTAMPTZ;
  v_has_used_trial BOOLEAN;
  v_premium_trial_start_date TIMESTAMPTZ := '2025-04-01T00:00:00+05:30'::TIMESTAMPTZ;
BEGIN
  SELECT 
    created_at,
    COALESCE(has_used_premium_trial, false)
  INTO v_user_created_at, v_has_used_trial
  FROM auth.users u
  LEFT JOIN public.user_profiles p ON p.id = u.id
  WHERE u.id = p_user_id;

  -- User must exist
  IF v_user_created_at IS NULL THEN
    RETURN FALSE;
  END IF;

  -- User must have signed up after April 1st, 2025
  IF v_user_created_at < v_premium_trial_start_date THEN
    RETURN FALSE;
  END IF;

  -- User must not have already used their trial
  IF v_has_used_trial THEN
    RETURN FALSE;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to start premium trial for eligible users
CREATE OR REPLACE FUNCTION public.start_premium_trial(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  v_can_start BOOLEAN;
  v_trial_start TIMESTAMPTZ;
  v_trial_end TIMESTAMPTZ;
  v_trial_days INTEGER := 7;
BEGIN
  -- Check eligibility
  v_can_start := public.can_start_premium_trial(p_user_id);
  
  IF NOT v_can_start THEN
    RETURN json_build_object(
      'success', false,
      'error', 'User is not eligible for Premium trial'
    );
  END IF;

  -- Calculate trial dates
  v_trial_start := NOW();
  v_trial_end := v_trial_start + (v_trial_days || ' days')::INTERVAL;

  -- Update user profile with trial info
  UPDATE public.user_profiles
  SET 
    premium_trial_started_at = v_trial_start,
    premium_trial_end_at = v_trial_end,
    has_used_premium_trial = TRUE,
    updated_at = NOW()
  WHERE id = p_user_id;

  -- If no rows updated, create the profile
  IF NOT FOUND THEN
    INSERT INTO public.user_profiles (id, premium_trial_started_at, premium_trial_end_at, has_used_premium_trial)
    VALUES (p_user_id, v_trial_start, v_trial_end, TRUE);
  END IF;

  RETURN json_build_object(
    'success', true,
    'trial_started_at', v_trial_start,
    'trial_end_at', v_trial_end,
    'days_remaining', v_trial_days
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get premium trial status for a user
CREATE OR REPLACE FUNCTION public.get_premium_trial_status(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  v_trial_started_at TIMESTAMPTZ;
  v_trial_end_at TIMESTAMPTZ;
  v_has_used_trial BOOLEAN;
  v_is_in_trial BOOLEAN;
  v_can_start_trial BOOLEAN;
  v_days_remaining INTEGER;
BEGIN
  SELECT 
    premium_trial_started_at,
    premium_trial_end_at,
    COALESCE(has_used_premium_trial, false)
  INTO v_trial_started_at, v_trial_end_at, v_has_used_trial
  FROM public.user_profiles 
  WHERE id = p_user_id;

  -- Check if currently in trial
  v_is_in_trial := v_trial_end_at IS NOT NULL AND NOW() < v_trial_end_at;

  -- Calculate days remaining if in trial
  IF v_is_in_trial THEN
    v_days_remaining := CEIL(EXTRACT(EPOCH FROM (v_trial_end_at - NOW())) / 86400);
  ELSE
    v_days_remaining := 0;
  END IF;

  -- Check if can start trial (only if not already used)
  IF NOT v_has_used_trial THEN
    v_can_start_trial := public.can_start_premium_trial(p_user_id);
  ELSE
    v_can_start_trial := FALSE;
  END IF;

  RETURN json_build_object(
    'is_in_premium_trial', v_is_in_trial,
    'premium_trial_started_at', v_trial_started_at,
    'premium_trial_end_at', v_trial_end_at,
    'premium_trial_days_remaining', v_days_remaining,
    'has_used_premium_trial', v_has_used_trial,
    'can_start_premium_trial', v_can_start_trial
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.is_in_premium_trial(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_start_premium_trial(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_premium_trial(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_premium_trial_status(UUID) TO authenticated;

-- Add comment for documentation
COMMENT ON COLUMN public.user_profiles.premium_trial_started_at IS 'Timestamp when Premium trial was started';
COMMENT ON COLUMN public.user_profiles.premium_trial_end_at IS 'Timestamp when Premium trial ends';
COMMENT ON COLUMN public.user_profiles.has_used_premium_trial IS 'Whether user has already used their one-time Premium trial';
