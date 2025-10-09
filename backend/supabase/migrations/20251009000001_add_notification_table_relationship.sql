-- ============================================================================
-- Migration: Add Helper Functions for Notification Token Queries
-- Version: 1.0
-- Date: 2025-10-09
-- Description: Creates database functions to fetch notification tokens with
--              preferences without requiring PostgREST automatic joins
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. FUNCTION: Get notification tokens with preferences for daily verse
-- ============================================================================

CREATE OR REPLACE FUNCTION get_daily_verse_notification_users(
  offset_min INTEGER,
  offset_max INTEGER
)
RETURNS TABLE (
  user_id UUID,
  fcm_token TEXT,
  timezone_offset_minutes INTEGER,
  platform VARCHAR(20)
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.user_id,
    t.fcm_token,
    p.timezone_offset_minutes,
    t.platform
  FROM user_notification_tokens t
  INNER JOIN user_notification_preferences p 
    ON t.user_id = p.user_id
  WHERE p.daily_verse_enabled = true
    AND p.timezone_offset_minutes >= offset_min
    AND p.timezone_offset_minutes <= offset_max;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 2. FUNCTION: Get notification tokens with preferences for recommended topics
-- ============================================================================

CREATE OR REPLACE FUNCTION get_recommended_topic_notification_users(
  offset_min INTEGER,
  offset_max INTEGER
)
RETURNS TABLE (
  user_id UUID,
  fcm_token TEXT,
  timezone_offset_minutes INTEGER,
  platform VARCHAR(20)
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.user_id,
    t.fcm_token,
    p.timezone_offset_minutes,
    t.platform
  FROM user_notification_tokens t
  INNER JOIN user_notification_preferences p 
    ON t.user_id = p.user_id
  WHERE p.recommended_topic_enabled = true
    AND p.timezone_offset_minutes >= offset_min
    AND p.timezone_offset_minutes <= offset_max;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 3. GRANT PERMISSIONS
-- ============================================================================

-- Allow Edge Functions to call these functions
GRANT EXECUTE ON FUNCTION get_daily_verse_notification_users(INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION get_recommended_topic_notification_users(INTEGER, INTEGER) TO service_role;

-- ============================================================================
-- 4. COMMENTS
-- ============================================================================

COMMENT ON FUNCTION get_daily_verse_notification_users IS
  'Returns all users with FCM tokens who should receive daily verse notifications for the given timezone offset range';

COMMENT ON FUNCTION get_recommended_topic_notification_users IS
  'Returns all users with FCM tokens who should receive recommended topic notifications for the given timezone offset range';

-- ============================================================================
-- 5. VALIDATION
-- ============================================================================

DO $$
DECLARE
  function_count INTEGER;
BEGIN
  -- Check functions were created
  SELECT COUNT(*) INTO function_count
  FROM information_schema.routines
  WHERE routine_name IN ('get_daily_verse_notification_users', 'get_recommended_topic_notification_users')
    AND routine_schema = 'public';

  IF function_count < 2 THEN
    RAISE EXCEPTION 'Helper functions were not created';
  END IF;

  RAISE NOTICE 'Migration completed successfully: % notification helper functions created', function_count;
END $$;

COMMIT;
