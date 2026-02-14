# Token-Based Usage System Design Document

## Overview

This document outlines the design and implementation plan for replacing the current rate-limiting system with a flexible token-based usage system. The new system provides better user experience and more granular control over API usage.

## Current System Analysis

### Existing Rate Limiter
- **Table**: `rate_limit_usage`
- **Logic**: Time-window based limiting
- **Anonymous Users**: 1 request per 8-hour window
- **Authenticated Users**: 5 requests per 1-hour window
- **Implementation**: Applied in `study-generate` endpoint after cache miss

### Limitations of Current System
1. **Inflexible**: Fixed time windows don't align with user expectations
2. **Poor UX**: Users don't understand when limits reset
3. **Binary**: All operations have same "cost"
4. **Complex**: Time-window calculations are error-prone

## Token System Architecture

### Token Allocation Model
- **Premium Plan**: Unlimited tokens (no daily limit)
- **Standard Plan**: 20 tokens daily (authenticated users, resets at midnight UTC)
- **Free Plan**: 8 tokens daily (guest/anonymous users, resets at midnight UTC)
- **Purchasable Tokens**: Additional tokens that users can buy, never reset
- **Reset Schedule**: Daily at 00:00 UTC for non-premium plans (purchasable tokens persist)

### Plan Assignment Logic
- **Free Plan**: Anonymous/guest users
- **Standard Plan**: Authenticated users with no active subscription
- **Premium Plan**: Authenticated users with active premium subscription

### Token Cost Structure
| Operation | Language | Token Cost |
|-----------|----------|------------|
| Study Guide | English | 10 tokens |
| Study Guide | Hindi | 20 tokens |
| Study Guide | Malayalam | 20 tokens |

*Note: Only single language selection is supported per study guide generation.*

### Cost Calculation Logic
```typescript
function calculateTokenCost(languages: string[]): number {
  // Validate single language constraint
  if (languages.length > 1) {
    throw new Error('Multiple languages not supported. Please select only one language.')
  }
  
  if (languages.length === 0) {
    throw new Error('At least one language must be specified.')
  }
  
  const languageCosts = {
    'en': 10,    // English
    'hi': 20,    // Hindi  
    'ml': 20     // Malayalam
  }
  
  const language = languages[0]
  const cost = languageCosts[language]
  
  if (cost === undefined) {
    throw new Error(`Unsupported language: ${language}. Supported languages: en, hi, ml`)
  }
  
  return cost
}
```

## Database Schema Design

### New Table: `user_tokens`

```sql
CREATE TABLE user_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  identifier TEXT NOT NULL, -- user_id for authenticated, session_id for anonymous
  user_plan TEXT NOT NULL CHECK (user_plan IN ('free', 'standard', 'premium')),
  available_tokens INTEGER NOT NULL DEFAULT 0, -- Daily allocation tokens
  purchased_tokens INTEGER NOT NULL DEFAULT 0, -- Purchased tokens (never reset)
  daily_limit INTEGER NOT NULL,
  last_reset TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC'),
  total_consumed_today INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for optimal performance
CREATE UNIQUE INDEX idx_user_tokens_identifier 
ON user_tokens(identifier, user_plan);

CREATE INDEX idx_user_tokens_reset 
ON user_tokens(last_reset);

CREATE INDEX idx_user_tokens_plan
ON user_tokens(user_plan);

-- Index for analytics queries
CREATE INDEX idx_user_tokens_created_at
ON user_tokens(created_at);

CREATE INDEX idx_user_tokens_updated_at
ON user_tokens(updated_at);

-- Comments for documentation
COMMENT ON TABLE user_tokens IS 'Token-based usage tracking for API operations across different subscription plans';
COMMENT ON COLUMN user_tokens.identifier IS 'User ID for authenticated users or session ID for anonymous users';
COMMENT ON COLUMN user_tokens.user_plan IS 'Subscription plan: free (anonymous), standard (authenticated), premium (subscription)';
COMMENT ON COLUMN user_tokens.available_tokens IS 'Current available daily allocation tokens';
COMMENT ON COLUMN user_tokens.purchased_tokens IS 'Purchased tokens balance that never resets';
COMMENT ON COLUMN user_tokens.daily_limit IS 'Maximum tokens per day for this subscription plan';
COMMENT ON COLUMN user_tokens.last_reset IS 'Last date when tokens were reset to daily limit';
COMMENT ON COLUMN user_tokens.total_consumed_today IS 'Total tokens consumed since last reset';
```

### Database Functions

```sql
-- SECURITY CRITICAL: Function to get or create user tokens record
-- This function must NOT be exposed to clients due to p_identifier bypass risk
-- Only service_role should have EXECUTE permission on this function
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
  last_reset TIMESTAMPTZ,
  total_consumed_today INTEGER
) AS $
DECLARE
  default_limit INTEGER;
BEGIN
  -- Set default daily limit based on user plan
  default_limit := CASE
    WHEN p_user_plan = 'premium' THEN 999999999  -- Effectively unlimited
    WHEN p_user_plan = 'standard' THEN 20
    WHEN p_user_plan = 'free' THEN 8
    ELSE 8  -- Fallback to free plan
  END;

  -- Try to get existing record, reset if needed
  RETURN QUERY
  SELECT 
    ut.id,
    ut.identifier,
    ut.user_plan,
    CASE 
      WHEN ut.user_plan = 'premium' THEN default_limit  -- Premium users always have max tokens
      WHEN (ut.last_reset AT TIME ZONE 'UTC')::date < (NOW() AT TIME ZONE 'UTC')::date THEN default_limit
      ELSE ut.available_tokens
    END as available_tokens,
    ut.purchased_tokens, -- Purchased tokens never reset
    default_limit as daily_limit,
    CASE 
      WHEN (ut.last_reset AT TIME ZONE 'UTC')::date < (NOW() AT TIME ZONE 'UTC')::date THEN (NOW() AT TIME ZONE 'UTC')
      ELSE ut.last_reset
    END as last_reset,
    CASE 
      WHEN ut.user_plan = 'premium' THEN 0  -- Premium users don't track consumption
      WHEN (ut.last_reset AT TIME ZONE 'UTC')::date < (NOW() AT TIME ZONE 'UTC')::date THEN 0
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
$ LANGUAGE plpgsql SECURITY DEFINER;

-- CRITICAL SECURITY: Revoke EXECUTE from anon and authenticated roles
-- This function MUST only be called by service_role from Edge Functions
REVOKE EXECUTE ON FUNCTION get_or_create_user_tokens FROM anon;
REVOKE EXECUTE ON FUNCTION get_or_create_user_tokens FROM authenticated;
GRANT EXECUTE ON FUNCTION get_or_create_user_tokens TO service_role;

-- Alternative SECURE implementation: Remove p_identifier parameter
-- This version derives identifier from auth.uid() and is safe for client access
CREATE OR REPLACE FUNCTION get_or_create_user_tokens_secure(
  p_user_plan TEXT
)
RETURNS TABLE(
  id UUID,
  identifier TEXT,
  user_plan TEXT,
  available_tokens INTEGER,
  purchased_tokens INTEGER,
  daily_limit INTEGER,
  last_reset TIMESTAMPTZ,
  total_consumed_today INTEGER
) AS $
DECLARE
  default_limit INTEGER;
  current_identifier TEXT;
BEGIN
  -- Get identifier from auth context - secure against bypass
  current_identifier := COALESCE(auth.uid()::text, 'anonymous_' || gen_random_uuid()::text);
  
  -- Set default daily limit based on user plan
  default_limit := CASE
    WHEN p_user_plan = 'premium' THEN 999999999  -- Effectively unlimited
    WHEN p_user_plan = 'standard' THEN 20
    WHEN p_user_plan = 'free' THEN 8
    ELSE 8  -- Fallback to free plan
  END;

  -- Try to get existing record, reset if needed
  RETURN QUERY
  SELECT 
    ut.id,
    ut.identifier,
    ut.user_plan,
    CASE 
      WHEN ut.user_plan = 'premium' THEN default_limit  -- Premium users always have max tokens
      WHEN (ut.last_reset AT TIME ZONE 'UTC')::date < (NOW() AT TIME ZONE 'UTC')::date THEN default_limit
      ELSE ut.available_tokens
    END as available_tokens,
    ut.purchased_tokens, -- Purchased tokens never reset
    default_limit as daily_limit,
    CASE 
      WHEN (ut.last_reset AT TIME ZONE 'UTC')::date < (NOW() AT TIME ZONE 'UTC')::date THEN (NOW() AT TIME ZONE 'UTC')
      ELSE ut.last_reset
    END as last_reset,
    CASE 
      WHEN ut.user_plan = 'premium' THEN 0  -- Premium users don't track consumption
      WHEN (ut.last_reset AT TIME ZONE 'UTC')::date < (NOW() AT TIME ZONE 'UTC')::date THEN 0
      ELSE ut.total_consumed_today
    END as total_consumed_today
  FROM user_tokens ut
  WHERE ut.identifier = current_identifier AND ut.user_plan = p_user_plan;
  
  -- If no record found, create one
  IF NOT FOUND THEN
    INSERT INTO user_tokens (identifier, user_plan, available_tokens, purchased_tokens, daily_limit)
    VALUES (current_identifier, p_user_plan, default_limit, 0, default_limit)
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
$ LANGUAGE plpgsql SECURITY INVOKER;  -- SECURITY INVOKER ensures auth context is preserved

-- Function to consume tokens atomically
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
) AS $
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
    WHEN p_user_plan = 'standard' THEN 20
    WHEN p_user_plan = 'free' THEN 8
    ELSE 8  -- Fallback to free plan
  END;

  -- Check if user needs daily reset and get current tokens
  SELECT 
    CASE 
      WHEN ut.user_plan = 'premium' THEN default_limit  -- Premium always has unlimited
      WHEN (ut.last_reset AT TIME ZONE 'UTC')::date < (NOW() AT TIME ZONE 'UTC')::date THEN default_limit 
      ELSE ut.available_tokens 
    END,
    ut.purchased_tokens,
    (ut.last_reset AT TIME ZONE 'UTC')::date < (NOW() AT TIME ZONE 'UTC')::date AND ut.user_plan != 'premium'
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
        last_reset = (NOW() AT TIME ZONE 'UTC'),
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
        last_reset = (NOW() AT TIME ZONE 'UTC'),
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
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to add purchased tokens
CREATE OR REPLACE FUNCTION add_purchased_tokens(
  p_identifier TEXT,
  p_user_plan TEXT,
  p_token_amount INTEGER
)
RETURNS TABLE(
  success BOOLEAN,
  new_purchased_balance INTEGER,
  error_message TEXT
) AS $
DECLARE
  default_limit INTEGER;
BEGIN
  -- Set default daily limit based on user plan
  default_limit := CASE
    WHEN p_user_plan = 'premium' THEN 999999999  -- Effectively unlimited
    WHEN p_user_plan = 'standard' THEN 20
    WHEN p_user_plan = 'free' THEN 8
    ELSE 8  -- Fallback to free plan
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
$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log token analytics events
CREATE OR REPLACE FUNCTION log_token_event(
  p_user_id TEXT,
  p_event_type TEXT,
  p_event_data JSONB,
  p_session_id TEXT DEFAULT NULL
)
RETURNS UUID AS $
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
$ LANGUAGE plpgsql SECURITY DEFINER;
```

## Token Analytics Schema

### Analytics Events Table

```sql
-- Assumes analytics_events table exists, if not create it
CREATE TABLE IF NOT EXISTS analytics_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT, -- Can be user_id or session_id for anonymous users
  session_id TEXT,
  event_type TEXT NOT NULL,
  event_data JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_type ON analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_events_created_at ON analytics_events(created_at);
CREATE INDEX IF NOT EXISTS idx_analytics_events_type_created ON analytics_events(event_type, created_at);

-- Comments
COMMENT ON TABLE analytics_events IS 'Tracks all user actions and system events for analytics';
COMMENT ON COLUMN analytics_events.user_id IS 'User ID for authenticated users, session ID for anonymous users';
COMMENT ON COLUMN analytics_events.event_type IS 'Type of event (e.g., token_consumed, token_purchased, token_added)';
COMMENT ON COLUMN analytics_events.event_data IS 'JSON data containing event-specific information';
```

### Token Event Types

```sql
-- Token-related event types to track
-- 'token_consumed' - When tokens are used for operations
-- 'token_purchased' - When user buys tokens
-- 'token_added' - When tokens are added (purchase, admin, etc.)
-- 'token_insufficient' - When user tries operation without enough tokens
-- 'token_reset' - When daily tokens are reset
-- 'token_balance_check' - When user checks token status
-- 'token_purchase_failed' - When token purchase fails
-- 'token_refund' - If tokens are refunded (future feature)
```

## Service Layer Design

### TokenService Class

```typescript
export class TokenService {
  constructor(private readonly supabaseClient: SupabaseClient) {}

  async getUserTokens(identifier: string, userPlan: UserPlan): Promise<TokenInfo> {
    // Get current token balance, auto-reset if needed
    const { data, error } = await this.supabaseClient
      .rpc('get_or_create_user_tokens', {
        p_identifier: identifier,
        p_user_plan: userPlan
      })
      .single()

    if (error) throw new AppError('TOKEN_ERROR', 'Failed to get user tokens', 500)
    
    return {
      availableTokens: data.available_tokens,
      purchasedTokens: data.purchased_tokens,
      dailyLimit: data.daily_limit,
      lastReset: data.last_reset,
      totalConsumedToday: data.total_consumed_today,
      totalTokens: data.available_tokens + data.purchased_tokens
    }
  }

  async consumeTokens(identifier: string, userPlan: UserPlan, tokenCost: number): Promise<TokenConsumptionResult> {
    // Atomically check and consume tokens
    const { data, error } = await this.supabaseClient
      .rpc('consume_user_tokens', {
        p_identifier: identifier,
        p_user_plan: userPlan,
        p_token_cost: tokenCost
      })
      .single()

    if (error) throw new AppError('TOKEN_ERROR', 'Failed to consume tokens', 500)
    
    if (!data.success) {
      throw new AppError('INSUFFICIENT_TOKENS', data.error_message, 429)
    }

    return {
      success: true,
      availableTokens: data.available_tokens,
      purchasedTokens: data.purchased_tokens,
      dailyLimit: data.daily_limit,
      totalTokens: data.available_tokens + data.purchased_tokens
    }
  }

  calculateTokenCost(languages: string[]): number {
    // Validate single language constraint
    if (languages.length > 1) {
      throw new AppError('MULTIPLE_LANGUAGES_NOT_SUPPORTED', 'Multiple languages not supported. Please select only one language.', 400)
    }
    
    if (languages.length === 0) {
      throw new AppError('LANGUAGE_REQUIRED', 'At least one language must be specified.', 400)
    }
    
    const languageCosts = {
      'en': 10,    // English
      'hi': 20,    // Hindi  
      'ml': 20     // Malayalam
    }
    
    const language = languages[0]
    const cost = languageCosts[language]
    
    if (cost === undefined) {
      throw new AppError('UNSUPPORTED_LANGUAGE', `Unsupported language: ${language}. Supported languages: en, hi, ml`, 400)
    }
    
    return cost
  }

  async purchaseTokens(identifier: string, userPlan: UserPlan, tokenAmount: number): Promise<void> {
    // Add purchased tokens to user's account
    const { error } = await this.supabaseClient
      .rpc('add_purchased_tokens', {
        p_identifier: identifier,
        p_user_plan: userPlan,
        p_token_amount: tokenAmount
      })

    if (error) throw new AppError('TOKEN_ERROR', 'Failed to add purchased tokens', 500)
  }
}
```

### Interface Definitions

```typescript
interface TokenInfo {
  availableTokens: number
  purchasedTokens: number
  dailyLimit: number
  lastReset: string
  totalConsumedToday: number
  totalTokens: number // availableTokens + purchasedTokens
}

interface TokenConsumptionResult {
  success: boolean
  availableTokens: number
  purchasedTokens: number
  dailyLimit: number
  totalTokens: number // availableTokens + purchasedTokens
}

type UserPlan = 'free' | 'standard' | 'premium'
```

## API Endpoint Changes

### Updated study-generate Endpoint

### User Plan Determination Helper

```typescript
// Helper function to determine user plan from context
function determineUserPlan(userContext: UserContext): UserPlan {
  if (userContext.type === 'anonymous') {
    return 'free'
  }
  
  if (userContext.type === 'authenticated') {
    // Check if user is admin (temporary premium access)
    if (userContext.userType === 'admin') {
      return 'premium'
    }
    
    // TODO: Add subscription check when subscription system is implemented
    // if (userContext.subscription && userContext.subscription.status === 'active') {
    //   return 'premium'
    // }
    
    return 'standard'
  }
  
  // Fallback to free plan
  return 'free'
}
```

```typescript
async function handleStudyGenerate(req: Request, services: ServiceContainer): Promise<Response> {
  const userContext = await services.authService.getUserContext(req)
  const { input_type, input_value, languages = ['en'] } = await parseAndValidateRequest(req)
  
  // Check for existing cached content FIRST
  const existingContent = await services.studyGuideRepository.findExistingContent(
    studyGuideInput, 
    userContext
  )
  
  if (existingContent) {
    return new Response(JSON.stringify({
      success: true,
      data: { study_guide: existingContent, from_cache: true }
    }), { status: 200, headers: { 'Content-Type': 'application/json' } })
  }

  // Calculate token cost for this operation
  const tokenCost = services.tokenService.calculateTokenCost(languages)
  
  // Determine user plan based on context
  const userPlan = determineUserPlan(userContext)
  
  // Check and consume tokens
  const identifier = userContext.type === 'authenticated' 
    ? userContext.userId! 
    : userContext.sessionId!
    
  const consumptionResult = await services.tokenService.consumeTokens(
    identifier, 
    userPlan, 
    tokenCost
  )

  // Generate new content
  const generatedContent = await services.llmService.generateStudyGuide({
    inputType: input_type,
    inputValue: input_value,
    languages
  })

  // Save and return content
  const savedGuide = await services.studyGuideRepository.saveStudyGuide(
    studyGuideInput,
    generatedContent,
    userContext
  )

  return new Response(JSON.stringify({
    success: true,
    data: { 
      study_guide: savedGuide, 
      from_cache: false 
    },
    tokens: {
      consumed: tokenCost,
      remaining: {
        available_tokens: consumptionResult.availableTokens,
        purchased_tokens: consumptionResult.purchasedTokens,
        total_tokens: consumptionResult.totalTokens
      },
      daily_limit: consumptionResult.dailyLimit
    }
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}
```

### New Token Status Endpoint

Create `/token-status` endpoint:

```typescript
// File: supabase/functions/token-status/index.ts
async function handleTokenStatus(req: Request, services: ServiceContainer): Promise<Response> {
  const userContext = await services.authService.getUserContext(req)
  
  // Determine user plan based on context
  const userPlan = determineUserPlan(userContext)
  
  const identifier = userContext.type === 'authenticated' 
    ? userContext.userId! 
    : userContext.sessionId!
    
  const tokenInfo = await services.tokenService.getUserTokens(identifier, userPlan)

  return new Response(JSON.stringify({
    success: true,
    data: {
      available_tokens: tokenInfo.availableTokens,
      purchased_tokens: tokenInfo.purchasedTokens,
      total_tokens: tokenInfo.totalTokens,
      daily_limit: tokenInfo.dailyLimit,
      total_consumed_today: tokenInfo.totalConsumedToday,
      last_reset: tokenInfo.lastReset,
      user_plan: userPlan,
      authentication_type: userContext.type,
      is_premium: userPlan === 'premium',
      unlimited_usage: userPlan === 'premium'
    }
  }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' }
  })
}

createFunction(handleTokenStatus, {
  requireAuth: false, // Allow both authenticated and anonymous users
  enableAnalytics: true,
  allowedMethods: ['GET']
})
```

### New Token Purchase Endpoint

Create `/purchase-tokens` endpoint:

```typescript
// File: supabase/functions/purchase-tokens/index.ts
async function handleTokenPurchase(req: Request, services: ServiceContainer): Promise<Response> {
  const userContext = await services.authService.getUserContext(req)
  
  // Only authenticated users can purchase tokens
  if (userContext.type !== 'authenticated') {
    return new Response(JSON.stringify({
      success: false,
      error: {
        code: 'AUTHENTICATION_REQUIRED',
        message: 'You must be logged in to purchase tokens'
      }
    }), { status: 401, headers: { 'Content-Type': 'application/json' } })
  }

  const { token_amount, payment_method_id } = await req.json()
  
  // Validate token amount
  if (!token_amount || token_amount <= 0 || token_amount > 10000) {
    return new Response(JSON.stringify({
      success: false,
      error: {
        code: 'INVALID_TOKEN_AMOUNT',
        message: 'Token amount must be between 1 and 10,000'
      }
    }), { status: 400, headers: { 'Content-Type': 'application/json' } })
  }

  try {
    // Calculate cost (10 tokens = ₹1) - Convert to paise first to avoid overcharging
    const paise = token_amount * 10 // Convert tokens to paise (1 token = 10 paise)
    const costInPaise = Math.ceil(paise) // Round up to nearest paise for Razorpay
    
    // Process payment via Razorpay
    const paymentResult = await services.paymentService.processTokenPurchase({
      amount: costInPaise,
      currency: 'INR',
      payment_method_id,
      user_id: userContext.userId!,
      metadata: {
        token_amount,
        purchase_type: 'token_purchase'
      }
    })

    if (paymentResult.status !== 'captured') {
      return new Response(JSON.stringify({
        success: false,
        error: {
          code: 'PAYMENT_FAILED',
          message: 'Payment processing failed'
        }
      }), { status: 402, headers: { 'Content-Type': 'application/json' } })
    }

    // Determine user plan
    const userPlan = determineUserPlan(userContext)
    
    // Add purchased tokens to user account
    await services.tokenService.purchaseTokens(
      userContext.userId!,
      userPlan,
      token_amount
    )

    // Get updated token info
    const updatedTokenInfo = await services.tokenService.getUserTokens(
      userContext.userId!,
      userPlan
    )

    // Log the purchase for analytics
    await services.analyticsService.logTokenPurchase({
      user_id: userContext.userId!,
      token_amount,
      cost_in_paise: costInPaise,
      payment_id: paymentResult.payment_id,
      timestamp: new Date()
    })

    return new Response(JSON.stringify({
      success: true,
      data: {
        tokens_purchased: token_amount,
        cost_paid: costInPaise / 100, // Amount in rupees
        tokens_per_rupee: 10,
        new_token_balance: {
          available_tokens: updatedTokenInfo.availableTokens,
          purchased_tokens: updatedTokenInfo.purchasedTokens,
          total_tokens: updatedTokenInfo.totalTokens
        },
        payment_id: paymentResult.payment_id
      }
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('Token purchase failed:', error)
    
    return new Response(JSON.stringify({
      success: false,
      error: {
        code: 'PURCHASE_ERROR',
        message: 'Failed to process token purchase'
      }
    }), { status: 500, headers: { 'Content-Type': 'application/json' } })
  }
}

createFunction(handleTokenPurchase, {
  requireAuth: true,
  enableAnalytics: true,
  allowedMethods: ['POST']
})
```

## User Context Interface Updates

### Updated UserContext Interface

```typescript
interface UserContext {
  type: 'anonymous' | 'authenticated'
  userId?: string
  sessionId?: string
  userType?: 'admin' | 'user'  // Admin users get premium access temporarily
  subscription?: {
    status: 'active' | 'inactive' | 'cancelled' | 'past_due'
    plan: string
    expiresAt?: Date
  }
}
```

## Migration Plan

### Phase 1: Database Setup
1. Create `user_tokens` table with functions
2. **CRITICAL SECURITY STEP**: Lock down function permissions
   ```sql
   -- Secure the get_or_create_user_tokens function
   REVOKE EXECUTE ON FUNCTION get_or_create_user_tokens FROM anon;
   REVOKE EXECUTE ON FUNCTION get_or_create_user_tokens FROM authenticated;
   GRANT EXECUTE ON FUNCTION get_or_create_user_tokens TO service_role;
   
   -- Use secure version for client access
   GRANT EXECUTE ON FUNCTION get_or_create_user_tokens_secure TO authenticated;
   GRANT EXECUTE ON FUNCTION get_or_create_user_tokens_secure TO anon;
   ```
3. Test database functions in isolation
4. Enable RLS policies

### **PREFERRED SECURITY APPROACH: Service Role Only**

For maximum security, the original `get_or_create_user_tokens` function should:
1. **Only be accessible to `service_role`** (implemented above)
2. **Be called exclusively from trusted Edge Functions**
3. **Never be exposed to client-side code**

**Migration Steps**:
```sql
-- 1. Revoke all public access
REVOKE ALL ON FUNCTION get_or_create_user_tokens FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION get_or_create_user_tokens FROM anon;
REVOKE EXECUTE ON FUNCTION get_or_create_user_tokens FROM authenticated;

-- 2. Grant only to service_role
GRANT EXECUTE ON FUNCTION get_or_create_user_tokens TO service_role;

-- 3. Use the secure variant for any client-accessible operations
-- (This variant automatically uses auth.uid() and cannot be bypassed)
GRANT EXECUTE ON FUNCTION get_or_create_user_tokens_secure TO authenticated;
GRANT EXECUTE ON FUNCTION get_or_create_user_tokens_secure TO anon;
```

**Edge Function Implementation**:
```typescript
// In Edge Functions, use service_role client
const serviceClient = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, // Service role key
  { auth: { persistSession: false } }
)

// Safe to call with service_role
const { data } = await serviceClient.rpc('get_or_create_user_tokens', {
  p_identifier: userIdentifier,
  p_user_plan: userPlan
})
```

### Phase 2: Service Implementation
1. Implement `TokenService` class
2. Add to `ServiceContainer`
3. Unit test token operations

### Phase 3: API Integration
1. Update `study-generate` endpoint
2. Create `token-status` endpoint
3. Integration testing

### Phase 4: Data Migration and Plan Transition
1. **User Plan Assignment Migration**:
   - Create migration script to identify existing users' subscription status
   - Map anonymous users → 'free' plan
   - Map authenticated users without subscription → 'standard' plan
   - Map authenticated users with active subscription → 'premium' plan
   - Assign full daily token allocation based on new plans

2. **Database Migration Considerations**:
   - Ensure backward compatibility during transition period
   - Handle edge cases where subscription status might be unclear
   - Implement rollback strategy in case of migration issues
   - Monitor token consumption patterns during migration

3. **Authentication Service Updates**:
   - Update `getUserContext()` to include subscription information
   - Implement subscription status checking logic
   - Add caching for subscription data to reduce database queries
   - Handle subscription status changes (upgrades/downgrades/cancellations)

### Phase 5: Security Validation & Cleanup
1. **SECURITY AUDIT**: Verify function permissions are correctly set
   ```sql
   -- Verify no unauthorized access
   SELECT 
     routine_name,
     routine_type,
     security_type,
     grantee,
     privilege_type
   FROM information_schema.routine_privileges 
   WHERE routine_name LIKE '%user_tokens%';
   ```
2. Remove `RateLimiter` service usage
3. Drop `rate_limit_usage` table
4. Update documentation
5. **PENETRATION TEST**: Verify p_identifier bypass is impossible

## Error Handling

### New Error Types

```typescript
// Add to AppError types
export const TOKEN_ERROR_CODES = {
  INSUFFICIENT_TOKENS: 'INSUFFICIENT_TOKENS',
  TOKEN_SERVICE_ERROR: 'TOKEN_SERVICE_ERROR',
  INVALID_TOKEN_OPERATION: 'INVALID_TOKEN_OPERATION'
} as const

// Error responses
{
  "success": false,
  "error": {
    "code": "INSUFFICIENT_TOKENS",
    "message": "Not enough tokens. You have 5 tokens but need 10 tokens for this operation.",
    "details": {
      "available_tokens": 5,
      "required_tokens": 10,
      "daily_limit": 100,
      "reset_time": "2025-01-08T00:00:00.000Z"
    }
  }
}
```

## Additional Implementation Considerations

### Subscription Status Handling

```typescript
// Add to AuthService
interface SubscriptionInfo {
  status: 'active' | 'inactive' | 'cancelled' | 'past_due'
  plan: string
  expiresAt?: Date
  renewsAt?: Date
}

class AuthService {
  async getUserContext(req: Request): Promise<UserContext> {
    const user = await this.getUser(req)
    
    if (!user) {
      return {
        type: 'anonymous',
        sessionId: this.getOrCreateSessionId(req)
      }
    }
    
    const subscription = await this.getSubscriptionInfo(user.id)
    
    return {
      type: 'authenticated',
      userId: user.id,
      subscription
    }
  }
  
  private async getSubscriptionInfo(userId: string): Promise<SubscriptionInfo | undefined> {
    // Query subscription table or external service (Razorpay)
    const { data } = await this.supabaseClient
      .from('user_subscriptions')
      .select('*')
      .eq('user_id', userId)
      .eq('status', 'active')
      .single()
    
    if (!data) return undefined
    
    return {
      status: data.status,
      plan: data.plan_name,
      expiresAt: new Date(data.expires_at),
      renewsAt: new Date(data.renews_at)
    }
  }
}
```

### Plan Transition Scenarios

1. **User Upgrades to Premium**:
   - Existing tokens remain in database for historical tracking
   - Future requests use unlimited premium access
   - No token deduction for premium operations

2. **Premium User Downgrades**:
   - Reset to standard/free plan limits immediately
   - Create new token record with appropriate daily limit
   - Handle mid-day downgrades gracefully

3. **Subscription Expiration**:
   - Automatic downgrade from premium to standard
   - Resume token-based limiting
   - Grace period consideration for expired subscriptions

### Error Handling Enhancements

```typescript
// Enhanced error responses for plan-related issues
export const PLAN_ERROR_CODES = {
  SUBSCRIPTION_EXPIRED: 'SUBSCRIPTION_EXPIRED',
  PLAN_DOWNGRADE_LIMIT: 'PLAN_DOWNGRADE_LIMIT',
  SUBSCRIPTION_VERIFICATION_FAILED: 'SUBSCRIPTION_VERIFICATION_FAILED'
} as const

// Example error response for subscription issues
{
  "success": false,
  "error": {
    "code": "SUBSCRIPTION_EXPIRED",
    "message": "Your premium subscription has expired. You've been moved to the standard plan.",
    "details": {
      "current_plan": "standard",
      "available_tokens": 85,
      "daily_limit": 100,
      "expired_at": "2025-01-07T23:59:59.000Z",
      "upgrade_url": "/subscription/upgrade"
    }
  }
}
```

## Benefits of Token System

### User Experience
- **Clear Usage**: Users see exact token balance (daily + purchased)
- **Predictable Costs**: Different operations have clear token costs
- **Daily Reset**: Easy to understand daily allocation (purchased tokens persist)
- **Fair Usage**: Authenticated users get more tokens
- **Premium Benefits**: Premium users enjoy unlimited usage without daily limits
- **Flexible Purchasing**: Buy exactly the tokens needed, when needed
- **No Token Loss**: Purchased tokens never expire or reset
- **Payment Integration**: Seamless Razorpay integration for token purchases

### Technical Benefits
- **Flexible**: Easy to adjust costs per operation
- **Scalable**: Can add user tiers with different limits
- **Atomic**: Database operations prevent race conditions
- **Efficient**: Single table, simple queries

### Business Benefits
- **Analytics**: Track usage patterns per user type
- **Revenue Model**: Foundation for paid tiers with premium subscriptions
- **Resource Control**: Prevent API abuse while rewarding premium users
- **User Retention**: Fair usage encourages engagement and premium upgrades

## Monitoring and Analytics

### Key Metrics to Track
1. **Daily token consumption** by user plan (free, standard, premium)
2. **Average tokens per study guide** by language selection
3. **Token exhaustion rate** (users hitting daily limit, excluding premium)
4. **Cache hit rate** impact on token usage
5. **Premium usage patterns** to understand unlimited user behavior
6. **Conversion rates** from authenticated to premium users
7. **Token purchase patterns** - frequency, amounts, and user segments
8. **Purchased token usage vs daily allocation usage** ratios
9. **Revenue from token purchases** by user plan
10. **Token purchase abandonment rates** and payment failures

### Alerts to Configure
1. **High token consumption** - Unusual usage patterns (especially for premium users)
2. **Token service errors** - Database/service issues
3. **User complaints** - Insufficient token allocation for non-premium users
4. **Premium abuse detection** - Unusual premium user activity patterns

## Future Enhancements

### Potential Features
1. **Token Package Bundles**: Bulk token purchases with discounts
   - 100 tokens for ₹9 (₹10 value, 10% discount)
   - 500 tokens for ₹40 (₹50 value, 20% discount)
   - 1000 tokens for ₹75 (₹100 value, 25% discount)
2. **Token Gifting**: Allow users to gift tokens to other users
3. **Token Sharing**: Family/group token pools for shared accounts
4. **Usage Analytics**: Personal usage dashboards with spending insights
5. **Smart Pricing**: Dynamic token costs based on operation complexity
6. **Token Rewards**: Earn tokens through referrals or daily check-ins
7. **Subscription + Token Hybrid**: Premium plans with included monthly tokens
8. **Auto-Refill**: Automatically purchase tokens when balance gets low
9. **Token Expiry**: Add expiry dates to purchased tokens to encourage usage
10. **Token Transfer**: Allow transferring purchased tokens between user accounts

This token-based system provides a solid foundation for fair usage management and future monetization strategies while delivering a better user experience than time-based rate limiting.