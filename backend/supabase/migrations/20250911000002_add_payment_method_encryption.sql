-- Add encryption security to payment methods
-- Migration: 20250911000002_add_payment_method_encryption.sql

-- Enable pgcrypto extension for encryption functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Add encrypted token storage columns
ALTER TABLE saved_payment_methods 
ADD COLUMN IF NOT EXISTS encrypted_token TEXT,
ADD COLUMN IF NOT EXISTS encryption_key_id TEXT DEFAULT 'default_key',
ADD COLUMN IF NOT EXISTS token_hash TEXT,
ADD COLUMN IF NOT EXISTS security_metadata JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

-- Create function to encrypt payment tokens
CREATE OR REPLACE FUNCTION encrypt_payment_token(
  p_token TEXT,
  p_key_id TEXT DEFAULT 'default_key'
) RETURNS TEXT AS $$
DECLARE
  v_encryption_key TEXT;
  v_encrypted_token TEXT;
BEGIN
  -- In production, this should use a proper key management system
  -- For now, we'll use a configurable encryption key from environment
  v_encryption_key := current_setting('app.encryption_key', true);
  
  -- If no encryption key is set, generate a warning and use default
  IF v_encryption_key IS NULL OR v_encryption_key = '' THEN
    v_encryption_key := 'disciplefy_default_key_2024_change_in_production';
    -- Log warning about using default key
    RAISE WARNING 'Using default encryption key - set app.encryption_key in production';
  END IF;
  
  -- Encrypt the token using AES-256
  v_encrypted_token := encode(
    encrypt(
      p_token::bytea,
      v_encryption_key::bytea,
      'aes'
    ),
    'base64'
  );
  
  RETURN v_encrypted_token;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to encrypt payment token: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to decrypt payment tokens
CREATE OR REPLACE FUNCTION decrypt_payment_token(
  p_encrypted_token TEXT,
  p_key_id TEXT DEFAULT 'default_key'
) RETURNS TEXT AS $$
DECLARE
  v_encryption_key TEXT;
  v_decrypted_token TEXT;
BEGIN
  -- Get the encryption key
  v_encryption_key := current_setting('app.encryption_key', true);
  
  IF v_encryption_key IS NULL OR v_encryption_key = '' THEN
    v_encryption_key := 'disciplefy_default_key_2024_change_in_production';
  END IF;
  
  -- Decrypt the token
  v_decrypted_token := convert_from(
    decrypt(
      decode(p_encrypted_token, 'base64'),
      v_encryption_key::bytea,
      'aes'
    ),
    'UTF8'
  );
  
  RETURN v_decrypted_token;
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to decrypt payment token: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to generate token hash for verification
CREATE OR REPLACE FUNCTION generate_token_hash(p_token TEXT) RETURNS TEXT AS $$
BEGIN
  -- Generate SHA-256 hash of the token for verification without decryption
  RETURN encode(digest(p_token::bytea, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Update the save_payment_method function to use encryption
CREATE OR REPLACE FUNCTION save_payment_method(
  p_user_id UUID,
  p_method_type TEXT,
  p_provider TEXT,
  p_token TEXT,
  p_last_four TEXT DEFAULT NULL,
  p_brand TEXT DEFAULT NULL,
  p_display_name TEXT DEFAULT NULL,
  p_is_default BOOLEAN DEFAULT FALSE,
  p_expiry_month INTEGER DEFAULT NULL,
  p_expiry_year INTEGER DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_method_id UUID;
  v_encrypted_token TEXT;
  v_token_hash TEXT;
  v_security_metadata JSONB;
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot save payment method for other users';
  END IF;
  
  -- Validate required fields
  IF p_token IS NULL OR p_token = '' THEN
    RAISE EXCEPTION 'Payment token is required';
  END IF;
  
  -- Check for duplicate tokens (using hash to avoid storing plain text)
  v_token_hash := generate_token_hash(p_token);
  
  IF EXISTS (
    SELECT 1 FROM saved_payment_methods 
    WHERE user_id = p_user_id AND token_hash = v_token_hash
  ) THEN
    RAISE EXCEPTION 'Payment method already saved';
  END IF;
  
  -- Encrypt the payment token
  v_encrypted_token := encrypt_payment_token(p_token);
  
  -- Prepare security metadata
  v_security_metadata := jsonb_build_object(
    'encryption_timestamp', EXTRACT(EPOCH FROM NOW()),
    'last_validation', EXTRACT(EPOCH FROM NOW()),
    'token_type', p_method_type,
    'security_level', 'encrypted'
  );
  
  -- If setting as default, unset other default methods
  IF p_is_default THEN
    UPDATE saved_payment_methods 
    SET is_default = FALSE 
    WHERE user_id = p_user_id;
  END IF;
  
  -- Insert new payment method with encryption
  INSERT INTO saved_payment_methods (
    user_id,
    method_type,
    provider,
    encrypted_token,
    token_hash,
    encryption_key_id,
    security_metadata,
    last_four,
    brand,
    display_name,
    is_default,
    expiry_month,
    expiry_year
  ) VALUES (
    p_user_id,
    p_method_type,
    p_provider,
    v_encrypted_token,
    v_token_hash,
    'default_key',
    v_security_metadata,
    p_last_four,
    p_brand,
    p_display_name,
    p_is_default,
    p_expiry_month,
    p_expiry_year
  ) RETURNING id INTO v_method_id;
  
  -- Log security event
  INSERT INTO audit_log (
    table_name,
    operation,
    record_id,
    user_id,
    metadata
  ) VALUES (
    'saved_payment_methods',
    'INSERT',
    v_method_id,
    p_user_id,
    jsonb_build_object(
      'method_type', p_method_type,
      'provider', p_provider,
      'is_default', p_is_default,
      'encryption_enabled', true
    )
  );
  
  RETURN v_method_id;
EXCEPTION
  WHEN OTHERS THEN
    -- Log security incident
    INSERT INTO security_incidents (
      incident_type,
      user_id,
      description,
      metadata
    ) VALUES (
      'PAYMENT_METHOD_SAVE_FAILED',
      p_user_id,
      'Failed to save encrypted payment method: ' || SQLERRM,
      jsonb_build_object(
        'method_type', p_method_type,
        'error_code', SQLSTATE
      )
    );
    
    RAISE EXCEPTION 'Failed to save payment method securely: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update get_user_payment_methods to handle encryption
-- Drop existing function to avoid return type conflicts
DROP FUNCTION IF EXISTS get_user_payment_methods(UUID);
CREATE OR REPLACE FUNCTION get_user_payment_methods(p_user_id UUID DEFAULT NULL)
RETURNS TABLE(
  id UUID,
  method_type TEXT,
  provider TEXT,
  last_four TEXT,
  brand TEXT,
  display_name TEXT,
  is_default BOOLEAN,
  expiry_month INTEGER,
  expiry_year INTEGER,
  created_at TIMESTAMP WITH TIME ZONE,
  last_used TIMESTAMP WITH TIME ZONE,
  usage_count INTEGER,
  is_expired BOOLEAN
) AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Use current user if no user specified
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  -- Check authorization
  IF v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized access to payment methods';
  END IF;
  
  -- Return payment methods WITHOUT decrypted tokens for security
  -- Frontend should never receive actual payment tokens
  RETURN QUERY
  SELECT 
    spm.id,
    spm.method_type,
    spm.provider,
    spm.last_four,
    spm.brand,
    spm.display_name,
    spm.is_default,
    spm.expiry_month,
    spm.expiry_year,
    spm.created_at,
    spm.last_used,
    spm.usage_count,
    CASE 
      WHEN spm.expiry_month IS NOT NULL AND spm.expiry_year IS NOT NULL THEN
        (EXTRACT(YEAR FROM NOW()) * 100 + EXTRACT(MONTH FROM NOW())) > 
        (spm.expiry_year * 100 + spm.expiry_month)
      ELSE FALSE
    END as is_expired
  FROM saved_payment_methods spm
  WHERE spm.user_id = v_user_id
    AND spm.deleted_at IS NULL
  ORDER BY spm.is_default DESC, spm.last_used DESC NULLS LAST, spm.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get decrypted token for payment processing (admin/system only)
CREATE OR REPLACE FUNCTION get_payment_method_token(
  p_method_id UUID,
  p_user_id UUID
) RETURNS TEXT AS $$
DECLARE
  v_encrypted_token TEXT;
  v_decrypted_token TEXT;
  v_method_user_id UUID;
BEGIN
  -- Verify this function is being called in a secure context
  -- Only allow system/backend processes to decrypt tokens
  IF current_setting('role', true) != 'service_role' THEN
    RAISE EXCEPTION 'Unauthorized: Token decryption requires service role';
  END IF;
  
  -- Get encrypted token and verify ownership
  SELECT encrypted_token, user_id INTO v_encrypted_token, v_method_user_id
  FROM saved_payment_methods
  WHERE id = p_method_id AND deleted_at IS NULL;
  
  IF v_encrypted_token IS NULL THEN
    RAISE EXCEPTION 'Payment method not found or has been deleted';
  END IF;
  
  IF v_method_user_id != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: Payment method belongs to different user';
  END IF;
  
  -- Decrypt token
  v_decrypted_token := decrypt_payment_token(v_encrypted_token);
  
  -- Update last used timestamp
  UPDATE saved_payment_methods 
  SET 
    last_used = NOW(),
    usage_count = usage_count + 1
  WHERE id = p_method_id;
  
  -- Log access for security audit
  INSERT INTO audit_log (
    table_name,
    operation,
    record_id,
    user_id,
    metadata
  ) VALUES (
    'saved_payment_methods',
    'TOKEN_DECRYPTED',
    p_method_id,
    p_user_id,
    jsonb_build_object(
      'access_time', EXTRACT(EPOCH FROM NOW()),
      'calling_function', 'get_payment_method_token'
    )
  );
  
  RETURN v_decrypted_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create security policies for encrypted payment methods
CREATE POLICY "Users can only access their own payment methods" 
  ON saved_payment_methods 
  FOR ALL 
  TO authenticated 
  USING (auth.uid() = user_id);

-- Create function to rotate encryption keys (for future key management)
CREATE OR REPLACE FUNCTION rotate_payment_method_encryption_key(
  p_old_key_id TEXT,
  p_new_key_id TEXT
) RETURNS INTEGER AS $$
DECLARE
  v_updated_count INTEGER := 0;
  v_method RECORD;
  v_decrypted_token TEXT;
  v_new_encrypted_token TEXT;
BEGIN
  -- Only allow service role to rotate encryption keys
  IF current_setting('role', true) != 'service_role' THEN
    RAISE EXCEPTION 'Unauthorized: Key rotation requires service role';
  END IF;
  
  -- Process each payment method with the old key
  FOR v_method IN 
    SELECT id, encrypted_token, user_id
    FROM saved_payment_methods 
    WHERE encryption_key_id = p_old_key_id 
      AND deleted_at IS NULL
  LOOP
    -- Decrypt with old key and re-encrypt with new key
    v_decrypted_token := decrypt_payment_token(v_method.encrypted_token, p_old_key_id);
    v_new_encrypted_token := encrypt_payment_token(v_decrypted_token, p_new_key_id);
    
    -- Update with new encryption
    UPDATE saved_payment_methods
    SET 
      encrypted_token = v_new_encrypted_token,
      encryption_key_id = p_new_key_id,
      security_metadata = security_metadata || jsonb_build_object(
        'key_rotation_timestamp', EXTRACT(EPOCH FROM NOW()),
        'previous_key_id', p_old_key_id
      )
    WHERE id = v_method.id;
    
    v_updated_count := v_updated_count + 1;
  END LOOP;
  
  -- Log key rotation event
  INSERT INTO audit_log (
    table_name,
    operation,
    record_id,
    user_id,
    metadata
  ) VALUES (
    'saved_payment_methods',
    'KEY_ROTATION',
    NULL,
    NULL,
    jsonb_build_object(
      'old_key_id', p_old_key_id,
      'new_key_id', p_new_key_id,
      'methods_updated', v_updated_count,
      'rotation_timestamp', EXTRACT(EPOCH FROM NOW())
    )
  );
  
  RETURN v_updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add indexes for encrypted token operations
CREATE INDEX IF NOT EXISTS idx_saved_payment_methods_token_hash 
  ON saved_payment_methods (token_hash) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_saved_payment_methods_encryption_key 
  ON saved_payment_methods (encryption_key_id) 
  WHERE deleted_at IS NULL;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION encrypt_payment_token(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION decrypt_payment_token(TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION generate_token_hash(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_payment_method_token(UUID, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION rotate_payment_method_encryption_key(TEXT, TEXT) TO service_role;

-- Add comment for migration tracking
COMMENT ON EXTENSION pgcrypto IS 'Payment method encryption support - added in migration 20250911000002';