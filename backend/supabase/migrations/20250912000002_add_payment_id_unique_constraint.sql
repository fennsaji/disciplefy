-- Migration: Add UNIQUE constraint on payment_id
-- Date: 2025-09-12
-- Purpose: Prevent double-credit from webhook retries by ensuring payment_id uniqueness

-- Add UNIQUE constraint on payment_id (excluding NULL values)
-- This prevents the same Razorpay payment_id from being processed multiple times
CREATE UNIQUE INDEX idx_pending_purchases_payment_id_unique 
ON pending_token_purchases(payment_id) 
WHERE payment_id IS NOT NULL;

-- Add UNIQUE constraint on payment_id in purchase_history table as well
-- This is the final safeguard against double-crediting tokens
CREATE UNIQUE INDEX IF NOT EXISTS idx_purchase_history_payment_id_unique
ON purchase_history(payment_id) 
WHERE payment_id IS NOT NULL;

-- Add comment explaining the constraint
COMMENT ON INDEX idx_pending_purchases_payment_id_unique IS 'Ensures payment_id uniqueness to prevent double-processing from webhook retries';
COMMENT ON INDEX idx_purchase_history_payment_id_unique IS 'Ensures payment_id uniqueness in completed purchases to prevent double-crediting';