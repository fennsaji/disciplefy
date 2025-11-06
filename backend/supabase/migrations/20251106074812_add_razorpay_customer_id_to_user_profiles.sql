-- Migration: Add Razorpay Customer ID to User Profiles
-- Description: Stores the Razorpay customer ID for each user to link subscriptions and payments properly

-- Add razorpay_customer_id column to user_profiles table
ALTER TABLE public.user_profiles
ADD COLUMN razorpay_customer_id TEXT DEFAULT NULL;

-- Add comment
COMMENT ON COLUMN public.user_profiles.razorpay_customer_id IS 'Razorpay customer ID for linking subscriptions and payments';

-- Create index for faster customer lookups
CREATE INDEX idx_user_profiles_razorpay_customer_id
ON public.user_profiles(razorpay_customer_id)
WHERE razorpay_customer_id IS NOT NULL;
