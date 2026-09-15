-- One way to link a blog to its lesson, and no duplicate blogs.
--
-- blog_posts.source_topic_id has held two different ids: older posts carry
-- learning_path_topics.id, while the blog generator writes recommended_topics.id.
-- next_telegram_topic() and content_pipeline_lessons() only understood the
-- first, so every newer article (e.g. The Gospel of Mark) showed as "no
-- article" in the content pipeline and the Telegram channel waited on it.
--
-- 1. Rewrite older links to recommended_topics.id, unless that topic already has
--    a blog in the same language (that row is a pre-existing duplicate; it keeps
--    its old link so nothing is lost and the unique index still holds).
-- 2. A trigger rewrites any learning_path_topics.id written later, so the
--    existing unique index (source_topic_id, locale) enforces one blog per lesson
--    per language whatever code inserts the row.
-- 3. Both readers match either id, so no leftover row is ever reported missing.

-- 1. Normalise existing rows ---------------------------------------------------

WITH candidates AS (
  SELECT DISTINCT ON (lpt.topic_id, bp.locale)
         bp.id, lpt.topic_id
    FROM blog_posts bp
    JOIN learning_path_topics lpt ON lpt.id = bp.source_topic_id
   WHERE NOT EXISTS (
           SELECT 1 FROM blog_posts other
            WHERE other.source_topic_id = lpt.topic_id
              AND other.locale = bp.locale
         )
   ORDER BY lpt.topic_id, bp.locale, bp.published_at NULLS LAST, bp.created_at
)
UPDATE blog_posts bp
   SET source_topic_id = c.topic_id
  FROM candidates c
 WHERE bp.id = c.id;

DO $$
DECLARE
  leftover INT;
BEGIN
  SELECT count(*) INTO leftover
    FROM blog_posts bp
    JOIN learning_path_topics lpt ON lpt.id = bp.source_topic_id;
  IF leftover > 0 THEN
    RAISE WARNING '% blog post(s) duplicate a lesson that already has a blog in the same language; left linked by learning_path_topics.id', leftover;
  END IF;
END
$$;

-- 2. Keep new rows normalised --------------------------------------------------

CREATE OR REPLACE FUNCTION public.normalize_blog_source_topic()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  resolved UUID;
BEGIN
  IF NEW.source_topic_id IS NOT NULL THEN
    SELECT topic_id INTO resolved FROM learning_path_topics WHERE id = NEW.source_topic_id;
    IF resolved IS NOT NULL THEN
      NEW.source_topic_id := resolved;
    END IF;
  END IF;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS trg_normalize_blog_source_topic ON blog_posts;
CREATE TRIGGER trg_normalize_blog_source_topic
  BEFORE INSERT OR UPDATE OF source_topic_id ON blog_posts
  FOR EACH ROW EXECUTE FUNCTION public.normalize_blog_source_topic();

-- 3. Readers accept either id ---------------------------------------------------

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
     WHERE (bp.source_topic_id = rt.id
            OR bp.source_topic_id IN (SELECT x.id FROM learning_path_topics x WHERE x.topic_id = rt.id))
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

CREATE OR REPLACE FUNCTION public.content_pipeline_lessons()
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
    -- source_topic_id is recommended_topics.id; a few older rows still carry
    -- learning_path_topics.id, so resolve either to the topic.
    SELECT COALESCE(x.topic_id, bp.source_topic_id) AS topic_id,
           bool_or(bp.locale = 'en') AS en,
           bool_or(bp.locale = 'hi') AS hi,
           bool_or(bp.locale = 'ml') AS ml
      FROM blog_posts bp
      LEFT JOIN learning_path_topics x ON x.id = bp.source_topic_id
     WHERE bp.status = 'published'
       AND bp.source_topic_id IS NOT NULL
     GROUP BY COALESCE(x.topic_id, bp.source_topic_id)
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
