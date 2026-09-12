-- Admin controls need to show WHERE the pipeline actually is, not just the
-- override floor. These mirror next_telegram_topic()/prewarm_missing_lessons()
-- but ignore any start_learning_path_id override, so they report the real
-- next topic the job would pick if left alone.

CREATE FUNCTION public.telegram_current_topic(p_language TEXT DEFAULT 'en')
RETURNS TABLE (
  topic_id       UUID,
  title          TEXT,
  learning_path_id UUID,
  path_title     TEXT,
  path_order     INT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT rt.id, COALESCE(rtt.title, rt.title), lp.id, COALESCE(lpt_tr.title, lp.title), lp.display_order
    FROM learning_path_topics lpt
    JOIN learning_paths lp     ON lp.id = lpt.learning_path_id
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    LEFT JOIN recommended_topics_translations rtt
           ON rtt.topic_id = rt.id AND rtt.language_code = p_language
    LEFT JOIN learning_path_translations lpt_tr
           ON lpt_tr.learning_path_id = lp.id AND lpt_tr.lang_code = p_language
   WHERE lpt.is_active AND rt.is_active AND lp.is_active
     AND NOT (
       EXISTS (SELECT 1 FROM telegram_daily_posts t WHERE t.topic_id = rt.id AND t.language = 'en' AND t.status = 'sent')
       AND EXISTS (SELECT 1 FROM telegram_daily_posts t WHERE t.topic_id = rt.id AND t.language = 'hi' AND t.status = 'sent')
       AND EXISTS (SELECT 1 FROM telegram_daily_posts t WHERE t.topic_id = rt.id AND t.language = 'ml' AND t.status = 'sent')
     )
   ORDER BY lp.display_order, lpt.position, rt.title
   LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.telegram_current_topic(TEXT) TO service_role;

CREATE FUNCTION public.prewarm_current_topic(
  p_language   TEXT DEFAULT 'en',
  p_study_mode TEXT DEFAULT 'standard'
)
RETURNS TABLE (
  topic_id       UUID,
  title          TEXT,
  learning_path_id UUID,
  path_title     TEXT,
  path_order     INT
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT topic_id, title, learning_path_id, path_title, path_order
  FROM (
    SELECT DISTINCT ON (rt.id)
      rt.id AS topic_id,
      COALESCE(rtt.title, rt.title) AS title,
      lp.id AS learning_path_id,
      COALESCE(lpt_tr.title, lp.title) AS path_title,
      lp.display_order AS path_order,
      lpt.position AS topic_position
    FROM learning_path_topics lpt
    JOIN learning_paths lp     ON lp.id = lpt.learning_path_id
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    LEFT JOIN recommended_topics_translations rtt
           ON rtt.topic_id = rt.id AND rtt.language_code = p_language
    LEFT JOIN learning_path_translations lpt_tr
           ON lpt_tr.learning_path_id = lp.id AND lpt_tr.lang_code = p_language
    WHERE lpt.is_active AND rt.is_active AND lp.is_active
      AND NOT EXISTS (
        SELECT 1 FROM study_guides g
         WHERE g.topic_id = rt.id
           AND g.language = p_language
           AND g.study_mode = p_study_mode
      )
    ORDER BY rt.id, lp.display_order, lpt.position
  ) deduped
  ORDER BY path_order, topic_position, title
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.prewarm_current_topic(TEXT, TEXT) TO service_role;
