-- Add email verification columns to user_profiles
-- Required by send-verification-email and verify-email Edge Functions

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS email_verification_token TEXT,
  ADD COLUMN IF NOT EXISTS email_verification_token_expires_at TIMESTAMPTZ;

-- Index for fast token lookups in the verify-email function
CREATE INDEX IF NOT EXISTS idx_user_profiles_email_verification_token
  ON user_profiles(email_verification_token)
  WHERE email_verification_token IS NOT NULL;
