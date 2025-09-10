-- =====================================
-- Migration: Fix consume_user_tokens Function
-- Date: 2025-09-07
-- Purpose: Fix table alias issues and ambiguous column references in consume_user_tokens function
-- =====================================

BEGIN;

-- Replace the buggy function with the corrected version
CREATE OR REPLACE FUNCTION consume_user_tokens(
  p_identifier TEXT,
  p_user_plan TEXT,
  p_token_cost INTEGER
)
RETURNS TABLE(
  success BOOLEAN,
  available_tokens INTEGER,
  purchased_tokens INTEGER,
  daily_limit INTEGER,
  error_message TEXT
) AS $$
DECLARE
  current_daily_tokens INTEGER;
  current_purchased_tokens INTEGER;
  total_available INTEGER;
  default_limit INTEGER;
  needs_reset BOOLEAN;
BEGIN
  -- Set default daily limit based on user plan
  default_limit := CASE 
    WHEN p_user_plan = 'premium' THEN 999999999  -- Effectively unlimited
    WHEN p_user_plan = 'standard' THEN 100
    WHEN p_user_plan = 'free' THEN 20
    ELSE 20  -- Fallback to free plan
  END;

  -- Check if user needs daily reset and get current tokens
  SELECT 
    CASE 
      WHEN user_tokens.user_plan = 'premium' THEN default_limit  -- Premium always has unlimited
      WHEN user_tokens.last_reset < CURRENT_DATE THEN default_limit 
      ELSE user_tokens.available_tokens 
    END,
    user_tokens.purchased_tokens,
    user_tokens.last_reset < CURRENT_DATE AND user_tokens.user_plan != 'premium'
  INTO current_daily_tokens, current_purchased_tokens, needs_reset
  FROM user_tokens 
  WHERE user_tokens.identifier = p_identifier AND user_tokens.user_plan = p_user_plan;
  
  -- Calculate total available tokens (daily + purchased)
  total_available := COALESCE(current_daily_tokens, 0) + COALESCE(current_purchased_tokens, 0);
  
  -- If user doesn't exist, create with default tokens
  IF current_daily_tokens IS NULL THEN
    INSERT INTO user_tokens (identifier, user_plan, available_tokens, purchased_tokens, daily_limit)
    VALUES (p_identifier, p_user_plan, default_limit, 0, default_limit);
    current_daily_tokens := default_limit;
    current_purchased_tokens := 0;
    total_available := default_limit;
    needs_reset := false;
  END IF;

  -- Check if user has enough tokens (skip check for premium users)
  IF p_user_plan != 'premium' AND total_available < p_token_cost THEN
    RETURN QUERY SELECT false, current_daily_tokens, current_purchased_tokens, default_limit, 'Insufficient tokens'::TEXT;
    RETURN;
  END IF;

  -- Consume tokens with atomic update (prioritize purchased tokens first)
  IF p_user_plan = 'premium' THEN
    -- Premium users don't consume tokens, just update timestamp
    UPDATE user_tokens 
    SET updated_at = NOW()
    WHERE identifier = p_identifier AND user_plan = p_user_plan;
    
    -- Log premium usage event
    PERFORM log_token_event(
      p_identifier,
      'token_consumed',
      jsonb_build_object(
        'user_plan', p_user_plan,
        'token_cost', p_token_cost,
        'premium_usage', true,
        'tokens_consumed', 0
      )
    );
    
    RETURN QUERY SELECT true, current_daily_tokens, current_purchased_tokens, default_limit, ''::TEXT;
  ELSIF needs_reset THEN
    -- Reset daily data and consume tokens
    IF current_purchased_tokens >= p_token_cost THEN
      -- Consume from purchased tokens only
      UPDATE user_tokens 
      SET 
        available_tokens = default_limit,
        purchased_tokens = user_tokens.purchased_tokens - p_token_cost,
        total_consumed_today = 0,
        last_reset = CURRENT_DATE,
        updated_at = NOW()
      WHERE identifier = p_identifier AND user_plan = p_user_plan;
      
      -- Log token consumption event
      PERFORM log_token_event(
        p_identifier,
        'token_consumed',
        jsonb_build_object(
          'user_plan', p_user_plan,
          'token_cost', p_token_cost,
          'purchased_tokens_used', p_token_cost,
          'daily_tokens_used', 0,
          'daily_reset', true,
          'remaining_purchased', current_purchased_tokens - p_token_cost,
          'remaining_daily', default_limit
        )
      );
      
      RETURN QUERY SELECT true, default_limit, current_purchased_tokens - p_token_cost, default_limit, ''::TEXT;
    ELSE
      -- Consume all purchased tokens + some daily tokens
      UPDATE user_tokens 
      SET 
        available_tokens = default_limit - (p_token_cost - user_tokens.purchased_tokens),
        purchased_tokens = 0,
        total_consumed_today = p_token_cost - current_purchased_tokens,
        last_reset = CURRENT_DATE,
        updated_at = NOW()
      WHERE identifier = p_identifier AND user_plan = p_user_plan;
      
      -- Log token consumption event
      PERFORM log_token_event(
        p_identifier,
        'token_consumed',
        jsonb_build_object(
          'user_plan', p_user_plan,
          'token_cost', p_token_cost,
          'purchased_tokens_used', current_purchased_tokens,
          'daily_tokens_used', p_token_cost - current_purchased_tokens,
          'daily_reset', true,
          'remaining_purchased', 0,
          'remaining_daily', default_limit - (p_token_cost - current_purchased_tokens)
        )
      );
      
      RETURN QUERY SELECT true, default_limit - (p_token_cost - current_purchased_tokens), 0, default_limit, ''::TEXT;
    END IF;
  ELSE
    -- Just consume tokens (prioritize purchased tokens)
    IF current_purchased_tokens >= p_token_cost THEN
      -- Consume from purchased tokens only
      UPDATE user_tokens 
      SET 
        purchased_tokens = user_tokens.purchased_tokens - p_token_cost,
        updated_at = NOW()
      WHERE identifier = p_identifier AND user_plan = p_user_plan;
      
      -- Log token consumption event
      PERFORM log_token_event(
        p_identifier,
        'token_consumed',
        jsonb_build_object(
          'user_plan', p_user_plan,
          'token_cost', p_token_cost,
          'purchased_tokens_used', p_token_cost,
          'daily_tokens_used', 0,
          'daily_reset', false,
          'remaining_purchased', current_purchased_tokens - p_token_cost,
          'remaining_daily', current_daily_tokens
        )
      );
      
      RETURN QUERY SELECT true, current_daily_tokens, current_purchased_tokens - p_token_cost, default_limit, ''::TEXT;
    ELSE
      -- Consume all purchased tokens + some daily tokens
      UPDATE user_tokens 
      SET 
        available_tokens = user_tokens.available_tokens - (p_token_cost - user_tokens.purchased_tokens),
        purchased_tokens = 0,
        total_consumed_today = user_tokens.total_consumed_today + (p_token_cost - current_purchased_tokens),
        updated_at = NOW()
      WHERE identifier = p_identifier AND user_plan = p_user_plan;
      
      -- Log token consumption event
      PERFORM log_token_event(
        p_identifier,
        'token_consumed',
        jsonb_build_object(
          'user_plan', p_user_plan,
          'token_cost', p_token_cost,
          'purchased_tokens_used', current_purchased_tokens,
          'daily_tokens_used', p_token_cost - current_purchased_tokens,
          'daily_reset', false,
          'remaining_purchased', 0,
          'remaining_daily', current_daily_tokens - (p_token_cost - current_purchased_tokens)
        )
      );
      
      RETURN QUERY SELECT true, current_daily_tokens - (p_token_cost - current_purchased_tokens), 0, default_limit, ''::TEXT;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update function documentation
COMMENT ON FUNCTION consume_user_tokens(TEXT, TEXT, INTEGER) IS 'Atomically consume tokens with purchased-first priority and premium user handling (FIXED: ambiguous column references resolved)';

COMMIT;