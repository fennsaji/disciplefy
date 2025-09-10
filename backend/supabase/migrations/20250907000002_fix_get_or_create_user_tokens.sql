-- =====================================
-- Migration: Fix get_or_create_user_tokens Function
-- Date: 2025-09-07
-- Purpose: Fix the NOT FOUND logic bug in get_or_create_user_tokens function
-- =====================================

BEGIN;

-- Replace the buggy function with the corrected version
CREATE OR REPLACE FUNCTION get_or_create_user_tokens(
  p_identifier TEXT,
  p_user_plan TEXT
)
RETURNS TABLE(
  id UUID,
  identifier TEXT,
  user_plan TEXT,
  available_tokens INTEGER,
  purchased_tokens INTEGER,
  daily_limit INTEGER,
  last_reset DATE,
  total_consumed_today INTEGER
) AS $$
DECLARE
  default_limit INTEGER;
  record_exists BOOLEAN;
BEGIN
  -- Set default daily limit based on user plan
  default_limit := CASE 
    WHEN p_user_plan = 'premium' THEN 999999999  -- Effectively unlimited
    WHEN p_user_plan = 'standard' THEN 100
    WHEN p_user_plan = 'free' THEN 20
    ELSE 20  -- Fallback to free plan
  END;

  -- Check if record exists
  SELECT EXISTS(SELECT 1 FROM user_tokens ut WHERE ut.identifier = p_identifier AND ut.user_plan = p_user_plan) INTO record_exists;
  
  -- If no record exists, create one
  IF NOT record_exists THEN
    INSERT INTO user_tokens (identifier, user_plan, available_tokens, purchased_tokens, daily_limit)
    VALUES (p_identifier, p_user_plan, default_limit, 0, default_limit);
  END IF;
  
  -- Return the record (existing or newly created), with daily reset logic
  RETURN QUERY
  SELECT 
    ut.id,
    ut.identifier,
    ut.user_plan,
    CASE 
      WHEN ut.user_plan = 'premium' THEN default_limit  -- Premium users always have max tokens
      WHEN ut.last_reset < CURRENT_DATE THEN default_limit
      ELSE ut.available_tokens
    END as available_tokens,
    ut.purchased_tokens, -- Purchased tokens never reset
    default_limit as daily_limit,
    CASE 
      WHEN ut.last_reset < CURRENT_DATE THEN CURRENT_DATE
      ELSE ut.last_reset
    END as last_reset,
    CASE 
      WHEN ut.user_plan = 'premium' THEN 0  -- Premium users don't track consumption
      WHEN ut.last_reset < CURRENT_DATE THEN 0
      ELSE ut.total_consumed_today
    END as total_consumed_today
  FROM user_tokens ut
  WHERE ut.identifier = p_identifier AND ut.user_plan = p_user_plan;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update function documentation
COMMENT ON FUNCTION get_or_create_user_tokens(TEXT, TEXT) IS 'Get or create user tokens record with automatic daily reset logic (FIXED: NOT FOUND bug resolved)';

COMMIT;