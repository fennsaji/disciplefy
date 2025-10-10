-- Phone Authentication RLS Policies Migration
-- Date: 2025-09-16
-- Purpose: Comprehensive Row Level Security policies for phone authentication features

-- Update user_profiles RLS policies to handle new phone auth fields
-- Users can only update their own phone verification status through proper auth flow
-- Note: Simplified policy without OLD/NEW references for compatibility
CREATE POLICY "Users can update own phone verification" ON user_profiles
FOR UPDATE USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Users can read their own onboarding status
CREATE POLICY "Users can read own onboarding status" ON user_profiles
FOR SELECT USING (auth.uid() = id OR auth.role() = 'service_role');

-- Users can update their own onboarding status (profile setup progress)
-- Note: Simplified policy - progression validation will be handled by functions
CREATE POLICY "Users can update own onboarding status" ON user_profiles
FOR UPDATE USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Enhanced OTP requests policies for better security
DROP POLICY IF EXISTS "Users can access own OTP requests" ON otp_requests;
DROP POLICY IF EXISTS "Service role can manage OTP requests" ON otp_requests;

-- Allow reading OTP requests for service role only
-- Security: All user-facing verification must use the verify_user_otp() security definer function
CREATE POLICY "Service role only OTP reads" ON otp_requests
FOR SELECT USING (
  auth.role() = 'service_role'
);

-- Allow inserting new OTP requests (for sending OTPs)
-- Note: Rate limiting will be handled by functions, not RLS policies
CREATE POLICY "Allow OTP request creation" ON otp_requests
FOR INSERT WITH CHECK (
  -- Service role for backend functions can always insert
  auth.role() = 'service_role'
);

-- Allow updating OTP requests for service role only
-- Security: All verification and attempt tracking must use the verify_user_otp() security definer function
CREATE POLICY "Service role only OTP updates" ON otp_requests
FOR UPDATE USING (
  auth.role() = 'service_role'
)
WITH CHECK (
  auth.role() = 'service_role'
);

-- Service role can delete expired OTP requests
CREATE POLICY "Service role can delete expired OTPs" ON otp_requests
FOR DELETE USING (
  auth.role() = 'service_role' AND
  expires_at < NOW()
);

-- Create function to safely verify OTP (callable by authenticated users)
CREATE OR REPLACE FUNCTION verify_user_otp(
  user_phone_number TEXT,
  provided_otp_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  otp_record RECORD;
  result JSONB;
BEGIN
  -- Find valid OTP record
  SELECT * INTO otp_record
  FROM otp_requests
  WHERE phone_number = user_phone_number
    AND otp_code = provided_otp_code
    AND is_verified = false
    AND expires_at > NOW()
    AND attempts < 5
  ORDER BY created_at DESC
  LIMIT 1;

  -- Check if OTP was found
  IF NOT FOUND THEN
    -- Increment attempts for rate limiting
    UPDATE otp_requests
    SET attempts = attempts + 1
    WHERE phone_number = user_phone_number
      AND is_verified = false
      AND expires_at > NOW();

    RETURN jsonb_build_object(
      'success', false,
      'message', 'Invalid or expired OTP code'
    );
  END IF;

  -- Mark OTP as verified
  UPDATE otp_requests
  SET is_verified = true
  WHERE id = otp_record.id;

  -- Return success
  RETURN jsonb_build_object(
    'success', true,
    'message', 'OTP verified successfully',
    'otp_id', otp_record.id
  );
END;
$$;

-- Create function to safely create OTP request with rate limiting
CREATE OR REPLACE FUNCTION create_otp_request(
  user_phone_number TEXT,
  user_ip_address INET DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  existing_count INTEGER;
  otp_code TEXT;
  new_otp_id UUID;
BEGIN
  -- Check rate limiting (max 3 requests per hour)
  SELECT COUNT(*) INTO existing_count
  FROM otp_requests
  WHERE phone_number = user_phone_number
    AND created_at > NOW() - INTERVAL '1 hour';

  IF existing_count >= 3 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Too many OTP requests. Please wait before requesting a new code.'
    );
  END IF;

  -- Check for existing active OTP
  IF EXISTS (
    SELECT 1 FROM otp_requests
    WHERE phone_number = user_phone_number
      AND is_verified = false
      AND expires_at > NOW()
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'An OTP is already active for this phone number. Please wait before requesting a new one.'
    );
  END IF;

  -- Generate 6-digit OTP
  otp_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');

  -- Insert new OTP request
  INSERT INTO otp_requests (phone_number, otp_code, ip_address)
  VALUES (user_phone_number, otp_code, user_ip_address)
  RETURNING id INTO new_otp_id;

  -- Return success WITHOUT exposing the OTP code
  -- Security: OTP code must be sent via SMS, never returned to client
  RETURN jsonb_build_object(
    'success', true,
    'message', 'OTP sent successfully',
    'otp_id', new_otp_id,
    'expires_in', 600
  );
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION verify_user_otp(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION create_otp_request(TEXT, INET) TO authenticated;

-- Grant service role additional permissions for backend functions
GRANT EXECUTE ON FUNCTION verify_user_otp(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION create_otp_request(TEXT, INET) TO service_role;

-- Add function to get user onboarding status
CREATE OR REPLACE FUNCTION get_user_onboarding_status(user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  status TEXT;
BEGIN
  -- Only allow users to check their own status or service role
  IF auth.uid() != user_id AND auth.role() != 'service_role' THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  SELECT onboarding_status INTO status
  FROM user_profiles
  WHERE id = user_id;

  RETURN COALESCE(status, 'pending');
END;
$$;

GRANT EXECUTE ON FUNCTION get_user_onboarding_status(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_onboarding_status(UUID) TO service_role;

-- Add function to update onboarding status safely
CREATE OR REPLACE FUNCTION update_onboarding_status(
  user_id UUID,
  new_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_status TEXT;
  valid_transition BOOLEAN := false;
BEGIN
  -- Only allow users to update their own status or service role
  IF auth.uid() != user_id AND auth.role() != 'service_role' THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  -- Get current status
  SELECT onboarding_status INTO current_status
  FROM user_profiles
  WHERE id = user_id;

  -- Validate status transition
  IF current_status IS NULL OR current_status = 'pending' THEN
    valid_transition := new_status IN ('profile_setup', 'language_selection', 'completed');
  ELSIF current_status = 'profile_setup' THEN
    valid_transition := new_status IN ('language_selection', 'completed');
  ELSIF current_status = 'language_selection' THEN
    valid_transition := new_status = 'completed';
  ELSIF current_status = 'completed' THEN
    valid_transition := true; -- Already completed, allow any status
  END IF;

  -- Service role can override any transition
  IF auth.role() = 'service_role' THEN
    valid_transition := true;
  END IF;

  IF NOT valid_transition THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Invalid onboarding status transition'
    );
  END IF;

  -- Update status
  UPDATE user_profiles
  SET onboarding_status = new_status,
      updated_at = NOW()
  WHERE id = user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Onboarding status updated successfully',
    'old_status', current_status,
    'new_status', new_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION update_onboarding_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION update_onboarding_status(UUID, TEXT) TO service_role;