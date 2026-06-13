-- Add 'on_hold' to the subscriptions.status CHECK constraint.
--
-- Both the Google Play webhook (SUBSCRIPTION_ON_HOLD) and the new Apple App Store
-- Server Notifications V2 webhook (DID_FAIL_TO_RENEW without a grace period)
-- write status = 'on_hold' to suspend access when a renewal payment fails.
--
-- The original constraint in 20260119000300_subscription_system.sql did NOT include
-- 'on_hold', so those writes would violate the CHECK constraint. This migration
-- recreates the constraint with 'on_hold' added. (This also fixes a latent bug in
-- the existing google-play-webhook handler.)

ALTER TABLE subscriptions
  DROP CONSTRAINT IF EXISTS subscriptions_status_check;

ALTER TABLE subscriptions
  ADD CONSTRAINT subscriptions_status_check CHECK (status IN (
    'trial',                -- Trial period subscription
    'created',              -- Initial state
    'in_progress',          -- Payment in progress
    'active',               -- Active subscription
    'pending_cancellation', -- Cancelled but still in grace period (auto-renew off)
    'paused',               -- User voluntarily paused
    'on_hold',              -- Renewal payment failed, access suspended (provider hold)
    'cancelled',            -- User cancelled / refunded / revoked
    'completed',            -- Subscription period completed
    'expired'               -- Subscription expired without renewal
  ));
