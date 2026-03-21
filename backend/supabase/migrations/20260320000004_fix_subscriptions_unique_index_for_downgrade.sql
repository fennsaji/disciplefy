-- Allow pending_cancellation subscriptions to coexist with new created/active ones.
--
-- This is required for the downgrade-at-cycle-end flow where:
--   1. Old (higher-tier) sub is marked pending_cancellation — user retains access until period end
--   2. New (lower-tier) sub is inserted as 'created' — user authorises it now; billing starts at cycle end
--
-- Without this change the unique partial index (one active sub per user) blocks the INSERT
-- because both 'pending_cancellation' and 'created' were in scope of the constraint.

DROP INDEX IF EXISTS idx_subscriptions_one_active_per_user;

CREATE UNIQUE INDEX idx_subscriptions_one_active_per_user
  ON public.subscriptions (user_id)
  WHERE status NOT IN ('cancelled', 'expired', 'paused', 'completed', 'pending_cancellation');
