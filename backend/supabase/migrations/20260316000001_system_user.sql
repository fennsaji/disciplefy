-- Insert a system/service-account user into auth.users so that
-- server-to-server calls (rs-backend CRON) can write study_guides
-- and study_guides_in_progress rows without FK violations.
--
-- Nil UUID (00000000-0000-0000-0000-000000000000) is the canonical
-- identifier for the internal system caller in auth-service.ts.

INSERT INTO auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'system@disciplefy.internal',
  '',
  now(),
  now(),
  '',
  '',
  '',
  ''
)
ON CONFLICT (id) DO NOTHING;

-- Also insert into user_profiles so is_admin = true is available
INSERT INTO user_profiles (id, is_admin)
VALUES ('00000000-0000-0000-0000-000000000000', true)
ON CONFLICT (id) DO NOTHING;
