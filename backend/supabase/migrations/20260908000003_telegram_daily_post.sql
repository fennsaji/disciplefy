-- Daily lesson broadcast to the official Telegram channel.
--
-- Independent of any fellowship: the channel walks the catalogue once, in
-- learning-path display order and then topic position, one lesson a day. The
-- ledger below is both the record and the cursor — the next lesson is simply
-- the first one it does not already contain.
--
-- A lesson only goes out when it has a published blog post to link to; the
-- picker skips the rest rather than posting a dead link.

CREATE TABLE IF NOT EXISTS public.telegram_daily_posts (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_date        DATE NOT NULL,
  topic_id         UUID NOT NULL REFERENCES public.recommended_topics(id) ON DELETE CASCADE,
  learning_path_id UUID REFERENCES public.learning_paths(id) ON DELETE SET NULL,
  blog_slug        TEXT NOT NULL,
  language         TEXT NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'hi', 'ml')),
  -- Telegram's id for the sent message, for editing or deleting it later.
  message_id       BIGINT,
  status           TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent', 'failed')),
  error            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- One post per channel-day. A retry after a failure replaces the failed row.
  CONSTRAINT telegram_daily_posts_date_unique UNIQUE (post_date, language)
);

-- The cursor query asks "has this topic gone out yet?" for every candidate.
CREATE INDEX IF NOT EXISTS idx_telegram_daily_posts_topic
  ON public.telegram_daily_posts (topic_id, language) WHERE status = 'sent';

ALTER TABLE public.telegram_daily_posts ENABLE ROW LEVEL SECURITY;
-- No policies: the broadcast job is the only reader and writer.
GRANT ALL ON public.telegram_daily_posts TO service_role;

/**
 * The next lesson due on the Telegram channel, or no rows when the catalogue
 * is exhausted.
 *
 * Ordering is the catalogue's own: learning path display order, then the
 * topic's position inside that path. A topic that appears in two paths is
 * offered at its earliest position and skipped afterwards, because the ledger
 * check is by topic, not by path.
 */
CREATE OR REPLACE FUNCTION public.next_telegram_topic(p_language TEXT DEFAULT 'en')
RETURNS TABLE (
  topic_id          UUID,
  topic_title       TEXT,
  topic_description TEXT,
  learning_path_id  UUID,
  path_title        TEXT,
  blog_slug         TEXT,
  verse             TEXT,
  question          TEXT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    rt.id,
    rt.title,
    rt.description,
    lp.id,
    lp.title,
    b.slug,
    -- Grounding for the teaser prompt. The same fields the fellowship cron
    -- sends, so whichever surface generates a lesson's teaser first produces
    -- the same quality — the wording is then shared by both.
    g.related_verses[1],
    g.reflection_questions[1]
  FROM learning_path_topics lpt
  JOIN learning_paths lp      ON lp.id = lpt.learning_path_id
  JOIN recommended_topics rt  ON rt.id = lpt.topic_id
  -- Only lessons with somewhere to send the reader.
  JOIN LATERAL (
    SELECT bp.slug, bp.source_guide_id
      FROM blog_posts bp
     WHERE bp.source_topic_id = rt.id
       AND bp.status = 'published'
       AND bp.locale = p_language
     ORDER BY bp.published_at DESC NULLS LAST
     LIMIT 1
  ) b ON TRUE
  -- The article's own study guide, when it has one: LEFT, because a missing
  -- guide costs the teaser some grounding but must not skip the lesson.
  LEFT JOIN study_guides g ON g.id = b.source_guide_id
  WHERE lpt.is_active
    AND rt.is_active
    AND lp.is_active
    AND NOT EXISTS (
      SELECT 1 FROM telegram_daily_posts t
       WHERE t.topic_id = rt.id
         AND t.language = p_language
         AND t.status = 'sent'
    )
  ORDER BY lp.display_order, lpt.position, rt.title
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.next_telegram_topic(TEXT) TO service_role;

COMMENT ON TABLE public.telegram_daily_posts IS
  'One row per day the official Telegram channel posted a lesson; also the cursor for the next one.';
