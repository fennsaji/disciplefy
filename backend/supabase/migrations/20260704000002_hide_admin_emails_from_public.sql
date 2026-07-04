-- Close a pre-existing anon-key exposure of the admin email allowlist.
--
-- system_config has a public RLS SELECT policy (USING (is_active = true)) plus
-- GRANT SELECT ... TO anon, and the get_system_configs() RPC (granted to anon +
-- authenticated) returns every is_active = true row. The 'admin_emails' row was
-- seeded with is_active = true, so any client holding only the public anon key
-- could read the admin email list via:
--   GET /rest/v1/system_config?key=eq.admin_emails
--   POST /rest/v1/rpc/get_system_configs
--
-- admin_emails is only ever consumed server-side by autoGrantAdminIfEligible
-- (user-profile Edge Function), which reads it with the service-role client
-- (bypasses RLS, no is_active filter), so hiding it from the public paths does
-- not affect the admin auto-grant. Mirror the feature_tester_emails handling.

UPDATE system_config
SET is_active = false,
    updated_at = NOW()
WHERE key = 'admin_emails';
