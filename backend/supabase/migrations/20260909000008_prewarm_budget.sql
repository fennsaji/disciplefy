-- A monthly budget for pre-warming, separate from the daily ceiling.
--
-- Pre-warming is planned spend: generating learning-path guides ahead of time,
-- on the Batch API at half price, so no reader ever waits for one and the
-- month's cost is known in advance. It is deliberately not governed by the
-- daily ceiling, which exists to catch runaway live traffic.
--
-- When the month's budget is spent the job stops and waits for the next month.
-- Whatever it did not reach stays uncached and is generated on demand, exactly
-- as it would have been anyway.

INSERT INTO public.system_config (key, value, description, is_active, metadata)
VALUES (
  'prewarm_monthly_budget_usd',
  '20',
  'Dollars a month for pre-generating learning-path study guides on the Batch API. The job stops when this is spent and resumes next month.',
  TRUE,
  jsonb_build_object('unit', 'usd', 'min', 0, 'editable_in_admin', true)
)
ON CONFLICT (key) DO UPDATE
  SET description = EXCLUDED.description,
      metadata    = EXCLUDED.metadata,
      is_active   = TRUE;

-- What pre-warming has spent this month. It writes usage_logs rows under the
-- 'prewarm' feature name, so its spend is visible on the LLM costs page beside
-- everything else and can be counted here without a second ledger.
CREATE OR REPLACE FUNCTION public.prewarm_spend_this_month()
RETURNS NUMERIC
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(llm_cost_usd), 0)::NUMERIC
    FROM usage_logs
   WHERE feature_name = 'prewarm'
     AND created_at >= date_trunc('month', now() AT TIME ZONE 'UTC');
$$;

GRANT EXECUTE ON FUNCTION public.prewarm_spend_this_month() TO service_role;
