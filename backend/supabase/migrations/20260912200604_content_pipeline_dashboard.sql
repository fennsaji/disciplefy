-- Content pipeline dashboard: lesson-level start point and one read model of
-- every catalogue lesson with its per-language state for both jobs.
--
-- Replaces the path-only start override and the two *_current_topic helpers
-- (20260912190913), which only reported one row and could not explain why a
-- job was stuck.

ALTER TABLE public.content_pipeline_progress
  ADD COLUMN start_learning_path_topic_id UUID
    REFERENCES public.learning_path_topics(id) ON DELETE SET NULL;

DROP FUNCTION IF EXISTS public.telegram_current_topic(TEXT);
DROP FUNCTION IF EXISTS public.prewarm_current_topic(TEXT, TEXT);

-- ---------------------------------------------------------------------------
-- Start key: the (path display_order, topic position) a job resumes from.
-- A chosen lesson gives its exact position; a chosen path starts at its first
-- lesson. No row when there is no override.
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.content_pipeline_start(p_job TEXT)
RETURNS TABLE (path_order INT, topic_position INT)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(tp.display_order, lp.display_order)::int,
         CASE WHEN lpt.id IS NOT NULL THEN lpt.position ELSE -2147483648 END::int
    FROM content_pipeline_progress cpp
    LEFT JOIN learning_path_topics lpt ON lpt.id = cpp.start_learning_path_topic_id
    LEFT JOIN learning_paths tp        ON tp.id = lpt.learning_path_id
    LEFT JOIN learning_paths lp        ON lp.id = cpp.start_learning_path_id
   WHERE cpp.job_name = p_job
     AND COALESCE(tp.display_order, lp.display_order) IS NOT NULL;
$$;

GRANT EXECUTE ON FUNCTION public.content_pipeline_start(TEXT) TO service_role;

-- ---------------------------------------------------------------------------
-- Pickers: skip every lesson that sorts before the start key.
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
  WITH shared_topic AS (
    -- The earliest catalogue topic not yet sent in every one of en, hi and ml.
    -- This is the one topic of the day, whatever language asks.
    SELECT rt.id
      FROM learning_path_topics lpt
      JOIN learning_paths lp     ON lp.id = lpt.learning_path_id
      JOIN recommended_topics rt ON rt.id = lpt.topic_id
     WHERE lpt.is_active
       AND rt.is_active
       AND lp.is_active
       AND NOT EXISTS (
         SELECT 1 FROM content_pipeline_start('telegram_daily_post') s
          WHERE (lp.display_order, lpt.position) < (s.path_order, s.topic_position)
       )
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
  WHERE NOT EXISTS (
    SELECT 1 FROM telegram_daily_posts t
     WHERE t.topic_id = rt.id AND t.language = p_language AND t.status = 'sent'
  )
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
      AND NOT EXISTS (
        SELECT 1 FROM content_pipeline_start('prewarm') s
         WHERE (lp.display_order, lpt.position) < (s.path_order, s.topic_position)
      )
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

-- ---------------------------------------------------------------------------
-- Read model: every active catalogue lesson, in catalogue order, with what
-- each job has done for it per language. Aggregated once per source table so
-- the whole catalogue is one cheap scan, not a subquery per lesson.
-- ---------------------------------------------------------------------------

CREATE FUNCTION public.content_pipeline_lessons()
RETURNS TABLE (
  learning_path_id       UUID,
  path_title             TEXT,
  path_order             INT,
  learning_path_topic_id UUID,
  topic_id               UUID,
  topic_title            TEXT,
  topic_position         INT,
  telegram_sent_en       BOOLEAN,
  telegram_sent_hi       BOOLEAN,
  telegram_sent_ml       BOOLEAN,
  blog_en                BOOLEAN,
  blog_hi                BOOLEAN,
  blog_ml                BOOLEAN,
  guide_en               BOOLEAN,
  guide_hi               BOOLEAN,
  guide_ml               BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  WITH sent AS (
    SELECT t.topic_id,
           bool_or(t.language = 'en') AS en,
           bool_or(t.language = 'hi') AS hi,
           bool_or(t.language = 'ml') AS ml
      FROM telegram_daily_posts t
     WHERE t.status = 'sent'
     GROUP BY t.topic_id
  ),
  blogs AS (
    -- blog_posts.source_topic_id holds learning_path_topics.id, not the topic id.
    SELECT x.topic_id,
           bool_or(bp.locale = 'en') AS en,
           bool_or(bp.locale = 'hi') AS hi,
           bool_or(bp.locale = 'ml') AS ml
      FROM blog_posts bp
      JOIN learning_path_topics x ON x.id = bp.source_topic_id
     WHERE bp.status = 'published'
     GROUP BY x.topic_id
  ),
  guides AS (
    SELECT g.topic_id,
           bool_or(g.language = 'en') AS en,
           bool_or(g.language = 'hi') AS hi,
           bool_or(g.language = 'ml') AS ml
      FROM study_guides g
     WHERE g.topic_id IS NOT NULL
       AND g.study_mode = 'standard'
     GROUP BY g.topic_id
  )
  SELECT lp.id,
         lp.title,
         lp.display_order::int,
         lpt.id,
         rt.id,
         rt.title,
         lpt.position::int,
         COALESCE(s.en, false), COALESCE(s.hi, false), COALESCE(s.ml, false),
         COALESCE(b.en, false), COALESCE(b.hi, false), COALESCE(b.ml, false),
         COALESCE(g.en, false), COALESCE(g.hi, false), COALESCE(g.ml, false)
    FROM learning_path_topics lpt
    JOIN learning_paths lp     ON lp.id = lpt.learning_path_id
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    LEFT JOIN sent s   ON s.topic_id = rt.id
    LEFT JOIN blogs b  ON b.topic_id = rt.id
    LEFT JOIN guides g ON g.topic_id = rt.id
   WHERE lpt.is_active AND lp.is_active AND rt.is_active
   ORDER BY lp.display_order, lp.id, lpt.position, rt.title;
$$;

GRANT EXECUTE ON FUNCTION public.content_pipeline_lessons() TO service_role;
