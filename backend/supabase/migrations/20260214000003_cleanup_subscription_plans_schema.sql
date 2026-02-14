-- Migration: Cleanup subscription_plans schema
-- Created: 2026-02-14
-- Description: Remove unused and conflicting fields that duplicate feature flag functionality

-- ============================================================================
-- PROBLEM: Conflicting Access Control Systems
-- ============================================================================
-- Feature flags control ACCESS (can you use this feature?)
-- Subscription quotas control LIMITS (how much can you use?)
--
-- REMOVED FIELDS (these conflict with feature flags or are unused):
-- 1. features.ai_discipler - Conflicts with ai_discipler feature flag
-- 2. features.followups - Not used; replaced by study_chat feature flag
-- 3. daily_unlocked_modes - Always empty array, never used
-- 4. voice_minutes_monthly - Always 0, not used
--
-- KEPT FIELDS (actual quotas/limits):
-- - features.daily_tokens - Token quota
-- - features.voice_conversations_monthly - Monthly conversation limit
-- - features.memory_verses - Memory verse limit
-- - features.practice_modes - Practice mode count
-- - features.practice_limit - Practice session limit
-- - features.study_modes - Available study modes
-- ============================================================================

-- Remove conflicting and unused fields from features JSONB column
UPDATE subscription_plans
SET
  features = features - 'ai_discipler' - 'followups',
  updated_at = NOW()
WHERE
  features ? 'ai_discipler' OR features ? 'followups';

-- Drop unused top-level columns if they exist
-- Note: These columns may not exist in all environments
DO $$
BEGIN
  -- Check and drop daily_unlocked_modes column
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'subscription_plans'
    AND column_name = 'daily_unlocked_modes'
  ) THEN
    ALTER TABLE subscription_plans DROP COLUMN daily_unlocked_modes;
    RAISE NOTICE 'Dropped column: daily_unlocked_modes';
  END IF;

  -- Check and drop voice_minutes_monthly column
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'subscription_plans'
    AND column_name = 'voice_minutes_monthly'
  ) THEN
    ALTER TABLE subscription_plans DROP COLUMN voice_minutes_monthly;
    RAISE NOTICE 'Dropped column: voice_minutes_monthly';
  END IF;
END $$;

-- Add comment documenting the cleaned schema
COMMENT ON COLUMN subscription_plans.features IS
  'JSONB containing usage quotas/limits only. Access control is handled by feature_flags table.
   Valid keys: daily_tokens, voice_conversations_monthly, memory_verses, practice_modes, practice_limit, study_modes';

-- Verify cleanup
DO $$
DECLARE
  plan_record RECORD;
  has_removed_fields BOOLEAN := FALSE;
BEGIN
  -- Check if any plan still has the removed fields
  FOR plan_record IN
    SELECT plan_code, features
    FROM subscription_plans
  LOOP
    IF plan_record.features ? 'ai_discipler' OR plan_record.features ? 'followups' THEN
      RAISE WARNING 'Plan % still contains removed fields', plan_record.plan_code;
      has_removed_fields := TRUE;
    END IF;
  END LOOP;

  IF NOT has_removed_fields THEN
    RAISE NOTICE '✅ Schema cleanup successful: All conflicting fields removed';
    RAISE NOTICE '✅ Remaining quota fields: daily_tokens, voice_conversations_monthly, memory_verses, practice_modes, practice_limit, study_modes';
  END IF;
END $$;
