-- Fix: prewarm batch submits were failing every tick with "custom_id`s must
-- be unique within a batch" — the Anthropic Batch API rejecting the request
-- outright, so nothing was ever pre-generated since the job was enabled.
--
-- Root cause: a topic can belong to more than one active learning path (10
-- topics currently do, one to as many as 4). This function joined
-- learning_path_topics to learning_paths without deduplicating, so a shared
-- topic produced one row per path it belongs to — all with the same
-- topic_id, hence the same customId(topic_id, language) once the caller
-- built its batch requests. Same input, different call sites (rs-backend's
-- cron vs the prewarm function's own lessonIndex()) — both read this
-- function, both got the duplicates.
--
-- Fixed with DISTINCT ON (topic_id): one row per topic, keeping its
-- earliest-ordered path placement (lowest display_order, then position) as
-- the canonical one for sorting. This does not change which topics are
-- pre-generated, only collapses duplicate rows for the same topic.

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
