-- Fix ambiguous column reference in get_or_create_user_tokens function
-- Migration: 20250913000001_fix_ambiguous_identifier_column.sql

CREATE OR REPLACE FUNCTION get_or_create_user_tokens(
  p_identifier UUID,
  p_user_plan TEXT
) RETURNS TABLE(
  id UUID,
  identifier UUID,
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
  current_date_utc DATE;
BEGIN
  -- SECURITY: Set explicit search_path to prevent hijacking
  SET LOCAL search_path = public, pg_catalog;
  
  -- Use UTC timezone for consistent date comparisons
  current_date_utc := (NOW() AT TIME ZONE 'UTC')::date;
  
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
    INSERT INTO user_tokens (identifier, user_plan, available_tokens, purchased_tokens, daily_limit, last_reset)
    VALUES (p_identifier, p_user_plan, default_limit, 0, default_limit, current_date_utc);
  ELSE
    -- CRITICAL FIX: Persist daily reset BEFORE SELECT to avoid virtual reset issues
    UPDATE user_tokens 
    SET 
      available_tokens = CASE 
        WHEN user_tokens.user_plan = 'premium' THEN 999999999
        WHEN user_tokens.last_reset < current_date_utc THEN default_limit
        ELSE user_tokens.available_tokens
      END,
      last_reset = CASE 
        WHEN user_tokens.last_reset < current_date_utc THEN current_date_utc
        ELSE user_tokens.last_reset
      END,
      total_consumed_today = CASE 
        WHEN user_tokens.user_plan = 'premium' THEN 0
        WHEN user_tokens.last_reset < current_date_utc THEN 0
        ELSE user_tokens.total_consumed_today
      END,
      updated_at = NOW()
    WHERE user_tokens.identifier = p_identifier AND user_tokens.user_plan = p_user_plan
      AND (user_tokens.last_reset < current_date_utc OR user_tokens.user_plan = 'premium');
  END IF;
  
  -- Return the record (existing or newly created), now with persisted reset
  RETURN QUERY
  SELECT 
    ut.id,
    ut.identifier,
    ut.user_plan,
    ut.available_tokens,  -- Now returns actual persisted values
    ut.purchased_tokens,
    ut.daily_limit,
    ut.last_reset,
    ut.total_consumed_today
  FROM user_tokens ut
  WHERE ut.identifier = p_identifier AND ut.user_plan = p_user_plan;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;