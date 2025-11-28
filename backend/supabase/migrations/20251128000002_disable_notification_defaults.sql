-- ============================================================================
-- Migration: Disable All Notification Defaults
-- Version: 1.0
-- Date: 2025-11-28
-- Description: Changes all notification preferences to default FALSE.
--              Users will be prompted to enable notifications contextually
--              when they interact with relevant features.
--
-- Trigger Points (implemented in frontend):
--   - daily_verse_enabled: When user views Daily Verse page
--   - recommended_topic_enabled: After completing a study guide
--   - streak_reminder_enabled: After user builds 3+ day streak
--   - streak_milestone_enabled: After reaching first milestone (7 days)
--   - streak_lost_enabled: After reaching first milestone (7 days)
--   - memory_verse_reminder_enabled: After adding first memory verse
--   - memory_verse_overdue_enabled: After reviewing first memory verse
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ALTER DEFAULT VALUES FOR ALL NOTIFICATION PREFERENCES
-- ============================================================================

-- Daily verse notification (originally true)
ALTER TABLE user_notification_preferences
  ALTER COLUMN daily_verse_enabled SET DEFAULT false;

-- Recommended topic notification (originally true)
ALTER TABLE user_notification_preferences
  ALTER COLUMN recommended_topic_enabled SET DEFAULT false;

-- Streak notifications (originally all true)
ALTER TABLE user_notification_preferences
  ALTER COLUMN streak_reminder_enabled SET DEFAULT false;

ALTER TABLE user_notification_preferences
  ALTER COLUMN streak_milestone_enabled SET DEFAULT false;

ALTER TABLE user_notification_preferences
  ALTER COLUMN streak_lost_enabled SET DEFAULT false;

-- Memory verse notifications (originally all true)
ALTER TABLE user_notification_preferences
  ALTER COLUMN memory_verse_reminder_enabled SET DEFAULT false;

ALTER TABLE user_notification_preferences
  ALTER COLUMN memory_verse_overdue_enabled SET DEFAULT false;

-- ============================================================================
-- 2. UPDATE COMMENTS TO REFLECT NEW BEHAVIOR
-- ============================================================================

COMMENT ON COLUMN user_notification_preferences.daily_verse_enabled IS
  'Enable daily verse notifications (default: false, prompted on Daily Verse page)';

COMMENT ON COLUMN user_notification_preferences.recommended_topic_enabled IS
  'Enable recommended topic notifications (default: false, prompted after completing study guide)';

COMMENT ON COLUMN user_notification_preferences.streak_reminder_enabled IS
  'Enable streak reminder notifications (default: false, prompted after building 3+ day streak)';

COMMENT ON COLUMN user_notification_preferences.streak_milestone_enabled IS
  'Enable milestone achievement notifications (default: false, prompted after first 7-day milestone)';

COMMENT ON COLUMN user_notification_preferences.streak_lost_enabled IS
  'Enable streak lost notifications (default: false, prompted after first 7-day milestone)';

COMMENT ON COLUMN user_notification_preferences.memory_verse_reminder_enabled IS
  'Enable memory verse review reminders (default: false, prompted after adding first verse)';

COMMENT ON COLUMN user_notification_preferences.memory_verse_overdue_enabled IS
  'Enable overdue verse notifications (default: false, prompted after first verse review)';

-- ============================================================================
-- 3. NOTE: EXISTING USERS ARE NOT AFFECTED
-- ============================================================================
-- This migration only changes DEFAULT values for NEW users/preferences.
-- Existing users who already have preferences will keep their current settings.
-- This is intentional - we don't want to disable notifications for users
-- who already enabled them.

-- ============================================================================
-- 4. VALIDATION
-- ============================================================================

DO $$
DECLARE
  default_val TEXT;
BEGIN
  -- Verify daily_verse_enabled default is now false
  SELECT column_default INTO default_val
  FROM information_schema.columns
  WHERE table_name = 'user_notification_preferences'
    AND column_name = 'daily_verse_enabled';
  
  IF default_val != 'false' THEN
    RAISE EXCEPTION 'daily_verse_enabled default not set to false: %', default_val;
  END IF;

  -- Verify streak_reminder_enabled default is now false
  SELECT column_default INTO default_val
  FROM information_schema.columns
  WHERE table_name = 'user_notification_preferences'
    AND column_name = 'streak_reminder_enabled';
  
  IF default_val != 'false' THEN
    RAISE EXCEPTION 'streak_reminder_enabled default not set to false: %', default_val;
  END IF;

  RAISE NOTICE 'Migration completed successfully:';
  RAISE NOTICE '  - All notification preferences now default to FALSE';
  RAISE NOTICE '  - Existing user preferences are unchanged';
  RAISE NOTICE '  - Frontend will prompt users contextually to enable notifications';
END $$;

COMMIT;
