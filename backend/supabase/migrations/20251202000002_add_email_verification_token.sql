-- Migration: Add email verification token fields to user_profiles
-- These are used for our custom delayed email verification flow

-- Add verification token column
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS email_verification_token TEXT;

-- Add token expiry column
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS email_verification_token_expires_at TIMESTAMPTZ;

-- Create index for token lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_email_verification_token 
ON public.user_profiles(email_verification_token) 
WHERE email_verification_token IS NOT NULL;

-- Add comments for documentation
COMMENT ON COLUMN public.user_profiles.email_verification_token IS
'Secure token for email verification. Generated when user requests verification email.';

COMMENT ON COLUMN public.user_profiles.email_verification_token_expires_at IS
'Expiry timestamp for the verification token. Tokens expire after 24 hours.';
