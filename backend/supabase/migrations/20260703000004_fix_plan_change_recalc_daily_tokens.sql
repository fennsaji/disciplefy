-- =====================================================
-- Fix: Plan-Change Token Recalc Issues (F21 + F22)
-- =====================================================
-- F21: get_or_create_user_tokens uses total_consumed_today in the plan-change
--      recalc formula. total_consumed_today includes purchased spend, so an
--      upgrade under-grants daily tokens by that day's purchased token spend.
--      Fix: Add daily_consumed_today (daily-only). Plan-change recalc uses it.
--
-- F22: consume_user_tokens does not detect plan changes. After an upgrade, the
--      DB still holds the old plan's remaining available_tokens. If the user
--      immediately calls consume (before token-status/get_or_create has run),
--      consume sees the old low balance → "Insufficient tokens" despite upgrade.
--      Fix: Detect plan change in SELECT FOR UPDATE; recompute current_daily_tokens
--      from new plan limit and daily_consumed_today. Persist plan change in UPDATE.
-- =====================================================

BEGIN;

-- -------------------------------------------------------
-- Step 1: Add daily_consumed_today column
-- -------------------------------------------------------
ALTER TABLE user_tokens
  ADD COLUMN IF NOT EXISTS daily_consumed_today INTEGER NOT NULL DEFAULT 0
  CHECK (daily_consumed_today >= 0);

COMMENT ON COLUMN user_tokens.daily_consumed_today IS
  'Tokens consumed from the daily allocation (available_tokens) since last reset. '
  'Excludes purchased token spend. Used by plan-change recalc to correctly '
  'grant new-plan daily tokens without penalising prior purchased-token usage.';

-- -------------------------------------------------------
-- Step 2: Patch consume_user_tokens (F21 + F22)
--   F21: Track daily_consumed_today separately per consumption
--   F22: Detect plan change in SELECT FOR UPDATE; use current_daily_tokens
--        (already reflecting the new plan limit) in the UPDATE's SET clause
--        instead of reading the stale ut.available_tokens from the DB.
-- -------------------------------------------------------

CREATE OR REPLACE FUNCTION consume_user_tokens(
  p_identifier TEXT,
  p_user_plan TEXT,
  p_token_cost INTEGER
)
RETURNS TABLE(
  success BOOLEAN,
  available_tokens INTEGER,
  purchased_tokens INTEGER,
  daily_limit INTEGER,
  daily_tokens_used INTEGER,
  purchased_tokens_used INTEGER,
  error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  current_daily_tokens INTEGER;
  current_purchased_tokens INTEGER;
  total_available INTEGER;
  default_limit INTEGER;
  needs_reset BOOLEAN;
  plan_changed BOOLEAN;   -- F22: true when plan upgraded mid-day
  updated_rows INTEGER;
  tokens_from_daily INTEGER := 0;
  tokens_from_purchased INTEGER := 0;
BEGIN
  -- INPUT VALIDATION: Check p_token_cost
  IF p_token_cost IS NULL OR p_token_cost <= 0 THEN
    RETURN QUERY SELECT
      false::BOOLEAN,
      0::INTEGER,
      0::INTEGER,
      0::INTEGER,
      0::INTEGER,
      0::INTEGER,
      'Invalid token cost: must be positive integer'::TEXT;
    RETURN;
  END IF;

  -- Read daily limit from subscription_plans (database-driven, not hardcoded)
  SELECT COALESCE((sp.features->>'daily_tokens')::INTEGER, 8) INTO default_limit
  FROM subscription_plans sp
  WHERE sp.plan_code = p_user_plan;

  IF default_limit IS NULL THEN default_limit := 8; END IF;
  IF default_limit = -1 THEN default_limit := 999999999; END IF;

  -- Check if user needs daily reset and get current tokens WITH ROW LOCK.
  -- F22: Also detect mid-day plan upgrades. When the stored plan differs from
  -- p_user_plan and it's the same day, recompute available tokens from the
  -- new plan limit minus daily-only consumption.
  SELECT
    CASE
      WHEN default_limit = 999999999 THEN default_limit
      WHEN ut.last_reset < CURRENT_DATE THEN default_limit            -- new day: full reset
      WHEN ut.user_plan IS DISTINCT FROM p_user_plan                  -- F22: plan upgraded mid-day
           THEN GREATEST(0, default_limit - ut.daily_consumed_today)
      ELSE ut.available_tokens
    END,
    ut.purchased_tokens,
    ut.last_reset < CURRENT_DATE AND default_limit != 999999999,
    ut.user_plan IS DISTINCT FROM p_user_plan AND ut.last_reset >= CURRENT_DATE
  INTO current_daily_tokens, current_purchased_tokens, needs_reset, plan_changed
  FROM user_tokens ut
  WHERE ut.identifier = p_identifier
  FOR UPDATE;  -- CRITICAL: Lock row to prevent race conditions

  -- Calculate total available tokens (daily + purchased)
  total_available := COALESCE(current_daily_tokens, 0) + COALESCE(current_purchased_tokens, 0);

  -- If user doesn't exist, create with default tokens
  IF current_daily_tokens IS NULL THEN
    INSERT INTO user_tokens (
      identifier,
      user_plan,
      available_tokens,
      purchased_tokens,
      daily_limit
    )
    VALUES (
      p_identifier,
      p_user_plan,
      default_limit,
      0,
      default_limit
    );
    current_daily_tokens := default_limit;
    current_purchased_tokens := 0;
    total_available := default_limit;
    needs_reset := false;
    plan_changed := false;
  END IF;

  -- Check if user has enough tokens (skip for unlimited plans)
  IF default_limit != 999999999 AND total_available < p_token_cost THEN
    RETURN QUERY SELECT
      false::BOOLEAN,
      current_daily_tokens,
      current_purchased_tokens,
      default_limit,
      0::INTEGER,
      0::INTEGER,
      'Insufficient tokens'::TEXT;
    RETURN;
  END IF;

  -- Consume tokens with atomic update
  -- Strategy: Prioritize daily tokens first, then purchased tokens
  IF default_limit = 999999999 THEN
    -- Unlimited plan users don't consume tokens; persist plan change if needed
    UPDATE user_tokens
    SET
      user_plan = p_user_plan,
      daily_limit = default_limit,
      updated_at = NOW()
    WHERE identifier = p_identifier;

    RETURN QUERY SELECT
      true::BOOLEAN,
      current_daily_tokens,
      current_purchased_tokens,
      default_limit,
      0::INTEGER,
      0::INTEGER,
      ''::TEXT;
    RETURN;
  END IF;

  -- Calculate token breakdown (prioritize daily tokens)
  IF current_daily_tokens >= p_token_cost THEN
    -- Consume entirely from daily tokens
    tokens_from_daily := p_token_cost;
    tokens_from_purchased := 0;
  ELSE
    -- Consume all daily tokens + remaining from purchased
    tokens_from_daily := current_daily_tokens;
    tokens_from_purchased := p_token_cost - current_daily_tokens;
  END IF;

  -- Apply reset if needed and consume tokens atomically (one row per user).
  -- F22: Use current_daily_tokens (already reflects plan change) for available_tokens SET.
  -- F21: Also update daily_consumed_today to track daily-only spend separately.
  IF needs_reset THEN
    UPDATE user_tokens
    SET
      user_plan = p_user_plan,
      daily_limit = default_limit,
      available_tokens = default_limit - tokens_from_daily,
      purchased_tokens = user_tokens.purchased_tokens - tokens_from_purchased,
      total_consumed_today = p_token_cost,
      daily_consumed_today = tokens_from_daily,  -- F21: daily-only spend
      last_reset = CURRENT_DATE,
      updated_at = NOW()
    WHERE identifier = p_identifier
      AND user_tokens.purchased_tokens >= tokens_from_purchased;  -- ATOMIC: Verify sufficient tokens

    GET DIAGNOSTICS updated_rows = ROW_COUNT;
    IF updated_rows = 0 THEN
      RETURN QUERY SELECT
        false::BOOLEAN,
        current_daily_tokens,
        current_purchased_tokens,
        default_limit,
        0::INTEGER,
        0::INTEGER,
        'Insufficient tokens (race condition detected)'::TEXT;
      RETURN;
    END IF;
  ELSE
    -- No reset. F22: Write current_daily_tokens - tokens_from_daily directly to
    -- available_tokens so plan upgrades are reflected without a separate get_or_create
    -- call. The WHERE clause drops the available_tokens check since current_daily_tokens
    -- already satisfies tokens_from_daily <= current_daily_tokens by construction,
    -- and the row is locked via FOR UPDATE so no race can occur between the check above.
    UPDATE user_tokens
    SET
      user_plan = p_user_plan,
      daily_limit = default_limit,
      available_tokens = current_daily_tokens - tokens_from_daily,  -- F22: uses new-plan value
      purchased_tokens = user_tokens.purchased_tokens - tokens_from_purchased,
      total_consumed_today = user_tokens.total_consumed_today + p_token_cost,
      daily_consumed_today = user_tokens.daily_consumed_today + tokens_from_daily,  -- F21: daily-only spend
      updated_at = NOW()
    WHERE identifier = p_identifier
      AND user_tokens.purchased_tokens >= tokens_from_purchased;  -- ATOMIC: Verify purchased balance

    GET DIAGNOSTICS updated_rows = ROW_COUNT;
    IF updated_rows = 0 THEN
      RETURN QUERY SELECT
        false::BOOLEAN,
        current_daily_tokens,
        current_purchased_tokens,
        default_limit,
        0::INTEGER,
        0::INTEGER,
        'Insufficient tokens (race condition detected)'::TEXT;
      RETURN;
    END IF;
  END IF;

  -- Return success with updated balances
  RETURN QUERY
  SELECT
    true::BOOLEAN,
    (current_daily_tokens - tokens_from_daily)::INTEGER,
    (current_purchased_tokens - tokens_from_purchased)::INTEGER,
    default_limit,
    tokens_from_daily,
    tokens_from_purchased,
    ''::TEXT;
END;
$$;

COMMENT ON FUNCTION consume_user_tokens(TEXT, TEXT, INTEGER) IS
  'Atomically consume tokens (one row per user) with SELECT FOR UPDATE locking and token breakdown response.
   Reads daily_limit from subscription_plans (database-driven, not hardcoded).
   FIX (F21): daily_consumed_today tracks only daily-allocation spend for correct plan-change recalc.
   FIX (F22): Detects mid-day plan upgrades; recomputes current_daily_tokens from new limit so the
   first consume after an upgrade succeeds without requiring a prior token-status call.';

-- -------------------------------------------------------
-- Step 3: Patch get_or_create_user_tokens (F21)
--   Use daily_consumed_today (not total_consumed_today) in the plan-change
--   recalc so purchased spend doesn't reduce the new daily allocation.
-- -------------------------------------------------------

CREATE OR REPLACE FUNCTION get_or_create_user_tokens(
  p_identifier TEXT,
  p_user_plan TEXT
)
RETURNS TABLE(
  id UUID,
  identifier TEXT,
  user_plan TEXT,
  available_tokens INTEGER,
  purchased_tokens INTEGER,
  daily_limit INTEGER,
  last_reset DATE,
  total_consumed_today INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  default_limit INTEGER;
  record_exists BOOLEAN;
  current_date_utc DATE;
  stored_plan TEXT;
  stored_consumed_today INTEGER;
  stored_last_reset DATE;
BEGIN
  -- Use UTC timezone for consistent date comparisons
  current_date_utc := (NOW() AT TIME ZONE 'UTC')::date;

  -- Read daily limit from subscription_plans.features (database-driven)
  SELECT COALESCE((sp.features->>'daily_tokens')::INTEGER, 8) INTO default_limit
  FROM subscription_plans sp
  WHERE sp.plan_code = p_user_plan;

  IF default_limit IS NULL THEN
    default_limit := 8;
  END IF;

  IF default_limit = -1 THEN
    default_limit := 999999999;
  END IF;

  -- Check if record exists (one row per user, keyed by identifier only)
  SELECT EXISTS(
    SELECT 1 FROM user_tokens ut
    WHERE ut.identifier = p_identifier
  ) INTO record_exists;

  -- If no record exists, create one
  IF NOT record_exists THEN
    INSERT INTO user_tokens (
      identifier,
      user_plan,
      available_tokens,
      purchased_tokens,
      daily_limit,
      last_reset
    )
    VALUES (
      p_identifier,
      p_user_plan,
      default_limit,
      0,
      default_limit,
      current_date_utc
    );
  ELSE
    -- Read current stored values to detect plan changes
    SELECT ut.user_plan, ut.total_consumed_today, ut.last_reset
    INTO stored_plan, stored_consumed_today, stored_last_reset
    FROM user_tokens ut
    WHERE ut.identifier = p_identifier;

    IF stored_plan IS DISTINCT FROM p_user_plan THEN
      -- Plan changed: update plan and recalculate available_tokens for today.
      -- FIX (F21): Use daily_consumed_today (not total_consumed_today) so that
      -- purchased-token spend on the same day does not reduce the new daily allocation.
      UPDATE user_tokens ut
      SET
        user_plan = p_user_plan,
        daily_limit = default_limit,
        available_tokens = CASE
          WHEN default_limit = 999999999 THEN 999999999
          WHEN stored_last_reset < current_date_utc THEN default_limit  -- new day resets
          ELSE GREATEST(0, default_limit - ut.daily_consumed_today)     -- FIX F21: daily-only spend
        END,
        last_reset = CASE
          WHEN stored_last_reset < current_date_utc THEN current_date_utc
          ELSE ut.last_reset
        END,
        total_consumed_today = CASE
          WHEN default_limit = 999999999 THEN 0
          WHEN stored_last_reset < current_date_utc THEN 0
          ELSE ut.total_consumed_today
        END,
        daily_consumed_today = CASE
          WHEN default_limit = 999999999 THEN 0
          WHEN stored_last_reset < current_date_utc THEN 0
          ELSE ut.daily_consumed_today
        END,
        updated_at = NOW()
      WHERE ut.identifier = p_identifier;
    ELSE
      -- Same plan: Persist daily reset BEFORE SELECT to avoid virtual reset issues
      UPDATE user_tokens ut
      SET
        available_tokens = CASE
          WHEN default_limit = 999999999 THEN 999999999
          WHEN ut.last_reset < current_date_utc THEN default_limit
          ELSE ut.available_tokens
        END,
        last_reset = CASE
          WHEN ut.last_reset < current_date_utc THEN current_date_utc
          ELSE ut.last_reset
        END,
        total_consumed_today = CASE
          WHEN default_limit = 999999999 THEN 0
          WHEN ut.last_reset < current_date_utc THEN 0
          ELSE ut.total_consumed_today
        END,
        daily_consumed_today = CASE
          WHEN default_limit = 999999999 THEN 0
          WHEN ut.last_reset < current_date_utc THEN 0
          ELSE ut.daily_consumed_today
        END,
        daily_limit = default_limit,
        updated_at = NOW()
      WHERE ut.identifier = p_identifier;
    END IF;
  END IF;

  -- Return the record (existing or newly created), now with persisted reset
  RETURN QUERY
  SELECT
    ut.id,
    ut.identifier,
    ut.user_plan,
    ut.available_tokens,
    ut.purchased_tokens,
    ut.daily_limit,
    ut.last_reset,
    ut.total_consumed_today
  FROM user_tokens ut
  WHERE ut.identifier = p_identifier;
END;
$$;

COMMENT ON FUNCTION get_or_create_user_tokens(TEXT, TEXT) IS
  'Get or create user tokens record (one row per user) with automatic daily reset and plan-change detection.
   Reads daily_tokens from subscription_plans.features (database-driven).
   FIX (F21): Plan-change recalc uses daily_consumed_today (not total_consumed_today) so that
   purchased-token spend does not reduce the new daily allocation on upgrade.';

COMMIT;
