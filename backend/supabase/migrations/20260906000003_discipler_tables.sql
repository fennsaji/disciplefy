-- =====================================================
-- Migration: Discipler tables
-- Date: 2026-09-06
-- Tables: discipler_reply_queue, discipler_replies, discipler_activity, discipler_daily_posts
-- =====================================================

BEGIN;

CREATE TABLE IF NOT EXISTS discipler_reply_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES fellowship_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES fellowship_comments(id) ON DELETE CASCADE,
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  trigger TEXT NOT NULL CHECK (trigger IN ('mention', 'question')),
  run_after TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'done', 'failed',
                      'skipped_mentor_answered', 'skipped_gate', 'skipped_injection', 'skipped_budget')),
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_discipler_queue_due
  ON discipler_reply_queue (run_after) WHERE status = 'pending';
-- One queue row per target; NULL comment_id means "the post itself" (PG15+ NULLS NOT DISTINCT).
ALTER TABLE discipler_reply_queue DROP CONSTRAINT IF EXISTS uq_discipler_queue_target;
ALTER TABLE discipler_reply_queue ADD CONSTRAINT uq_discipler_queue_target
  UNIQUE NULLS NOT DISTINCT (post_id, comment_id);

CREATE TABLE IF NOT EXISTS discipler_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_id UUID REFERENCES discipler_reply_queue(id) ON DELETE SET NULL,
  post_id UUID NOT NULL REFERENCES fellowship_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES fellowship_comments(id) ON DELETE SET NULL,
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  asked_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  trigger TEXT NOT NULL CHECK (trigger IN ('mention', 'question')),
  action TEXT NOT NULL CHECK (action IN ('reply', 'react')),
  reaction TEXT,
  guide_attached BOOLEAN NOT NULL DEFAULT false,
  language_detected TEXT,
  model TEXT NOT NULL,
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  cost_usd NUMERIC(10, 6) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_discipler_replies_day
  ON discipler_replies (fellowship_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_discipler_replies_user_day
  ON discipler_replies (asked_by, created_at DESC);

CREATE TABLE IF NOT EXISTS discipler_activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('reply', 'react', 'draft', 'daily_post')),
  post_id UUID REFERENCES fellowship_posts(id) ON DELETE CASCADE,
  comment_id UUID REFERENCES fellowship_comments(id) ON DELETE CASCADE,
  reaction TEXT,
  language TEXT,
  summary TEXT NOT NULL,
  pushed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_discipler_activity_fellowship
  ON discipler_activity (fellowship_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_discipler_activity_unpushed
  ON discipler_activity (fellowship_id) WHERE pushed_at IS NULL;

CREATE TABLE IF NOT EXISTS discipler_daily_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fellowship_id UUID NOT NULL REFERENCES fellowships(id) ON DELETE CASCADE,
  post_date DATE NOT NULL,
  topic_id UUID NOT NULL,
  learning_path_topic_id UUID NOT NULL,
  study_guide_id UUID REFERENCES study_guides(id) ON DELETE SET NULL,
  post_id UUID REFERENCES fellowship_posts(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_discipler_daily UNIQUE (fellowship_id, post_date)
);
CREATE INDEX IF NOT EXISTS idx_discipler_daily_topic
  ON discipler_daily_posts (fellowship_id, learning_path_topic_id);

-- Budget helper: replies today for a user and for a fellowship (UTC day).
CREATE OR REPLACE FUNCTION discipler_daily_budget(p_fellowship_id UUID, p_user_id UUID)
RETURNS TABLE(user_count INTEGER, fellowship_count INTEGER)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    (SELECT COUNT(*)::int FROM discipler_replies
      WHERE asked_by = p_user_id AND created_at >= date_trunc('day', now())),
    (SELECT COUNT(*)::int FROM discipler_replies
      WHERE fellowship_id = p_fellowship_id AND created_at >= date_trunc('day', now()));
$$;

-- RLS: service role only, like every other fellowship table.
ALTER TABLE discipler_reply_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE discipler_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE discipler_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE discipler_daily_posts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "discipler_reply_queue_service_all" ON discipler_reply_queue;
CREATE POLICY "discipler_reply_queue_service_all" ON discipler_reply_queue FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "discipler_replies_service_all" ON discipler_replies;
CREATE POLICY "discipler_replies_service_all" ON discipler_replies FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "discipler_activity_service_all" ON discipler_activity;
CREATE POLICY "discipler_activity_service_all" ON discipler_activity FOR ALL TO service_role USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "discipler_daily_posts_service_all" ON discipler_daily_posts;
CREATE POLICY "discipler_daily_posts_service_all" ON discipler_daily_posts FOR ALL TO service_role USING (true) WITH CHECK (true);

GRANT ALL ON public.discipler_reply_queue TO service_role;
GRANT ALL ON public.discipler_replies TO service_role;
GRANT ALL ON public.discipler_activity TO service_role;
GRANT ALL ON public.discipler_daily_posts TO service_role;

COMMIT;
