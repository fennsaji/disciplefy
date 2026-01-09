-- Migration: Add token breakdown fields to consume_user_tokens return type
-- Date: 2026-01-10
-- Description: Adds daily_tokens_used and purchased_tokens_used to the return
--              type of consume_user_tokens so the caller knows exactly how
--              tokens were consumed (fixing usage history calculation bug)

BEGIN;

-- Drop the existing function so we can change the return type
DROP FUNCTION IF EXISTS consume_user_tokens(TEXT, TEXT, INTEGER);

-- Recreate with additional return fields for token breakdown
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
  daily_tokens_used INTEGER,
  purchased_tokens_used INTEGER,
  error_message TEXT
) AS $$
DECLARE
  current_daily_tokens INTEGER;
  current_purchased_tokens INTEGER;
  total_available INTEGER;
  default_limit INTEGER;
  effective_limit INTEGER;
  needs_reset BOOLEAN;
  calculated_daily_used INTEGER;
  calculated_purchased_used INTEGER;
BEGIN
  -- Set secure search_path to prevent schema injection attacks
  SET LOCAL search_path = pg_temp, public;

  -- Set default daily limit based on user plan
  default_limit := CASE
    WHEN p_user_plan = 'premium' THEN 999999999  -- Effectively unlimited
    WHEN p_user_plan = 'standard' THEN 100
    WHEN p_user_plan = 'free' THEN 20
    ELSE 20  -- Fallback to free plan
  END;

  -- Check if user needs daily reset and get current tokens
  -- CRITICAL: FOR UPDATE locks the row to prevent race conditions in concurrent token consumption
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
  WHERE user_tokens.identifier = p_identifier AND user_tokens.user_plan = p_user_plan
  FOR UPDATE;

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
    RETURN QUERY SELECT
      false::BOOLEAN,
      current_daily_tokens::INTEGER,
      current_purchased_tokens::INTEGER,
      default_limit::INTEGER,
      0::INTEGER,  -- daily_tokens_used
      0::INTEGER,  -- purchased_tokens_used
      'Insufficient tokens'::TEXT;
    RETURN;
  END IF;

  -- Consume tokens with atomic update (PRIORITY: daily tokens first, then purchased)
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

    RETURN QUERY SELECT
      true::BOOLEAN,
      current_daily_tokens::INTEGER,
      current_purchased_tokens::INTEGER,
      default_limit::INTEGER,
      0::INTEGER,  -- daily_tokens_used (premium doesn't consume)
      0::INTEGER,  -- purchased_tokens_used
      ''::TEXT;
  ELSIF needs_reset THEN
    -- Reset daily data and consume tokens (PRIORITY: daily first)
    IF default_limit >= p_token_cost THEN
      -- Consume from daily tokens only (after reset)
      calculated_daily_used := p_token_cost;
      calculated_purchased_used := 0;

      UPDATE user_tokens
      SET
        available_tokens = default_limit - p_token_cost,
        purchased_tokens = user_tokens.purchased_tokens,  -- Keep purchased tokens unchanged
        total_consumed_today = p_token_cost,
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
          'daily_tokens_used', calculated_daily_used,
          'purchased_tokens_used', calculated_purchased_used,
          'daily_reset', true,
          'remaining_daily', default_limit - p_token_cost,
          'remaining_purchased', current_purchased_tokens
        )
      );

      RETURN QUERY SELECT
        true::BOOLEAN,
        (default_limit - p_token_cost)::INTEGER,
        current_purchased_tokens::INTEGER,
        default_limit::INTEGER,
        calculated_daily_used::INTEGER,
        calculated_purchased_used::INTEGER,
        ''::TEXT;
    ELSE
      -- Consume all daily tokens + some purchased tokens
      calculated_daily_used := default_limit;
      calculated_purchased_used := p_token_cost - default_limit;

      UPDATE user_tokens
      SET
        available_tokens = 0,
        purchased_tokens = user_tokens.purchased_tokens - calculated_purchased_used,
        total_consumed_today = default_limit,
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
          'daily_tokens_used', calculated_daily_used,
          'purchased_tokens_used', calculated_purchased_used,
          'daily_reset', true,
          'remaining_daily', 0,
          'remaining_purchased', current_purchased_tokens - calculated_purchased_used
        )
      );

      RETURN QUERY SELECT
        true::BOOLEAN,
        0::INTEGER,
        (current_purchased_tokens - calculated_purchased_used)::INTEGER,
        default_limit::INTEGER,
        calculated_daily_used::INTEGER,
        calculated_purchased_used::INTEGER,
        ''::TEXT;
    END IF;
  ELSE
    -- No reset needed, consume from existing balances (PRIORITY: daily first)
    IF current_daily_tokens >= p_token_cost THEN
      -- Consume from daily tokens only
      calculated_daily_used := p_token_cost;
      calculated_purchased_used := 0;

      UPDATE user_tokens
      SET
        available_tokens = user_tokens.available_tokens - p_token_cost,
        total_consumed_today = user_tokens.total_consumed_today + p_token_cost,
        updated_at = NOW()
      WHERE identifier = p_identifier AND user_plan = p_user_plan;

      -- Log token consumption event
      PERFORM log_token_event(
        p_identifier,
        'token_consumed',
        jsonb_build_object(
          'user_plan', p_user_plan,
          'token_cost', p_token_cost,
          'daily_tokens_used', calculated_daily_used,
          'purchased_tokens_used', calculated_purchased_used,
          'remaining_daily', current_daily_tokens - p_token_cost,
          'remaining_purchased', current_purchased_tokens
        )
      );

      RETURN QUERY SELECT
        true::BOOLEAN,
        (current_daily_tokens - p_token_cost)::INTEGER,
        current_purchased_tokens::INTEGER,
        default_limit::INTEGER,
        calculated_daily_used::INTEGER,
        calculated_purchased_used::INTEGER,
        ''::TEXT;
    ELSE
      -- Consume all daily tokens + some purchased tokens
      calculated_daily_used := current_daily_tokens;
      calculated_purchased_used := p_token_cost - current_daily_tokens;

      UPDATE user_tokens
      SET
        available_tokens = 0,
        purchased_tokens = user_tokens.purchased_tokens - calculated_purchased_used,
        total_consumed_today = user_tokens.total_consumed_today + calculated_daily_used,
        updated_at = NOW()
      WHERE identifier = p_identifier AND user_plan = p_user_plan;

      -- Log token consumption event
      PERFORM log_token_event(
        p_identifier,
        'token_consumed',
        jsonb_build_object(
          'user_plan', p_user_plan,
          'token_cost', p_token_cost,
          'daily_tokens_used', calculated_daily_used,
          'purchased_tokens_used', calculated_purchased_used,
          'remaining_daily', 0,
          'remaining_purchased', current_purchased_tokens - calculated_purchased_used
        )
      );

      RETURN QUERY SELECT
        true::BOOLEAN,
        0::INTEGER,
        (current_purchased_tokens - calculated_purchased_used)::INTEGER,
        default_limit::INTEGER,
        calculated_daily_used::INTEGER,
        calculated_purchased_used::INTEGER,
        ''::TEXT;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-grant permissions
GRANT EXECUTE ON FUNCTION consume_user_tokens(TEXT, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION consume_user_tokens(TEXT, TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION consume_user_tokens(TEXT, TEXT, INTEGER) TO service_role;

-- Update comment
COMMENT ON FUNCTION consume_user_tokens(TEXT, TEXT, INTEGER) IS
  'Atomically consume tokens with DAILY-FIRST priority (daily tokens consumed before purchased tokens), with premium user unlimited handling. Returns breakdown of tokens consumed from each source.';

COMMIT;
