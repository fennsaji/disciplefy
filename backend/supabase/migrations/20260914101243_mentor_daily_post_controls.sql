-- =====================================================
-- Migration: Mentor controls for the Discipler daily post
-- Date: 2026-09-14
-- =====================================================
-- Mentors can see what posts next, skip or pause it, choose when it goes out,
-- and pick the next lesson. Three controls cost an LLM call and are therefore
-- switched on per fellowship by an admin: preview, regenerate teaser, post now.
--
-- The LLM actions are not run by the Edge Function: it only records a request,
-- and the rs-backend fellowship_daily_post job (now every minute) processes it.

BEGIN;

-- Admin-only switches (default off)
ALTER TABLE fellowships
  ADD COLUMN IF NOT EXISTS daily_post_preview_allowed    BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS daily_post_regenerate_allowed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS daily_post_post_now_allowed   BOOLEAN NOT NULL DEFAULT false;

-- Mentor-editable schedule
ALTER TABLE fellowships
  ADD COLUMN IF NOT EXISTS daily_post_time         TEXT NOT NULL DEFAULT '06:30',
  ADD COLUMN IF NOT EXISTS daily_post_skip_date    DATE,
  ADD COLUMN IF NOT EXISTS daily_post_paused_until DATE;

-- Set by the job when generating a group's post fails. The job runs every
-- minute, so without it a failing group would retry (and pay for) generation
-- every minute; it waits an hour instead.
ALTER TABLE fellowships
  ADD COLUMN IF NOT EXISTS daily_post_last_failed_at TIMESTAMPTZ;

-- Times are India Standard Time. Every slot is after 05:30 IST, so the IST
-- date and the UTC date the job keys posts on are always the same day.
ALTER TABLE fellowships DROP CONSTRAINT IF EXISTS fellowships_daily_post_time_check;
ALTER TABLE fellowships ADD CONSTRAINT fellowships_daily_post_time_check
  CHECK (daily_post_time IN ('06:30', '08:00', '12:00', '18:00', '20:00'));

COMMENT ON COLUMN fellowships.daily_post_preview_allowed IS 'Admin: mentors may generate a preview of the next daily post.';
COMMENT ON COLUMN fellowships.daily_post_regenerate_allowed IS 'Admin: mentors may regenerate the next daily post teaser (capped per day).';
COMMENT ON COLUMN fellowships.daily_post_post_now_allowed IS 'Admin: mentors may publish today''s daily post immediately.';
COMMENT ON COLUMN fellowships.daily_post_time IS 'Mentor: IST time the daily post goes out.';
COMMENT ON COLUMN fellowships.daily_post_skip_date IS 'Mentor: no daily post on this date.';
COMMENT ON COLUMN fellowships.daily_post_paused_until IS 'Mentor: no daily posts up to and including this date.';

-- The next post's lesson and teaser, generated ahead of time. The job reuses the
-- teaser when it posts the same lesson on the same date, so a preview is not
-- paid for twice.
CREATE TABLE IF NOT EXISTS discipler_daily_post_previews (
  fellowship_id           UUID PRIMARY KEY REFERENCES fellowships(id) ON DELETE CASCADE,
  post_date               DATE NOT NULL,
  learning_path_topic_id  UUID NOT NULL,
  topic_id                UUID NOT NULL,
  topic_title             TEXT NOT NULL,
  study_guide_id          UUID REFERENCES study_guides(id) ON DELETE SET NULL,
  teaser_hook             TEXT,
  teaser_body             TEXT,
  content                 TEXT NOT NULL,
  regenerate_date         DATE,
  regenerate_count        INTEGER NOT NULL DEFAULT 0,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS discipler_daily_post_requests (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  kind          TEXT NOT NULL CHECK (kind IN ('post_now', 'preview', 'regenerate', 'repost')),
  requested_by  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- For 'repost': the daily post to replace with a newly written version.
  target_daily_post_id UUID REFERENCES discipler_daily_posts(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'done', 'failed')),
  error         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- When the job picked it up. A request still 'processing' long after this
  -- was abandoned (process restarted) and is picked up again.
  claimed_at    TIMESTAMPTZ,
  processed_at  TIMESTAMPTZ
);

-- One open request of each kind per fellowship: a second tap does not queue a
-- second LLM call.
CREATE UNIQUE INDEX IF NOT EXISTS uq_daily_post_request_open
  ON discipler_daily_post_requests (fellowship_id, kind)
  WHERE status IN ('pending', 'processing');
CREATE INDEX IF NOT EXISTS idx_daily_post_requests_pending
  ON discipler_daily_post_requests (created_at)
  WHERE status = 'pending';

-- Service role only (Edge Functions and rs-backend); no client access.
ALTER TABLE discipler_daily_post_previews ENABLE ROW LEVEL SECURITY;
ALTER TABLE discipler_daily_post_requests ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.discipler_daily_post_previews TO service_role;
GRANT ALL ON public.discipler_daily_post_requests TO service_role;

-- The job now runs every minute: it posts for each fellowship once its chosen
-- time has passed and processes mentor requests promptly.
UPDATE cron_config
   SET schedule = '0 * * * * *',
       label = 'Every minute — Discipler daily posts at each group''s time, and mentor requests',
       updated_at = now()
 WHERE name = 'fellowship_daily_post';

COMMIT;
