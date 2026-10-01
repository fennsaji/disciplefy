-- Daily verse and recommended topic notifications are on by default.
-- The columns default to true but were nullable, and the senders filter with
-- "= true", so a NULL silently opted a user out. NULL is never an explicit
-- choice (the app always writes true/false), so backfill it to true and make
-- the columns NOT NULL. Explicit false values are left untouched. Idempotent.
BEGIN;

UPDATE user_notification_preferences
   SET daily_verse_enabled = true
 WHERE daily_verse_enabled IS NULL;

UPDATE user_notification_preferences
   SET recommended_topic_enabled = true
 WHERE recommended_topic_enabled IS NULL;

ALTER TABLE user_notification_preferences
  ALTER COLUMN daily_verse_enabled SET DEFAULT true,
  ALTER COLUMN daily_verse_enabled SET NOT NULL,
  ALTER COLUMN recommended_topic_enabled SET DEFAULT true,
  ALTER COLUMN recommended_topic_enabled SET NOT NULL;

COMMIT;
