-- ============================================================================
-- notification_logs — Allow Every Notification Type
-- ============================================================================
-- The CHECK constraint on notification_logs.notification_type only permitted
-- five values:
--
--   daily_verse, recommended_topic, streak_reminder,
--   memory_verse_reminder, achievement_unlocked
--
-- but the Edge Functions send four more: continue_learning, streak_milestone,
-- streak_lost and memory_verse_overdue.
--
-- WHY THIS MATTERED
-- -----------------
-- logNotification() deliberately swallows insert errors so a logging failure
-- can never fail a push that was already delivered. The rejected rows were
-- therefore invisible — but per-day dedup reads this exact table, so a
-- notification whose type violated the constraint was never recorded and never
-- deduped. Every subsequent run re-selected the same user and sent again.
--
-- Observed in production: a user received BOTH "Continue Your Study" and
-- "Recommended Topic" from two workflow runs six minutes apart, because the
-- first run's continue_learning row was rejected and the second run could not
-- see it.
--
-- Keeping the constraint (rather than dropping it) preserves the guard against
-- typo'd types; it just has to list the full set the application actually uses.
-- Kept in sync with the NotificationType union in
-- _shared/services/notification-helper-service.ts.
-- ============================================================================

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
    'achievement_unlocked'
  ));

COMMENT ON COLUMN notification_logs.notification_type IS
  'Notification category. Must stay in sync with the NotificationType union in '
  '_shared/services/notification-helper-service.ts — per-day dedup reads this table, '
  'so a type missing from the constraint is silently never logged and therefore '
  'never deduped, causing repeat sends.';

COMMIT;
