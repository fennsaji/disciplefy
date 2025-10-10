-- Create pending token purchases table for Razorpay payment processing
-- Migration: 20250910000001_create_pending_token_purchases.sql

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create pending_token_purchases table
CREATE TABLE IF NOT EXISTS pending_token_purchases (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    order_id TEXT UNIQUE NOT NULL,
    token_amount INTEGER NOT NULL CHECK (token_amount > 0 AND token_amount <= 10000),
    amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'expired')),
    payment_id TEXT,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '15 minutes')
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_pending_purchases_user_id ON pending_token_purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_pending_purchases_order_id ON pending_token_purchases(order_id);
CREATE INDEX IF NOT EXISTS idx_pending_purchases_status ON pending_token_purchases(status);
CREATE INDEX IF NOT EXISTS idx_pending_purchases_created_at ON pending_token_purchases(created_at);

-- Create function to store pending purchase
CREATE OR REPLACE FUNCTION store_pending_purchase(
    p_user_id UUID,
    p_order_id TEXT,
    p_token_amount INTEGER,
    p_amount_paise INTEGER
) RETURNS BOOLEAN AS $$
BEGIN
    -- Insert pending purchase record
    INSERT INTO pending_token_purchases (
        user_id, 
        order_id, 
        token_amount, 
        amount_paise,
        status,
        created_at,
        updated_at,
        expires_at
    ) VALUES (
        p_user_id, 
        p_order_id, 
        p_token_amount, 
        p_amount_paise,
        'pending',
        NOW(),
        NOW(),
        NOW() + INTERVAL '15 minutes'
    );
    
    RETURN TRUE;
EXCEPTION
    WHEN unique_violation THEN
        -- Order ID already exists
        RAISE EXCEPTION 'Order ID already exists: %', p_order_id;
    WHEN OTHERS THEN
        -- Other errors
        RAISE EXCEPTION 'Failed to store pending purchase: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update pending purchase status
CREATE OR REPLACE FUNCTION update_pending_purchase_status(
    p_order_id TEXT,
    p_status TEXT,
    p_payment_id TEXT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    -- Validate status
    IF p_status NOT IN ('pending', 'completed', 'failed', 'expired') THEN
        RAISE EXCEPTION 'Invalid status: %', p_status;
    END IF;

    -- Update the pending purchase
    UPDATE pending_token_purchases 
    SET 
        status = p_status,
        payment_id = COALESCE(p_payment_id, payment_id),
        error_message = COALESCE(p_error_message, error_message),
        updated_at = NOW()
    WHERE order_id = p_order_id;
    
    -- Check if row was updated
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pending purchase not found for order: %', p_order_id;
    END IF;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to update pending purchase: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get pending purchase by order ID
CREATE OR REPLACE FUNCTION get_pending_purchase(
    p_order_id TEXT
) RETURNS TABLE (
    id UUID,
    user_id UUID,
    order_id TEXT,
    token_amount INTEGER,
    amount_paise INTEGER,
    status TEXT,
    payment_id TEXT,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pp.id,
        pp.user_id,
        pp.order_id,
        pp.token_amount,
        pp.amount_paise,
        pp.status,
        pp.payment_id,
        pp.error_message,
        pp.created_at,
        pp.updated_at,
        pp.expires_at
    FROM pending_token_purchases pp
    WHERE pp.order_id = p_order_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to cleanup expired pending purchases
CREATE OR REPLACE FUNCTION cleanup_expired_pending_purchases()
RETURNS INTEGER AS $$
DECLARE
    affected_rows INTEGER;
BEGIN
    -- Update expired pending purchases
    UPDATE pending_token_purchases
    SET 
        status = 'expired',
        updated_at = NOW()
    WHERE 
        status = 'pending' 
        AND expires_at < NOW();
        
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    
    -- Log cleanup activity
    RAISE LOG 'Cleaned up % expired pending purchases', affected_rows;
    
    RETURN affected_rows;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable Row Level Security
ALTER TABLE pending_token_purchases ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only see their own pending purchases
CREATE POLICY "Users can view own pending purchases" ON pending_token_purchases
    FOR SELECT USING (auth.uid() = user_id);

-- RLS Policy: Users can insert their own pending purchases
CREATE POLICY "Users can insert own pending purchases" ON pending_token_purchases
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own pending purchases
CREATE POLICY "Users can update own pending purchases" ON pending_token_purchases
    FOR UPDATE USING (auth.uid() = user_id);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON pending_token_purchases TO authenticated;
GRANT EXECUTE ON FUNCTION store_pending_purchase TO authenticated;
GRANT EXECUTE ON FUNCTION update_pending_purchase_status TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_purchase TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_expired_pending_purchases TO authenticated;

-- Comment the table and functions
COMMENT ON TABLE pending_token_purchases IS 'Stores pending token purchases awaiting Razorpay payment confirmation';
COMMENT ON FUNCTION store_pending_purchase IS 'Creates a new pending purchase record';
COMMENT ON FUNCTION update_pending_purchase_status IS 'Updates the status of a pending purchase';
COMMENT ON FUNCTION get_pending_purchase IS 'Retrieves pending purchase details by order ID';
COMMENT ON FUNCTION cleanup_expired_pending_purchases IS 'Marks expired pending purchases as expired';