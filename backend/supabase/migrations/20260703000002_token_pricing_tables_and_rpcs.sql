-- Token pricing tables and RPCs.
-- Provides server-side authoritative pricing so the backend never trusts client-supplied prices.
-- Previously get-token-pricing always returned hardcoded fallback; calculateCostInRupees
-- fell back to flat rate, meaning package discounts never applied server-side.

-- ─── Tables ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS token_pricing_config (
  id            SERIAL PRIMARY KEY,
  region        TEXT NOT NULL DEFAULT 'IN',
  tokens_per_rupee NUMERIC(10,4) NOT NULL DEFAULT 2,
  effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS token_packages (
  id                  SERIAL PRIMARY KEY,
  region              TEXT NOT NULL DEFAULT 'IN',
  tokens              INTEGER NOT NULL,
  base_price_rupees   NUMERIC(10,2) NOT NULL,
  discount_percentage NUMERIC(5,2) NOT NULL DEFAULT 0,
  is_popular          BOOLEAN NOT NULL DEFAULT false,
  is_active           BOOLEAN NOT NULL DEFAULT true,
  sort_order          INTEGER NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT token_packages_tokens_positive CHECK (tokens > 0),
  CONSTRAINT token_packages_discount_range CHECK (discount_percentage >= 0 AND discount_percentage <= 100)
);

-- Seed default pricing (IN region) matching the existing hardcoded fallback
INSERT INTO token_pricing_config (region, tokens_per_rupee, is_active)
VALUES ('IN', 2, true)
ON CONFLICT DO NOTHING;

INSERT INTO token_packages (region, tokens, base_price_rupees, discount_percentage, is_popular, sort_order)
VALUES
  ('IN', 20,   10,  0,  false, 1),
  ('IN', 50,   25, 12,  false, 2),   -- ₹22 effective (advertised as 10%, actual ~12%)
  ('IN', 100,  50, 20,  true,  3),   -- ₹40 effective
  ('IN', 200, 100, 25,  false, 4),   -- ₹75 effective
  ('IN', 400, 200, 30,  false, 5),   -- ₹140 effective
  ('IN', 1000, 500, 40, false, 6)    -- ₹300 effective
ON CONFLICT DO NOTHING;

-- RLS: these are read-only reference tables; service role manages writes
ALTER TABLE token_pricing_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_packages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read token pricing" ON token_pricing_config
  FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can read token packages" ON token_packages
  FOR SELECT TO authenticated, anon USING (true);

-- ─── RPCs ──────────────────────────────────────────────────────────────────

-- Returns the current active pricing config for a region.
CREATE OR REPLACE FUNCTION get_current_token_pricing(p_region TEXT DEFAULT 'IN')
RETURNS TABLE (tokens_per_rupee NUMERIC, effective_from TIMESTAMPTZ)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT tokens_per_rupee, effective_from
  FROM token_pricing_config
  WHERE region = p_region
    AND is_active = true
  ORDER BY effective_from DESC
  LIMIT 1;
$$;

-- Returns all active token packages for a region.
CREATE OR REPLACE FUNCTION get_token_packages(p_region TEXT DEFAULT 'IN')
RETURNS TABLE (
  id                  INTEGER,
  tokens              INTEGER,
  rupees              NUMERIC,
  discount_percentage NUMERIC,
  is_popular          BOOLEAN,
  sort_order          INTEGER
)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT
    id,
    tokens,
    ROUND(base_price_rupees * (1 - discount_percentage / 100), 2) AS rupees,
    discount_percentage,
    is_popular,
    sort_order
  FROM token_packages
  WHERE region = p_region
    AND is_active = true
  ORDER BY sort_order;
$$;

-- Returns the discounted price for an exact token amount match.
-- Returns NULL if no package matches (caller falls back to flat rate).
CREATE OR REPLACE FUNCTION get_token_price(p_token_amount INTEGER, p_region TEXT DEFAULT 'IN')
RETURNS TABLE (discounted_price NUMERIC)
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT ROUND(base_price_rupees * (1 - discount_percentage / 100), 2) AS discounted_price
  FROM token_packages
  WHERE region = p_region
    AND tokens = p_token_amount
    AND is_active = true
  LIMIT 1;
$$;

-- Grant execute to authenticated users (read-only pricing data)
GRANT EXECUTE ON FUNCTION get_current_token_pricing(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_token_packages(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_token_price(INTEGER, TEXT) TO authenticated, anon;
