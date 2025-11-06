-- Make subscriptions unlimited by default (instead of 12 cycles)
-- Migration: 20251111000006_make_subscriptions_unlimited.sql
-- Changes total_count from INTEGER DEFAULT 12 to INTEGER DEFAULT NULL
-- NULL means unlimited subscription (no end date)

BEGIN;

-- 1. Allow NULL for total_count, remaining_count
ALTER TABLE public.subscriptions
  ALTER COLUMN total_count DROP DEFAULT,
  ALTER COLUMN total_count DROP NOT NULL,
  ALTER COLUMN remaining_count DROP DEFAULT,
  ALTER COLUMN remaining_count DROP NOT NULL;

-- 2. Set new defaults (NULL = unlimited)
ALTER TABLE public.subscriptions
  ALTER COLUMN total_count SET DEFAULT NULL,
  ALTER COLUMN remaining_count SET DEFAULT NULL;

-- 3. Update comment to explain unlimited subscriptions
COMMENT ON COLUMN public.subscriptions.total_count IS
  'Total billing cycles. NULL = unlimited subscription (continues until cancelled).';

COMMENT ON COLUMN public.subscriptions.remaining_count IS
  'Remaining billing cycles. NULL = unlimited (for unlimited subscriptions).';

-- 4. Update existing subscriptions with 12 cycles to be unlimited
-- This is optional - uncomment if you want to convert existing subscriptions
-- UPDATE public.subscriptions
-- SET total_count = NULL, remaining_count = NULL
-- WHERE total_count = 12;

COMMIT;
