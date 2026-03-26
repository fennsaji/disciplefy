-- ============================================================================
-- Add Kill-Switch Feature Flags
-- ============================================================================
-- Adds two admin-controlled kill switches:
--   enable_token_purchase    - set is_enabled=false to hide all token purchase UI
--   enable_new_subscriptions - set is_enabled=false to block new subscription
--                              creation; existing paid subscribers are unaffected
-- ============================================================================

INSERT INTO feature_flags (feature_key, feature_name, is_enabled, enabled_for_plans, display_mode, description, metadata)
VALUES (
  'enable_token_purchase',
  'Token Purchase',
  true,
  ARRAY['free', 'standard', 'plus', 'premium'],
  'hide',
  'When disabled (is_enabled=false), hides all token purchase UI for all users',
  '{"category": "kill_switches"}'::jsonb
)
ON CONFLICT (feature_key) DO NOTHING;

INSERT INTO feature_flags (feature_key, feature_name, is_enabled, enabled_for_plans, display_mode, description, metadata)
VALUES (
  'enable_new_subscriptions',
  'New Subscriptions',
  true,
  ARRAY['free', 'standard', 'plus', 'premium'],
  'hide',
  'When disabled (is_enabled=false), blocks new subscription creation. Existing paid subscribers (non-trial) are unaffected.',
  '{"category": "kill_switches"}'::jsonb
)
ON CONFLICT (feature_key) DO NOTHING;
