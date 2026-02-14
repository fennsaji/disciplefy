-- =====================================================
-- Consolidated Migration: Token System
-- =====================================================
-- Source: Consolidation of 13 token-related migrations
-- Tables: 2 (user_tokens, token_usage_history)
-- Description: Complete token-based usage system with consumption tracking,
--              atomic operations, daily resets, and comprehensive analytics
-- =====================================================

-- Dependencies: 0001_core_schema.sql (auth.users)

BEGIN;

-- =====================================================
-- PART 1: User Tokens Table (Balance Tracking)
-- =====================================================

CREATE TABLE user_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- User identification
  identifier TEXT NOT NULL, -- user_id for authenticated, session_id for anonymous

  -- Subscription plan
  user_plan TEXT NOT NULL CHECK (user_plan IN ('free', 'standard', 'plus', 'premium')),

  -- Token balances
  available_tokens INTEGER NOT NULL DEFAULT 0 CHECK (available_tokens >= 0), -- Daily allocation
  purchased_tokens INTEGER NOT NULL DEFAULT 0 CHECK (purchased_tokens >= 0), -- Purchased (never reset)

  -- Daily limits and tracking
  daily_limit INTEGER NOT NULL CHECK (daily_limit >= 0),
  last_reset DATE NOT NULL DEFAULT CURRENT_DATE,
  total_consumed_today INTEGER NOT NULL DEFAULT 0 CHECK (total_consumed_today >= 0),

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- Performance Indexes
-- =====================================================

-- Primary lookup index (most critical)
CREATE UNIQUE INDEX idx_user_tokens_identifier ON user_tokens(identifier, user_plan);

-- Daily reset cleanup
CREATE INDEX idx_user_tokens_reset ON user_tokens(last_reset);

-- Plan-based queries
CREATE INDEX idx_user_tokens_plan ON user_tokens(user_plan);

-- Analytics indexes
CREATE INDEX idx_user_tokens_created_at ON user_tokens(created_at);
CREATE INDEX idx_user_tokens_updated_at ON user_tokens(updated_at);

-- =====================================================
-- Updated Timestamp Trigger
-- =====================================================

CREATE OR REPLACE FUNCTION update_user_tokens_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_user_tokens_updated_at
  BEFORE UPDATE ON user_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_user_tokens_updated_at();

-- =====================================================
-- Table Comments
-- =====================================================

COMMENT ON TABLE user_tokens IS 'Token-based usage tracking for API operations across subscription plans';
COMMENT ON COLUMN user_tokens.identifier IS 'User ID for authenticated or session ID for anonymous users';
COMMENT ON COLUMN user_tokens.user_plan IS 'Subscription plan: free, standard, plus, premium';
COMMENT ON COLUMN user_tokens.available_tokens IS 'Current daily allocation tokens (resets daily)';
COMMENT ON COLUMN user_tokens.purchased_tokens IS 'Purchased tokens balance (never resets)';
COMMENT ON COLUMN user_tokens.daily_limit IS 'Maximum tokens per day for this subscription plan';
COMMENT ON COLUMN user_tokens.last_reset IS 'Last date when tokens were reset to daily limit';
COMMENT ON COLUMN user_tokens.total_consumed_today IS 'Total tokens consumed since last reset';

-- =====================================================
-- PART 2: Token Usage History (Audit Trail)
-- =====================================================

CREATE TABLE token_usage_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- User identification
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Token consumption details
  token_cost INTEGER NOT NULL CHECK (token_cost > 0),
  daily_tokens_used INTEGER NOT NULL DEFAULT 0 CHECK (daily_tokens_used >= 0),
  purchased_tokens_used INTEGER NOT NULL DEFAULT 0 CHECK (purchased_tokens_used >= 0),

  -- Feature context
  feature_name TEXT NOT NULL CHECK (feature_name != ''),
  operation_type TEXT NOT NULL,
  user_plan TEXT NOT NULL CHECK (user_plan IN ('free', 'standard', 'plus', 'premium')),

  -- Content context (optional)
  study_mode TEXT CHECK (study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon')),
  language TEXT NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'hi', 'ml')),
  content_title TEXT,
  content_reference TEXT,
  input_type TEXT CHECK (input_type IN ('scripture', 'topic', 'question')),

  -- Session tracking
  session_id TEXT,

  -- Timestamp
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- Performance Indexes
-- =====================================================

-- User lookup (most common query)
CREATE INDEX idx_token_usage_history_user_id ON token_usage_history(user_id);

-- Temporal queries
CREATE INDEX idx_token_usage_history_created_at ON token_usage_history(created_at DESC);

-- Composite for paginated user queries
CREATE INDEX idx_token_usage_history_user_date ON token_usage_history(user_id, created_at DESC);

-- Feature analytics
CREATE INDEX idx_token_usage_history_feature ON token_usage_history(feature_name);

-- Plan-based analytics
CREATE INDEX idx_token_usage_history_plan ON token_usage_history(user_plan);

-- =====================================================
-- Table Comments
-- =====================================================

COMMENT ON TABLE token_usage_history IS 'Detailed token consumption history with feature, mode, language, and content context for analytics';
COMMENT ON COLUMN token_usage_history.feature_name IS 'Feature that consumed tokens (e.g., study_generate, continue_learning, study_followup)';
COMMENT ON COLUMN token_usage_history.operation_type IS 'Type of operation (e.g., study_generation, follow_up_question)';
COMMENT ON COLUMN token_usage_history.study_mode IS 'Study mode if applicable: quick, standard, deep, lectio, sermon';
COMMENT ON COLUMN token_usage_history.content_title IS 'User-friendly title of generated content (e.g., "John 3:16 Study")';
COMMENT ON COLUMN token_usage_history.content_reference IS 'Scripture reference, topic name, or question text';
COMMENT ON COLUMN token_usage_history.daily_tokens_used IS 'Tokens consumed from daily allocation';
COMMENT ON COLUMN token_usage_history.purchased_tokens_used IS 'Tokens consumed from purchased balance';

-- =====================================================
-- PART 3: Core Functions
-- =====================================================

-- -----------------------------------------------------
-- Function: get_or_create_user_tokens
-- Purpose: Get or create user tokens with automatic daily reset
-- Fixed: NOT FOUND bug (migration 20250907000002)
-- -----------------------------------------------------

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
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  default_limit INTEGER;
  record_exists BOOLEAN;
  current_date_utc DATE;
BEGIN
  -- Use UTC timezone for consistent date comparisons
  current_date_utc := (NOW() AT TIME ZONE 'UTC')::date;

  -- Read daily limit from subscription_plans.features
  -- Updated: 2026-02-13 - Now reads from database instead of hardcoded values
  -- This allows admin web updates to be reflected in client apps
  SELECT COALESCE((sp.features->>'daily_tokens')::INTEGER, 8) INTO default_limit
  FROM subscription_plans sp
  WHERE sp.plan_code = p_user_plan;

  -- If plan not found in database, use free plan default
  IF default_limit IS NULL THEN
    default_limit := 8;
  END IF;

  -- Handle unlimited plans (represented as -1 in features)
  IF default_limit = -1 THEN
    default_limit := 999999999;
  END IF;

  -- Check if record exists
  SELECT EXISTS(
    SELECT 1 FROM user_tokens ut
    WHERE ut.identifier = p_identifier AND ut.user_plan = p_user_plan
  ) INTO record_exists;

  -- If no record exists, create one
  IF NOT record_exists THEN
    INSERT INTO user_tokens (
      identifier,
      user_plan,
      available_tokens,
      purchased_tokens,
      daily_limit,
      last_reset
    )
    VALUES (
      p_identifier,
      p_user_plan,
      default_limit,
      0,
      default_limit,
      current_date_utc
    );
  ELSE
    -- CRITICAL FIX: Persist daily reset BEFORE SELECT to avoid virtual reset issues
    UPDATE user_tokens ut
    SET
      available_tokens = CASE
        WHEN default_limit = 999999999 THEN 999999999
        WHEN ut.last_reset < current_date_utc THEN default_limit
        ELSE ut.available_tokens
      END,
      last_reset = CASE
        WHEN ut.last_reset < current_date_utc THEN current_date_utc
        ELSE ut.last_reset
      END,
      total_consumed_today = CASE
        WHEN default_limit = 999999999 THEN 0
        WHEN ut.last_reset < current_date_utc THEN 0
        ELSE ut.total_consumed_today
      END,
      daily_limit = default_limit,  -- Update daily_limit to match database
      updated_at = NOW()
    WHERE ut.identifier = p_identifier
      AND ut.user_plan = p_user_plan;
  END IF;

  -- Return the record (existing or newly created), now with persisted reset
  RETURN QUERY
  SELECT
    ut.id,
    ut.identifier,
    ut.user_plan,
    ut.available_tokens,
    ut.purchased_tokens,
    ut.daily_limit,
    ut.last_reset,
    ut.total_consumed_today
  FROM user_tokens ut
  WHERE ut.identifier = p_identifier AND ut.user_plan = p_user_plan;
END;
$$;

COMMENT ON FUNCTION get_or_create_user_tokens(TEXT, TEXT) IS
  'Get or create user tokens record with automatic daily reset logic.
   Reads daily_tokens from subscription_plans.features (database-driven).
   Admin web updates are reflected automatically.';

-- -----------------------------------------------------
-- Function: consume_user_tokens
-- Purpose: Atomically consume tokens with proper locking
-- Fixed: SELECT FOR UPDATE locking (migration 20250907000003)
-- Fixed: Ambiguous column references
-- Updated: Token breakdown in response (migration 20260110000002)
-- -----------------------------------------------------

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
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  current_daily_tokens INTEGER;
  current_purchased_tokens INTEGER;
  total_available INTEGER;
  default_limit INTEGER;
  needs_reset BOOLEAN;
  updated_rows INTEGER;
  tokens_from_daily INTEGER := 0;
  tokens_from_purchased INTEGER := 0;
BEGIN
  -- INPUT VALIDATION: Check p_token_cost
  IF p_token_cost IS NULL OR p_token_cost <= 0 THEN
    RETURN QUERY SELECT
      false::BOOLEAN,
      0::INTEGER,
      0::INTEGER,
      0::INTEGER,
      0::INTEGER,
      0::INTEGER,
      'Invalid token cost: must be positive integer'::TEXT;
    RETURN;
  END IF;

  -- Set default daily limit based on subscription plan
  default_limit := CASE
    WHEN p_user_plan = 'premium' THEN 999999999
    WHEN p_user_plan = 'plus' THEN 50
    WHEN p_user_plan = 'standard' THEN 20
    WHEN p_user_plan = 'free' THEN 8
    ELSE 8
  END;

  -- Check if user needs daily reset and get current tokens WITH ROW LOCK
  SELECT
    CASE
      WHEN ut.user_plan = 'premium' THEN default_limit
      WHEN ut.last_reset < CURRENT_DATE THEN default_limit
      ELSE ut.available_tokens
    END,
    ut.purchased_tokens,
    ut.last_reset < CURRENT_DATE AND ut.user_plan != 'premium'
  INTO current_daily_tokens, current_purchased_tokens, needs_reset
  FROM user_tokens ut
  WHERE ut.identifier = p_identifier AND ut.user_plan = p_user_plan
  FOR UPDATE;  -- CRITICAL: Lock row to prevent race conditions

  -- Calculate total available tokens (daily + purchased)
  total_available := COALESCE(current_daily_tokens, 0) + COALESCE(current_purchased_tokens, 0);

  -- If user doesn't exist, create with default tokens
  IF current_daily_tokens IS NULL THEN
    INSERT INTO user_tokens (
      identifier,
      user_plan,
      available_tokens,
      purchased_tokens,
      daily_limit
    )
    VALUES (
      p_identifier,
      p_user_plan,
      default_limit,
      0,
      default_limit
    );
    current_daily_tokens := default_limit;
    current_purchased_tokens := 0;
    total_available := default_limit;
    needs_reset := false;
  END IF;

  -- Check if user has enough tokens (skip for premium)
  IF p_user_plan != 'premium' AND total_available < p_token_cost THEN
    RETURN QUERY SELECT
      false::BOOLEAN,
      current_daily_tokens,
      current_purchased_tokens,
      default_limit,
      0::INTEGER,
      0::INTEGER,
      'Insufficient tokens'::TEXT;
    RETURN;
  END IF;

  -- Consume tokens with atomic update
  -- Strategy: Prioritize daily tokens first, then purchased tokens
  IF p_user_plan = 'premium' THEN
    -- Premium users don't consume tokens, just update timestamp
    UPDATE user_tokens
    SET updated_at = NOW()
    WHERE identifier = p_identifier AND user_plan = p_user_plan;

    RETURN QUERY SELECT
      true::BOOLEAN,
      current_daily_tokens,
      current_purchased_tokens,
      default_limit,
      0::INTEGER,
      0::INTEGER,
      ''::TEXT;
    RETURN;
  END IF;

  -- Calculate token breakdown (prioritize daily tokens)
  IF current_daily_tokens >= p_token_cost THEN
    -- Consume entirely from daily tokens
    tokens_from_daily := p_token_cost;
    tokens_from_purchased := 0;
  ELSE
    -- Consume all daily tokens + remaining from purchased
    tokens_from_daily := current_daily_tokens;
    tokens_from_purchased := p_token_cost - current_daily_tokens;
  END IF;

  -- Apply reset if needed and consume tokens atomically
  IF needs_reset THEN
    UPDATE user_tokens
    SET
      available_tokens = default_limit - tokens_from_daily,
      purchased_tokens = user_tokens.purchased_tokens - tokens_from_purchased,
      total_consumed_today = p_token_cost,
      last_reset = CURRENT_DATE,
      updated_at = NOW()
    WHERE identifier = p_identifier
      AND user_plan = p_user_plan
      AND user_tokens.purchased_tokens >= tokens_from_purchased;  -- ATOMIC: Verify sufficient tokens

    GET DIAGNOSTICS updated_rows = ROW_COUNT;
    IF updated_rows = 0 THEN
      RETURN QUERY SELECT
        false::BOOLEAN,
        current_daily_tokens,
        current_purchased_tokens,
        default_limit,
        0::INTEGER,
        0::INTEGER,
        'Insufficient tokens (race condition detected)'::TEXT;
      RETURN;
    END IF;
  ELSE
    -- No reset needed, just consume tokens
    UPDATE user_tokens
    SET
      available_tokens = user_tokens.available_tokens - tokens_from_daily,
      purchased_tokens = user_tokens.purchased_tokens - tokens_from_purchased,
      total_consumed_today = user_tokens.total_consumed_today + p_token_cost,
      updated_at = NOW()
    WHERE identifier = p_identifier
      AND user_plan = p_user_plan
      AND user_tokens.available_tokens >= tokens_from_daily
      AND user_tokens.purchased_tokens >= tokens_from_purchased;  -- ATOMIC: Verify sufficient tokens

    GET DIAGNOSTICS updated_rows = ROW_COUNT;
    IF updated_rows = 0 THEN
      RETURN QUERY SELECT
        false::BOOLEAN,
        current_daily_tokens,
        current_purchased_tokens,
        default_limit,
        0::INTEGER,
        0::INTEGER,
        'Insufficient tokens (race condition detected)'::TEXT;
      RETURN;
    END IF;
  END IF;

  -- Return success with updated balances
  RETURN QUERY
  SELECT
    true::BOOLEAN,
    (current_daily_tokens - tokens_from_daily)::INTEGER,
    (current_purchased_tokens - tokens_from_purchased)::INTEGER,
    default_limit,
    tokens_from_daily,
    tokens_from_purchased,
    ''::TEXT;
END;
$$;

COMMENT ON FUNCTION consume_user_tokens(TEXT, TEXT, INTEGER) IS
  'Atomically consume tokens with SELECT FOR UPDATE row-level locking and token breakdown response (FIXED: race conditions, ambiguous columns, transaction isolation)';

-- -----------------------------------------------------
-- Function: add_purchased_tokens
-- Purpose: Add purchased tokens to user balance
-- -----------------------------------------------------

CREATE OR REPLACE FUNCTION add_purchased_tokens(
  p_identifier TEXT,
  p_user_plan TEXT,
  p_token_amount INTEGER
)
RETURNS TABLE(
  success BOOLEAN,
  new_balance INTEGER,
  error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  current_balance INTEGER;
BEGIN
  -- INPUT VALIDATION
  IF p_token_amount IS NULL OR p_token_amount <= 0 THEN
    RETURN QUERY SELECT
      false::BOOLEAN,
      0::INTEGER,
      'Invalid token amount: must be positive integer'::TEXT;
    RETURN;
  END IF;

  -- Update purchased tokens atomically
  UPDATE user_tokens
  SET
    purchased_tokens = user_tokens.purchased_tokens + p_token_amount,
    updated_at = NOW()
  WHERE identifier = p_identifier
    AND user_plan = p_user_plan
  RETURNING user_tokens.purchased_tokens INTO current_balance;

  -- If no record found, create one
  IF current_balance IS NULL THEN
    INSERT INTO user_tokens (
      identifier,
      user_plan,
      purchased_tokens,
      daily_limit,
      available_tokens
    ) VALUES (
      p_identifier,
      p_user_plan,
      p_token_amount,
      CASE
        WHEN p_user_plan = 'premium' THEN 999999999
        WHEN p_user_plan = 'plus' THEN 50
        WHEN p_user_plan = 'standard' THEN 20
        ELSE 8
      END,
      CASE
        WHEN p_user_plan = 'premium' THEN 999999999
        WHEN p_user_plan = 'plus' THEN 50
        WHEN p_user_plan = 'standard' THEN 20
        ELSE 8
      END
    )
    RETURNING user_tokens.purchased_tokens INTO current_balance;
  END IF;

  -- Return success
  RETURN QUERY SELECT
    true::BOOLEAN,
    current_balance,
    ''::TEXT;
END;
$$;

COMMENT ON FUNCTION add_purchased_tokens(TEXT, TEXT, INTEGER) IS
  'Add purchased tokens to user balance atomically';

-- -----------------------------------------------------
-- Function: record_token_usage
-- Purpose: Record token consumption in history table
-- Created: 2026-01-10
-- -----------------------------------------------------

CREATE OR REPLACE FUNCTION record_token_usage(
  p_user_id UUID,
  p_token_cost INTEGER,
  p_feature_name TEXT,
  p_operation_type TEXT,
  p_study_mode TEXT DEFAULT NULL,
  p_language TEXT DEFAULT 'en',
  p_content_title TEXT DEFAULT NULL,
  p_content_reference TEXT DEFAULT NULL,
  p_input_type TEXT DEFAULT NULL,
  p_user_plan TEXT DEFAULT 'free',
  p_session_id TEXT DEFAULT NULL,
  p_daily_tokens_used INTEGER DEFAULT 0,
  p_purchased_tokens_used INTEGER DEFAULT 0
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
  v_record_id UUID;
BEGIN
  -- Validate required inputs
  IF p_user_id IS NULL THEN
    RAISE WARNING 'record_token_usage: user_id is NULL, skipping recording';
    RETURN NULL;
  END IF;

  IF p_token_cost <= 0 THEN
    RAISE WARNING 'record_token_usage: invalid token_cost (%), skipping', p_token_cost;
    RETURN NULL;
  END IF;

  IF p_feature_name IS NULL OR p_feature_name = '' THEN
    RAISE WARNING 'record_token_usage: feature_name is empty, skipping';
    RETURN NULL;
  END IF;

  -- Insert usage record (non-blocking - catch any errors)
  BEGIN
    INSERT INTO token_usage_history (
      user_id,
      token_cost,
      feature_name,
      operation_type,
      study_mode,
      language,
      content_title,
      content_reference,
      input_type,
      user_plan,
      session_id,
      daily_tokens_used,
      purchased_tokens_used
    ) VALUES (
      p_user_id,
      p_token_cost,
      p_feature_name,
      p_operation_type,
      p_study_mode,
      p_language,
      p_content_title,
      p_content_reference,
      p_input_type,
      p_user_plan,
      p_session_id,
      p_daily_tokens_used,
      p_purchased_tokens_used
    )
    RETURNING id INTO v_record_id;

    RETURN v_record_id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'record_token_usage: Failed to insert record: %', SQLERRM;
    RETURN NULL;
  END;
END;
$$;

COMMENT ON FUNCTION record_token_usage IS
  'Record token consumption in history table for analytics (non-blocking, service-role only)';

-- -----------------------------------------------------
-- Function: get_user_token_usage_history
-- Purpose: Retrieve paginated usage history for a user
-- Created: 2026-01-10
-- -----------------------------------------------------

CREATE OR REPLACE FUNCTION get_user_token_usage_history(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0,
  p_start_date TIMESTAMPTZ DEFAULT NULL,
  p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
  id UUID,
  token_cost INTEGER,
  feature_name TEXT,
  operation_type TEXT,
  study_mode TEXT,
  language TEXT,
  content_title TEXT,
  content_reference TEXT,
  input_type TEXT,
  user_plan TEXT,
  session_id TEXT,
  daily_tokens_used INTEGER,
  purchased_tokens_used INTEGER,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
BEGIN
  -- Validate limit (1-100)
  IF p_limit < 1 THEN
    p_limit := 20;
  END IF;
  IF p_limit > 100 THEN
    p_limit := 100;
  END IF;

  -- Validate offset (>=0)
  IF p_offset < 0 THEN
    p_offset := 0;
  END IF;

  -- Return paginated usage history with optional date filtering
  RETURN QUERY
  SELECT
    tuh.id,
    tuh.token_cost,
    tuh.feature_name,
    tuh.operation_type,
    tuh.study_mode,
    tuh.language,
    tuh.content_title,
    tuh.content_reference,
    tuh.input_type,
    tuh.user_plan,
    tuh.session_id,
    tuh.daily_tokens_used,
    tuh.purchased_tokens_used,
    tuh.created_at
  FROM token_usage_history tuh
  WHERE tuh.user_id = p_user_id
    AND (p_start_date IS NULL OR tuh.created_at >= p_start_date)
    AND (p_end_date IS NULL OR tuh.created_at <= p_end_date)
  ORDER BY tuh.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION get_user_token_usage_history IS
  'Retrieve paginated token usage history for a user with optional date filtering. Ordered by created_at DESC.';

-- =====================================================
-- PART 4: Row Level Security (RLS) Policies
-- =====================================================

-- Enable RLS on both tables
ALTER TABLE user_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_usage_history ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------
-- user_tokens RLS Policies
-- -----------------------------------------------------

-- Service role has full access
CREATE POLICY "service_role_user_tokens_all" ON user_tokens
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Authenticated users can view their own tokens (via functions)
-- No direct SELECT access - use get_or_create_user_tokens() function
CREATE POLICY "authenticated_no_direct_access" ON user_tokens
  FOR SELECT
  TO authenticated
  USING (false); -- Block direct access, use functions only

-- Anonymous users cannot access directly
CREATE POLICY "anonymous_no_direct_access" ON user_tokens
  FOR SELECT
  TO anon
  USING (false); -- Block direct access, use functions only

-- -----------------------------------------------------
-- token_usage_history RLS Policies
-- Fixed: 20260110000003, 20260110000004, 20260110000005
-- -----------------------------------------------------

-- Users can view their own usage history
CREATE POLICY "users_view_own_token_usage" ON token_usage_history
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Service role can INSERT usage records (from Edge Functions)
CREATE POLICY "service_role_insert_usage" ON token_usage_history
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Service role has full access for analytics
CREATE POLICY "service_role_token_usage_all" ON token_usage_history
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- =====================================================
-- PART 5: Grant Permissions
-- =====================================================

-- Grant function execution permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_or_create_user_tokens(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION consume_user_tokens(TEXT, TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_token_usage_history(UUID, INTEGER, INTEGER, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- Grant service role access to all functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Grant table permissions
GRANT SELECT ON token_usage_history TO authenticated;
GRANT INSERT ON token_usage_history TO service_role;

-- =====================================================
-- PART 6: Verification Queries
-- =====================================================

-- Verify both tables created
DO $$
DECLARE
  missing_tables TEXT[];
BEGIN
  SELECT ARRAY_AGG(table_name)
  INTO missing_tables
  FROM (
    SELECT 'user_tokens' AS table_name
    UNION SELECT 'token_usage_history'
  ) expected
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = expected.table_name
  );

  IF array_length(missing_tables, 1) > 0 THEN
    RAISE EXCEPTION 'Migration failed: Missing tables: %', array_to_string(missing_tables, ', ');
  ELSE
    RAISE NOTICE '✅ Migration successful: All 2 token system tables created';
  END IF;
END $$;

-- Verify critical functions exist
DO $$
DECLARE
  missing_functions TEXT[];
BEGIN
  SELECT ARRAY_AGG(function_name)
  INTO missing_functions
  FROM (
    SELECT 'get_or_create_user_tokens' AS function_name
    UNION SELECT 'consume_user_tokens'
    UNION SELECT 'add_purchased_tokens'
    UNION SELECT 'record_token_usage'
    UNION SELECT 'get_user_token_usage_history'
  ) expected
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = expected.function_name
  );

  IF array_length(missing_functions, 1) > 0 THEN
    RAISE EXCEPTION 'Migration failed: Missing functions: %', array_to_string(missing_functions, ', ');
  ELSE
    RAISE NOTICE '✅ Migration successful: All 5 core token functions created';
  END IF;
END $$;

COMMIT;

-- =====================================================
-- Migration Complete: Token System
-- =====================================================
-- Tables created: 2
--   1. user_tokens (balance tracking per user per plan)
--   2. token_usage_history (consumption audit trail)
--
-- Functions created: 5
--   1. get_or_create_user_tokens() - Get/create with auto-reset (FIXED: NOT FOUND bug)
--   2. consume_user_tokens() - Atomic consumption with locking (FIXED: race conditions)
--   3. add_purchased_tokens() - Add purchased tokens to balance
--   4. record_token_usage() - Record consumption in history
--   5. get_user_token_usage_history() - Query paginated history
--
-- Features:
--   ✅ Daily token limits per plan (free: 8, standard: 20, plus: 50, premium: unlimited)
--   ✅ Purchased tokens never reset
--   ✅ Automatic daily reset at UTC midnight
--   ✅ Atomic token consumption with row-level locking
--   ✅ NOT FOUND bug fixed in get_or_create
--   ✅ Token breakdown in consumption response (daily vs purchased)
--   ✅ Comprehensive usage history tracking
--   ✅ RLS policies for security (service role access for history)
--   ✅ Performance-optimized indexes
--
-- Next: 0004_subscription_system.sql
-- =====================================================
