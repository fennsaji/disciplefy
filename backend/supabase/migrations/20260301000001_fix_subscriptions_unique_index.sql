-- Fix subscriptions unique constraint to allow historical records
--
-- The original idx_subscriptions_one_per_user was a non-partial UNIQUE index on
-- user_id alone. This blocked any INSERT even when the existing row was cancelled
-- or in trial. Replace with a partial index that only enforces uniqueness for
-- non-terminal statuses so historical records are preserved.

-- Drop the old global unique index
DROP INDEX IF EXISTS idx_subscriptions_one_per_user;

-- Create partial unique index — only one active/pending subscription per user.
-- 'cancelled' and 'expired' are terminal: a new subscription is always allowed.
CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_one_active_per_user
  ON public.subscriptions (user_id)
  WHERE status NOT IN ('cancelled', 'expired');
