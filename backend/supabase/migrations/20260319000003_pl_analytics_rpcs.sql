-- backend/supabase/migrations/20260319000003_pl_analytics_rpcs.sql
-- Depends on: 20260318000002_usage_breakdown_rpcs.sql

-- Index for cash-basis revenue filter
CREATE INDEX IF NOT EXISTS idx_subscription_invoices_paid_at
  ON subscription_invoices(paid_at) WHERE status = 'paid';

-- ── get_pl_by_tier ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_pl_by_tier(
  p_start_date    TIMESTAMPTZ,
  p_end_date      TIMESTAMPTZ,
  p_exchange_rate NUMERIC
)
RETURNS TABLE (
  plan_code        TEXT,
  active_users     INT,
  revenue_inr      NUMERIC,
  llm_cost_inr     NUMERIC,
  gross_profit_inr NUMERIC,
  margin_pct       NUMERIC
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH tier_stats AS (
    SELECT
      sp.plan_code,
      COUNT(DISTINCT s.user_id)::INT                                          AS active_users,
      COALESCE(SUM(si.amount_paise) / 100.0, 0)                             AS revenue_inr,
      COALESCE(SUM(ul.llm_cost_usd) * p_exchange_rate, 0)                   AS llm_cost_inr,
      COALESCE(SUM(si.amount_paise) / 100.0, 0)
        - COALESCE(SUM(ul.llm_cost_usd) * p_exchange_rate, 0)               AS gross_profit_inr
    FROM subscriptions s
      JOIN subscription_plans sp ON s.plan_id = sp.id
      LEFT JOIN subscription_invoices si
        ON si.user_id = s.user_id
        AND si.status = 'paid'
        AND si.paid_at BETWEEN p_start_date AND p_end_date
      LEFT JOIN usage_logs ul
        ON ul.user_id = s.user_id
        AND ul.created_at BETWEEN p_start_date AND p_end_date
    WHERE s.status IN ('active', 'trial', 'in_progress', 'pending_cancellation', 'paused')
    GROUP BY sp.plan_code
  )
  SELECT
    ts.plan_code,
    ts.active_users,
    ts.revenue_inr,
    ts.llm_cost_inr,
    ts.gross_profit_inr,
    (ts.gross_profit_inr / NULLIF(ts.revenue_inr, 0)) * 100 AS margin_pct
  FROM tier_stats ts

  UNION ALL

  SELECT
    'total'::TEXT,
    SUM(ts.active_users)::INT,
    SUM(ts.revenue_inr),
    SUM(ts.llm_cost_inr),
    SUM(ts.gross_profit_inr),
    -- Blended margin across all tiers (free tier's zero revenue excluded by NULLIF)
    (SUM(ts.gross_profit_inr) / NULLIF(SUM(ts.revenue_inr), 0)) * 100
  FROM tier_stats ts;
END;
$$;

-- ── get_top_heavy_users ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_top_heavy_users(
  p_start_date    TIMESTAMPTZ,
  p_end_date      TIMESTAMPTZ,
  p_exchange_rate NUMERIC,
  p_limit         INT DEFAULT 10
)
RETURNS TABLE (
  rank          INT,
  user_id       UUID,
  email         TEXT,
  tier          TEXT,
  operations    INT,
  llm_cost_inr  NUMERIC,
  revenue_inr   NUMERIC,
  is_profitable BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH user_costs AS (
    SELECT
      ul.user_id,
      COUNT(*)::INT                                          AS operations,
      COALESCE(SUM(ul.llm_cost_usd) * p_exchange_rate, 0)  AS llm_cost_inr
    FROM usage_logs ul
    WHERE ul.created_at BETWEEN p_start_date AND p_end_date
      AND ul.user_id IS NOT NULL
    GROUP BY ul.user_id
  ),
  user_revenue AS (
    SELECT
      si.user_id,
      COALESCE(SUM(si.amount_paise) / 100.0, 0) AS revenue_inr
    FROM subscription_invoices si
    WHERE si.status = 'paid'
      AND si.paid_at BETWEEN p_start_date AND p_end_date
    GROUP BY si.user_id
  )
  SELECT
    ROW_NUMBER() OVER (ORDER BY uc.llm_cost_inr DESC)::INT AS rank,
    uc.user_id,
    au.email::TEXT,
    sp.plan_code                                             AS tier,
    uc.operations,
    uc.llm_cost_inr,
    COALESCE(ur.revenue_inr, 0)                             AS revenue_inr,
    COALESCE(ur.revenue_inr, 0) > COALESCE(uc.llm_cost_inr, 0) AS is_profitable
  FROM user_costs uc
    JOIN auth.users au ON au.id = uc.user_id
    JOIN subscriptions s ON s.user_id = uc.user_id AND s.status IN ('active', 'trial', 'in_progress', 'pending_cancellation', 'paused')
    JOIN subscription_plans sp ON sp.id = s.plan_id
    LEFT JOIN user_revenue ur ON ur.user_id = uc.user_id
  ORDER BY uc.llm_cost_inr DESC
  LIMIT p_limit;
END;
$$;
