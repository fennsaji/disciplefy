-- Allow on_hold subscriptions to coexist with a new subscription row.
--
-- When Google Play places a subscription on_hold (renewal payment failed),
-- the user's access is suspended. They may try to re-subscribe via a new
-- purchase token. Without this change, the unique-per-user index blocks
-- the INSERT because on_hold was not excluded from the constraint.
--
-- Adding on_hold to the exclusion list matches the treatment of paused
-- and pending_cancellation: the row is retained for audit/history but does
-- not block a fresh subscription for the same user.

DROP INDEX IF EXISTS idx_subscriptions_one_active_per_user;

CREATE UNIQUE INDEX idx_subscriptions_one_active_per_user
  ON public.subscriptions (user_id)
  WHERE status NOT IN ('cancelled', 'expired', 'paused', 'completed', 'pending_cancellation', 'on_hold');
