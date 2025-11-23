-- ============================================================================
-- Migration: Fix Memory Verse Notification Functions
-- Version: 1.1
-- Date: 2025-11-23
-- Description: Fixes ambiguous column reference in notification helper functions
--              by fully qualifying user_id in subqueries
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. FIX MEMORY VERSE REMINDER NOTIFICATION FUNCTION
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
    -- Fully qualify user_id to avoid ambiguity with RETURNS TABLE columns
    SELECT
      memory_verses.user_id as mv_user_id,
      COUNT(*) FILTER (WHERE next_review_date <= CURRENT_DATE) as due_count,
      COUNT(*) FILTER (WHERE next_review_date < CURRENT_DATE) as overdue_count
    FROM memory_verses
    GROUP BY memory_verses.user_id
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
-- 2. FIX MEMORY VERSE OVERDUE NOTIFICATION FUNCTION
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
    -- Get count and max age of overdue verses per user
    -- Fully qualify user_id to avoid ambiguity with RETURNS TABLE columns
    SELECT
      memory_verses.user_id as mv_user_id,
      COUNT(*) as overdue_count,
      MAX(CURRENT_DATE - next_review_date)::INTEGER as max_overdue
    FROM memory_verses
    WHERE next_review_date < CURRENT_DATE
    GROUP BY memory_verses.user_id
  ) mv ON t.user_id = mv.mv_user_id
  WHERE p.memory_verse_overdue_enabled = true
    -- Only users who have at least one overdue verse
    AND COALESCE(mv.overdue_count, 0) > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
