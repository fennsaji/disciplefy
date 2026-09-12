-- The USD→INR rate was hardcoded at 83.5 in four places and had gone badly stale.
--
-- Two TypeScript services, this SQL function, and a fallback in the P&L endpoint
-- each carried their own copy of the rate — 83.5, or 84.0 in the P&L fallback —
-- with a comment saying "update periodically". The rupee has since passed 95, so
-- every INR figure in the dashboard understated cost by more than a tenth, and
-- correcting it meant editing four files, a migration and a deploy.
--
-- The rate now lives in system_config beside the other money settings, editable
-- from the admin dashboard. This function reads it there; a missing or nonsense
-- row falls back to the same default the application code uses, so a bad edit
-- cannot make costs read as zero.
--
-- Note this only affects rows written from now on: estimated_revenue_inr and
-- profit_margin_inr are stamped at insert time, so historical rows keep the rate
-- that was in force when they were written. That is the honest behaviour — they
-- record what was believed then — and the P&L endpoint converts from
-- llm_cost_usd at the current rate anyway.

INSERT INTO public.system_config (key, value, description, is_active, metadata)
VALUES (
  'usd_to_inr_rate',
  '95.5',
  'USD to INR conversion rate for cost and profit reporting. Update when the rate moves materially.',
  true,
  '{"category": "billing", "unit": "INR per USD"}'::jsonb
)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION log_usage(
  p_user_id UUID,
  p_tier TEXT,
  p_feature_name TEXT,
  p_operation_type TEXT DEFAULT 'create',
  p_tokens_consumed INTEGER DEFAULT 0,
  p_llm_provider TEXT DEFAULT NULL,
  p_llm_model TEXT DEFAULT NULL,
  p_llm_input_tokens INTEGER DEFAULT NULL,
  p_llm_output_tokens INTEGER DEFAULT NULL,
  p_llm_cost_usd DECIMAL(10,6) DEFAULT NULL,
  p_request_metadata JSONB DEFAULT NULL,
  p_response_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_log_id UUID;
  v_revenue_allocation DECIMAL(10,2);
  v_cost_inr DECIMAL(10,2);
  v_profit_margin DECIMAL(10,2);
  v_usd_to_inr_rate DECIMAL(10,2);
BEGIN
  -- One source for the rate, with the same sanity band the application uses: a
  -- decimal point in the wrong place must not silently distort every margin.
  SELECT NULLIF(value, '')::NUMERIC
    INTO v_usd_to_inr_rate
    FROM public.system_config
   WHERE key = 'usd_to_inr_rate'
     AND is_active = true;

  IF v_usd_to_inr_rate IS NULL
     OR v_usd_to_inr_rate < 50
     OR v_usd_to_inr_rate > 200 THEN
    v_usd_to_inr_rate := 95.5;
  END IF;

  -- Calculate revenue allocation based on tier
  v_revenue_allocation := CASE p_tier
    WHEN 'free' THEN 0.00
    WHEN 'standard' THEN 0.79 -- ₹79/month / 100 operations
    WHEN 'plus' THEN 1.49 -- ₹149/month / 100 operations
    WHEN 'premium' THEN 4.99 -- ₹499/month / 100 operations
    ELSE 0.00
  END;

  -- Convert USD cost to INR
  v_cost_inr := COALESCE(p_llm_cost_usd, 0) * v_usd_to_inr_rate;

  -- Calculate profit margin
  v_profit_margin := v_revenue_allocation - v_cost_inr;

  -- Insert usage log
  INSERT INTO usage_logs (
    user_id,
    tier,
    feature_name,
    operation_type,
    tokens_consumed,
    llm_provider,
    llm_model,
    llm_input_tokens,
    llm_output_tokens,
    llm_cost_usd,
    request_metadata,
    response_metadata,
    estimated_revenue_inr,
    profit_margin_inr
  ) VALUES (
    p_user_id,
    p_tier,
    p_feature_name,
    p_operation_type,
    p_tokens_consumed,
    p_llm_provider,
    p_llm_model,
    p_llm_input_tokens,
    p_llm_output_tokens,
    p_llm_cost_usd,
    p_request_metadata,
    p_response_metadata,
    v_revenue_allocation,
    v_profit_margin
  ) RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION log_usage IS
  'Logs a usage operation with automatic profit margin calculation based on tier and LLM costs. The USD to INR rate is read from system_config.usd_to_inr_rate.';
