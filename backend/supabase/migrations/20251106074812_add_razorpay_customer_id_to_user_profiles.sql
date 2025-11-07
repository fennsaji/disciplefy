-- Migration: Add Razorpay Customer ID to User Profiles
-- Description: Stores the Razorpay customer ID for each user to link subscriptions and payments properly
-- Each Razorpay customer ID must be unique across all users (one customer per user)

-- Add razorpay_customer_id column to user_profiles table
ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS razorpay_customer_id TEXT DEFAULT NULL;

-- Add comment
COMMENT ON COLUMN public.user_profiles.razorpay_customer_id IS 'Razorpay customer ID for linking subscriptions and payments (unique per user)';

-- Drop existing non-unique index if it exists (from earlier version of this migration)
DROP INDEX IF EXISTS idx_user_profiles_razorpay_customer_id;
