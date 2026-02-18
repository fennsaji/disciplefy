-- ============================================================================
-- Migration: Remove Duplicate Memory Verse Configuration
-- Date: 2026-02-11
-- Purpose: Remove practice_limit and memory_verses from subscription_plans.features
--          to use system_config as single source of truth
-- ============================================================================

-- Remove practice_limit from all subscription plans
UPDATE subscription_plans
SET features = features - 'practice_limit'
WHERE features ? 'practice_limit';

-- Remove memory_verses from all subscription plans
UPDATE subscription_plans
SET features = features - 'memory_verses'
WHERE features ? 'memory_verses';

-- Verify removal (this will log the results)
DO $$
DECLARE
  plan_record RECORD;
  has_practice_limit BOOLEAN;
  has_memory_verses BOOLEAN;
BEGIN
  FOR plan_record IN
    SELECT plan_code, features
    FROM subscription_plans
    ORDER BY tier
  LOOP
    has_practice_limit := plan_record.features ? 'practice_limit';
    has_memory_verses := plan_record.features ? 'memory_verses';

    RAISE NOTICE 'Plan: %, practice_limit: %, memory_verses: %',
      plan_record.plan_code,
      has_practice_limit,
      has_memory_verses;
  END LOOP;
END $$;

-- Add comment documenting the change
COMMENT ON TABLE subscription_plans IS 'Subscription plans table. Note: practice_limit and memory_verses removed from features JSONB (2026-02-11) - now stored in system_config table for dynamic configuration.';
