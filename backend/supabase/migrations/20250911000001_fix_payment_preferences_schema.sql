-- Fix payment_preferences table schema to match frontend expectations
-- Migration: 20250911000001_fix_payment_preferences_schema.sql

-- Add missing columns that frontend expects
ALTER TABLE payment_preferences 
ADD COLUMN IF NOT EXISTS preferred_wallet TEXT,
ADD COLUMN IF NOT EXISTS default_payment_type TEXT CHECK (default_payment_type IN ('card', 'upi', 'netbanking', 'wallet'));

-- Update existing preferred_method_type to default_payment_type for consistency
-- Only assign values that match the CHECK constraint
UPDATE payment_preferences 
SET default_payment_type = CASE 
  WHEN preferred_method_type IN ('card', 'upi', 'netbanking', 'wallet') THEN preferred_method_type
  WHEN preferred_method_type = 'credit_card' OR preferred_method_type = 'debit_card' THEN 'card'
  WHEN preferred_method_type = 'mobile_wallet' THEN 'wallet'
  WHEN preferred_method_type = 'net_banking' THEN 'netbanking'
  ELSE 'card' -- Safe default for unrecognized values
END 
WHERE preferred_method_type IS NOT NULL;

-- Map existing mobile wallet preferences to new structure
UPDATE payment_preferences 
SET preferred_wallet = CASE 
  WHEN prefer_mobile_wallets = TRUE THEN 'paytm'
  ELSE NULL
END
WHERE preferred_wallet IS NULL;

-- Update the database functions to use correct column names
CREATE OR REPLACE FUNCTION get_or_create_payment_preferences()
RETURNS payment_preferences AS $
DECLARE
  v_preferences payment_preferences;
  v_user_id UUID;
BEGIN
  -- Always use current authenticated user
  v_user_id := auth.uid();
  
  -- Ensure user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  
  -- Try to get existing preferences
  SELECT * INTO v_preferences
  FROM payment_preferences
  WHERE user_id = v_user_id;
  
  -- Create if doesn't exist
  IF v_preferences IS NULL THEN
    INSERT INTO payment_preferences (
      user_id,
      auto_save_methods,
      preferred_wallet,
      enable_one_click_purchase,
      default_payment_type
    )
    VALUES (
      v_user_id,
      TRUE,
      NULL,
      TRUE,
      'card'
    )
    RETURNING * INTO v_preferences;
  END IF;
  
  RETURN v_preferences;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the payment preferences update function
CREATE OR REPLACE FUNCTION update_payment_preferences(
  p_user_id UUID,
  p_auto_save_payment_methods BOOLEAN DEFAULT NULL,
  p_preferred_wallet TEXT DEFAULT NULL,
  p_enable_one_click_purchase BOOLEAN DEFAULT NULL,
  p_default_payment_type TEXT DEFAULT NULL
) RETURNS payment_preferences AS $$
DECLARE
  v_preferences payment_preferences;
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot update payment preferences';
  END IF;
  
  -- Validate default_payment_type if provided
  IF p_default_payment_type IS NOT NULL AND 
     p_default_payment_type NOT IN ('card', 'upi', 'netbanking', 'wallet') THEN
    RAISE EXCEPTION 'Invalid payment type: %', p_default_payment_type;
  END IF;
  
  -- Update preferences
  UPDATE payment_preferences 
  SET 
    auto_save_methods = COALESCE(p_auto_save_payment_methods, auto_save_methods),
    preferred_wallet = COALESCE(p_preferred_wallet, preferred_wallet),
    enable_one_click_purchase = COALESCE(p_enable_one_click_purchase, enable_one_click_purchase),
    default_payment_type = COALESCE(p_default_payment_type, default_payment_type),
    updated_at = NOW()
  WHERE user_id = p_user_id
  RETURNING * INTO v_preferences;
  
  -- Create if doesn't exist
  IF v_preferences IS NULL THEN
    INSERT INTO payment_preferences (
      user_id,
      auto_save_methods,
      preferred_wallet,
      enable_one_click_purchase,
      default_payment_type
    ) VALUES (
      p_user_id,
      COALESCE(p_auto_save_payment_methods, TRUE),
      p_preferred_wallet,
      COALESCE(p_enable_one_click_purchase, TRUE),
      COALESCE(p_default_payment_type, 'card')
    ) RETURNING * INTO v_preferences;
  END IF;
  
  RETURN v_preferences;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add function to get payment preferences with proper column names
CREATE OR REPLACE FUNCTION get_payment_preferences_for_user(p_user_id UUID DEFAULT NULL)
RETURNS TABLE(
  id UUID,
  user_id UUID,
  auto_save_payment_methods BOOLEAN,
  preferred_wallet TEXT,
  enable_one_click_purchase BOOLEAN,
  default_payment_type TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Use current user if no user specified
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  -- Check authorization
  IF v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized access to payment preferences';
  END IF;
  
  -- Return preferences with mapped column names
  RETURN QUERY
  SELECT 
    pp.id,
    pp.user_id,
    pp.auto_save_methods as auto_save_payment_methods,
    pp.preferred_wallet,
    pp.enable_one_click_purchase,
    pp.default_payment_type,
    pp.created_at,
    pp.updated_at
  FROM payment_preferences pp
  WHERE pp.user_id = v_user_id;
  
  -- Create default preferences if none exist
  IF NOT FOUND THEN
    INSERT INTO payment_preferences (user_id)
    VALUES (v_user_id);
    
    -- Return the newly created preferences
    RETURN QUERY
    SELECT 
      pp.id,
      pp.user_id,
      pp.auto_save_methods as auto_save_payment_methods,
      pp.preferred_wallet,
      pp.enable_one_click_purchase,
      pp.default_payment_type,
      pp.created_at,
      pp.updated_at
    FROM payment_preferences pp
    WHERE pp.user_id = v_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add security function to validate payment method ownership
CREATE OR REPLACE FUNCTION validate_payment_method_ownership(
  p_method_id UUID,
  p_user_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
  v_count INTEGER;
BEGIN
  -- Check if payment method belongs to user
  SELECT COUNT(*) INTO v_count
  FROM saved_payment_methods
  WHERE id = p_method_id 
    AND user_id = p_user_id 
    AND is_active = TRUE;
  
  RETURN v_count > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add function to get valid payment methods (non-expired cards)
CREATE OR REPLACE FUNCTION get_valid_payment_methods(p_user_id UUID DEFAULT NULL)
RETURNS TABLE(
  id UUID,
  method_type TEXT,
  provider TEXT,
  token TEXT,
  last_four TEXT,
  brand TEXT,
  display_name TEXT,
  is_default BOOLEAN,
  is_active BOOLEAN,
  expiry_month INTEGER,
  expiry_year INTEGER,
  is_expired BOOLEAN,
  created_at TIMESTAMP WITH TIME ZONE,
  last_used_at TIMESTAMP WITH TIME ZONE
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
  
  RETURN QUERY
  SELECT 
    pm.id,
    pm.method_type,
    pm.provider,
    pm.token,
    pm.last_four,
    pm.brand,
    pm.display_name,
    pm.is_default,
    pm.is_active,
    pm.expiry_month,
    pm.expiry_year,
    -- Check if card is expired (only for cards) - using proper date comparison
    CASE 
      WHEN pm.method_type = 'card' AND pm.expiry_year IS NOT NULL AND pm.expiry_month IS NOT NULL
      THEN (
        -- Construct the last day of the expiry month and compare against current UTC date
        make_date(pm.expiry_year, pm.expiry_month, 
                 EXTRACT(DAY FROM (make_date(pm.expiry_year, pm.expiry_month, 1) + INTERVAL '1 month - 1 day'))::INTEGER
        ) < (NOW() AT TIME ZONE 'UTC')::date
      )
      ELSE FALSE
    END as is_expired,
    pm.created_at,
    pm.last_used_at
  FROM saved_payment_methods pm
  WHERE pm.user_id = v_user_id
    AND pm.is_active = TRUE
  ORDER BY pm.is_default DESC, pm.last_used_at DESC NULLS LAST, pm.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION get_payment_preferences_for_user TO authenticated;
GRANT EXECUTE ON FUNCTION validate_payment_method_ownership TO authenticated;
GRANT EXECUTE ON FUNCTION get_valid_payment_methods TO authenticated;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_payment_preferences_user_wallet ON payment_preferences(user_id, preferred_wallet);
CREATE INDEX IF NOT EXISTS idx_payment_methods_expiry ON saved_payment_methods(expiry_year, expiry_month) WHERE method_type = 'card';

-- Comment the functions
COMMENT ON FUNCTION get_payment_preferences_for_user IS 'Gets payment preferences with frontend-compatible column names';
COMMENT ON FUNCTION validate_payment_method_ownership IS 'Validates that a payment method belongs to the specified user';
COMMENT ON FUNCTION get_valid_payment_methods IS 'Gets payment methods with expiry validation for cards';