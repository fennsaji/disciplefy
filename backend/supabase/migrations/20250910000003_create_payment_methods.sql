-- Create payment methods table for Phase 3 advanced features
-- Stores user's saved payment methods for quick purchases

CREATE TABLE saved_payment_methods (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  method_type TEXT NOT NULL CHECK (method_type IN ('card', 'upi', 'netbanking', 'wallet')),
  provider TEXT NOT NULL, -- 'razorpay', 'paytm', 'googlepay', etc.
  
  -- NOTE: Plaintext token column intentionally omitted for security
  -- Encrypted token storage will be added in 20250911000002_add_payment_method_encryption.sql
  last_four TEXT, -- Last 4 digits for cards, UPI ID suffix, etc.
  brand TEXT, -- 'visa', 'mastercard', 'upi', etc.
  
  -- Display information
  display_name TEXT, -- User-friendly name like "My Visa Card"
  is_default BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  
  -- Metadata
  expiry_month INTEGER, -- For cards
  expiry_year INTEGER,  -- For cards
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_used_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for performance
CREATE INDEX idx_saved_payment_methods_user_id ON saved_payment_methods(user_id);
CREATE INDEX idx_saved_payment_methods_user_default ON saved_payment_methods(user_id, is_default) WHERE is_default = TRUE;
CREATE INDEX idx_saved_payment_methods_active ON saved_payment_methods(user_id, is_active) WHERE is_active = TRUE;

-- RLS policies
ALTER TABLE saved_payment_methods ENABLE ROW LEVEL SECURITY;

-- Users can only see their own payment methods
CREATE POLICY "Users can view own payment methods" ON saved_payment_methods
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own payment methods
CREATE POLICY "Users can insert own payment methods" ON saved_payment_methods
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own payment methods
CREATE POLICY "Users can update own payment methods" ON saved_payment_methods
  FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own payment methods
CREATE POLICY "Users can delete own payment methods" ON saved_payment_methods
  FOR DELETE USING (auth.uid() = user_id);

-- Function to ensure only one default payment method per user
CREATE OR REPLACE FUNCTION ensure_single_default_payment_method()
RETURNS TRIGGER AS $$
BEGIN
  -- If setting this method as default, unset others
  IF NEW.is_default = TRUE THEN
    UPDATE saved_payment_methods 
    SET is_default = FALSE, updated_at = NOW()
    WHERE user_id = NEW.user_id 
      AND id != NEW.id 
      AND is_default = TRUE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to maintain single default payment method
CREATE TRIGGER trigger_ensure_single_default_payment_method
  BEFORE INSERT OR UPDATE ON saved_payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION ensure_single_default_payment_method();

-- Function to get user's payment methods
CREATE OR REPLACE FUNCTION get_user_payment_methods(p_user_id UUID DEFAULT NULL)
RETURNS TABLE(
  id UUID,
  method_type TEXT,
  provider TEXT,
  last_four TEXT,
  brand TEXT,
  display_name TEXT,
  is_default BOOLEAN,
  is_active BOOLEAN,
  expiry_month INTEGER,
  expiry_year INTEGER,
  created_at TIMESTAMP WITH TIME ZONE,
  last_used_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  -- Use current user if no user specified
  IF p_user_id IS NULL THEN
    p_user_id := auth.uid();
  END IF;
  
  -- Check user can only access their own methods
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized access to payment methods';
  END IF;
  
  RETURN QUERY
  SELECT 
    pm.id,
    pm.method_type,
    pm.provider,
    pm.last_four,
    pm.brand,
    pm.display_name,
    pm.is_default,
    pm.is_active,
    pm.expiry_month,
    pm.expiry_year,
    pm.created_at,
    pm.last_used_at
  FROM saved_payment_methods pm
  WHERE pm.user_id = p_user_id
    AND pm.is_active = TRUE
  ORDER BY pm.is_default DESC, pm.last_used_at DESC NULLS LAST, pm.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to save a payment method
CREATE OR REPLACE FUNCTION save_payment_method(
  p_user_id UUID,
  p_method_type TEXT,
  p_provider TEXT,
  p_last_four TEXT DEFAULT NULL,
  p_brand TEXT DEFAULT NULL,
  p_display_name TEXT DEFAULT NULL,
  p_is_default BOOLEAN DEFAULT FALSE,
  p_expiry_month INTEGER DEFAULT NULL,
  p_expiry_year INTEGER DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  v_method_id UUID;
BEGIN
  -- Check user authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot save payment method for another user';
  END IF;
  
  -- Insert payment method (token will be added via encryption migration)
  INSERT INTO saved_payment_methods (
    user_id,
    method_type,
    provider,
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
    p_last_four,
    p_brand,
    p_display_name,
    p_is_default,
    p_expiry_month,
    p_expiry_year
  ) RETURNING id INTO v_method_id;
  
  RETURN v_method_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update payment method last used
CREATE OR REPLACE FUNCTION update_payment_method_usage(
  p_method_id UUID,
  p_user_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot update payment method usage';
  END IF;
  
  -- Update last used timestamp
  UPDATE saved_payment_methods 
  SET last_used_at = NOW(), updated_at = NOW()
  WHERE id = p_method_id 
    AND user_id = p_user_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to set default payment method
CREATE OR REPLACE FUNCTION set_default_payment_method(
  p_method_id UUID,
  p_user_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot modify payment method';
  END IF;
  
  -- Update default status (trigger will handle unsetting others)
  UPDATE saved_payment_methods 
  SET is_default = TRUE, updated_at = NOW()
  WHERE id = p_method_id 
    AND user_id = p_user_id
    AND is_active = TRUE;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to delete payment method
CREATE OR REPLACE FUNCTION delete_payment_method(
  p_method_id UUID,
  p_user_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot delete payment method';
  END IF;
  
  -- Soft delete by setting inactive
  UPDATE saved_payment_methods 
  SET is_active = FALSE, is_default = FALSE, updated_at = NOW()
  WHERE id = p_method_id 
    AND user_id = p_user_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create payment preferences table
CREATE TABLE payment_preferences (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  
  -- Preference settings
  auto_save_methods BOOLEAN DEFAULT TRUE,
  preferred_method_type TEXT CHECK (preferred_method_type IN ('card', 'upi', 'netbanking', 'wallet')),
  enable_one_click_purchase BOOLEAN DEFAULT TRUE,
  require_cvv_for_saved_cards BOOLEAN DEFAULT TRUE,
  
  -- Mobile optimization preferences
  prefer_mobile_wallets BOOLEAN DEFAULT TRUE,
  enable_upi_autopay BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS for payment preferences
ALTER TABLE payment_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own payment preferences" ON payment_preferences
  FOR ALL USING (auth.uid() = user_id);

-- Function to get or create user payment preferences
CREATE OR REPLACE FUNCTION get_or_create_payment_preferences(p_user_id UUID DEFAULT NULL)
RETURNS payment_preferences AS $$
DECLARE
  v_preferences payment_preferences;
  v_user_id UUID;
BEGIN
  -- Use current user if no user specified
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  -- Check authorization
  IF v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized access to payment preferences';
  END IF;
  
  -- Try to get existing preferences
  SELECT * INTO v_preferences
  FROM payment_preferences
  WHERE user_id = v_user_id;
  
  -- Create if doesn't exist
  IF v_preferences IS NULL THEN
    INSERT INTO payment_preferences (user_id)
    VALUES (v_user_id)
    RETURNING * INTO v_preferences;
  END IF;
  
  RETURN v_preferences;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update payment preferences
CREATE OR REPLACE FUNCTION update_payment_preferences(
  p_user_id UUID,
  p_auto_save_methods BOOLEAN DEFAULT NULL,
  p_preferred_method_type TEXT DEFAULT NULL,
  p_enable_one_click_purchase BOOLEAN DEFAULT NULL,
  p_require_cvv_for_saved_cards BOOLEAN DEFAULT NULL,
  p_prefer_mobile_wallets BOOLEAN DEFAULT NULL,
  p_enable_upi_autopay BOOLEAN DEFAULT NULL
) RETURNS payment_preferences AS $$
DECLARE
  v_preferences payment_preferences;
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot update payment preferences';
  END IF;
  
  -- Update preferences
  UPDATE payment_preferences 
  SET 
    auto_save_methods = COALESCE(p_auto_save_methods, auto_save_methods),
    preferred_method_type = COALESCE(p_preferred_method_type, preferred_method_type),
    enable_one_click_purchase = COALESCE(p_enable_one_click_purchase, enable_one_click_purchase),
    require_cvv_for_saved_cards = COALESCE(p_require_cvv_for_saved_cards, require_cvv_for_saved_cards),
    prefer_mobile_wallets = COALESCE(p_prefer_mobile_wallets, prefer_mobile_wallets),
    enable_upi_autopay = COALESCE(p_enable_upi_autopay, enable_upi_autopay),
    updated_at = NOW()
  WHERE user_id = p_user_id
  RETURNING * INTO v_preferences;
  
  -- Create if doesn't exist
  IF v_preferences IS NULL THEN
    INSERT INTO payment_preferences (
      user_id,
      auto_save_methods,
      preferred_method_type,
      enable_one_click_purchase,
      require_cvv_for_saved_cards,
      prefer_mobile_wallets,
      enable_upi_autopay
    ) VALUES (
      p_user_id,
      COALESCE(p_auto_save_methods, TRUE),
      p_preferred_method_type,
      COALESCE(p_enable_one_click_purchase, TRUE),
      COALESCE(p_require_cvv_for_saved_cards, TRUE),
      COALESCE(p_prefer_mobile_wallets, TRUE),
      COALESCE(p_enable_upi_autopay, FALSE)
    ) RETURNING * INTO v_preferences;
  END IF;
  
  RETURN v_preferences;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update purchase_history to track payment method used
ALTER TABLE purchase_history 
ADD COLUMN saved_payment_method_id UUID REFERENCES saved_payment_methods(id) ON DELETE SET NULL;