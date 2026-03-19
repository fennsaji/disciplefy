-- =====================================================
-- Migration: Update Token Economy (2026-03-19)
-- =====================================================
-- Changes:
--   - tokensPerRupee: 4 → 2 (₹0.50/token, up from ₹0.25/token)
--   - Free daily_tokens: 3 → 15 (enough for 1 Quick in any language)
--   - Standard daily_tokens: 20 → 40 (enough for 1 Standard in any language)
--   - Plus daily_tokens: 50 → 60 (enough for 1 Deep in any language)
--   - Premium: unchanged (-1 = unlimited)
--
-- Rationale: All mode×language combinations were running at a loss under
-- the old pricing. See docs/analysis/token_economy_analysis.md.
-- =====================================================

BEGIN;

-- Free plan: 3 → 15 tokens/day
UPDATE subscription_plans
SET
  features = jsonb_set(features, '{daily_tokens}', '15'),
  description = 'Free plan — 15 daily tokens (1 Quick in any language)'
WHERE plan_code = 'free';

-- Standard plan: 20 → 40 tokens/day
UPDATE subscription_plans
SET
  features = jsonb_set(features, '{daily_tokens}', '40'),
  description = 'Standard plan — 40 daily tokens (1 Standard in any language)'
WHERE plan_code = 'standard';

-- Plus plan: 50 → 60 tokens/day
UPDATE subscription_plans
SET
  features = jsonb_set(features, '{daily_tokens}', '60'),
  description = 'Plus plan — 60 daily tokens (1 Deep in any language)'
WHERE plan_code = 'plus';

-- Premium: unchanged (-1 = unlimited), update description only
UPDATE subscription_plans
SET
  description = 'Premium plan — unlimited tokens (avg ~1,500/month fresh)'
WHERE plan_code = 'premium';

-- Reset all existing user_tokens.daily_limit to new plan values.
-- Avoids stranding users on old limits until their next daily reset.
UPDATE user_tokens ut
SET
  daily_limit = (
    SELECT COALESCE((sp.features->>'daily_tokens')::INTEGER, 15)
    FROM subscription_plans sp
    WHERE sp.plan_code = ut.user_plan
  ),
  -- Also top up available_tokens if they are below the new limit
  -- (don't penalise users who haven't consumed yet today)
  available_tokens = GREATEST(
    ut.available_tokens,
    (
      SELECT COALESCE((sp.features->>'daily_tokens')::INTEGER, 15)
      FROM subscription_plans sp
      WHERE sp.plan_code = ut.user_plan
    ) - ut.total_consumed_today
  )
WHERE ut.user_plan != 'premium';

COMMIT;
