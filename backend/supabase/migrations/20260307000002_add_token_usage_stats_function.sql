-- =====================================================
-- Migration: Add get_user_token_usage_stats Function
-- =====================================================
-- Purpose: Aggregated token usage statistics for the Usage Summary
--          card in the token usage history page.
--
-- This function was missing from the initial token system migration,
-- causing the Usage Summary to show all zeros despite real usage data
-- existing in the token_usage_history table.
--
-- Called by: token-usage-history Edge Function (include_statistics=true)
-- Returns: Single-row table with aggregate stats + JSONB breakdown arrays
-- =====================================================

BEGIN;

-- =====================================================
-- FUNCTION: get_user_token_usage_stats
-- =====================================================
-- Returns a single-row result set with comprehensive usage statistics
-- for a user, optionally filtered by date range.
--
-- Parameters:
--   p_user_id    UUID        - User to query
--   p_start_date TIMESTAMPTZ - Optional start date filter (inclusive)
--   p_end_date   TIMESTAMPTZ - Optional end date filter (inclusive)
--
-- Returns columns matching the UsageStatistics TypeScript interface:
--   total_tokens, total_operations, daily_tokens_consumed,
--   purchased_tokens_consumed, most_used_feature, most_used_language,
--   most_used_mode, feature_breakdown (JSONB), language_breakdown (JSONB),
--   study_mode_breakdown (JSONB), first_usage_date, last_usage_date

CREATE OR REPLACE FUNCTION get_user_token_usage_stats(
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
BEGIN
  RETURN QUERY
  WITH filtered AS (
    SELECT
      tuh.token_cost,
      tuh.daily_tokens_used,
      tuh.purchased_tokens_used,
      tuh.feature_name,
      tuh.language,
      tuh.study_mode,
      tuh.created_at
    FROM token_usage_history tuh
    WHERE tuh.user_id = p_user_id
      AND (p_start_date IS NULL OR tuh.created_at >= p_start_date)
      AND (p_end_date IS NULL OR tuh.created_at <= p_end_date)
  ),
  aggregates AS (
    SELECT
      COALESCE(SUM(token_cost), 0)::BIGINT           AS total_tokens,
      COUNT(*)::BIGINT                                AS total_operations,
      COALESCE(SUM(daily_tokens_used), 0)::BIGINT    AS daily_tokens_consumed,
      COALESCE(SUM(purchased_tokens_used), 0)::BIGINT AS purchased_tokens_consumed,
      MIN(created_at)                                 AS first_usage_date,
      MAX(created_at)                                 AS last_usage_date
    FROM filtered
  ),
  feature_stats AS (
    SELECT
      feature_name,
      SUM(token_cost)::BIGINT AS token_count,
      COUNT(*)::BIGINT        AS operation_count
    FROM filtered
    GROUP BY feature_name
    ORDER BY operation_count DESC
  ),
  language_stats AS (
    SELECT
      language,
      SUM(token_cost)::BIGINT AS token_count
    FROM filtered
    GROUP BY language
    ORDER BY token_count DESC
  ),
  mode_stats AS (
    SELECT
      study_mode,
      SUM(token_cost)::BIGINT AS token_count
    FROM filtered
    WHERE study_mode IS NOT NULL
    GROUP BY study_mode
    ORDER BY token_count DESC
  )
  SELECT
    a.total_tokens,
    a.total_operations,
    a.daily_tokens_consumed,
    a.purchased_tokens_consumed,
    (SELECT feature_name FROM feature_stats LIMIT 1),
    (SELECT language     FROM language_stats LIMIT 1),
    (SELECT study_mode   FROM mode_stats LIMIT 1),
    COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object(
          'feature_name',   fs.feature_name,
          'token_count',    fs.token_count,
          'operation_count', fs.operation_count
        )
      ) FROM feature_stats fs),
      '[]'::JSONB
    ),
    COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object('language', ls.language, 'token_count', ls.token_count)
      ) FROM language_stats ls),
      '[]'::JSONB
    ),
    COALESCE(
      (SELECT jsonb_agg(
        jsonb_build_object('study_mode', ms.study_mode, 'token_count', ms.token_count)
      ) FROM mode_stats ms),
      '[]'::JSONB
    ),
    a.first_usage_date,
    a.last_usage_date
  FROM aggregates a;
END;
$$;

COMMENT ON FUNCTION get_user_token_usage_stats(UUID, TIMESTAMPTZ, TIMESTAMPTZ) IS
  'Aggregated token usage statistics for a user with optional date range filter.
   Returns a single row with totals, most-used breakdowns, and JSONB arrays
   for feature/language/study-mode distributions.
   Called by the token-usage-history Edge Function when include_statistics=true.';

-- Grant execute permission to authenticated users (called via service role in Edge Functions)
GRANT EXECUTE ON FUNCTION get_user_token_usage_stats(UUID, TIMESTAMPTZ, TIMESTAMPTZ)
  TO authenticated, service_role;

COMMIT;

-- =====================================================
-- Migration Complete
-- =====================================================
-- ✅ Function: get_user_token_usage_stats
-- ✅ Permissions: authenticated + service_role
-- =====================================================
