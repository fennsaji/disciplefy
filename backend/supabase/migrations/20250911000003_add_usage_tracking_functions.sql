-- Add comprehensive usage tracking for payment methods
-- Migration: 20250911000003_add_usage_tracking_functions.sql

-- Create payment method usage history table for detailed analytics
CREATE TABLE IF NOT EXISTS payment_method_usage_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  payment_method_id UUID NOT NULL REFERENCES saved_payment_methods(id) ON DELETE CASCADE,
  transaction_amount DECIMAL(10,2) NOT NULL,
  transaction_type TEXT NOT NULL, -- 'token_purchase', 'subscription', etc.
  transaction_id TEXT, -- Reference to the actual transaction
  metadata JSONB DEFAULT '{}'::jsonb,
  used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_payment_method_usage_history_user_id 
  ON payment_method_usage_history (user_id);
  
CREATE INDEX IF NOT EXISTS idx_payment_method_usage_history_payment_method_id 
  ON payment_method_usage_history (payment_method_id);
  
CREATE INDEX IF NOT EXISTS idx_payment_method_usage_history_used_at 
  ON payment_method_usage_history (used_at DESC);
  
CREATE INDEX IF NOT EXISTS idx_payment_method_usage_history_transaction_type 
  ON payment_method_usage_history (transaction_type);

-- Add RLS policies
ALTER TABLE payment_method_usage_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access their own usage history" 
  ON payment_method_usage_history 
  FOR ALL 
  TO authenticated 
  USING (auth.uid() = user_id);

-- Create function to record detailed payment method usage
CREATE OR REPLACE FUNCTION record_payment_method_usage(
  p_method_id UUID,
  p_user_id UUID,
  p_transaction_amount DECIMAL,
  p_transaction_type TEXT,
  p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS BOOLEAN AS $$
DECLARE
  v_method_exists BOOLEAN;
BEGIN
  -- Check authorization
  IF p_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: Cannot record usage for other users';
  END IF;
  
  -- Verify payment method exists and belongs to user
  SELECT EXISTS(
    SELECT 1 FROM saved_payment_methods 
    WHERE id = p_method_id 
      AND user_id = p_user_id 
      AND deleted_at IS NULL
  ) INTO v_method_exists;
  
  IF NOT v_method_exists THEN
    RAISE EXCEPTION 'Payment method not found or does not belong to user';
  END IF;
  
  -- Validate transaction amount
  IF p_transaction_amount <= 0 THEN
    RAISE EXCEPTION 'Transaction amount must be positive';
  END IF;
  
  -- Validate transaction type
  IF p_transaction_type IS NULL OR p_transaction_type = '' THEN
    RAISE EXCEPTION 'Transaction type is required';
  END IF;
  
  -- Record detailed usage in history table
  INSERT INTO payment_method_usage_history (
    user_id,
    payment_method_id,
    transaction_amount,
    transaction_type,
    metadata,
    used_at
  ) VALUES (
    p_user_id,
    p_method_id,
    p_transaction_amount,
    p_transaction_type,
    p_metadata,
    NOW()
  );
  
  -- Update the payment method's basic usage tracking
  UPDATE saved_payment_methods 
  SET 
    last_used = NOW(),
    usage_count = usage_count + 1,
    updated_at = NOW()
  WHERE id = p_method_id;
  
  -- Log the usage event for security audit
  INSERT INTO audit_log (
    table_name,
    operation,
    record_id,
    user_id,
    metadata
  ) VALUES (
    'saved_payment_methods',
    'USAGE_RECORDED',
    p_method_id,
    p_user_id,
    jsonb_build_object(
      'transaction_amount', p_transaction_amount,
      'transaction_type', p_transaction_type,
      'usage_timestamp', EXTRACT(EPOCH FROM NOW())
    )
  );
  
  RETURN TRUE;
  
EXCEPTION
  WHEN OTHERS THEN
    -- Log security incident for failed usage recording
    INSERT INTO security_incidents (
      incident_type,
      user_id,
      description,
      metadata
    ) VALUES (
      'PAYMENT_METHOD_USAGE_RECORDING_FAILED',
      p_user_id,
      'Failed to record payment method usage: ' || SQLERRM,
      jsonb_build_object(
        'payment_method_id', p_method_id,
        'transaction_amount', p_transaction_amount,
        'transaction_type', p_transaction_type,
        'error_code', SQLSTATE
      )
    );
    
    RAISE EXCEPTION 'Failed to record payment method usage: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get payment method usage analytics
CREATE OR REPLACE FUNCTION get_payment_method_usage_analytics(
  p_user_id UUID DEFAULT NULL,
  p_days_back INTEGER DEFAULT 30
) RETURNS TABLE(
  payment_method_id UUID,
  method_type TEXT,
  provider TEXT,
  display_name TEXT,
  total_usage_count INTEGER,
  total_transaction_amount DECIMAL,
  last_used_at TIMESTAMP WITH TIME ZONE,
  usage_frequency_score DECIMAL,
  preferred_transaction_types JSONB
) AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Use current user if no user specified
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  -- Check authorization
  IF v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized access to usage analytics';
  END IF;
  
  RETURN QUERY
  SELECT 
    spm.id as payment_method_id,
    spm.method_type,
    spm.provider,
    spm.display_name,
    COALESCE(spm.usage_count, 0) as total_usage_count,
    COALESCE(usage_stats.total_amount, 0) as total_transaction_amount,
    spm.last_used as last_used_at,
    -- Calculate usage frequency score (usage per day since creation)
    CASE 
      WHEN EXTRACT(DAYS FROM (NOW() - spm.created_at)) > 0 THEN
        COALESCE(spm.usage_count, 0)::DECIMAL / EXTRACT(DAYS FROM (NOW() - spm.created_at))
      ELSE 0
    END as usage_frequency_score,
    COALESCE(usage_stats.transaction_types, '[]'::jsonb) as preferred_transaction_types
  FROM saved_payment_methods spm
  LEFT JOIN (
    SELECT 
      pmuh.payment_method_id,
      SUM(pmuh.transaction_amount) as total_amount,
      jsonb_agg(
        DISTINCT jsonb_build_object(
          'type', pmuh.transaction_type,
          'count', transaction_type_counts.count
        )
      ) as transaction_types
    FROM payment_method_usage_history pmuh
    LEFT JOIN (
      SELECT 
        payment_method_id,
        transaction_type,
        COUNT(*) as count
      FROM payment_method_usage_history
      WHERE user_id = v_user_id
        AND used_at >= NOW() - (p_days_back || ' days')::INTERVAL
      GROUP BY payment_method_id, transaction_type
    ) transaction_type_counts 
      ON pmuh.payment_method_id = transaction_type_counts.payment_method_id
      AND pmuh.transaction_type = transaction_type_counts.transaction_type
    WHERE pmuh.user_id = v_user_id
      AND pmuh.used_at >= NOW() - (p_days_back || ' days')::INTERVAL
    GROUP BY pmuh.payment_method_id
  ) usage_stats ON spm.id = usage_stats.payment_method_id
  WHERE spm.user_id = v_user_id
    AND spm.deleted_at IS NULL
  ORDER BY 
    total_usage_count DESC,
    last_used_at DESC NULLS LAST,
    spm.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get payment method recommendations based on usage
CREATE OR REPLACE FUNCTION get_payment_method_recommendations(
  p_user_id UUID DEFAULT NULL,
  p_transaction_type TEXT DEFAULT NULL
) RETURNS TABLE(
  payment_method_id UUID,
  method_type TEXT,
  provider TEXT,
  display_name TEXT,
  recommendation_score DECIMAL,
  recommendation_reason TEXT
) AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Use current user if no user specified
  v_user_id := COALESCE(p_user_id, auth.uid());
  
  -- Check authorization
  IF v_user_id != auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized access to payment method recommendations';
  END IF;
  
  RETURN QUERY
  SELECT 
    spm.id as payment_method_id,
    spm.method_type,
    spm.provider,
    spm.display_name,
    -- Calculate recommendation score based on multiple factors
    (
      -- Usage frequency weight (40%)
      LEAST(COALESCE(spm.usage_count, 0)::DECIMAL / 10, 1) * 0.4 +
      
      -- Recency weight (30%) - more recent usage scores higher
      CASE 
        WHEN spm.last_used IS NOT NULL THEN
          GREATEST(0, 1 - (EXTRACT(DAYS FROM (NOW() - spm.last_used)) / 30)) * 0.3
        ELSE 0
      END +
      
      -- Default method bonus (20%)
      CASE WHEN spm.is_default THEN 0.2 ELSE 0 END +
      
      -- Transaction type match bonus (10%)
      CASE 
        WHEN p_transaction_type IS NOT NULL AND type_match.match_count > 0 THEN 0.1
        ELSE 0
      END
    ) * 100 as recommendation_score,
    
    -- Generate recommendation reason
    CASE
      WHEN spm.is_default AND spm.usage_count > 0 THEN 'Your most-used default method'
      WHEN spm.is_default THEN 'Your default payment method'
      WHEN spm.usage_count > 5 THEN 'Frequently used method'
      WHEN spm.last_used > NOW() - INTERVAL '7 days' THEN 'Recently used method'
      WHEN type_match.match_count > 0 THEN 'Good for ' || p_transaction_type || ' transactions'
      ELSE 'Available payment method'
    END as recommendation_reason
    
  FROM saved_payment_methods spm
  LEFT JOIN (
    SELECT 
      payment_method_id,
      COUNT(*) as match_count
    FROM payment_method_usage_history
    WHERE user_id = v_user_id
      AND transaction_type = p_transaction_type
      AND used_at >= NOW() - INTERVAL '90 days'
    GROUP BY payment_method_id
  ) type_match ON spm.id = type_match.payment_method_id
  
  WHERE spm.user_id = v_user_id
    AND spm.deleted_at IS NULL
    AND NOT (
      -- Exclude expired cards
      spm.method_type = 'card' 
      AND spm.expiry_month IS NOT NULL 
      AND spm.expiry_year IS NOT NULL
      AND (EXTRACT(YEAR FROM NOW()) * 100 + EXTRACT(MONTH FROM NOW())) > 
          (spm.expiry_year * 100 + spm.expiry_month)
    )
  ORDER BY recommendation_score DESC, spm.usage_count DESC, spm.created_at DESC
  LIMIT 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION record_payment_method_usage(UUID, UUID, DECIMAL, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION get_payment_method_usage_analytics(UUID, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_payment_method_recommendations(UUID, TEXT) TO authenticated;

-- Add comment for migration tracking
COMMENT ON TABLE payment_method_usage_history IS 'Detailed payment method usage tracking - added in migration 20250911000003';
COMMENT ON FUNCTION record_payment_method_usage(UUID, UUID, DECIMAL, TEXT, JSONB) IS 'Records detailed payment method usage with transaction context';
COMMENT ON FUNCTION get_payment_method_usage_analytics(UUID, INTEGER) IS 'Provides usage analytics for payment methods';
COMMENT ON FUNCTION get_payment_method_recommendations(UUID, TEXT) IS 'Suggests optimal payment methods based on usage patterns';