-- Migration: Restore subscription_config table
-- Date: 2026-01-05
-- Description: Restores subscription_config table that was accidentally dropped
--              while still being used by subscription status functions

BEGIN;

-- ============================================================================
-- 1. Recreate subscription_config table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.subscription_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.subscription_config ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (read-only for authenticated users)
CREATE POLICY "Allow read access to all authenticated users"
  ON public.subscription_config
  FOR SELECT
  TO authenticated, anon
  USING (true);

-- Only service_role can modify
CREATE POLICY "Allow service_role to manage config"
  ON public.subscription_config
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 2. Insert configuration values (with extended 2026 dates)
-- ============================================================================

INSERT INTO public.subscription_config (key, value, description) VALUES
  (
    'standard_trial_end_date',
    '2026-03-31T23:59:59+05:30',
    'Standard plan trial period end date. All users get free Standard access until this date.'
  ),
  (
    'grace_period_days',
    '7',
    'Number of days grace period after trial ends'
  ),
  (
    'grace_period_end_date',
    '2026-04-07T23:59:59+05:30',
    'End date for grace period after trial ends. Users keep Standard access for 7 days after trial.'
  ),
  (
    'premium_trial_start_date',
    '2026-04-01T00:00:00+05:30',
    'Start date for Premium trial eligibility period'
  ),
  (
    'premium_trial_days',
    '7',
    'Duration of Premium trial in days'
  )
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- ============================================================================
-- 3. Grant permissions
-- ============================================================================

GRANT SELECT ON public.subscription_config TO authenticated, anon, service_role;

COMMIT;

-- Verification query
-- SELECT * FROM public.subscription_config ORDER BY key;
