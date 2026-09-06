-- =====================================================
-- Migration: Discipler system user
-- Date: 2026-09-06
-- Adds the AI helper identity used by fellowship auto-replies and daily posts.
-- Pattern copied from 20260316000001_system_user.sql.
-- =====================================================

BEGIN;

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS is_system BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN user_profiles.is_system IS
  'True for machine authors (Discipler). Clients render an AI chip and hide report/block; counts exclude these rows.';

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  created_at, updated_at, confirmation_token, email_change,
  email_change_token_new, recovery_token, raw_user_meta_data, banned_until
)
VALUES (
  '00000000-0000-4000-8000-00000000d15c',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'discipler@disciplefy.in',
  '',
  now(), now(), '', '', '', '',
  '{"full_name": "Discipler", "name": "Discipler", "display_name": "Discipler"}'::jsonb,
  '2999-12-31T00:00:00Z'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO user_profiles (id, is_admin, is_system)
VALUES ('00000000-0000-4000-8000-00000000d15c', false, true)
ON CONFLICT (id) DO UPDATE SET is_system = true;

INSERT INTO public.system_config (key, value, description, is_active, metadata)
VALUES
  ('discipler_user_id', '00000000-0000-4000-8000-00000000d15c',
   'auth.users id of the Discipler AI helper', true, '{"category": "discipler"}'::jsonb),
  ('discipler_global_enabled', 'false',
   'Kill switch for all Discipler replies and reactions', true, '{"category": "discipler"}'::jsonb)
ON CONFLICT (key) DO UPDATE SET
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  metadata = EXCLUDED.metadata;

COMMIT;
