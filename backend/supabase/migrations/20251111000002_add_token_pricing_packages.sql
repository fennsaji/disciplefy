-- Migration: Add token pricing packages with discount tiers
-- Created: 2025-11-11
-- Purpose: Implement official pricing tiers with discounts to match frontend display

-- Create pricing packages table
CREATE TABLE IF NOT EXISTS token_pricing_packages (
  id SERIAL PRIMARY KEY,
  token_amount INTEGER NOT NULL UNIQUE,
  base_price_rupees DECIMAL(10, 2) NOT NULL,
  discounted_price_rupees DECIMAL(10, 2) NOT NULL,
  discount_percentage INTEGER NOT NULL DEFAULT 0,
  is_popular BOOLEAN NOT NULL DEFAULT false,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT positive_token_amount CHECK (token_amount > 0),
  CONSTRAINT positive_base_price CHECK (base_price_rupees > 0),
  CONSTRAINT positive_discounted_price CHECK (discounted_price_rupees > 0),
  CONSTRAINT valid_discount CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
  CONSTRAINT discounted_price_valid CHECK (discounted_price_rupees <= base_price_rupees)
);

-- Add comment
COMMENT ON TABLE token_pricing_packages IS
  'Official token pricing packages with discount tiers for bulk purchases';

-- Insert default pricing packages matching frontend display
-- Base rate: 10 tokens = ₹1
INSERT INTO token_pricing_packages
  (token_amount, base_price_rupees, discounted_price_rupees, discount_percentage, is_popular, display_order)
VALUES
  -- 50 tokens: ₹5 (no discount)
  (50, 5.00, 5.00, 0, false, 1),

  -- 100 tokens: ₹9 (10% discount from ₹10)
  (100, 10.00, 9.00, 10, false, 2),

  -- 250 tokens: ₹20 (20% discount from ₹25)
  (250, 25.00, 20.00, 20, true, 3),

  -- 500 tokens: ₹35 (30% discount from ₹50)
  (500, 50.00, 35.00, 30, false, 4)
ON CONFLICT (token_amount) DO UPDATE SET
  base_price_rupees = EXCLUDED.base_price_rupees,
  discounted_price_rupees = EXCLUDED.discounted_price_rupees,
  discount_percentage = EXCLUDED.discount_percentage,
  is_popular = EXCLUDED.is_popular,
  display_order = EXCLUDED.display_order,
  updated_at = NOW();

-- Create index for fast lookup
CREATE INDEX IF NOT EXISTS idx_token_pricing_active
  ON token_pricing_packages(is_active, display_order)
  WHERE is_active = true;

-- Create function to get pricing for a specific token amount
CREATE OR REPLACE FUNCTION get_token_price(p_token_amount INTEGER)
RETURNS TABLE (
  base_price DECIMAL(10, 2),
  discounted_price DECIMAL(10, 2),
  discount_percentage INTEGER
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  -- Try to find exact match in pricing packages
  RETURN QUERY
  SELECT
    base_price_rupees,
    discounted_price_rupees,
    token_pricing_packages.discount_percentage
  FROM token_pricing_packages
  WHERE token_amount = p_token_amount
    AND is_active = true
  LIMIT 1;

  -- If no match found, return NULL (caller should use flat rate)
  IF NOT FOUND THEN
    RETURN;
  END IF;
END;
$$;

COMMENT ON FUNCTION get_token_price(INTEGER) IS
  'Returns pricing information for a specific token amount from predefined packages';

-- Create function to get all active pricing packages
CREATE OR REPLACE FUNCTION get_all_token_pricing_packages()
RETURNS TABLE (
  token_amount INTEGER,
  base_price_rupees DECIMAL(10, 2),
  discounted_price_rupees DECIMAL(10, 2),
  discount_percentage INTEGER,
  is_popular BOOLEAN
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.token_amount,
    p.base_price_rupees,
    p.discounted_price_rupees,
    p.discount_percentage,
    p.is_popular
  FROM token_pricing_packages p
  WHERE p.is_active = true
  ORDER BY p.display_order ASC;
END;
$$;

COMMENT ON FUNCTION get_all_token_pricing_packages() IS
  'Returns all active pricing packages for display in frontend';

-- Grant necessary permissions
GRANT SELECT ON token_pricing_packages TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_token_price(INTEGER) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_all_token_pricing_packages() TO authenticated, anon;
