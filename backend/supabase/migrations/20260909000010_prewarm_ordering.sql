-- Pre-warm in display order, across languages rather than one language at a
-- time.
--
-- The first version returned lessons in path order within a language, but the
-- job asked for English, then Hindi, then Malayalam. On a small monthly budget
-- that cached the whole English catalogue before Malayalam path 1, so a
-- Malayalam reader starting the first path still waited for a live generation
-- while English path 40 sat ready.
--
-- Returning the path and topic ordinals lets the job interleave: every language
-- of lesson 1, then every language of lesson 2. Readers of every language reach
-- a cached guide at the same point in the catalogue.

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
  SELECT
    rt.id,
    COALESCE(rtt.title, rt.title),
    COALESCE(rtt.description, rt.description),
    COALESCE(lpt_tr.title, lp.title),
    lp.description,
    lp.disciple_level,
    lp.display_order,
    lpt.position
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
  ORDER BY lp.display_order, lpt.position, rt.title
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.prewarm_missing_lessons(TEXT, TEXT, INT) TO service_role;
