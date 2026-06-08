-- =====================================================
-- Restrict anonymous_sessions SELECT policy
-- =====================================================
-- Fixes HIGH: the SELECT policy "Allow anonymous session reads" used USING (true),
-- with no role restriction, letting any anon/authenticated caller using the anon
-- key read every session row (device_fingerprint_hash, ip_address_hash, activity
-- counters) — an IDOR / cross-session data exposure.
--
-- Mirrors the UPDATE policy fix in 20260409000001_fix_anonymous_sessions_rls.sql:
-- scope reads to the caller's own session via the app.session_id GUC. Server-side
-- Edge Functions use the service-role client (RLS bypassed), so this does not
-- affect backend session management.

DROP POLICY IF EXISTS "Allow anonymous session reads" ON anonymous_sessions;

CREATE POLICY "Allow anonymous session reads" ON anonymous_sessions
  FOR SELECT
  USING (session_id = (current_setting('app.session_id', true))::uuid);
