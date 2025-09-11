-- Migration: Create Purchase History System
-- Date: January 10, 2025
-- Purpose: Add comprehensive purchase history tracking for Phase 2

-- Create purchase_history table
CREATE TABLE purchase_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Purchase Details
  token_amount INTEGER NOT NULL CHECK (token_amount > 0),
  cost_rupees DECIMAL(10,2) NOT NULL CHECK (cost_rupees > 0),
  cost_paise INTEGER NOT NULL CHECK (cost_paise > 0),
  
  -- Payment Details
  payment_id TEXT NOT NULL,
  order_id TEXT NOT NULL,
  payment_method TEXT, -- 'card', 'upi', 'netbanking', 'wallet', etc.
  payment_provider TEXT DEFAULT 'razorpay',
  
  -- Status and Metadata
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'failed', 'refunded', 'pending')),
  receipt_url TEXT, -- For receipt storage
  receipt_number TEXT UNIQUE, -- Generated receipt number
  
  -- Timestamps
  purchased_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for efficient queries
CREATE INDEX idx_purchase_history_user_id ON purchase_history(user_id);
CREATE INDEX idx_purchase_history_status ON purchase_history(status);
CREATE INDEX idx_purchase_history_purchased_at ON purchase_history(purchased_at DESC);
CREATE INDEX idx_purchase_history_payment_id ON purchase_history(payment_id);
CREATE INDEX idx_purchase_history_receipt_number ON purchase_history(receipt_number);

-- Enable RLS
ALTER TABLE purchase_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own purchase history" 
ON purchase_history FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage purchase history" 
ON purchase_history FOR ALL 
USING (auth.role() = 'service_role');

-- Function to generate receipt number
CREATE OR REPLACE FUNCTION generate_receipt_number()
RETURNS TEXT AS $$
DECLARE
  receipt_num TEXT;
  year_month TEXT;
  sequence_num INTEGER;
BEGIN
  -- Format: DISC-YYYYMM-NNNN (e.g., DISC-202501-0001)
  year_month := TO_CHAR(NOW(), 'YYYYMM');
  
  -- Get next sequence number for this month
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(receipt_number FROM 'DISC-[0-9]{6}-([0-9]{4})') AS INTEGER)
  ), 0) + 1
  INTO sequence_num
  FROM purchase_history
  WHERE receipt_number LIKE 'DISC-' || year_month || '-%';
  
  receipt_num := 'DISC-' || year_month || '-' || LPAD(sequence_num::TEXT, 4, '0');
  
  RETURN receipt_num;
END;
$$ LANGUAGE plpgsql;

-- Function to record purchase in history
CREATE OR REPLACE FUNCTION record_purchase_history(
  p_user_id UUID,
  p_token_amount INTEGER,
  p_cost_rupees DECIMAL,
  p_cost_paise INTEGER,
  p_payment_id TEXT,
  p_order_id TEXT,
  p_payment_method TEXT DEFAULT NULL,
  p_status TEXT DEFAULT 'completed'
) RETURNS UUID AS $$
DECLARE
  history_id UUID;
  receipt_num TEXT;
BEGIN
  -- Generate receipt number
  receipt_num := generate_receipt_number();
  
  -- Insert purchase history record
  INSERT INTO purchase_history (
    user_id,
    token_amount,
    cost_rupees,
    cost_paise,
    payment_id,
    order_id,
    payment_method,
    status,
    receipt_number
  ) VALUES (
    p_user_id,
    p_token_amount,
    p_cost_rupees,
    p_cost_paise,
    p_payment_id,
    p_order_id,
    p_payment_method,
    p_status,
    receipt_num
  ) RETURNING id INTO history_id;
  
  RETURN history_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user purchase history with pagination
CREATE OR REPLACE FUNCTION get_user_purchase_history(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
) RETURNS TABLE (
  id UUID,
  token_amount INTEGER,
  cost_rupees DECIMAL(10,2),
  payment_method TEXT,
  status TEXT,
  receipt_number TEXT,
  purchased_at TIMESTAMP WITH TIME ZONE,
  payment_id TEXT,
  order_id TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ph.id,
    ph.token_amount,
    ph.cost_rupees,
    ph.payment_method,
    ph.status,
    ph.receipt_number,
    ph.purchased_at,
    ph.payment_id,
    ph.order_id
  FROM purchase_history ph
  WHERE ph.user_id = p_user_id
  ORDER BY ph.purchased_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get purchase statistics for user
CREATE OR REPLACE FUNCTION get_user_purchase_stats(p_user_id UUID)
RETURNS TABLE (
  total_purchases INTEGER,
  total_tokens INTEGER,
  total_spent DECIMAL(10,2),
  average_purchase DECIMAL(10,2),
  last_purchase_date TIMESTAMP WITH TIME ZONE,
  most_used_payment_method TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH stats AS (
    SELECT 
      COUNT(*)::INTEGER as purchase_count,
      SUM(ph.token_amount)::INTEGER as token_sum,
      SUM(ph.cost_rupees)::DECIMAL(10,2) as spent_sum,
      AVG(ph.cost_rupees)::DECIMAL(10,2) as avg_purchase,
      MAX(ph.purchased_at) as last_purchase,
      MODE() WITHIN GROUP (ORDER BY ph.payment_method) as common_method
    FROM purchase_history ph
    WHERE ph.user_id = p_user_id
      AND ph.status = 'completed'
  )
  SELECT 
    s.purchase_count,
    s.token_sum,
    s.spent_sum,
    s.avg_purchase,
    s.last_purchase,
    s.common_method
  FROM stats s;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update trigger for updated_at
CREATE OR REPLACE FUNCTION update_purchase_history_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_purchase_history_updated_at
  BEFORE UPDATE ON purchase_history
  FOR EACH ROW
  EXECUTE FUNCTION update_purchase_history_updated_at();

-- Grant permissions
GRANT SELECT ON purchase_history TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_purchase_history(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_purchase_stats(UUID) TO authenticated;