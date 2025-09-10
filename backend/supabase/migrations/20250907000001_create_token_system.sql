-- Migration: Create Token-Based Usage System
-- Date: 2025-09-07
-- Purpose: Replace rate limiting with flexible token-based system
-- Based on: backend/docs/token_based_system_design.md

-- Begin transaction for atomic migration
BEGIN;

-- =====================================
-- STEP 1: Create user_tokens Table
-- =====================================

CREATE TABLE user_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  identifier TEXT NOT NULL, -- user_id for authenticated, session_id for anonymous
  user_plan TEXT NOT NULL CHECK (user_plan IN ('free', 'standard', 'premium')),
  available_tokens INTEGER NOT NULL DEFAULT 0, -- Daily allocation tokens
  purchased_tokens INTEGER NOT NULL DEFAULT 0, -- Purchased tokens (never reset)
  daily_limit INTEGER NOT NULL,
  last_reset DATE NOT NULL DEFAULT CURRENT_DATE,
  total_consumed_today INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================
-- STEP 2: Create Indexes for Performance
-- =====================================

-- Primary lookup index (most important)
CREATE UNIQUE INDEX idx_user_tokens_identifier 
ON user_tokens(identifier, user_plan);

-- Daily reset cleanup index
CREATE INDEX idx_user_tokens_reset 
ON user_tokens(last_reset);

-- Plan-based queries
CREATE INDEX idx_user_tokens_plan
ON user_tokens(user_plan);

-- Analytics and reporting indexes
CREATE INDEX idx_user_tokens_created_at
ON user_tokens(created_at);

CREATE INDEX idx_user_tokens_updated_at
ON user_tokens(updated_at);

-- =====================================
-- STEP 3: Add Table Documentation
-- =====================================

COMMENT ON TABLE user_tokens IS 'Token-based usage tracking for API operations across different subscription plans';
COMMENT ON COLUMN user_tokens.identifier IS 'User ID for authenticated users or session ID for anonymous users';
COMMENT ON COLUMN user_tokens.user_plan IS 'Subscription plan: free (anonymous), standard (authenticated), premium (subscription)';
COMMENT ON COLUMN user_tokens.available_tokens IS 'Current available daily allocation tokens';
COMMENT ON COLUMN user_tokens.purchased_tokens IS 'Purchased tokens balance that never resets';
COMMENT ON COLUMN user_tokens.daily_limit IS 'Maximum tokens per day for this subscription plan';
COMMENT ON COLUMN user_tokens.last_reset IS 'Last date when tokens were reset to daily limit';
COMMENT ON COLUMN user_tokens.total_consumed_today IS 'Total tokens consumed since last reset';

-- =====================================
-- STEP 4: Create Database Functions
-- =====================================

-- Function to get or create user tokens record with auto-reset logic
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
BEGIN
  -- Set default daily limit based on user plan
  default_limit := CASE 
    WHEN p_user_plan = 'premium' THEN 999999999  -- Effectively unlimited
    WHEN p_user_plan = 'standard' THEN 100
    WHEN p_user_plan = 'free' THEN 20
    ELSE 20  -- Fallback to free plan
  END;

  -- Try to get existing record, reset if needed
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
  
  -- If no record found, create one
  IF NOT FOUND THEN
    INSERT INTO user_tokens (identifier, user_plan, available_tokens, purchased_tokens, daily_limit)
    VALUES (p_identifier, p_user_plan, default_limit, 0, default_limit)
    RETURNING 
      user_tokens.id,
      user_tokens.identifier,
      user_tokens.user_plan,
      user_tokens.available_tokens,
      user_tokens.purchased_tokens,
      user_tokens.daily_limit,
      user_tokens.last_reset,
      user_tokens.total_consumed_today;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to consume tokens atomically with proper priority logic
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
      WHEN ut.user_plan = 'premium' THEN default_limit  -- Premium always has unlimited
      WHEN ut.last_reset < CURRENT_DATE THEN default_limit 
      ELSE ut.available_tokens 
    END,
    ut.purchased_tokens,
    ut.last_reset < CURRENT_DATE AND ut.user_plan != 'premium'
  INTO current_daily_tokens, current_purchased_tokens, needs_reset
  FROM user_tokens ut
  WHERE ut.identifier = p_identifier AND ut.user_plan = p_user_plan;
  
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
        purchased_tokens = purchased_tokens - p_token_cost,
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
        available_tokens = default_limit - (p_token_cost - purchased_tokens),
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
        purchased_tokens = purchased_tokens - p_token_cost,
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
        available_tokens = available_tokens - (p_token_cost - purchased_tokens),
        purchased_tokens = 0,
        total_consumed_today = total_consumed_today + (p_token_cost - current_purchased_tokens),
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

-- Function to add purchased tokens to user account
CREATE OR REPLACE FUNCTION add_purchased_tokens(
  p_identifier TEXT,
  p_user_plan TEXT,
  p_token_amount INTEGER
)
RETURNS TABLE(
  success BOOLEAN,
  new_purchased_balance INTEGER,
  error_message TEXT
) AS $$
DECLARE
  default_limit INTEGER;
BEGIN
  -- Set default daily limit based on user plan
  default_limit := CASE 
    WHEN p_user_plan = 'premium' THEN 999999999  -- Effectively unlimited
    WHEN p_user_plan = 'standard' THEN 100
    WHEN p_user_plan = 'free' THEN 20
    ELSE 20  -- Fallback to free plan
  END;

  -- Validate token amount
  IF p_token_amount <= 0 THEN
    RETURN QUERY SELECT false, 0, 'Invalid token amount'::TEXT;
    RETURN;
  END IF;

  -- Insert or update user tokens record
  INSERT INTO user_tokens (identifier, user_plan, available_tokens, purchased_tokens, daily_limit)
  VALUES (p_identifier, p_user_plan, default_limit, p_token_amount, default_limit)
  ON CONFLICT (identifier, user_plan) 
  DO UPDATE SET 
    purchased_tokens = user_tokens.purchased_tokens + p_token_amount,
    updated_at = NOW()
  RETURNING purchased_tokens INTO default_limit;

  -- Log token purchase event
  PERFORM log_token_event(
    p_identifier,
    'token_added',
    jsonb_build_object(
      'user_plan', p_user_plan,
      'tokens_added', p_token_amount,
      'source', 'purchase',
      'new_purchased_balance', default_limit
    )
  );

  -- Return success with new balance
  RETURN QUERY SELECT true, default_limit, ''::TEXT;
EXCEPTION
  WHEN OTHERS THEN
    -- Log failed token addition
    PERFORM log_token_event(
      p_identifier,
      'token_add_failed',
      jsonb_build_object(
        'user_plan', p_user_plan,
        'tokens_requested', p_token_amount,
        'error', SQLERRM
      )
    );
    RETURN QUERY SELECT false, 0, SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log token analytics events (integrates with existing analytics_events table)
CREATE OR REPLACE FUNCTION log_token_event(
  p_user_id TEXT,
  p_event_type TEXT,
  p_event_data JSONB,
  p_session_id TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  event_id UUID;
BEGIN
  INSERT INTO analytics_events (
    id,
    user_id,
    session_id,
    event_type,
    event_data,
    created_at
  )
  VALUES (
    uuid_generate_v4(),
    p_user_id,
    p_session_id,
    p_event_type,
    p_event_data,
    NOW()
  )
  RETURNING id INTO event_id;
  
  RETURN event_id;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the main operation
    RAISE WARNING 'Failed to log token event: %', SQLERRM;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================
-- STEP 5: Add Function Documentation
-- =====================================

COMMENT ON FUNCTION get_or_create_user_tokens(TEXT, TEXT) IS 'Get or create user tokens record with automatic daily reset logic';
COMMENT ON FUNCTION consume_user_tokens(TEXT, TEXT, INTEGER) IS 'Atomically consume tokens with purchased-first priority and premium user handling';
COMMENT ON FUNCTION add_purchased_tokens(TEXT, TEXT, INTEGER) IS 'Add purchased tokens to user account (never reset)';
COMMENT ON FUNCTION log_token_event(TEXT, TEXT, JSONB, TEXT) IS 'Log token-related events to analytics_events table for tracking';

-- Commit transaction
COMMIT;