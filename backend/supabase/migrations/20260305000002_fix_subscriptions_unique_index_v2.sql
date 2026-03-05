-- Fix partial unique index to also exclude 'paused' and 'completed' statuses
-- so they don't block new subscription inserts.

DROP INDEX IF EXISTS idx_subscriptions_one_active_per_user;

CREATE UNIQUE INDEX idx_subscriptions_one_active_per_user
  ON public.subscriptions (user_id)
  WHERE status NOT IN ('cancelled', 'expired', 'paused', 'completed');
