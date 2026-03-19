-- =====================================================
-- Migration: Update Marketing Features for Token Economy (2026-03-19)
-- =====================================================
-- Changes:
--   - Update marketing_features display strings to reflect new daily token limits
--   - Free: "8 Study Tokens/Day" → "15 Study Tokens/Day"
--   - Standard: "20 Study Tokens/Day" → "40 Study Tokens/Day"
--   - Plus: "50 Study Tokens/Day" → "60 Study Tokens/Day"
--
-- Depends on: 20260319000001_update_token_economy.sql
-- =====================================================

BEGIN;

-- Free plan: replace "8 Study Tokens/Day" with "15 Study Tokens/Day" in marketing_features array
UPDATE subscription_plans
SET marketing_features = (
  SELECT jsonb_agg(
    CASE
      WHEN elem::text = '"8 Study Tokens/Day"' THEN '"15 Study Tokens/Day"'::jsonb
      ELSE elem
    END
  )
  FROM jsonb_array_elements(marketing_features) AS elem
)
WHERE plan_code = 'free'
  AND marketing_features IS NOT NULL;

-- Standard plan: replace "20 Study Tokens/Day" with "40 Study Tokens/Day"
UPDATE subscription_plans
SET marketing_features = (
  SELECT jsonb_agg(
    CASE
      WHEN elem::text = '"20 Study Tokens/Day"' THEN '"40 Study Tokens/Day"'::jsonb
      ELSE elem
    END
  )
  FROM jsonb_array_elements(marketing_features) AS elem
)
WHERE plan_code = 'standard'
  AND marketing_features IS NOT NULL;

-- Plus plan: replace "50 Study Tokens/Day" with "60 Study Tokens/Day"
UPDATE subscription_plans
SET marketing_features = (
  SELECT jsonb_agg(
    CASE
      WHEN elem::text = '"50 Study Tokens/Day"' THEN '"60 Study Tokens/Day"'::jsonb
      ELSE elem
    END
  )
  FROM jsonb_array_elements(marketing_features) AS elem
)
WHERE plan_code = 'plus'
  AND marketing_features IS NOT NULL;

COMMIT;
