-- Fix ambiguous column reference in can_start_premium_trial function
-- The created_at column exists in both auth.users and user_profiles

CREATE OR REPLACE FUNCTION public.can_start_premium_trial(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_user_created_at TIMESTAMPTZ;
  v_has_used_trial BOOLEAN;
  v_premium_trial_start_date TIMESTAMPTZ := '2025-04-01T00:00:00+05:30'::TIMESTAMPTZ;
BEGIN
  SELECT 
    u.created_at,
    COALESCE(p.has_used_premium_trial, false)
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.can_start_premium_trial(UUID) TO authenticated;
