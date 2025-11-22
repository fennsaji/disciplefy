-- Add 'pending_cancellation' status to subscriptions table
-- This status represents subscriptions that are scheduled to cancel at the end of the billing period
-- but are still active and providing premium access.

-- Drop the existing status constraint
ALTER TABLE subscriptions DROP CONSTRAINT IF EXISTS subscriptions_status_check;

-- Add new constraint with pending_cancellation status
ALTER TABLE subscriptions ADD CONSTRAINT subscriptions_status_check
  CHECK (status IN (
    'created',
    'authenticated',
    'active',
    'pending_cancellation',  -- NEW: Scheduled for cancellation but still active
    'paused',
    'cancelled',
    'completed',
    'expired'
  ));

-- Update existing 'cancelled' subscriptions that have cancel_at_cycle_end=true
-- and are still within their active period to 'pending_cancellation'
UPDATE subscriptions
SET status = 'pending_cancellation'
WHERE status = 'cancelled'
  AND cancel_at_cycle_end = true
  AND current_period_end > NOW();

-- Add comment explaining the new status
COMMENT ON COLUMN subscriptions.status IS
  'Subscription status: created, authenticated, active, pending_cancellation (scheduled to cancel at cycle end), paused, cancelled, completed, expired';
