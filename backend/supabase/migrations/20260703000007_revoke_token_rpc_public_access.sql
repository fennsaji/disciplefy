-- Security: revoke direct client access to token-mutating and secret-reading RPCs.
-- These functions are SECURITY DEFINER and were callable by anon/authenticated via
-- PostgREST (/rest/v1/rpc/...), bypassing the Edge Function authorization layer.
-- All legitimate callers use the service-role client inside Edge Functions.
--
-- Fixes: C1 (token-mint/plan-spoof), C3 (IAP secret disclosure), M8 (usage history IDOR).

-- Revoke from all roles that should never call these directly.
REVOKE EXECUTE ON FUNCTION get_or_create_user_tokens(TEXT, TEXT)         FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION consume_user_tokens(TEXT, TEXT, INTEGER)       FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION add_purchased_tokens(TEXT, TEXT, INTEGER)      FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION refund_user_tokens(TEXT, INTEGER, INTEGER)     FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION get_user_token_usage_history(UUID, INTEGER, INTEGER, TIMESTAMPTZ, TIMESTAMPTZ)
                                                                           FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION get_iap_config(TEXT, TEXT, TEXT)               FROM PUBLIC, anon, authenticated;

-- Prevent future functions from being accidentally world-executable.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
