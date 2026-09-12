-- Lets an admin choose which learning path the telegram_daily_post and
-- prewarm pickers start from, instead of always the catalogue's earliest
-- topic — the same kind of control fellowship_daily_post already gives a
-- mentor over their group's current learning path, but for these two global
-- jobs.
--
-- NULL (the default) means "no override" — both pickers behave exactly as
-- they do today, starting from the earliest active topic. Setting a value
-- makes every topic in an earlier-ordered path invisible to that job's
-- picker, as if already done, without touching any sent/generated history.

CREATE TABLE public.content_pipeline_progress (
  job_name               TEXT PRIMARY KEY CHECK (job_name IN ('telegram_daily_post', 'prewarm')),
  start_learning_path_id UUID REFERENCES public.learning_paths(id) ON DELETE SET NULL,
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO public.content_pipeline_progress (job_name) VALUES
  ('telegram_daily_post'),
  ('prewarm')
ON CONFLICT (job_name) DO NOTHING;

CREATE OR REPLACE FUNCTION public.update_content_pipeline_progress_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER content_pipeline_progress_updated_at
  BEFORE UPDATE ON public.content_pipeline_progress
  FOR EACH ROW EXECUTE FUNCTION public.update_content_pipeline_progress_updated_at();

ALTER TABLE public.content_pipeline_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY content_pipeline_progress_service_write ON public.content_pipeline_progress
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- Apply the override in both pickers: skip topics whose path sorts earlier
-- than the chosen start path, by display_order.
-- ---------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.next_telegram_topic(TEXT);

CREATE FUNCTION public.next_telegram_topic(p_language TEXT DEFAULT 'en')
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
  WITH start_order AS (
    SELECT lp.display_order AS v
      FROM content_pipeline_progress cpp
      JOIN learning_paths lp ON lp.id = cpp.start_learning_path_id
     WHERE cpp.job_name = 'telegram_daily_post'
  ),
  shared_topic AS (
    -- The earliest catalogue topic not yet sent in every one of en, hi and ml.
    -- This is the one topic of the day, whatever language asks.
    SELECT rt.id
      FROM learning_path_topics lpt
      JOIN learning_paths lp     ON lp.id = lpt.learning_path_id
      JOIN recommended_topics rt ON rt.id = lpt.topic_id
     WHERE lpt.is_active
       AND rt.is_active
       AND lp.is_active
       AND (NOT EXISTS (SELECT 1 FROM start_order) OR lp.display_order >= (SELECT v FROM start_order))
       AND NOT (
         EXISTS (SELECT 1 FROM telegram_daily_posts t WHERE t.topic_id = rt.id AND t.language = 'en' AND t.status = 'sent')
         AND EXISTS (SELECT 1 FROM telegram_daily_posts t WHERE t.topic_id = rt.id AND t.language = 'hi' AND t.status = 'sent')
         AND EXISTS (SELECT 1 FROM telegram_daily_posts t WHERE t.topic_id = rt.id AND t.language = 'ml' AND t.status = 'sent')
       )
     ORDER BY lp.display_order, lpt.position, rt.title
     LIMIT 1
  )
  SELECT
    rt.id,
    COALESCE(rtt.title, rt.title),
    COALESCE(g.summary, rtt.description, rt.description),
    lp.id,
    COALESCE(lpt_tr.title, lp.title),
    b.slug,
    g.related_verses[1],
    g.reflection_questions[1]
  FROM shared_topic st
  JOIN recommended_topics rt        ON rt.id = st.id
  JOIN learning_path_topics lpt     ON lpt.topic_id = rt.id AND lpt.is_active
  JOIN learning_paths lp            ON lp.id = lpt.learning_path_id AND lp.is_active
  LEFT JOIN recommended_topics_translations rtt
         ON rtt.topic_id = rt.id AND rtt.language_code = p_language
  LEFT JOIN learning_path_translations lpt_tr
         ON lpt_tr.learning_path_id = lp.id AND lpt_tr.lang_code = p_language
  JOIN LATERAL (
    SELECT bp.slug, bp.source_guide_id
      FROM blog_posts bp
     WHERE bp.source_topic_id IN (
             SELECT x.id FROM learning_path_topics x WHERE x.topic_id = rt.id
           )
       AND bp.status = 'published'
       AND bp.locale = p_language
     ORDER BY bp.published_at DESC NULLS LAST
     LIMIT 1
  ) b ON TRUE
  LEFT JOIN study_guides g ON g.id = b.source_guide_id
  -- This language's own turn on the shared topic: skip if it has already sent
  -- it (an earlier run, or a retry), so today's slot doesn't repeat.
  WHERE NOT EXISTS (
    SELECT 1 FROM telegram_daily_posts t
     WHERE t.topic_id = rt.id AND t.language = p_language AND t.status = 'sent'
  )
  -- A topic linked into multiple paths joins lpt/lp more than once above;
  -- take one row for it rather than reporting it as several candidates.
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.next_telegram_topic(TEXT) TO service_role;

DROP FUNCTION IF EXISTS public.prewarm_missing_lessons(TEXT, TEXT, INT);

CREATE FUNCTION public.prewarm_missing_lessons(
  p_language   TEXT,
  p_study_mode TEXT DEFAULT 'standard',
  p_limit      INT  DEFAULT 1000
)
RETURNS TABLE (
  topic_id         UUID,
  title            TEXT,
  description      TEXT,
  path_title       TEXT,
  path_description TEXT,
  disciple_level   TEXT,
  path_order       INT,
  topic_position   INT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  WITH start_order AS (
    SELECT lp.display_order AS v
      FROM content_pipeline_progress cpp
      JOIN learning_paths lp ON lp.id = cpp.start_learning_path_id
     WHERE cpp.job_name = 'prewarm'
  )
  SELECT topic_id, title, description, path_title, path_description, disciple_level, path_order, topic_position
  FROM (
    SELECT DISTINCT ON (rt.id)
      rt.id AS topic_id,
      COALESCE(rtt.title, rt.title) AS title,
      COALESCE(rtt.description, rt.description) AS description,
      COALESCE(lpt_tr.title, lp.title) AS path_title,
      lp.description AS path_description,
      lp.disciple_level AS disciple_level,
      lp.display_order AS path_order,
      lpt.position AS topic_position
    FROM learning_path_topics lpt
    JOIN learning_paths lp     ON lp.id = lpt.learning_path_id
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    LEFT JOIN recommended_topics_translations rtt
           ON rtt.topic_id = rt.id AND rtt.language_code = p_language
    LEFT JOIN learning_path_translations lpt_tr
           ON lpt_tr.learning_path_id = lp.id AND lpt_tr.lang_code = p_language
    WHERE lpt.is_active
      AND rt.is_active
      AND lp.is_active
      AND (NOT EXISTS (SELECT 1 FROM start_order) OR lp.display_order >= (SELECT v FROM start_order))
      AND NOT EXISTS (
        SELECT 1 FROM study_guides g
         WHERE g.topic_id = rt.id
           AND g.language = p_language
           AND g.study_mode = p_study_mode
      )
    ORDER BY rt.id, lp.display_order, lpt.position
  ) deduped
  ORDER BY path_order, topic_position, title
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.prewarm_missing_lessons(TEXT, TEXT, INT) TO service_role;
