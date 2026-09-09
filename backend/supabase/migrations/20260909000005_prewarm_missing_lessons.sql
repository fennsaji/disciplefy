-- Lists catalogue lessons that have no cached guide yet, for the pre-warm
-- script (backend/scripts/prewarm-catalogue.ts).
--
-- "Missing" is judged on topic_id, which is what the app now looks guides up
-- by, so a lesson the blog generator already wrote under a translated title
-- counts as present and is not paid for twice.

CREATE OR REPLACE FUNCTION public.prewarm_missing_lessons(
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
  disciple_level   TEXT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    rt.id,
    -- The localised title when there is one, so the guide reads in the
    -- language it was asked for.
    COALESCE(rtt.title, rt.title),
    COALESCE(rtt.description, rt.description),
    COALESCE(lpt_tr.title, lp.title),
    lp.description,
    lp.disciple_level
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
