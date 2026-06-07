-- =====================================================
-- Create rate_limit_usage table + increment RPC
-- =====================================================
-- Fixes CRITICAL: RateLimiter (_shared/services/rate-limiter.ts) queries the
-- `rate_limit_usage` table and calls the `increment_rate_limit_usage` RPC, but
-- neither existed in any migration. Every lookup hit the fail-open catch block
-- (returning 0 usage), so enforceRateLimit() never blocked anyone — payment and
-- subscription endpoints (create-subscription, purchase-tokens, etc.) had no
-- effective rate limiting.
--
-- Schema matches exactly what the service reads/writes:
--   - getUsageFromRateLimitTable(): SELECT count WHERE identifier, user_type, window_start
--   - incrementUsageInRateLimitTable(): RPC increment_rate_limit_usage(p_identifier, p_user_type, p_window_start)
--   - resetRateLimitInTable(): DELETE WHERE identifier, user_type

CREATE TABLE IF NOT EXISTS rate_limit_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier TEXT NOT NULL,
  user_type TEXT NOT NULL CHECK (user_type IN ('anonymous', 'authenticated')),
  window_start TIMESTAMPTZ NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- One row per (identifier, user_type, window_start) — required for atomic upsert
  CONSTRAINT rate_limit_usage_unique UNIQUE (identifier, user_type, window_start)
);

-- Lookup index for the SELECT in getUsageFromRateLimitTable()
CREATE INDEX IF NOT EXISTS idx_rate_limit_usage_lookup
  ON rate_limit_usage (identifier, user_type, window_start);

-- Cleanup index for purging expired windows
CREATE INDEX IF NOT EXISTS idx_rate_limit_usage_window_start
  ON rate_limit_usage (window_start);

COMMENT ON TABLE rate_limit_usage IS
  'Per-identifier request counters used by RateLimiter for fixed-window rate limiting (anonymous: 8h windows, authenticated: 1h windows).';

-- =====================================================
-- Atomic increment function
-- =====================================================
-- Inserts a new window row at count=1, or atomically increments an existing one.
-- Uses INSERT ... ON CONFLICT to avoid read-modify-write races across concurrent
-- Edge Function invocations.
CREATE OR REPLACE FUNCTION increment_rate_limit_usage(
  p_identifier TEXT,
  p_user_type TEXT,
  p_window_start TIMESTAMPTZ
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  INSERT INTO rate_limit_usage (identifier, user_type, window_start, count)
  VALUES (p_identifier, p_user_type, p_window_start, 1)
  ON CONFLICT (identifier, user_type, window_start)
  DO UPDATE SET
    count = rate_limit_usage.count + 1,
    updated_at = NOW()
  RETURNING count INTO v_count;

  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION increment_rate_limit_usage(TEXT, TEXT, TIMESTAMPTZ) IS
  'Atomically increments (or initializes) the request counter for a rate-limit window. Returns the new count.';

-- =====================================================
-- RLS + grants
-- =====================================================
-- Rate-limit counters are server-only state. Edge Functions touch this table via
-- the service-role client (which bypasses RLS). Enable RLS with no permissive
-- policy so anon/authenticated cannot read or tamper with counters.
ALTER TABLE rate_limit_usage ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON rate_limit_usage FROM anon, authenticated;
GRANT ALL ON rate_limit_usage TO service_role;

-- Only the service role may call the increment RPC.
REVOKE ALL ON FUNCTION increment_rate_limit_usage(TEXT, TEXT, TIMESTAMPTZ) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION increment_rate_limit_usage(TEXT, TEXT, TIMESTAMPTZ) TO service_role;
