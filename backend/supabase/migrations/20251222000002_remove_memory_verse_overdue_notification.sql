-- ============================================================================
-- Migration: Remove Memory Verse Overdue Notification
-- Version: 1.0
-- Date: 2025-12-22
-- Description: Removes the Memory Verse Overdue notification feature:
--              - Drops overdue_enabled preference column
--              - Drops get_memory_verse_overdue_notification_users function
--              - Removes overdue-related indexes
--              - Updates reminder function to remove overdue_verse_count
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. DROP OVERDUE NOTIFICATION FUNCTION
-- ============================================================================

DROP FUNCTION IF EXISTS get_memory_verse_overdue_notification_users();

-- ============================================================================
-- 2. UPDATE REMINDER FUNCTION TO REMOVE OVERDUE COUNT
-- ============================================================================

-- Drop existing function first (return type is changing)
DROP FUNCTION IF EXISTS get_memory_verse_reminder_notification_users(INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION get_memory_verse_reminder_notification_users(
  target_hour INTEGER,
  target_minute INTEGER
)
RETURNS TABLE (
  user_id UUID,
  fcm_token TEXT,
  timezone_offset_minutes INTEGER,
  platform VARCHAR(20),
  due_verse_count INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.user_id,
    t.fcm_token,
    p.timezone_offset_minutes,
    t.platform,
    COALESCE(mv.due_count, 0)::INTEGER as due_verse_count
  FROM user_notification_tokens t
  INNER JOIN user_notification_preferences p
    ON t.user_id = p.user_id
  LEFT JOIN (
    -- Get count of due verses per user
    SELECT
      mv.user_id as mv_user_id,
      COUNT(*) FILTER (WHERE mv.next_review_date <= CURRENT_DATE) as due_count
    FROM memory_verses mv
    GROUP BY mv.user_id
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
$$ LANGUAGE plpgsql SET search_path = public, pg_temp SECURITY DEFINER;

-- ============================================================================
-- 3. DROP OVERDUE-RELATED INDEX
-- ============================================================================

DROP INDEX IF EXISTS idx_notification_prefs_memory_verse_overdue;

-- ============================================================================
-- 4. DROP OVERDUE PREFERENCE COLUMN
-- ============================================================================

ALTER TABLE user_notification_preferences
  DROP COLUMN IF EXISTS memory_verse_overdue_enabled;

-- ============================================================================
-- 5. VALIDATION
-- ============================================================================

DO $$
DECLARE
  col_exists BOOLEAN;
  func_exists BOOLEAN;
  index_exists BOOLEAN;
BEGIN
  -- Check overdue column was removed
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_notification_preferences'
      AND column_name = 'memory_verse_overdue_enabled'
  ) INTO col_exists;

  IF col_exists THEN
    RAISE EXCEPTION 'memory_verse_overdue_enabled column was not dropped';
  END IF;

  -- Check overdue function was removed
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routines
    WHERE routine_name = 'get_memory_verse_overdue_notification_users'
      AND routine_schema = 'public'
  ) INTO func_exists;

  IF func_exists THEN
    RAISE EXCEPTION 'get_memory_verse_overdue_notification_users function was not dropped';
  END IF;

  -- Check reminder function still exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routines
    WHERE routine_name = 'get_memory_verse_reminder_notification_users'
      AND routine_schema = 'public'
  ) INTO func_exists;

  IF NOT func_exists THEN
    RAISE EXCEPTION 'get_memory_verse_reminder_notification_users function was dropped (should be updated, not dropped)';
  END IF;

  -- Check overdue index was removed
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE indexname = 'idx_notification_prefs_memory_verse_overdue'
  ) INTO index_exists;

  IF index_exists THEN
    RAISE EXCEPTION 'idx_notification_prefs_memory_verse_overdue index was not dropped';
  END IF;

  RAISE NOTICE 'Migration completed successfully:';
  RAISE NOTICE '  - Dropped memory_verse_overdue_enabled column';
  RAISE NOTICE '  - Dropped get_memory_verse_overdue_notification_users function';
  RAISE NOTICE '  - Updated get_memory_verse_reminder_notification_users function';
  RAISE NOTICE '  - Dropped idx_notification_prefs_memory_verse_overdue index';
END $$;

COMMIT;
