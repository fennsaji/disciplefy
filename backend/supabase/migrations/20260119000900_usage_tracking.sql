-- =====================================================
-- Consolidated Migration: Usage Tracking & Analytics
-- =====================================================
-- Source: 20260117000002_create_usage_logs_system.sql (comprehensive)
-- Tables: 4 (usage_logs, llm_api_costs, rate_limit_rules, usage_alerts)
-- Description: Centralized usage tracking, cost attribution, profitability
--              analysis, and rate limiting system with admin analytics
-- =====================================================

-- Dependencies: 0001_core_schema.sql (user_profiles, auth.users)

BEGIN;

-- =====================================================
-- SUMMARY: Migration creates comprehensive usage tracking
-- Features: Cost tracking, profitability analysis, rate limiting,
--           anomaly detection, admin analytics
-- =====================================================


-- ========================================
-- TABLE 1: usage_logs (Centralized Logging)
-- ========================================
CREATE TABLE IF NOT EXISTS usage_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- User Context
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id TEXT,
  tier TEXT NOT NULL, -- free, standard, plus, premium

  -- Feature Identification
  feature_name TEXT NOT NULL, -- study_generate, follow_up, voice_conversation, memory_practice, subscription_change, etc.
  operation_type TEXT NOT NULL, -- create, read, update, delete, consume

  -- Usage Details
  tokens_consumed INTEGER DEFAULT 0,
  llm_provider TEXT, -- openai, anthropic, elevenlabs
  llm_model TEXT, -- gpt-3.5-turbo, claude-haiku-3, etc.
  llm_input_tokens INTEGER,
  llm_output_tokens INTEGER,
  llm_cost_usd DECIMAL(10,6), -- Actual LLM API cost in USD

  -- Request Metadata
  request_metadata JSONB, -- language, study_mode, content_type, etc.
  response_metadata JSONB, -- cache_hit, latency_ms, success, error_code

  -- Cost Attribution
  estimated_revenue_inr DECIMAL(10,2), -- Allocated revenue from subscription
  profit_margin_inr DECIMAL(10,2), -- Revenue - Cost

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_usage_logs_user_date ON usage_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_usage_logs_feature ON usage_logs(feature_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_usage_logs_tier ON usage_logs(tier, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_usage_logs_cost ON usage_logs(llm_cost_usd DESC) WHERE llm_cost_usd > 0;
CREATE INDEX IF NOT EXISTS idx_usage_logs_profitable ON usage_logs(profit_margin_inr DESC);

-- Enable Row Level Security
ALTER TABLE usage_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only view their own logs
CREATE POLICY usage_logs_user_policy ON usage_logs
  FOR SELECT USING (auth.uid() = user_id);

-- RLS Policy: Service role can manage all logs
CREATE POLICY usage_logs_service_policy ON usage_logs
  FOR ALL USING (auth.role() = 'service_role');

-- RLS Policy: Admin users can view all logs
CREATE POLICY usage_logs_admin_policy ON usage_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

COMMENT ON TABLE usage_logs IS
  'Centralized logging for ALL operations (token-based + non-token) with cost attribution and profitability tracking';

-- ========================================
-- TABLE 2: llm_api_costs (LLM Provider Costs)
-- ========================================
CREATE TABLE IF NOT EXISTS llm_api_costs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operation_id UUID REFERENCES usage_logs(id) ON DELETE SET NULL,
  provider TEXT NOT NULL, -- openai, anthropic, elevenlabs
  model TEXT NOT NULL, -- gpt-3.5-turbo, claude-haiku-3, etc.
  input_tokens INTEGER,
  output_tokens INTEGER,
  cost_usd DECIMAL(10,6),
  request_id TEXT, -- Provider request ID for reconciliation
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for cost reconciliation
CREATE INDEX IF NOT EXISTS idx_llm_api_costs_operation ON llm_api_costs(operation_id);
CREATE INDEX IF NOT EXISTS idx_llm_api_costs_provider ON llm_api_costs(provider, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_llm_api_costs_request ON llm_api_costs(request_id);

-- Enable Row Level Security
ALTER TABLE llm_api_costs ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Service role only
CREATE POLICY llm_api_costs_service_policy ON llm_api_costs
  FOR ALL USING (auth.role() = 'service_role');

-- RLS Policy: Admin users can view
CREATE POLICY llm_api_costs_admin_policy ON llm_api_costs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

COMMENT ON TABLE llm_api_costs IS
  'Tracks actual LLM provider costs (OpenAI, Anthropic, ElevenLabs) for profitability analysis';

-- ========================================
-- TABLE 3: rate_limit_rules (Feature-Specific Limits)
-- ========================================
CREATE TABLE IF NOT EXISTS rate_limit_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_name TEXT NOT NULL,
  tier TEXT NOT NULL, -- free, standard, plus, premium
  max_requests_per_hour INTEGER,
  max_requests_per_day INTEGER,
  max_cost_per_day_usd DECIMAL(10,2),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Ensure one rule per feature per tier
  CONSTRAINT rate_limit_rules_unique UNIQUE(feature_name, tier)
);

-- Index for active rule lookups
CREATE INDEX IF NOT EXISTS idx_rate_limit_rules_active ON rate_limit_rules(feature_name, tier) WHERE is_active = true;

-- Enable Row Level Security
ALTER TABLE rate_limit_rules ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Everyone can read active rules
CREATE POLICY rate_limit_rules_read_policy ON rate_limit_rules
  FOR SELECT USING (is_active = true);

-- RLS Policy: Service role can manage
CREATE POLICY rate_limit_rules_service_policy ON rate_limit_rules
  FOR ALL USING (auth.role() = 'service_role');

-- RLS Policy: Admin users can manage
CREATE POLICY rate_limit_rules_admin_policy ON rate_limit_rules
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

COMMENT ON TABLE rate_limit_rules IS
  'Defines tier-based rate limits per feature for abuse prevention';

-- ========================================
-- TABLE 4: usage_alerts (Alert Configuration)
-- ========================================
CREATE TABLE IF NOT EXISTS usage_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alert_type TEXT NOT NULL, -- cost_spike, usage_anomaly, rate_limit_exceeded, negative_profitability
  threshold_value DECIMAL(10,2),
  notification_channel TEXT, -- email, slack, database
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for active alert lookups
CREATE INDEX IF NOT EXISTS idx_usage_alerts_active ON usage_alerts(alert_type) WHERE is_active = true;

-- Enable Row Level Security
ALTER TABLE usage_alerts ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Service role can manage
CREATE POLICY usage_alerts_service_policy ON usage_alerts
  FOR ALL USING (auth.role() = 'service_role');

-- RLS Policy: Admin users can manage
CREATE POLICY usage_alerts_admin_policy ON usage_alerts
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.is_admin = true
    )
  );

COMMENT ON TABLE usage_alerts IS
  'Configuration for usage monitoring alerts (cost spikes, anomalies, profitability)';

-- ========================================
-- RPC FUNCTION 1: log_usage
-- ========================================
CREATE OR REPLACE FUNCTION log_usage(
  p_user_id UUID,
  p_tier TEXT,
  p_feature_name TEXT,
  p_operation_type TEXT,
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
  v_usd_to_inr_rate DECIMAL(10,2) := 83.5; -- Update periodically
BEGIN
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
  'Logs a usage operation with automatic profit margin calculation based on tier and LLM costs';

-- ========================================
-- RPC FUNCTION 2: get_usage_stats
-- ========================================
CREATE OR REPLACE FUNCTION get_usage_stats(
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ,
  p_tier TEXT DEFAULT NULL,
  p_feature_name TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  v_stats JSONB;
BEGIN
  SELECT jsonb_build_object(
    'total_operations', COUNT(*),
    'total_cost_usd', COALESCE(SUM(llm_cost_usd), 0),
    'total_revenue_inr', COALESCE(SUM(estimated_revenue_inr), 0),
    'total_profit_margin_inr', COALESCE(SUM(profit_margin_inr), 0),
    'avg_cost_usd', COALESCE(AVG(llm_cost_usd), 0),
    'avg_revenue_inr', COALESCE(AVG(estimated_revenue_inr), 0),
    'avg_profit_margin_inr', COALESCE(AVG(profit_margin_inr), 0),
    'unique_users', COUNT(DISTINCT user_id)
  )
  INTO v_stats
  FROM usage_logs
  WHERE created_at BETWEEN p_start_date AND p_end_date
    AND (p_tier IS NULL OR tier = p_tier)
    AND (p_feature_name IS NULL OR feature_name = p_feature_name);

  RETURN v_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_usage_stats IS
  'Aggregate usage statistics by date range, tier, and feature';

-- ========================================
-- RPC FUNCTION 3: get_profitability_report
-- ========================================
CREATE OR REPLACE FUNCTION get_profitability_report(
  p_tier TEXT,
  p_feature_name TEXT
) RETURNS JSONB AS $$
DECLARE
  v_report JSONB;
  v_total_ops INTEGER;
  v_avg_cost DECIMAL(10,6);
  v_avg_revenue DECIMAL(10,2);
  v_avg_profit DECIMAL(10,2);
  v_profitability_score DECIMAL(10,2);
BEGIN
  -- Calculate aggregates
  SELECT
    COUNT(*),
    COALESCE(AVG(llm_cost_usd), 0),
    COALESCE(AVG(estimated_revenue_inr), 0),
    COALESCE(AVG(profit_margin_inr), 0)
  INTO v_total_ops, v_avg_cost, v_avg_revenue, v_avg_profit
  FROM usage_logs
  WHERE tier = p_tier
    AND feature_name = p_feature_name
    AND created_at >= NOW() - INTERVAL '30 days';

  -- Calculate profitability score (profit/cost as percentage)
  v_profitability_score := CASE
    WHEN v_avg_revenue > 0 THEN (v_avg_profit / v_avg_revenue) * 100
    ELSE 0
  END;

  -- Build report
  v_report := jsonb_build_object(
    'tier', p_tier,
    'feature', p_feature_name,
    'total_operations', v_total_ops,
    'avg_llm_cost_usd', v_avg_cost,
    'avg_allocated_revenue_inr', v_avg_revenue,
    'avg_profit_margin_inr', v_avg_profit,
    'profitability_score', v_profitability_score,
    'recommendations', CASE
      WHEN v_avg_profit < 0 THEN jsonb_build_array(
        'Increase token cost',
        'Optimize LLM model usage',
        'Consider subscription price adjustment'
      )
      WHEN v_avg_profit < v_avg_revenue * 0.2 THEN jsonb_build_array(
        'Profit margin below 20%',
        'Review LLM provider costs',
        'Consider tier feature restrictions'
      )
      ELSE jsonb_build_array(
        'Healthy profit margins',
        'Continue monitoring trends'
      )
    END
  );

  RETURN v_report;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_profitability_report IS
  'Detailed profitability analysis per tier and feature with recommendations';

-- ========================================
-- RPC FUNCTION 4: detect_usage_anomalies
-- ========================================
CREATE OR REPLACE FUNCTION detect_usage_anomalies(
  p_threshold_multiplier DECIMAL DEFAULT 3.0
) RETURNS TABLE(
  user_id UUID,
  tier TEXT,
  feature_name TEXT,
  recent_usage_count BIGINT,
  avg_usage_count DECIMAL,
  anomaly_factor DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  WITH recent_usage AS (
    SELECT
      ul.user_id,
      ul.tier,
      ul.feature_name,
      COUNT(*) as usage_count
    FROM usage_logs ul
    WHERE ul.created_at >= NOW() - INTERVAL '24 hours'
    GROUP BY ul.user_id, ul.tier, ul.feature_name
  ),
  avg_usage AS (
    SELECT
      ul.tier,
      ul.feature_name,
      AVG(daily_count) as avg_daily_count
    FROM (
      SELECT
        tier,
        feature_name,
        DATE(created_at) as usage_date,
        COUNT(*) as daily_count
      FROM usage_logs
      WHERE created_at >= NOW() - INTERVAL '30 days'
        AND created_at < NOW() - INTERVAL '1 day' -- Exclude today
      GROUP BY tier, feature_name, DATE(created_at)
    ) ul
    GROUP BY ul.tier, ul.feature_name
  )
  SELECT
    ru.user_id,
    ru.tier,
    ru.feature_name,
    ru.usage_count as recent_usage_count,
    au.avg_daily_count as avg_usage_count,
    ROUND((ru.usage_count::DECIMAL / NULLIF(au.avg_daily_count, 0))::NUMERIC, 2) as anomaly_factor
  FROM recent_usage ru
  INNER JOIN avg_usage au
    ON ru.tier = au.tier
    AND ru.feature_name = au.feature_name
  WHERE ru.usage_count > (au.avg_daily_count * p_threshold_multiplier)
  ORDER BY anomaly_factor DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION detect_usage_anomalies IS
  'Detects users with usage patterns significantly above average (default 3x threshold)';

-- ========================================
-- RPC FUNCTION 5: calculate_user_profitability
-- ========================================
CREATE OR REPLACE FUNCTION calculate_user_profitability(
  p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_profitability JSONB;
  v_tier TEXT;
  v_lifetime_ops INTEGER;
  v_lifetime_cost DECIMAL(10,6);
  v_lifetime_revenue DECIMAL(10,2);
  v_lifetime_profit DECIMAL(10,2);
  v_avg_monthly_ops DECIMAL(10,2);
  v_first_operation TIMESTAMPTZ;
  v_months_active INTEGER;
BEGIN
  -- Get user's current tier
  SELECT tier INTO v_tier
  FROM usage_logs
  WHERE user_id = p_user_id
  ORDER BY created_at DESC
  LIMIT 1;

  -- Get first operation date
  SELECT MIN(created_at) INTO v_first_operation
  FROM usage_logs
  WHERE user_id = p_user_id;

  -- Calculate months active (minimum 1)
  v_months_active := GREATEST(
    1,
    EXTRACT(MONTH FROM AGE(NOW(), v_first_operation))::INTEGER
  );

  -- Calculate lifetime metrics
  SELECT
    COUNT(*),
    COALESCE(SUM(llm_cost_usd), 0),
    COALESCE(SUM(estimated_revenue_inr), 0),
    COALESCE(SUM(profit_margin_inr), 0)
  INTO v_lifetime_ops, v_lifetime_cost, v_lifetime_revenue, v_lifetime_profit
  FROM usage_logs
  WHERE user_id = p_user_id;

  -- Calculate average monthly operations
  v_avg_monthly_ops := ROUND((v_lifetime_ops::DECIMAL / v_months_active)::NUMERIC, 2);

  -- Build profitability report
  v_profitability := jsonb_build_object(
    'user_id', p_user_id,
    'tier', COALESCE(v_tier, 'unknown'),
    'lifetime_operations', v_lifetime_ops,
    'lifetime_cost_usd', v_lifetime_cost,
    'lifetime_revenue_inr', v_lifetime_revenue,
    'lifetime_profit_inr', v_lifetime_profit,
    'profitability_status', CASE
      WHEN v_lifetime_profit > 0 THEN 'profit'
      WHEN v_lifetime_profit = 0 THEN 'break_even'
      ELSE 'loss'
    END,
    'avg_operations_per_month', v_avg_monthly_ops,
    'months_active', v_months_active,
    'first_operation_date', v_first_operation
  );

  RETURN v_profitability;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION calculate_user_profitability IS
  'Calculates lifetime profitability metrics for a specific user';

-- ========================================
-- GRANT PERMISSIONS
-- ========================================

-- Grant execute permissions on RPC functions
GRANT EXECUTE ON FUNCTION log_usage TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_usage_stats TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_profitability_report TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION detect_usage_anomalies TO service_role;
GRANT EXECUTE ON FUNCTION calculate_user_profitability TO authenticated, service_role;

-- ========================================
-- DEFAULT RATE LIMIT RULES
-- ========================================

-- Insert default rate limit rules for each tier and common features
INSERT INTO rate_limit_rules (feature_name, tier, max_requests_per_hour, max_requests_per_day, max_cost_per_day_usd)
VALUES
  -- Study Generate
  ('study_generate', 'free', 5, 10, 0.50),
  ('study_generate', 'standard', 20, 50, 2.00),
  ('study_generate', 'plus', 50, 150, 5.00),
  ('study_generate', 'premium', 200, 500, 20.00),

  -- Follow-up Questions
  ('study_followup', 'free', 0, 0, 0.00),
  ('study_followup', 'standard', 10, 25, 1.00),
  ('study_followup', 'plus', 30, 75, 2.50),
  ('study_followup', 'premium', 100, 250, 10.00),

  -- Voice Conversations
  ('voice_conversation', 'free', 1, 1, 0.10),
  ('voice_conversation', 'standard', 3, 3, 0.50),
  ('voice_conversation', 'plus', 10, 10, 2.00),
  ('voice_conversation', 'premium', 50, 50, 10.00)
ON CONFLICT (feature_name, tier) DO NOTHING;

-- ========================================
-- DEFAULT ALERT CONFIGURATION
-- ========================================

-- Insert default alert rules
INSERT INTO usage_alerts (alert_type, threshold_value, notification_channel)
VALUES
  ('cost_spike', 50.00, 'email'), -- $50/hour from single user
  ('usage_anomaly', 5.00, 'email'), -- 5x average daily operations
  ('rate_limit_exceeded', 1000.00, 'database'), -- >1000 requests/hour
  ('negative_profitability', -500.00, 'email') -- Users with <-₹500 lifetime profit
ON CONFLICT DO NOTHING;

COMMIT;

-- ========================================
-- MIGRATION COMPLETE
-- ========================================
-- ✅ 4 tables: usage_logs, llm_api_costs, rate_limit_rules, usage_alerts
-- ✅ 5 RPC functions: log_usage, get_usage_stats, get_profitability_report,
--                     detect_usage_anomalies, calculate_user_profitability
-- ✅ RLS policies for security
-- ✅ Indexes for performance
-- ✅ Default rate limit rules
-- ✅ Default alert configuration
