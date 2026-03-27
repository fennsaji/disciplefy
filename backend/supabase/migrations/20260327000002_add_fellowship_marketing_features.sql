-- =====================================================
-- Migration: Add Fellowship Features to Marketing Features (2026-03-27)
-- =====================================================
-- Changes:
--   - Free: append "Join Fellowship Groups"
--   - Standard: append "Join Fellowship Groups"
--   - Plus: append "Create & Lead Fellowship Groups"
--   - Premium: append "Create & Lead Fellowship Groups"
-- =====================================================

BEGIN;

-- Free plan: join fellowship
UPDATE public.subscription_plans
SET marketing_features = marketing_features || '["Join Fellowship Groups"]'::jsonb
WHERE plan_code = 'free'
  AND NOT (marketing_features @> '["Join Fellowship Groups"]'::jsonb);

-- Standard plan: join fellowship
UPDATE public.subscription_plans
SET marketing_features = marketing_features || '["Join Fellowship Groups"]'::jsonb
WHERE plan_code = 'standard'
  AND NOT (marketing_features @> '["Join Fellowship Groups"]'::jsonb);

-- Plus plan: create & lead fellowship
UPDATE public.subscription_plans
SET marketing_features = marketing_features || '["Create & Lead Fellowship Groups"]'::jsonb
WHERE plan_code = 'plus'
  AND NOT (marketing_features @> '["Create & Lead Fellowship Groups"]'::jsonb);

-- Premium plan: create & lead fellowship
UPDATE public.subscription_plans
SET marketing_features = marketing_features || '["Create & Lead Fellowship Groups"]'::jsonb
WHERE plan_code = 'premium'
  AND NOT (marketing_features @> '["Create & Lead Fellowship Groups"]'::jsonb);

COMMIT;
