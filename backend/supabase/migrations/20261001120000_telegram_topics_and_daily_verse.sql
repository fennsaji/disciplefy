-- Telegram forum topics, the daily verse post, and live schedules.
--
-- The Telegram group now uses forum topics: each post kind goes to a topic per
-- language. Which topic is data, not code — change a thread id with
--   UPDATE public.telegram_topics SET thread_id = <id> WHERE kind = '<kind>' AND language = '<lang>';
-- and delete a row to post that kind/language to the group with no topic.
--
-- Scheduling stays in cron_config (rs-backend dispatches it; the admin Crons
-- page edits it). Both Telegram jobs are enabled here: turning the channel on
-- was an explicit product decision.

CREATE TABLE IF NOT EXISTS public.telegram_topics (
  kind       TEXT NOT NULL CHECK (kind IN ('study_post', 'daily_verse')),
  language   TEXT NOT NULL CHECK (language IN ('en', 'hi', 'ml')),
  thread_id  BIGINT NOT NULL CHECK (thread_id > 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (kind, language)
);

COMMENT ON TABLE public.telegram_topics IS
  'Telegram forum topic (message_thread_id) per post kind and language. Missing row = post without a topic.';

-- Service role only: no policies, RLS on.
ALTER TABLE public.telegram_topics ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.telegram_topics FROM anon, authenticated;
GRANT ALL ON public.telegram_topics TO service_role;

INSERT INTO public.telegram_topics (kind, language, thread_id) VALUES
  ('study_post',  'en', 74),
  ('study_post',  'hi', 72),
  ('study_post',  'ml', 73),
  ('daily_verse', 'en', 79),
  ('daily_verse', 'hi', 80),
  ('daily_verse', 'ml', 81)
ON CONFLICT (kind, language) DO NOTHING;

-- Ledger for the daily verse post: one row per date and language, so a retry
-- cannot post twice. A failed row is replaced by the retry's outcome.
CREATE TABLE IF NOT EXISTS public.telegram_daily_verse_posts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_date   DATE NOT NULL,
  language    TEXT NOT NULL CHECK (language IN ('en', 'hi', 'ml')),
  reference   TEXT NOT NULL,
  thread_id   BIGINT,
  message_id  BIGINT,
  status      TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'failed')),
  error       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT telegram_daily_verse_posts_date_lang_unique UNIQUE (post_date, language)
);

ALTER TABLE public.telegram_daily_verse_posts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.telegram_daily_verse_posts FROM anon, authenticated;
GRANT ALL ON public.telegram_daily_verse_posts TO service_role;

-- Schedules (6-field, UTC). Daily verse 06:00 IST, study post 08:00 IST.
INSERT INTO public.cron_config (name, enabled, schedule, label, updated_at)
VALUES ('telegram_daily_verse', true, '0 30 0 * * *',
        'Daily 06:00 IST — Telegram daily verse (en, hi, ml)', NOW())
ON CONFLICT (name) DO UPDATE
  SET enabled = true, schedule = EXCLUDED.schedule, label = EXCLUDED.label, updated_at = NOW();

INSERT INTO public.cron_config (name, enabled, schedule, label, updated_at)
VALUES ('telegram_daily_post', true, '0 30 2 * * *',
        'Daily 08:00 IST — Telegram study post (en, hi, ml)', NOW())
ON CONFLICT (name) DO UPDATE
  SET enabled = true, schedule = EXCLUDED.schedule, label = EXCLUDED.label, updated_at = NOW();
