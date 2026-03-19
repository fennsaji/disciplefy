-- =====================================================
-- Migration: Usage Breakdown RPC Functions
-- Provides language, study mode, and cross-breakdown
-- aggregates from usage_logs.request_metadata JSONB
-- =====================================================

BEGIN;

-- =====================================================
-- RPC 1: Language breakdown for study_generate operations
-- =====================================================
CREATE OR REPLACE FUNCTION get_language_breakdown(
  p_start_date timestamptz,
  p_end_date timestamptz
)
RETURNS TABLE(
  language text,
  operations bigint,
  cost_usd numeric,
  avg_cost_per_operation numeric,
  input_tokens bigint,
  output_tokens bigint
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    request_metadata->>'language',
    COUNT(*),
    COALESCE(SUM(llm_cost_usd), 0),
    COALESCE(AVG(llm_cost_usd), 0),
    COALESCE(SUM(llm_input_tokens), 0),
    COALESCE(SUM(llm_output_tokens), 0)
  FROM usage_logs
  WHERE created_at BETWEEN p_start_date AND p_end_date
    AND feature_name = 'study_generate'
    AND request_metadata->>'language' IS NOT NULL
  GROUP BY request_metadata->>'language'
  ORDER BY SUM(llm_cost_usd) DESC NULLS LAST;
$$;

-- =====================================================
-- RPC 2: Study mode breakdown for study_generate operations
-- =====================================================
CREATE OR REPLACE FUNCTION get_study_mode_breakdown(
  p_start_date timestamptz,
  p_end_date timestamptz
)
RETURNS TABLE(
  study_mode text,
  operations bigint,
  cost_usd numeric,
  avg_cost_per_operation numeric,
  input_tokens bigint,
  output_tokens bigint
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    request_metadata->>'study_mode',
    COUNT(*),
    COALESCE(SUM(llm_cost_usd), 0),
    COALESCE(AVG(llm_cost_usd), 0),
    COALESCE(SUM(llm_input_tokens), 0),
    COALESCE(SUM(llm_output_tokens), 0)
  FROM usage_logs
  WHERE created_at BETWEEN p_start_date AND p_end_date
    AND feature_name = 'study_generate'
    AND request_metadata->>'study_mode' IS NOT NULL
  GROUP BY request_metadata->>'study_mode'
  ORDER BY SUM(llm_cost_usd) DESC NULLS LAST;
$$;

-- =====================================================
-- RPC 3: Language x Study Mode cross-breakdown
-- =====================================================
CREATE OR REPLACE FUNCTION get_language_study_mode_breakdown(
  p_start_date timestamptz,
  p_end_date timestamptz
)
RETURNS TABLE(
  language text,
  study_mode text,
  operations bigint,
  cost_usd numeric,
  avg_cost_per_operation numeric
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    request_metadata->>'language',
    request_metadata->>'study_mode',
    COUNT(*),
    COALESCE(SUM(llm_cost_usd), 0),
    COALESCE(AVG(llm_cost_usd), 0)
  FROM usage_logs
  WHERE created_at BETWEEN p_start_date AND p_end_date
    AND feature_name = 'study_generate'
    AND request_metadata->>'language' IS NOT NULL
    AND request_metadata->>'study_mode' IS NOT NULL
  GROUP BY request_metadata->>'language', request_metadata->>'study_mode'
  ORDER BY request_metadata->>'language', SUM(llm_cost_usd) DESC NULLS LAST;
$$;

COMMIT;
