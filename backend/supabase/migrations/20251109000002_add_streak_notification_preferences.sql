-- ============================================================================
-- Migration: Add Streak Notification Preferences
-- Version: 1.0
-- Date: 2025-11-09
-- Description: Adds streak-specific notification preferences to support:
--              1. Streak about to break warning (evening reminder)
--              2. Milestone achievement notifications (7, 30, 100, 365 days)
--              3. Streak lost notifications (when streak resets)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ADD STREAK NOTIFICATION PREFERENCE COLUMNS
-- ============================================================================

ALTER TABLE user_notification_preferences
  ADD COLUMN IF NOT EXISTS streak_reminder_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS streak_milestone_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS streak_lost_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS streak_reminder_time TIME NOT NULL DEFAULT '20:00:00';

-- ============================================================================
-- 2. ADD COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON COLUMN user_notification_preferences.streak_reminder_enabled IS
  'Enable evening reminder if user hasnt viewed todays verse (sent at streak_reminder_time)';

COMMENT ON COLUMN user_notification_preferences.streak_milestone_enabled IS
  'Enable notifications when reaching streak milestones (7, 30, 100, 365 days)';

COMMENT ON COLUMN user_notification_preferences.streak_lost_enabled IS
  'Enable notification when user loses their streak';

COMMENT ON COLUMN user_notification_preferences.streak_reminder_time IS
  'Time of day (in users timezone) to send streak reminder if verse not viewed';

-- ============================================================================
-- 3. CREATE HELPER FUNCTION FOR STREAK REMINDER NOTIFICATIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION get_streak_reminder_notification_users(
  target_hour INTEGER,
  target_minute INTEGER
)
RETURNS TABLE (
  user_id UUID,
  fcm_token TEXT,
  timezone_offset_minutes INTEGER,
  platform VARCHAR(20),
  current_streak INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.user_id,
    t.fcm_token,
    p.timezone_offset_minutes,
    t.platform,
    COALESCE(s.current_streak, 0) as current_streak
  FROM user_notification_tokens t
  INNER JOIN user_notification_preferences p
    ON t.user_id = p.user_id
  LEFT JOIN daily_verse_streaks s
    ON t.user_id = s.user_id
  WHERE p.streak_reminder_enabled = true
    -- Only users who haven't viewed today's verse
    AND (
      s.last_viewed_at IS NULL
      OR DATE(s.last_viewed_at AT TIME ZONE 'UTC') < CURRENT_DATE
    )
    -- Match users whose local time is close to the reminder time
    AND EXTRACT(HOUR FROM p.streak_reminder_time) = target_hour
    AND EXTRACT(MINUTE FROM p.streak_reminder_time) = target_minute;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION get_streak_reminder_notification_users(INTEGER, INTEGER) TO service_role;

-- ============================================================================
-- 5. ADD INDEXES FOR EFFICIENT QUERYING
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_notification_prefs_streak_reminder
  ON user_notification_preferences(streak_reminder_enabled, streak_reminder_time)
  WHERE streak_reminder_enabled = true;

CREATE INDEX IF NOT EXISTS idx_notification_prefs_streak_milestone
  ON user_notification_preferences(streak_milestone_enabled)
  WHERE streak_milestone_enabled = true;

CREATE INDEX IF NOT EXISTS idx_notification_prefs_streak_lost
  ON user_notification_preferences(streak_lost_enabled)
  WHERE streak_lost_enabled = true;

-- ============================================================================
-- 6. VALIDATION
-- ============================================================================

DO $$
DECLARE
  col_count INTEGER;
  func_exists BOOLEAN;
BEGIN
  -- Check columns were added
  SELECT COUNT(*) INTO col_count
  FROM information_schema.columns
  WHERE table_name = 'user_notification_preferences'
    AND column_name IN (
      'streak_reminder_enabled',
      'streak_milestone_enabled',
      'streak_lost_enabled',
      'streak_reminder_time'
    );

  IF col_count < 4 THEN
    RAISE EXCEPTION 'Streak notification preference columns were not created';
  END IF;

  -- Check function was created
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routines
    WHERE routine_name = 'get_streak_reminder_notification_users'
      AND routine_schema = 'public'
  ) INTO func_exists;

  IF NOT func_exists THEN
    RAISE EXCEPTION 'Helper function get_streak_reminder_notification_users was not created';
  END IF;

  RAISE NOTICE 'Migration completed successfully:';
  RAISE NOTICE '  - Added 4 streak notification preference columns';
  RAISE NOTICE '  - Created helper function for streak reminder queries';
  RAISE NOTICE '  - Added indexes for efficient querying';
END $$;

COMMIT;
