-- =====================================================
-- Migration: Grant service_role SELECT on system_config
-- Date: 2026-09-06
-- Context:
--   20260513000001_explicit_data_api_grants.sql granted SELECT on
--   system_config to anon/authenticated but never to service_role, so any
--   Edge Function reading system_config directly via the service client
--   (e.g. discipler-service.ts's isDisciplerGloballyEnabled) gets
--   "permission denied for table system_config". service_role bypasses RLS
--   but still needs an explicit table-level GRANT.
-- =====================================================

GRANT SELECT ON public.system_config TO service_role;
