-- Migration: Make store_pending_purchase idempotent
-- Date: 2025-09-12
-- Purpose: Allow safe retries of store_pending_purchase without duplicate key errors

-- Drop existing function first (changing return type)
DROP FUNCTION IF EXISTS store_pending_purchase(UUID, TEXT, INTEGER, INTEGER);

-- Create the idempotent version with new return type
CREATE OR REPLACE FUNCTION store_pending_purchase(
    p_user_id UUID,
    p_order_id TEXT,
    p_token_amount INTEGER,
    p_amount_paise INTEGER
) RETURNS JSONB AS $$
DECLARE
    result JSONB;
    existing_record RECORD;
BEGIN
    -- Try to insert new pending purchase record
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
    )
    ON CONFLICT (order_id) DO NOTHING
    RETURNING id, status, created_at INTO existing_record;
    
    -- If we inserted a new record, return success
    IF existing_record.id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'action', 'created',
            'order_id', p_order_id,
            'status', existing_record.status,
            'created_at', existing_record.created_at
        );
    END IF;
    
    -- Record already exists, check if parameters match
    SELECT id, user_id, token_amount, amount_paise, status, created_at, updated_at
    INTO existing_record
    FROM pending_token_purchases
    WHERE order_id = p_order_id;
    
    -- Validate that existing record matches current parameters
    IF existing_record.user_id != p_user_id THEN
        RETURN jsonb_build_object(
            'success', false,
            'action', 'conflict',
            'error', 'Order ID belongs to different user',
            'order_id', p_order_id
        );
    END IF;
    
    IF existing_record.token_amount != p_token_amount OR existing_record.amount_paise != p_amount_paise THEN
        RETURN jsonb_build_object(
            'success', false,
            'action', 'conflict',
            'error', 'Order ID exists with different parameters',
            'order_id', p_order_id,
            'existing_token_amount', existing_record.token_amount,
            'existing_amount_paise', existing_record.amount_paise,
            'requested_token_amount', p_token_amount,
            'requested_amount_paise', p_amount_paise
        );
    END IF;
    
    -- Parameters match, return existing record info
    RETURN jsonb_build_object(
        'success', true,
        'action', 'exists',
        'order_id', p_order_id,
        'status', existing_record.status,
        'created_at', existing_record.created_at,
        'updated_at', existing_record.updated_at
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'action', 'error',
            'error', SQLERRM,
            'order_id', p_order_id
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update function comment
COMMENT ON FUNCTION store_pending_purchase IS 'Creates a new pending purchase record (idempotent - safe for retries)';