-- ============================================================================
-- Migration: Fix Memory Verse Reminder Ambiguous user_id
-- Date: 2026-01-05
-- Description: Fixes "column reference user_id is ambiguous" error in
--              get_memory_verse_reminder_notification_users function by
--              properly aliasing the memory_verses table in the subquery
-- ============================================================================

BEGIN;

-- Drop existing function
DROP FUNCTION IF EXISTS get_memory_verse_reminder_notification_users(INTEGER, INTEGER);

-- Recreate with proper table aliasing to fix ambiguous column reference
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
    -- FIX: Added table alias 'mv' to avoid ambiguous user_id column reference
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_memory_verse_reminder_notification_users(INTEGER, INTEGER) TO service_role;

COMMIT;

-- Verification
DO $$
DECLARE
  func_exists BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routines
    WHERE routine_name = 'get_memory_verse_reminder_notification_users'
      AND routine_schema = 'public'
  ) INTO func_exists;

  IF NOT func_exists THEN
    RAISE EXCEPTION 'Function get_memory_verse_reminder_notification_users was not created';
  END IF;

  RAISE NOTICE 'Migration completed successfully:';
  RAISE NOTICE '  ✓ Fixed ambiguous user_id column reference in subquery';
  RAISE NOTICE '  ✓ Added table alias "mv" to memory_verses table';
  RAISE NOTICE '  ✓ Function recreated with proper column qualification';
END $$;
