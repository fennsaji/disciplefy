-- Add Phone Authentication Support Migration
-- Date: 2025-09-16
-- Purpose: Add mobile number authentication with OTP verification and profile setup tracking

-- Add phone authentication fields to user_profiles table
ALTER TABLE user_profiles ADD COLUMN phone_number TEXT;
ALTER TABLE user_profiles ADD COLUMN phone_verified BOOLEAN DEFAULT false;
ALTER TABLE user_profiles ADD COLUMN phone_country_code VARCHAR(5);

-- Add onboarding status tracking for new user flow
ALTER TABLE user_profiles ADD COLUMN onboarding_status VARCHAR(20) DEFAULT 'pending';
-- Possible values: 'pending', 'profile_setup', 'language_selection', 'completed'

-- Create OTP requests table for rate limiting and security
CREATE TABLE otp_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_number TEXT NOT NULL,
  otp_code VARCHAR(6) NOT NULL,
  ip_address INET,
  attempts INTEGER DEFAULT 0,
  is_verified BOOLEAN DEFAULT false,
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '10 minutes'),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for performance and cleanup
CREATE INDEX idx_otp_requests_phone ON otp_requests(phone_number);
CREATE INDEX idx_otp_requests_expires ON otp_requests(expires_at);
CREATE INDEX idx_otp_requests_created_at ON otp_requests(created_at DESC);

-- Add constraints for security
-- Ensure only one active (unverified, non-expired) OTP per phone number
-- Note: Cannot use NOW() in index predicate, will handle this with application logic
-- CREATE UNIQUE INDEX idx_otp_requests_active_phone ON otp_requests(phone_number) 
-- WHERE is_verified = false AND expires_at > NOW();

-- Add phone number uniqueness constraint (one account per phone number)
CREATE UNIQUE INDEX idx_user_profiles_phone ON user_profiles(phone_number) 
WHERE phone_number IS NOT NULL;

-- Add index for onboarding status queries
CREATE INDEX idx_user_profiles_onboarding_status ON user_profiles(onboarding_status);

-- Create RLS policies for OTP requests table
ALTER TABLE otp_requests ENABLE ROW LEVEL SECURITY;

-- Users can only access their own OTP records
-- Note: For phone auth, we allow access by phone number since user isn't authenticated yet
CREATE POLICY "Users can access own OTP requests" ON otp_requests
FOR ALL USING (
  auth.role() = 'service_role' OR 
  auth.uid()::text = phone_number
);

-- Service role can manage all OTP requests for backend functions
CREATE POLICY "Service role can manage OTP requests" ON otp_requests
FOR ALL USING (auth.role() = 'service_role');

-- Add trigger to automatically clean up expired OTP requests
CREATE OR REPLACE FUNCTION cleanup_expired_otp_requests()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM otp_requests 
  WHERE expires_at < NOW() - INTERVAL '1 hour';
END;
$$;

-- Create a scheduled job to run cleanup (if pg_cron is available)
-- Note: This requires pg_cron extension to be enabled
-- SELECT cron.schedule('cleanup-expired-otps', '0 */1 * * *', 'SELECT cleanup_expired_otp_requests();');

-- Add comments for documentation
COMMENT ON TABLE otp_requests IS 'Stores OTP verification codes for phone authentication with rate limiting';
COMMENT ON COLUMN user_profiles.phone_number IS 'User phone number in international format (+1234567890)';
COMMENT ON COLUMN user_profiles.phone_verified IS 'Whether the phone number has been verified via OTP';
COMMENT ON COLUMN user_profiles.phone_country_code IS 'Country code for the phone number (+1, +91, etc.)';
COMMENT ON COLUMN user_profiles.onboarding_status IS 'Current step in user onboarding flow';
COMMENT ON COLUMN otp_requests.attempts IS 'Number of failed verification attempts for this OTP';
COMMENT ON COLUMN otp_requests.expires_at IS 'When this OTP code expires (10 minutes from creation)';

-- Update existing users to have completed onboarding status
-- (since they're already using the app)
UPDATE user_profiles 
SET onboarding_status = 'completed' 
WHERE onboarding_status = 'pending' AND created_at < NOW();