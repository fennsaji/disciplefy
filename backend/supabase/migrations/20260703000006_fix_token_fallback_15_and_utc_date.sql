-- Migration: Fix token function config drift (F35)
-- 1. Change fallback daily_limit from 8 → 15 (matches free plan default in TS/Flutter token-types.ts)
-- 2. consume_user_tokens: replace CURRENT_DATE with explicit UTC cast to match
--    get_or_create_user_tokens which already uses (NOW() AT TIME ZONE 'UTC')::date

BEGIN;

-- Fix consume_user_tokens: fallback 8→15 + CURRENT_DATE→UTC
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
  current_date_utc DATE;
  needs_reset BOOLEAN;
  plan_changed BOOLEAN;
  updated_rows INTEGER;
  tokens_from_daily INTEGER := 0;
  tokens_from_purchased INTEGER := 0;
BEGIN
  current_date_utc := (NOW() AT TIME ZONE 'UTC')::date;

  IF p_token_cost IS NULL OR p_token_cost <= 0 THEN
    RETURN QUERY SELECT
      false::BOOLEAN, 0::INTEGER, 0::INTEGER, 0::INTEGER, 0::INTEGER, 0::INTEGER,
      'Invalid token cost: must be positive integer'::TEXT;
    RETURN;
  END IF;

  SELECT COALESCE((sp.features->>'daily_tokens')::INTEGER, 15) INTO default_limit
  FROM subscription_plans sp
  WHERE sp.plan_code = p_user_plan;

  IF default_limit IS NULL THEN default_limit := 15; END IF;
  IF default_limit = -1 THEN default_limit := 999999999; END IF;

  SELECT
    CASE
      WHEN default_limit = 999999999 THEN default_limit
      WHEN ut.last_reset < current_date_utc THEN default_limit
      WHEN ut.user_plan IS DISTINCT FROM p_user_plan
           THEN GREATEST(0, default_limit - ut.daily_consumed_today)
      ELSE ut.available_tokens
    END,
    ut.purchased_tokens,
    ut.last_reset < current_date_utc AND default_limit != 999999999,
    ut.user_plan IS DISTINCT FROM p_user_plan AND ut.last_reset >= current_date_utc
  INTO current_daily_tokens, current_purchased_tokens, needs_reset, plan_changed
  FROM user_tokens ut
  WHERE ut.identifier = p_identifier
  FOR UPDATE;

  total_available := COALESCE(current_daily_tokens, 0) + COALESCE(current_purchased_tokens, 0);

  IF current_daily_tokens IS NULL THEN
    INSERT INTO user_tokens (identifier, user_plan, available_tokens, purchased_tokens, daily_limit)
    VALUES (p_identifier, p_user_plan, default_limit, 0, default_limit);
    current_daily_tokens := default_limit;
    current_purchased_tokens := 0;
    total_available := default_limit;
    needs_reset := false;
    plan_changed := false;
  END IF;

  IF default_limit != 999999999 AND total_available < p_token_cost THEN
    RETURN QUERY SELECT
      false::BOOLEAN, current_daily_tokens, current_purchased_tokens, default_limit,
      0::INTEGER, 0::INTEGER, 'Insufficient tokens'::TEXT;
    RETURN;
  END IF;

  IF default_limit = 999999999 THEN
    UPDATE user_tokens SET user_plan = p_user_plan, daily_limit = default_limit, updated_at = NOW()
    WHERE identifier = p_identifier;
    RETURN QUERY SELECT
      true::BOOLEAN, current_daily_tokens, current_purchased_tokens, default_limit,
      0::INTEGER, 0::INTEGER, ''::TEXT;
    RETURN;
  END IF;

  IF current_daily_tokens >= p_token_cost THEN
    tokens_from_daily := p_token_cost;
    tokens_from_purchased := 0;
  ELSE
    tokens_from_daily := current_daily_tokens;
    tokens_from_purchased := p_token_cost - current_daily_tokens;
  END IF;

  IF needs_reset THEN
    UPDATE user_tokens
    SET
      user_plan = p_user_plan,
      daily_limit = default_limit,
      available_tokens = default_limit - tokens_from_daily,
      purchased_tokens = user_tokens.purchased_tokens - tokens_from_purchased,
      total_consumed_today = p_token_cost,
      daily_consumed_today = tokens_from_daily,
      last_reset = current_date_utc,
      updated_at = NOW()
    WHERE identifier = p_identifier
      AND user_tokens.purchased_tokens >= tokens_from_purchased;

    GET DIAGNOSTICS updated_rows = ROW_COUNT;
    IF updated_rows = 0 THEN
      RETURN QUERY SELECT
        false::BOOLEAN, current_daily_tokens, current_purchased_tokens, default_limit,
        0::INTEGER, 0::INTEGER, 'Insufficient tokens (race condition detected)'::TEXT;
      RETURN;
    END IF;
  ELSE
    UPDATE user_tokens
    SET
      user_plan = p_user_plan,
      daily_limit = default_limit,
      available_tokens = current_daily_tokens - tokens_from_daily,
      purchased_tokens = user_tokens.purchased_tokens - tokens_from_purchased,
      total_consumed_today = user_tokens.total_consumed_today + p_token_cost,
      daily_consumed_today = user_tokens.daily_consumed_today + tokens_from_daily,
      updated_at = NOW()
    WHERE identifier = p_identifier
      AND user_tokens.purchased_tokens >= tokens_from_purchased;

    GET DIAGNOSTICS updated_rows = ROW_COUNT;
    IF updated_rows = 0 THEN
      RETURN QUERY SELECT
        false::BOOLEAN, current_daily_tokens, current_purchased_tokens, default_limit,
        0::INTEGER, 0::INTEGER, 'Insufficient tokens (race condition detected)'::TEXT;
      RETURN;
    END IF;
  END IF;

  RETURN QUERY SELECT
    true::BOOLEAN,
    (current_daily_tokens - tokens_from_daily)::INTEGER,
    (current_purchased_tokens - tokens_from_purchased)::INTEGER,
    default_limit,
    tokens_from_daily,
    tokens_from_purchased,
    ''::TEXT;
END;
$$;

-- Fix get_or_create_user_tokens: fallback 8→15
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
  current_date_utc := (NOW() AT TIME ZONE 'UTC')::date;

  SELECT COALESCE((sp.features->>'daily_tokens')::INTEGER, 15) INTO default_limit
  FROM subscription_plans sp
  WHERE sp.plan_code = p_user_plan;

  IF default_limit IS NULL THEN default_limit := 15; END IF;
  IF default_limit = -1 THEN default_limit := 999999999; END IF;

  SELECT EXISTS(SELECT 1 FROM user_tokens ut WHERE ut.identifier = p_identifier)
  INTO record_exists;

  IF NOT record_exists THEN
    INSERT INTO user_tokens (identifier, user_plan, available_tokens, purchased_tokens, daily_limit, last_reset)
    VALUES (p_identifier, p_user_plan, default_limit, 0, default_limit, current_date_utc);
  ELSE
    SELECT ut.user_plan, ut.total_consumed_today, ut.last_reset
    INTO stored_plan, stored_consumed_today, stored_last_reset
    FROM user_tokens ut
    WHERE ut.identifier = p_identifier;

    IF stored_plan IS DISTINCT FROM p_user_plan THEN
      UPDATE user_tokens ut
      SET
        user_plan = p_user_plan,
        daily_limit = default_limit,
        available_tokens = CASE
          WHEN default_limit = 999999999 THEN 999999999
          WHEN stored_last_reset < current_date_utc THEN default_limit
          ELSE GREATEST(0, default_limit - ut.daily_consumed_today)
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

  RETURN QUERY
  SELECT
    ut.id, ut.identifier, ut.user_plan, ut.available_tokens, ut.purchased_tokens,
    ut.daily_limit, ut.last_reset, ut.total_consumed_today
  FROM user_tokens ut
  WHERE ut.identifier = p_identifier;
END;
$$;

COMMIT;
