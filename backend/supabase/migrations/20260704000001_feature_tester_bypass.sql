-- Feature flag tester bypass (spec: docs/superpowers/specs/2026-07-04-feature-flag-tester-bypass-design.md)
--
-- 1) Per-flag opt-in: allow_tester_bypass — when true, users whose email is in
--    the feature_tester_emails list see this flag as enabled even if is_enabled=false.
-- 2) Global tester list: system_config key 'feature_tester_emails'
--    (comma-separated). Stored with is_active = false so it is NOT reachable
--    via the public paths (see the is_active comment on the INSERT below).
--    NOTE: unlike 'admin_emails' (which is stored is_active = true and IS
--    therefore anon-readable via get_system_configs()/REST — a separate
--    pre-existing exposure), this row is deliberately kept off those paths.
--    Resolution happens ONLY server-side via trusted service-role reads.

ALTER TABLE feature_flags
  ADD COLUMN IF NOT EXISTS allow_tester_bypass BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN feature_flags.allow_tester_bypass IS
  'When true, emails in system_config.feature_tester_emails treat this flag as enabled even when is_enabled=false. Plan gating still applies.';

-- is_active MUST be false here. system_config's public RLS policy
-- (USING (is_active = true)) and the get_system_configs() RPC (granted to
-- anon + authenticated) both expose every is_active=true row directly to
-- the anon key via REST or rpc('get_system_configs'). Setting is_active =
-- false keeps this row invisible to those generic public paths; it is only
-- ever read by trusted service-role code (feature-flag-service.ts and the
-- admin-web API route), which uses a service-role client that bypasses RLS
-- entirely and does not filter on is_active.
INSERT INTO system_config (key, value, description, is_active)
VALUES (
  'feature_tester_emails',
  '',
  'Comma-separated emails allowed to bypass feature flags that have allow_tester_bypass=true. Server-side only — never expose to clients.',
  false
)
ON CONFLICT (key) DO NOTHING;
