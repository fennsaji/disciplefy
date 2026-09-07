-- Feature flag for creating a fellowship.
--
-- The Community "⋮" menu used to hide "Create Fellowship" outright unless the
-- user was an admin, already a mentor, or on plus/premium — so the capability
-- was invisible to everyone else and there was nothing to upgrade towards.
-- With display_mode 'lock' the item is always shown and the app offers the
-- upgrade sheet when the plan does not include it.
--
-- Kept as a flag rather than hardcoded so entitlement can be changed from the
-- admin dashboard without an app release.

INSERT INTO public.feature_flags (
  feature_key, feature_name, description, is_enabled,
  enabled_for_plans, rollout_percentage, display_mode, metadata
) VALUES (
  'create_fellowship',
  'Create Fellowship',
  'Start and mentor your own fellowship group',
  true,
  ARRAY['plus', 'premium'],
  100,
  'lock',
  '{"category": "premium_features", "min_app_version": "1.0.0", "requires_subscription": true}'::jsonb
)
ON CONFLICT (feature_key) DO UPDATE SET
  feature_name = EXCLUDED.feature_name,
  description = EXCLUDED.description,
  display_mode = EXCLUDED.display_mode,
  updated_at = now();
