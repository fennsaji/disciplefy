-- ============================================================================
-- Continue Learning — Per-Guide Reminder Tracking
-- ============================================================================
-- Adds reminder bookkeeping to user_study_guides so the "Continue Your Study"
-- push notification can cap repeats and rotate between guides.
--
-- WHY
-- ---
-- The notification selector picked the single OLDEST incomplete guide
-- (ORDER BY created_at ASC LIMIT 1) with no repeat cap and no rotation. One
-- guide the user never finished pinned the notification to that same topic
-- every single day, indefinitely, and blocked the personalised "For You"
-- notification from ever being sent.
--
-- notification_logs could not be used for this: its topic_id is nullable (a
-- guide generated from free-text input has none) and it identifies a topic,
-- not the specific user_study_guides row being nagged about.
-- ============================================================================

BEGIN;

ALTER TABLE user_study_guides
  ADD COLUMN IF NOT EXISTS continue_reminder_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_continue_reminder_at TIMESTAMPTZ;

COMMENT ON COLUMN user_study_guides.continue_reminder_count IS
  'How many "Continue Your Study" push notifications have been sent for this guide. '
  'Capped by the selector so a guide the user never finishes stops being nagged about.';
COMMENT ON COLUMN user_study_guides.last_continue_reminder_at IS
  'When the last "Continue Your Study" push was sent for this guide. The selector '
  'prefers the least-recently-reminded guide so multiple incomplete guides rotate.';

-- Supports the selector's hot path: incomplete guides for one user, ordered by
-- least-recently-reminded. NULLS FIRST matches the query's ordering so a guide
-- that has never been reminded about is picked first.
CREATE INDEX IF NOT EXISTS idx_user_study_guides_continue_reminder
  ON user_study_guides (user_id, last_continue_reminder_at NULLS FIRST)
  WHERE completed_at IS NULL;

-- ============================================================================
-- Atomic increment
-- ============================================================================
-- Done in SQL rather than a read-modify-write from the Edge Function: several
-- notification runs can overlap, and a client-side increment would lose counts
-- and let a guide exceed its reminder cap.

CREATE OR REPLACE FUNCTION increment_continue_reminder(p_guide_id UUID)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
    UPDATE user_study_guides
    SET continue_reminder_count = continue_reminder_count + 1,
        last_continue_reminder_at = NOW()
    WHERE id = p_guide_id;
$$;

GRANT EXECUTE ON FUNCTION increment_continue_reminder(UUID) TO service_role;

COMMENT ON FUNCTION increment_continue_reminder IS
    'Atomically records that a "Continue Your Study" reminder was sent for a guide. '
    'Called by send-recommended-topic-notification after a successful push so the '
    'selector''s repeat cap and least-recently-reminded rotation advance correctly.';

COMMIT;
