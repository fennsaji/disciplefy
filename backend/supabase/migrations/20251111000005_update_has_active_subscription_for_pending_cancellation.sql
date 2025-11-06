-- Update has_active_subscription function to include pending_cancellation status
-- Users with pending_cancellation still have premium access until period ends

CREATE OR REPLACE FUNCTION has_active_subscription(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_has_active BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM subscriptions
    WHERE user_id = p_user_id
      -- Include active, authenticated, and pending_cancellation statuses
      AND status IN ('active', 'authenticated', 'pending_cancellation')
      AND (current_period_end IS NULL OR current_period_end > NOW())
  ) INTO v_has_active;

  RETURN v_has_active;
END;
$$;

COMMENT ON FUNCTION has_active_subscription(UUID) IS
  'Returns true if user has an active subscription (status active/authenticated/pending_cancellation and not expired)';
