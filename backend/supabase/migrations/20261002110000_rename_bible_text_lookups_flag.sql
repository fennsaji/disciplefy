-- Rename the Bible lookup kill switch now that Bible text comes from the
-- self-hosted Bible text service instead of API.Bible.
--   bible_api_calls_enabled -> bible_text_lookups_enabled
-- The row is renamed in place, so its current is_enabled value is kept.
-- Idempotent: safe to run when the rename already happened.

UPDATE public.feature_flags
SET feature_key = 'bible_text_lookups_enabled',
    feature_name = 'Bible text — lookups',
    description = 'Operational switch. When OFF, the backend makes no new Bible text lookups (serves cache + fallbacks).',
    updated_at = NOW()
WHERE feature_key = 'bible_api_calls_enabled'
  AND NOT EXISTS (
    SELECT 1 FROM public.feature_flags WHERE feature_key = 'bible_text_lookups_enabled'
  );

-- Old key left behind only if both rows existed; the new row wins.
DELETE FROM public.feature_flags WHERE feature_key = 'bible_api_calls_enabled';

-- Environments that never had the old row get the switch, enabled.
INSERT INTO public.feature_flags
  (feature_key, feature_name, description, is_enabled, display_mode, enabled_for_plans, rollout_percentage, metadata)
VALUES
  ('bible_text_lookups_enabled', 'Bible text — lookups',
   'Operational switch. When OFF, the backend makes no new Bible text lookups (serves cache + fallbacks).',
   true, 'hide', ARRAY['free','standard','plus','premium'], 100,
   '{"category":"kill_switches","critical":true}'::jsonb)
ON CONFLICT (feature_key) DO NOTHING;

-- The content switch keeps its key (installed apps read it); only its labels change.
UPDATE public.feature_flags
SET feature_name = 'Bible text — content',
    description = 'Compliance kill-switch. When OFF, Bible text is not served or shown (hides verse surfaces, blocks endpoints).',
    updated_at = NOW()
WHERE feature_key = 'bible_content_enabled'
  AND feature_name IS DISTINCT FROM 'Bible text — content';
