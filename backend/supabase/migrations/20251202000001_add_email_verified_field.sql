-- Migration: Add email_verified field to user_profiles for delayed verification tracking
-- This allows us to track email verification separately from Supabase's auto-confirmation

-- Add email_verified column to user_profiles
-- Defaults to false for new email signups, true for OAuth users
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false;

-- Update existing OAuth users to be marked as verified
-- (Google/Apple users don't need email verification)
UPDATE public.user_profiles up
SET email_verified = true
FROM auth.users au
WHERE up.id = au.id
  AND (au.raw_app_meta_data->>'provider' = 'google'
       OR au.raw_app_meta_data->>'provider' = 'apple');

-- Create function to set email_verified based on provider on profile creation
CREATE OR REPLACE FUNCTION public.set_email_verified_on_profile_create()
RETURNS TRIGGER AS $$
DECLARE
  user_provider TEXT;
BEGIN
  -- Get the provider from auth.users
  SELECT raw_app_meta_data->>'provider' INTO user_provider
  FROM auth.users
  WHERE id = NEW.id;

  -- Set email_verified to true for OAuth providers
  IF user_provider IN ('google', 'apple') THEN
    NEW.email_verified := true;
  ELSE
    NEW.email_verified := false;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new profile creation
DROP TRIGGER IF EXISTS on_profile_create_set_email_verified ON public.user_profiles;
CREATE TRIGGER on_profile_create_set_email_verified
  BEFORE INSERT ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_email_verified_on_profile_create();

-- Add comment for documentation
COMMENT ON COLUMN public.user_profiles.email_verified IS
'Tracks whether user has verified their email. Auto-set to true for OAuth users (Google/Apple).
Email/password users must click verification link to set this to true.';
