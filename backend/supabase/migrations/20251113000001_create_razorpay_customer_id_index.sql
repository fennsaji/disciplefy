-- Migration: Create Unique Index on Razorpay Customer ID
-- Description: Creates a unique partial index on razorpay_customer_id to enforce one customer ID per user
-- This must run outside a transaction block, so it's in a separate migration from the column addition

-- Create UNIQUE partial index to enforce one Razorpay customer ID per user
-- Partial index only includes non-null values (null values are allowed for users without Razorpay accounts)
-- Using CONCURRENTLY to avoid blocking reads/writes during index creation
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_user_profiles_razorpay_customer_id_unique
ON public.user_profiles(razorpay_customer_id)
WHERE razorpay_customer_id IS NOT NULL;
