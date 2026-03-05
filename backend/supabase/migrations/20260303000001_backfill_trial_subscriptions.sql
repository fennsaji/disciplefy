-- Backfill trial subscriptions for existing eligible users.
-- The create_subscription_on_signup trigger only fires for NEW users.
-- Safety conditions:
--   1. User is not an admin
--   2. Standard trial is currently active
--   3. User has no existing non-terminal subscription (not cancelled/expired)

INSERT INTO subscriptions (
  user_id, plan_id, plan_type, status, provider,
  provider_subscription_id, current_period_start, current_period_end
)
SELECT
  up.id,
  (SELECT id FROM subscription_plans WHERE plan_code = 'standard' LIMIT 1),
  'standard_trial',
  'trial',
  'trial',
  'trial_' || up.id::text,
  NOW(),
  get_standard_trial_end_date()
FROM user_profiles up
WHERE COALESCE(up.is_admin, false) = false
  AND is_standard_trial_active()
  AND NOT EXISTS (
    SELECT 1 FROM subscriptions s
    WHERE s.user_id = up.id
      AND s.status NOT IN ('cancelled', 'expired')
  );

-- Verify: SELECT user_id, status, plan_type, current_period_end FROM subscriptions WHERE status = 'trial';
