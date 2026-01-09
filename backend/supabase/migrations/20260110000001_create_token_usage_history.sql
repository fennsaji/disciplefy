-- ============================================================================
-- MIGRATION: Create Token Usage History System
-- Date: 2026-01-10
-- Description: Creates comprehensive token usage tracking with analytics
--              - token_usage_history table for detailed consumption records
--              - Indexes for performance (user lookups, pagination, aggregations)
--              - RLS policies for security
--              - 3 RPC functions for recording and querying usage history
--
-- Security: Implements Row Level Security to ensure users only access own data
--           Service role bypasses RLS for Edge Function operations
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Create token_usage_history Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.token_usage_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token_cost INTEGER NOT NULL CHECK (token_cost > 0),
  feature_name TEXT NOT NULL CHECK (feature_name != ''),
  operation_type TEXT NOT NULL,
  study_mode TEXT CHECK (study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon')),
  language TEXT NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'hi', 'ml')),
  content_title TEXT,
  content_reference TEXT,
  input_type TEXT CHECK (input_type IN ('scripture', 'topic', 'question')),
  user_plan TEXT NOT NULL CHECK (user_plan IN ('free', 'standard', 'premium')),
  session_id TEXT,
  daily_tokens_used INTEGER NOT NULL DEFAULT 0 CHECK (daily_tokens_used >= 0),
  purchased_tokens_used INTEGER NOT NULL DEFAULT 0 CHECK (purchased_tokens_used >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comment to table
COMMENT ON TABLE public.token_usage_history IS
  'Records detailed token consumption history with feature, mode, language, and content context for analytics';

-- Add comments to columns
COMMENT ON COLUMN public.token_usage_history.feature_name IS
  'Feature that consumed tokens (e.g., study_generate, continue_learning, study_followup)';
COMMENT ON COLUMN public.token_usage_history.operation_type IS
  'Type of operation (e.g., study_generation, follow_up_question)';
COMMENT ON COLUMN public.token_usage_history.study_mode IS
  'Study mode if applicable: quick, standard, deep, lectio, sermon';
COMMENT ON COLUMN public.token_usage_history.content_title IS
  'User-friendly title of generated content (e.g., "John 3:16 Study")';
COMMENT ON COLUMN public.token_usage_history.content_reference IS
  'Scripture reference, topic name, or question text';
COMMENT ON COLUMN public.token_usage_history.daily_tokens_used IS
  'Tokens consumed from daily allocation';
COMMENT ON COLUMN public.token_usage_history.purchased_tokens_used IS
  'Tokens consumed from purchased balance';

-- ============================================================================
-- 2. Create Performance Indexes
-- ============================================================================

-- User lookup index (most common query pattern)
CREATE INDEX IF NOT EXISTS idx_token_usage_history_user_id
  ON public.token_usage_history(user_id);

-- Created date index for temporal queries
CREATE INDEX IF NOT EXISTS idx_token_usage_history_created_at
  ON public.token_usage_history(created_at DESC);

-- Composite index for paginated user queries (most efficient for usage history page)
CREATE INDEX IF NOT EXISTS idx_token_usage_history_user_date
  ON public.token_usage_history(user_id, created_at DESC);

-- Feature name index for aggregations and analytics
CREATE INDEX IF NOT EXISTS idx_token_usage_history_feature
  ON public.token_usage_history(feature_name);

-- ============================================================================
-- 3. Enable Row Level Security
-- ============================================================================

ALTER TABLE public.token_usage_history ENABLE ROW LEVEL SECURITY;

-- Policy: Users can SELECT their own usage history
CREATE POLICY "Users can view own token usage history"
  ON public.token_usage_history
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Service role can INSERT usage records (from Edge Functions)
CREATE POLICY "Service role can insert usage records"
  ON public.token_usage_history
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- Grant necessary permissions
GRANT SELECT ON public.token_usage_history TO authenticated;
GRANT INSERT ON public.token_usage_history TO service_role;

-- ============================================================================
-- 4. Function: record_token_usage()
-- ============================================================================

CREATE OR REPLACE FUNCTION public.record_token_usage(
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
    INSERT INTO public.token_usage_history (
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
    -- Log error but don't fail the transaction
    RAISE WARNING 'record_token_usage: Failed to record usage - %', SQLERRM;
    RETURN NULL;
  END;
END;
$$;

COMMENT ON FUNCTION public.record_token_usage IS
  'Records token usage with full context for analytics. Non-blocking - returns NULL on error without failing parent transaction.';

-- ============================================================================
-- 5. Function: get_user_token_usage_history()
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_token_usage_history(
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
  FROM public.token_usage_history tuh
  WHERE tuh.user_id = p_user_id
    AND (p_start_date IS NULL OR tuh.created_at >= p_start_date)
    AND (p_end_date IS NULL OR tuh.created_at <= p_end_date)
  ORDER BY tuh.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION public.get_user_token_usage_history IS
  'Retrieves paginated token usage history for a user with optional date filtering. Ordered by created_at DESC.';

-- ============================================================================
-- 6. Function: get_user_token_usage_stats()
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_token_usage_stats(
  p_user_id UUID,
  p_start_date TIMESTAMPTZ DEFAULT NULL,
  p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
  total_tokens BIGINT,
  total_operations BIGINT,
  daily_tokens_consumed BIGINT,
  purchased_tokens_consumed BIGINT,
  most_used_feature TEXT,
  most_used_language TEXT,
  most_used_mode TEXT,
  feature_breakdown JSONB,
  language_breakdown JSONB,
  study_mode_breakdown JSONB,
  first_usage_date TIMESTAMPTZ,
  last_usage_date TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_temp
AS $$
DECLARE
  v_total_tokens BIGINT;
  v_total_operations BIGINT;
  v_daily_consumed BIGINT;
  v_purchased_consumed BIGINT;
  v_most_used_feature TEXT;
  v_most_used_language TEXT;
  v_most_used_mode TEXT;
  v_feature_breakdown JSONB;
  v_language_breakdown JSONB;
  v_study_mode_breakdown JSONB;
  v_first_usage TIMESTAMPTZ;
  v_last_usage TIMESTAMPTZ;
BEGIN
  -- Calculate aggregate statistics
  SELECT
    COALESCE(SUM(token_cost), 0),
    COUNT(*),
    COALESCE(SUM(daily_tokens_used), 0),
    COALESCE(SUM(purchased_tokens_used), 0),
    MIN(created_at),
    MAX(created_at)
  INTO
    v_total_tokens,
    v_total_operations,
    v_daily_consumed,
    v_purchased_consumed,
    v_first_usage,
    v_last_usage
  FROM public.token_usage_history
  WHERE user_id = p_user_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  -- Find most used feature
  SELECT feature_name
  INTO v_most_used_feature
  FROM public.token_usage_history
  WHERE user_id = p_user_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date)
  GROUP BY feature_name
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  -- Find most used language
  SELECT language
  INTO v_most_used_language
  FROM public.token_usage_history
  WHERE user_id = p_user_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date)
  GROUP BY language
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  -- Find most used study mode
  SELECT study_mode
  INTO v_most_used_mode
  FROM public.token_usage_history
  WHERE user_id = p_user_id
    AND study_mode IS NOT NULL
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date)
  GROUP BY study_mode
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  -- Build feature breakdown (feature_name, token_count, operation_count)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'feature_name', feature_name,
      'token_count', token_count,
      'operation_count', operation_count
    )
  ), '[]'::jsonb)
  INTO v_feature_breakdown
  FROM (
    SELECT
      feature_name,
      SUM(token_cost)::INTEGER AS token_count,
      COUNT(*)::INTEGER AS operation_count
    FROM public.token_usage_history
    WHERE user_id = p_user_id
      AND (p_start_date IS NULL OR created_at >= p_start_date)
      AND (p_end_date IS NULL OR created_at <= p_end_date)
    GROUP BY feature_name
    ORDER BY token_count DESC
  ) feature_stats;

  -- Build language breakdown (language, token_count)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'language', language,
      'token_count', token_count
    )
  ), '[]'::jsonb)
  INTO v_language_breakdown
  FROM (
    SELECT
      language,
      SUM(token_cost)::INTEGER AS token_count
    FROM public.token_usage_history
    WHERE user_id = p_user_id
      AND (p_start_date IS NULL OR created_at >= p_start_date)
      AND (p_end_date IS NULL OR created_at <= p_end_date)
    GROUP BY language
    ORDER BY token_count DESC
  ) language_stats;

  -- Build study mode breakdown (study_mode, token_count)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'study_mode', study_mode,
      'token_count', token_count
    )
  ), '[]'::jsonb)
  INTO v_study_mode_breakdown
  FROM (
    SELECT
      study_mode,
      SUM(token_cost)::INTEGER AS token_count
    FROM public.token_usage_history
    WHERE user_id = p_user_id
      AND study_mode IS NOT NULL
      AND (p_start_date IS NULL OR created_at >= p_start_date)
      AND (p_end_date IS NULL OR created_at <= p_end_date)
    GROUP BY study_mode
    ORDER BY token_count DESC
  ) mode_stats;

  -- Return single row with all statistics
  RETURN QUERY
  SELECT
    v_total_tokens,
    v_total_operations,
    v_daily_consumed,
    v_purchased_consumed,
    v_most_used_feature,
    v_most_used_language,
    v_most_used_mode,
    v_feature_breakdown,
    v_language_breakdown,
    v_study_mode_breakdown,
    v_first_usage,
    v_last_usage;
END;
$$;

COMMENT ON FUNCTION public.get_user_token_usage_stats IS
  'Returns aggregated token usage statistics with feature, language, and study mode breakdowns. Supports date filtering.';

-- ============================================================================
-- 7. Verification
-- ============================================================================

DO $$
BEGIN
  -- Verify table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'token_usage_history') THEN
    RAISE NOTICE '✅ Table token_usage_history created successfully';
  ELSE
    RAISE WARNING '❌ Table token_usage_history was not created';
  END IF;

  -- Verify indexes
  IF (SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'token_usage_history') >= 4 THEN
    RAISE NOTICE '✅ All 4 indexes created successfully';
  ELSE
    RAISE WARNING '❌ Some indexes missing for token_usage_history';
  END IF;

  -- Verify RLS enabled
  IF (SELECT relrowsecurity FROM pg_class WHERE relname = 'token_usage_history') THEN
    RAISE NOTICE '✅ Row Level Security enabled';
  ELSE
    RAISE WARNING '❌ Row Level Security not enabled';
  END IF;

  -- Verify functions exist
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'record_token_usage') THEN
    RAISE NOTICE '✅ Function record_token_usage created';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_user_token_usage_history') THEN
    RAISE NOTICE '✅ Function get_user_token_usage_history created';
  END IF;

  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_user_token_usage_stats') THEN
    RAISE NOTICE '✅ Function get_user_token_usage_stats created';
  END IF;

  RAISE NOTICE '🎉 Token Usage History migration completed successfully!';
END $$;

COMMIT;
