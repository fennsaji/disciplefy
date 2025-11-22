-- ============================================================================
-- Migration: Add Memory Verse Notification Preferences
-- Version: 1.0
-- Date: 2025-11-22
-- Description: Adds memory verse notification preferences to support:
--              1. Daily reminder when verses are due for review (9 AM default)
--              2. Overdue alert when verses are past their review date
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ADD MEMORY VERSE NOTIFICATION PREFERENCE COLUMNS
-- ============================================================================

ALTER TABLE user_notification_preferences
  ADD COLUMN IF NOT EXISTS memory_verse_reminder_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS memory_verse_reminder_time TIME NOT NULL DEFAULT '09:00:00',
  ADD COLUMN IF NOT EXISTS memory_verse_overdue_enabled BOOLEAN NOT NULL DEFAULT true;

-- ============================================================================
-- 2. ADD COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON COLUMN user_notification_preferences.memory_verse_reminder_enabled IS
  'Enable daily reminder when user has memory verses due for review (sent at memory_verse_reminder_time)';

COMMENT ON COLUMN user_notification_preferences.memory_verse_reminder_time IS
  'Time of day (in users timezone) to send memory verse review reminder';

COMMENT ON COLUMN user_notification_preferences.memory_verse_overdue_enabled IS
  'Enable notification when memory verses become overdue for review';

-- ============================================================================
-- 3. CREATE HELPER FUNCTION FOR MEMORY VERSE REMINDER NOTIFICATIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION get_memory_verse_reminder_notification_users(
  target_hour INTEGER,
  target_minute INTEGER
)
RETURNS TABLE (
  user_id UUID,
  fcm_token TEXT,
  timezone_offset_minutes INTEGER,
  platform VARCHAR(20),
  due_verse_count INTEGER,
  overdue_verse_count INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.user_id,
    t.fcm_token,
    p.timezone_offset_minutes,
    t.platform,
    COALESCE(mv.due_count, 0)::INTEGER as due_verse_count,
    COALESCE(mv.overdue_count, 0)::INTEGER as overdue_verse_count
  FROM user_notification_tokens t
  INNER JOIN user_notification_preferences p
    ON t.user_id = p.user_id
  LEFT JOIN (
    -- Get count of due and overdue verses per user
    SELECT
      user_id as mv_user_id,
      COUNT(*) FILTER (WHERE next_review_date <= CURRENT_DATE) as due_count,
      COUNT(*) FILTER (WHERE next_review_date < CURRENT_DATE) as overdue_count
    FROM memory_verses
    GROUP BY user_id
  ) mv ON t.user_id = mv.mv_user_id
  WHERE p.memory_verse_reminder_enabled = true
    -- Only users who have at least one due verse
    AND COALESCE(mv.due_count, 0) > 0
    -- TIMEZONE-AWARE: Convert UTC target time to user's local time before comparing
    AND EXTRACT(HOUR FROM p.memory_verse_reminder_time)::INTEGER =
        (((target_hour * 60 + target_minute + p.timezone_offset_minutes) % 1440 + 1440) % 1440) / 60
    AND EXTRACT(MINUTE FROM p.memory_verse_reminder_time)::INTEGER =
        (((target_hour * 60 + target_minute + p.timezone_offset_minutes) % 1440 + 1440) % 1440) % 60;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. CREATE HELPER FUNCTION FOR OVERDUE NOTIFICATION CHECK
-- ============================================================================

CREATE OR REPLACE FUNCTION get_memory_verse_overdue_notification_users()
RETURNS TABLE (
  user_id UUID,
  fcm_token TEXT,
  timezone_offset_minutes INTEGER,
  platform VARCHAR(20),
  overdue_verse_count INTEGER,
  max_days_overdue INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.user_id,
    t.fcm_token,
    p.timezone_offset_minutes,
    t.platform,
    COALESCE(mv.overdue_count, 0)::INTEGER as overdue_verse_count,
    COALESCE(mv.max_overdue, 0)::INTEGER as max_days_overdue
  FROM user_notification_tokens t
  INNER JOIN user_notification_preferences p
    ON t.user_id = p.user_id
  LEFT JOIN (
    -- Get count of overdue verses and max days overdue per user
    SELECT
      user_id as mv_user_id,
      COUNT(*) as overdue_count,
      MAX(CURRENT_DATE - next_review_date) as max_overdue
    FROM memory_verses
    WHERE next_review_date < CURRENT_DATE
    GROUP BY user_id
  ) mv ON t.user_id = mv.mv_user_id
  WHERE p.memory_verse_overdue_enabled = true
    -- Only users who have at least one overdue verse
    AND COALESCE(mv.overdue_count, 0) > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION get_memory_verse_reminder_notification_users(INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION get_memory_verse_overdue_notification_users() TO service_role;

-- ============================================================================
-- 6. ADD INDEXES FOR EFFICIENT QUERYING
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_notification_prefs_memory_verse_reminder
  ON user_notification_preferences(memory_verse_reminder_enabled, memory_verse_reminder_time)
  WHERE memory_verse_reminder_enabled = true;

CREATE INDEX IF NOT EXISTS idx_notification_prefs_memory_verse_overdue
  ON user_notification_preferences(memory_verse_overdue_enabled)
  WHERE memory_verse_overdue_enabled = true;

-- Index for efficient due verse counting
-- Note: Cannot use CURRENT_DATE in partial index (not immutable)
-- Index on user_id and next_review_date for efficient filtering in queries
CREATE INDEX IF NOT EXISTS idx_memory_verses_next_review_date
  ON memory_verses(user_id, next_review_date)
  WHERE next_review_date IS NOT NULL;

-- ============================================================================
-- 7. VALIDATION
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
      'memory_verse_reminder_enabled',
      'memory_verse_reminder_time',
      'memory_verse_overdue_enabled'
    );

  IF col_count < 3 THEN
    RAISE EXCEPTION 'Memory verse notification preference columns were not created';
  END IF;

  -- Check reminder function was created
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routines
    WHERE routine_name = 'get_memory_verse_reminder_notification_users'
      AND routine_schema = 'public'
  ) INTO func_exists;

  IF NOT func_exists THEN
    RAISE EXCEPTION 'Helper function get_memory_verse_reminder_notification_users was not created';
  END IF;

  -- Check overdue function was created
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routines
    WHERE routine_name = 'get_memory_verse_overdue_notification_users'
      AND routine_schema = 'public'
  ) INTO func_exists;

  IF NOT func_exists THEN
    RAISE EXCEPTION 'Helper function get_memory_verse_overdue_notification_users was not created';
  END IF;

  RAISE NOTICE 'Migration completed successfully:';
  RAISE NOTICE '  - Added 3 memory verse notification preference columns';
  RAISE NOTICE '  - Created helper function for reminder notification queries';
  RAISE NOTICE '  - Created helper function for overdue notification queries';
  RAISE NOTICE '  - Added indexes for efficient querying';
END $$;

COMMIT;
