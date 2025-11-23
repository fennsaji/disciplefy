-- ============================================================================
-- Migration: Fix Interval to Integer Cast in Overdue Function
-- Version: 1.2
-- Date: 2025-11-23
-- Description: Fixes interval to integer cast error by using EXTRACT(DAY FROM interval)
-- ============================================================================

BEGIN;

-- ============================================================================
-- FIX MEMORY VERSE OVERDUE NOTIFICATION FUNCTION
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
    -- Use EXTRACT(DAY FROM interval) to get integer days
    SELECT
      memory_verses.user_id as mv_user_id,
      COUNT(*)::INTEGER as overdue_count,
      EXTRACT(DAY FROM MAX(CURRENT_DATE - next_review_date))::INTEGER as max_overdue
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
