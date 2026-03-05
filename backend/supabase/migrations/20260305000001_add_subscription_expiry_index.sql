-- Add composite index to speed up the daily subscription expiry cron query.
--
-- The check-subscription-status edge function runs at 2 AM UTC daily and
-- queries subscriptions filtered by status, current_period_end, and provider.
-- This partial index covers all three columns for that exact query pattern and
-- is scoped to only the non-terminal statuses that the cron actually touches.

CREATE INDEX IF NOT EXISTS idx_subscriptions_expiry_check
  ON subscriptions (status, current_period_end, provider)
  WHERE status IN ('active', 'pending_cancellation');
