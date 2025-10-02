-- Add 'processing' status to pending_token_purchases check constraint
-- Migration: 20250913000004_add_processing_status.sql
-- Issue: Atomic claim logic needs 'processing' status but constraint only allows 'pending', 'completed', 'failed', 'expired'

-- Drop the existing constraint
ALTER TABLE pending_token_purchases
DROP CONSTRAINT IF EXISTS pending_token_purchases_status_check;

-- Add the constraint with 'processing' included
ALTER TABLE pending_token_purchases
ADD CONSTRAINT pending_token_purchases_status_check
CHECK (status = ANY (ARRAY['pending'::text, 'processing'::text, 'completed'::text, 'failed'::text, 'expired'::text]));

-- Update the store_pending_purchase function to allow 'processing' status in validation
CREATE OR REPLACE FUNCTION store_pending_purchase(
    p_order_id TEXT,
    p_user_id UUID,
    p_token_amount INTEGER,
    p_amount_paise INTEGER,
    p_status TEXT DEFAULT 'pending'
)
RETURNS UUID AS $$
DECLARE
    purchase_id UUID;
    purchase_expires_at TIMESTAMPTZ;
BEGIN
    -- SECURITY: Set explicit search_path to prevent hijacking
    SET LOCAL search_path = public, pg_catalog;

    -- Validate status parameter (updated to include 'processing')
    IF p_status NOT IN ('pending', 'processing', 'completed', 'failed', 'expired') THEN
        RAISE EXCEPTION 'Invalid status: %. Must be pending, processing, completed, failed, or expired', p_status;
    END IF;

    -- Validate token amount
    IF p_token_amount <= 0 OR p_token_amount > 10000 THEN
        RAISE EXCEPTION 'Token amount must be between 1 and 10000, got: %', p_token_amount;
    END IF;

    -- Validate amount in paise
    IF p_amount_paise <= 0 THEN
        RAISE EXCEPTION 'Amount in paise must be positive, got: %', p_amount_paise;
    END IF;

    -- Ensure user_id is provided and valid
    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'User ID cannot be null';
    END IF;

    -- Check if order already exists (idempotency check)
    SELECT id INTO purchase_id
    FROM pending_token_purchases
    WHERE order_id = p_order_id AND user_id = p_user_id;

    IF purchase_id IS NOT NULL THEN
        -- Order already exists, return existing ID
        RETURN purchase_id;
    END IF;

    -- Calculate expiration time (15 minutes from now)
    purchase_expires_at := NOW() + INTERVAL '15 minutes';

    -- Insert new pending purchase
    INSERT INTO pending_token_purchases (
        user_id,
        order_id,
        token_amount,
        amount_paise,
        status,
        expires_at
    ) VALUES (
        p_user_id,
        p_order_id,
        p_token_amount,
        p_amount_paise,
        p_status,
        purchase_expires_at
    ) RETURNING id INTO purchase_id;

    RETURN purchase_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;