-- Migration: Add refund_user_tokens function
-- Purpose: Refund tokens when study generation fails after consumption
-- This ensures users are not charged for failed generations

CREATE OR REPLACE FUNCTION refund_user_tokens(
  p_identifier TEXT,
  p_daily_tokens_used INTEGER,
  p_purchased_tokens_used INTEGER
)
RETURNS TABLE(
  success BOOLEAN,
  available_tokens INTEGER,
  purchased_tokens INTEGER,
  error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  updated_rows INTEGER;
BEGIN
  -- INPUT VALIDATION
  IF p_daily_tokens_used IS NULL OR p_purchased_tokens_used IS NULL THEN
    RETURN QUERY SELECT
      false::BOOLEAN,
      0::INTEGER,
      0::INTEGER,
      'Invalid refund amounts: must not be null'::TEXT;
    RETURN;
  END IF;

  IF p_daily_tokens_used < 0 OR p_purchased_tokens_used < 0 THEN
    RETURN QUERY SELECT
      false::BOOLEAN,
      0::INTEGER,
      0::INTEGER,
      'Invalid refund amounts: must be non-negative'::TEXT;
    RETURN;
  END IF;

  IF p_daily_tokens_used = 0 AND p_purchased_tokens_used = 0 THEN
    RETURN QUERY SELECT
      false::BOOLEAN,
      0::INTEGER,
      0::INTEGER,
      'Nothing to refund'::TEXT;
    RETURN;
  END IF;

  -- Refund tokens atomically
  UPDATE user_tokens
  SET
    available_tokens = user_tokens.available_tokens + p_daily_tokens_used,
    purchased_tokens = user_tokens.purchased_tokens + p_purchased_tokens_used,
    total_consumed_today = GREATEST(user_tokens.total_consumed_today - (p_daily_tokens_used + p_purchased_tokens_used), 0),
    updated_at = NOW()
  WHERE identifier = p_identifier;

  GET DIAGNOSTICS updated_rows = ROW_COUNT;

  IF updated_rows = 0 THEN
    RETURN QUERY SELECT
      false::BOOLEAN,
      0::INTEGER,
      0::INTEGER,
      'User token record not found'::TEXT;
    RETURN;
  END IF;

  -- Return updated balances
  RETURN QUERY
  SELECT
    true::BOOLEAN,
    ut.available_tokens,
    ut.purchased_tokens,
    ''::TEXT
  FROM user_tokens ut
  WHERE ut.identifier = p_identifier;
END;
$$;

COMMENT ON FUNCTION refund_user_tokens(TEXT, INTEGER, INTEGER) IS
  'Refund tokens to a user when an operation (e.g. study generation) fails after consumption.
   Accepts the exact breakdown of daily vs purchased tokens that were consumed,
   and adds them back to the respective balances atomically.';
