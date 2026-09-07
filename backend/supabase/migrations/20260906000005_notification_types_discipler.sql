-- =====================================================
-- Migration: notification_logs types for Discipler
-- Date: 2026-09-06
-- Keep in sync with NotificationType in notification-helper-service.ts.
-- =====================================================

BEGIN;

ALTER TABLE notification_logs
  DROP CONSTRAINT IF EXISTS notification_logs_notification_type_check;

ALTER TABLE notification_logs
  ADD CONSTRAINT notification_logs_notification_type_check
  CHECK (notification_type IN (
    'daily_verse',
    'recommended_topic',
    'continue_learning',
    'streak_reminder',
    'streak_milestone',
    'streak_lost',
    'memory_verse_reminder',
    'memory_verse_overdue',
    'achievement_unlocked',
    'fellowship_daily_post',
    'fellowship_discipler_reply',
    'fellowship_discipler_activity'
  ));

COMMIT;
