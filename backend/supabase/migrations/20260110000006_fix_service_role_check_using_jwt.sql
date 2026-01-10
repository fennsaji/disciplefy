-- ============================================================================
-- MIGRATION: Fix Service Role Detection Using JWT Claims
-- Date: 2026-01-10
-- Description: Use JWT claims to detect service_role instead of current_user
--
-- Issue: current_user in SECURITY DEFINER functions returns function owner,
--        not the caller. Need to check request.jwt.claims for role
--
-- Solution: Check current_setting('request.jwt.claims')::json->>'role' = 'service_role'
-- ============================================================================

BEGIN;

-- ============================================================================
-- Fix 1: Update get_user_token_usage_history() to check JWT role
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
DECLARE
  jwt_role TEXT;
BEGIN
  -- Get the role from JWT claims
  BEGIN
    jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
  EXCEPTION WHEN OTHERS THEN
    jwt_role := NULL;
  END;

  -- SECURITY: Verify caller is authorized to access this user's data
  -- Allow service_role (Edge Functions) OR authenticated user accessing own data
  IF jwt_role IS DISTINCT FROM 'service_role' AND (auth.uid() IS NULL OR auth.uid() <> p_user_id) THEN
    RAISE EXCEPTION 'Not authorized to access token usage history for this user'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

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
  'Retrieves paginated token usage history. Uses JWT role claim to allow service_role (Edge Functions) and authenticated users accessing own data.';

-- ============================================================================
-- Fix 2: Update get_user_token_usage_stats() to check JWT role
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
  jwt_role TEXT;
  v_total_tokens BIGINT;
  v_total_operations BIGINT;
  v_daily_consumed BIGINT;
  v_purchased_consumed BIGINT;
  v_most_used_feature TEXT;
  v_most_used_language TEXT;
  v_most_used_mode TEXT;
  v_feature_breakdown JSONB;
  v_language_breakdown JSONB;
  v_mode_breakdown JSONB;
  v_first_usage TIMESTAMPTZ;
  v_last_usage TIMESTAMPTZ;
BEGIN
  -- Get the role from JWT claims
  BEGIN
    jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
  EXCEPTION WHEN OTHERS THEN
    jwt_role := NULL;
  END;

  -- SECURITY: Verify caller is authorized to access this user's data
  -- Allow service_role (Edge Functions) OR authenticated user accessing own data
  IF jwt_role IS DISTINCT FROM 'service_role' AND (auth.uid() IS NULL OR auth.uid() <> p_user_id) THEN
    RAISE EXCEPTION 'Not authorized to access token usage statistics for this user'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- Get total tokens and operations
  SELECT
    COALESCE(SUM(token_cost), 0),
    COUNT(*)
  INTO v_total_tokens, v_total_operations
  FROM public.token_usage_history
  WHERE user_id = p_user_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  -- Get daily vs purchased token consumption
  SELECT
    COALESCE(SUM(daily_tokens_used), 0),
    COALESCE(SUM(purchased_tokens_used), 0)
  INTO v_daily_consumed, v_purchased_consumed
  FROM public.token_usage_history
  WHERE user_id = p_user_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  -- Get most used feature
  SELECT feature_name
  INTO v_most_used_feature
  FROM public.token_usage_history
  WHERE user_id = p_user_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date)
  GROUP BY feature_name
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  -- Get most used language
  SELECT language
  INTO v_most_used_language
  FROM public.token_usage_history
  WHERE user_id = p_user_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date)
  GROUP BY language
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  -- Get most used study mode
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

  -- Get feature breakdown
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'feature_name', feature_name,
        'token_count', token_count,
        'operation_count', operation_count
      )
      ORDER BY token_count DESC
    ),
    '[]'::jsonb
  )
  INTO v_feature_breakdown
  FROM (
    SELECT
      feature_name,
      SUM(token_cost) as token_count,
      COUNT(*) as operation_count
    FROM public.token_usage_history
    WHERE user_id = p_user_id
      AND (p_start_date IS NULL OR created_at >= p_start_date)
      AND (p_end_date IS NULL OR created_at <= p_end_date)
    GROUP BY feature_name
  ) features;

  -- Get language breakdown
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'language', language,
        'token_count', token_count
      )
      ORDER BY token_count DESC
    ),
    '[]'::jsonb
  )
  INTO v_language_breakdown
  FROM (
    SELECT
      language,
      SUM(token_cost) as token_count
    FROM public.token_usage_history
    WHERE user_id = p_user_id
      AND (p_start_date IS NULL OR created_at >= p_start_date)
      AND (p_end_date IS NULL OR created_at <= p_end_date)
    GROUP BY language
  ) languages;

  -- Get study mode breakdown
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'study_mode', study_mode,
        'token_count', token_count
      )
      ORDER BY token_count DESC
    ),
    '[]'::jsonb
  )
  INTO v_mode_breakdown
  FROM (
    SELECT
      study_mode,
      SUM(token_cost) as token_count
    FROM public.token_usage_history
    WHERE user_id = p_user_id
      AND study_mode IS NOT NULL
      AND (p_start_date IS NULL OR created_at >= p_start_date)
      AND (p_end_date IS NULL OR created_at <= p_end_date)
    GROUP BY study_mode
  ) modes;

  -- Get first and last usage dates
  SELECT MIN(created_at), MAX(created_at)
  INTO v_first_usage, v_last_usage
  FROM public.token_usage_history
  WHERE user_id = p_user_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  -- Return aggregated statistics
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
    v_mode_breakdown,
    v_first_usage,
    v_last_usage;
END;
$$;

COMMENT ON FUNCTION public.get_user_token_usage_stats IS
  'Retrieves aggregate token usage statistics. Uses JWT role claim to allow service_role (Edge Functions) and authenticated users accessing own data.';

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Token usage functions updated to use JWT role claim';
  RAISE NOTICE '✅ Service role detection now works correctly in Edge Functions';
  RAISE NOTICE '🎉 JWT-based authorization fix completed successfully!';
END $$;

COMMIT;
