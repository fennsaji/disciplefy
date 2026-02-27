-- ============================================================================
-- Notification Preference Defaults — UX Update
-- ============================================================================
-- Changes memory_verse_reminder_enabled default from true → false.
--
-- Rationale: Memory verse reminders are only useful once the user has actually
-- added a memory verse. Defaulting to ON sends reminders to users who have
-- never used the feature, creating noise. The reminder is auto-enabled when
-- the user saves their first memory verse via the app.
--
-- streak_lost_enabled was already set to DEFAULT false in migration 20260227000001.
--
-- Final default matrix:
--   daily_verse_enabled           → true   (core feature, always relevant)
--   recommended_topic_enabled     → true   (personalized discovery)
--   streak_reminder_enabled       → true   (core retention mechanic)
--   streak_milestone_enabled      → true   (rare, celebratory — always welcome)
--   streak_lost_enabled           → false  (contextual opt-in)
--   memory_verse_reminder_enabled → false  (contextual — enabled on first verse save)
-- ============================================================================

BEGIN;

ALTER TABLE user_notification_preferences
  ALTER COLUMN memory_verse_reminder_enabled SET DEFAULT false;

COMMENT ON COLUMN user_notification_preferences.memory_verse_reminder_enabled IS
  'Whether to send daily memory verse review reminders. Defaults to false; '
  'auto-enabled when the user saves their first memory verse.';

COMMIT;
