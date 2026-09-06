-- =====================================================
-- Migration: Fellowship Discipler flags and mentor preferences
-- Date: 2026-09-06
-- =====================================================

BEGIN;

-- Admin-only flags
ALTER TABLE fellowships
  ADD COLUMN IF NOT EXISTS is_official        BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS discipler_allowed  BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS daily_post_allowed BOOLEAN NOT NULL DEFAULT false;

-- Mentor-editable preferences
ALTER TABLE fellowships
  ADD COLUMN IF NOT EXISTS discipler_reply_mode TEXT NOT NULL DEFAULT 'auto',
  ADD COLUMN IF NOT EXISTS discipler_reply_scope TEXT NOT NULL DEFAULT 'all',
  ADD COLUMN IF NOT EXISTS discipler_reply_delay_min INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discipler_react_enabled BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS daily_post_on BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE fellowships DROP CONSTRAINT IF EXISTS fellowships_discipler_reply_mode_check;
ALTER TABLE fellowships ADD CONSTRAINT fellowships_discipler_reply_mode_check
  CHECK (discipler_reply_mode IN ('off', 'auto', 'review'));
ALTER TABLE fellowships DROP CONSTRAINT IF EXISTS fellowships_discipler_reply_scope_check;
ALTER TABLE fellowships ADD CONSTRAINT fellowships_discipler_reply_scope_check
  CHECK (discipler_reply_scope IN ('all', 'lessons_only'));
ALTER TABLE fellowships DROP CONSTRAINT IF EXISTS fellowships_discipler_reply_delay_check;
ALTER TABLE fellowships ADD CONSTRAINT fellowships_discipler_reply_delay_check
  CHECK (discipler_reply_delay_min IN (0, 30, 120, 720));

COMMENT ON COLUMN fellowships.discipler_allowed IS 'Admin: Discipler may reply/react here. Mentors control mode/scope/delay.';
COMMENT ON COLUMN fellowships.daily_post_allowed IS 'Admin: rs-backend daily post cron may post here when daily_post_on is true.';

CREATE INDEX IF NOT EXISTS idx_fellowships_daily_post
  ON fellowships (id) WHERE daily_post_allowed = true AND daily_post_on = true AND is_active = true;

-- Per-mentor push preference
ALTER TABLE fellowship_members
  ADD COLUMN IF NOT EXISTS discipler_activity_push BOOLEAN NOT NULL DEFAULT true;

-- Posts
ALTER TABLE fellowship_posts
  ADD COLUMN IF NOT EXISTS to_mentors BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS mentions_discipler BOOLEAN NOT NULL DEFAULT false;

-- Remove join announcements; they become notifications only.
DELETE FROM fellowship_posts WHERE post_type = 'system';

ALTER TABLE fellowship_posts DROP CONSTRAINT IF EXISTS fellowship_posts_post_type_check;
ALTER TABLE fellowship_posts ADD CONSTRAINT fellowship_posts_post_type_check
  CHECK (post_type = ANY (ARRAY[
    'general'::text, 'prayer'::text, 'praise'::text,
    'question'::text, 'study_note'::text, 'shared_guide'::text,
    'daily'::text
  ]));

CREATE INDEX IF NOT EXISTS idx_fellowship_posts_daily
  ON fellowship_posts (fellowship_id, created_at DESC) WHERE post_type = 'daily' AND is_deleted = false;

-- Comments
ALTER TABLE fellowship_comments
  ADD COLUMN IF NOT EXISTS is_pending_review BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS mentions_discipler BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS study_guide_id UUID REFERENCES study_guides(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS guide_title TEXT,
  ADD COLUMN IF NOT EXISTS guide_input_type TEXT,
  ADD COLUMN IF NOT EXISTS guide_input_value TEXT,
  ADD COLUMN IF NOT EXISTS guide_language TEXT;

ALTER TABLE fellowship_comments DROP CONSTRAINT IF EXISTS fellowship_comments_guide_input_type_check;
ALTER TABLE fellowship_comments ADD CONSTRAINT fellowship_comments_guide_input_type_check
  CHECK (guide_input_type IS NULL OR guide_input_type IN ('topic', 'scripture'));

CREATE INDEX IF NOT EXISTS idx_fellowship_comments_pending
  ON fellowship_comments (fellowship_id, created_at) WHERE is_pending_review = true AND is_deleted = false;

-- Helper: every active mentor of a fellowship (the owner is also a mentor row).
CREATE OR REPLACE FUNCTION fellowship_mentor_ids(p_fellowship_id UUID)
RETURNS TABLE(user_id UUID, discipler_activity_push BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT user_id, discipler_activity_push
  FROM fellowship_members
  WHERE fellowship_id = p_fellowship_id AND role = 'mentor' AND is_active = true;
$$;

COMMIT;
