-- Fix get_pl_by_tier to compute LLM costs from usage_logs.tier directly.
-- The previous version joined subscriptions → usage_logs which missed users
-- whose subscription status had changed, causing LLM costs to be understated.
-- usage_logs.tier is stamped at call time and is the correct source of truth.

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
  WITH
  -- LLM costs from usage_logs.tier — captures all operations regardless of
  -- current subscription status (tier is stamped at call time)
  tier_llm_costs AS (
    SELECT
      ul.tier                                                       AS plan_code,
      COALESCE(SUM(ul.llm_cost_usd) * p_exchange_rate, 0)         AS llm_cost_inr
    FROM usage_logs ul
    WHERE ul.created_at BETWEEN p_start_date AND p_end_date
      AND ul.user_id IS NOT NULL
      AND ul.tier IS NOT NULL
      AND ul.tier != 'system'
    GROUP BY ul.tier
  ),
  -- Active user counts from current subscription status
  tier_users AS (
    SELECT
      sp.plan_code,
      COUNT(DISTINCT s.user_id)::INT AS active_users
    FROM subscriptions s
      JOIN subscription_plans sp ON s.plan_id = sp.id
    WHERE s.status IN ('active', 'trial', 'in_progress', 'pending_cancellation', 'paused')
    GROUP BY sp.plan_code
  ),
  -- Cash-basis revenue from paid invoices in the period
  tier_revenue AS (
    SELECT
      sp.plan_code,
      COALESCE(SUM(si.amount_paise) / 100.0, 0) AS revenue_inr
    FROM subscription_invoices si
      JOIN subscriptions s  ON s.user_id  = si.user_id
      JOIN subscription_plans sp ON sp.id = s.plan_id
    WHERE si.status = 'paid'
      AND si.paid_at BETWEEN p_start_date AND p_end_date
    GROUP BY sp.plan_code
  ),
  -- Combine: FULL OUTER JOIN so tiers with cost but no active subscription
  -- (or vice versa) are still represented
  all_plans AS (
    SELECT COALESCE(tu.plan_code, lc.plan_code) AS plan_code
    FROM tier_users tu
    FULL OUTER JOIN tier_llm_costs lc ON lc.plan_code = tu.plan_code
  ),
  tier_stats AS (
    SELECT
      ap.plan_code,
      COALESCE(tu.active_users, 0)                                AS active_users,
      COALESCE(tr.revenue_inr,  0)                                AS revenue_inr,
      COALESCE(lc.llm_cost_inr, 0)                                AS llm_cost_inr,
      COALESCE(tr.revenue_inr,  0) - COALESCE(lc.llm_cost_inr, 0) AS gross_profit_inr
    FROM all_plans ap
    LEFT JOIN tier_users     tu ON tu.plan_code = ap.plan_code
    LEFT JOIN tier_llm_costs lc ON lc.plan_code = ap.plan_code
    LEFT JOIN tier_revenue   tr ON tr.plan_code = ap.plan_code
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
    (SUM(ts.gross_profit_inr) / NULLIF(SUM(ts.revenue_inr), 0)) * 100
  FROM tier_stats ts;
END;
$$;
