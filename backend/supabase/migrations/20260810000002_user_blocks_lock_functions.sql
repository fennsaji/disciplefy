-- =====================================================
-- Migration: Lock down user_blocks RPC functions
-- Date: 2026-08-10
-- Reason: block_user() and blocked_user_ids() default to PUBLIC EXECUTE,
--         which PostgREST exposes at /rest/v1/rpc/*. Any authenticated
--         client could forge blocks or enumerate who blocked whom.
--         Restrict execution to service_role only (Edge Functions call
--         these via services.supabaseServiceClient).
-- =====================================================

BEGIN;

REVOKE EXECUTE ON FUNCTION block_user(UUID, UUID, UUID, TEXT, UUID, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION blocked_user_ids(UUID) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION block_user(UUID, UUID, UUID, TEXT, UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION blocked_user_ids(UUID) TO service_role;

COMMIT;
