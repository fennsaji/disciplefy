-- Scheduled publishing for blog posts.
-- Adds a 'scheduled' status + scheduled_for timestamp. A rs-backend poll cron
-- flips due rows to 'published'. Public RLS read stays 'published' only, so
-- scheduled rows are never publicly visible.

BEGIN;

ALTER TABLE blog_posts DROP CONSTRAINT IF EXISTS blog_posts_status_check;
ALTER TABLE blog_posts
  ADD CONSTRAINT blog_posts_status_check
  CHECK (status IN ('draft', 'published', 'scheduled'));

ALTER TABLE blog_posts ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ;

-- A scheduled post must carry a target time.
ALTER TABLE blog_posts DROP CONSTRAINT IF EXISTS blog_posts_scheduled_requires_time;
ALTER TABLE blog_posts
  ADD CONSTRAINT blog_posts_scheduled_requires_time
  CHECK (status <> 'scheduled' OR scheduled_for IS NOT NULL);

-- Poll index: only scheduled rows.
CREATE INDEX IF NOT EXISTS idx_blog_posts_scheduled
  ON blog_posts(scheduled_for) WHERE status = 'scheduled';

-- Seed cron_config row so the new job persists + is listed by admin cron status.
-- cron_config.name is TEXT PRIMARY KEY (see 20260325000000_cron_config.sql), so
-- ON CONFLICT (name) is valid here.
INSERT INTO cron_config (name, enabled, schedule, label)
VALUES ('blog_publish_scheduled', true, '0 * * * * *', 'Every minute — publish due scheduled posts')
ON CONFLICT (name) DO NOTHING;

COMMIT;
