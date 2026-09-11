-- The Telegram picker grounded its teaser on the topic description while the
-- fellowship cron grounds on the study guide's summary. Both now key the teaser
-- cache on topic_id, so whichever runs first writes the wording the other
-- reuses; give them the same grounding so the wording is the same quality
-- regardless of which surface generated it.

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
  SELECT
    rt.id,
    COALESCE(rtt.title, rt.title),
    -- The article's study guide summary when it has one, matching what the
    -- fellowship cron sends; the topic description otherwise.
    COALESCE(g.summary, rtt.description, rt.description),
    lp.id,
    COALESCE(lpt_tr.title, lp.title),
    b.slug,
    g.related_verses[1],
    g.reflection_questions[1]
  FROM learning_path_topics lpt
  JOIN learning_paths lp      ON lp.id = lpt.learning_path_id
  JOIN recommended_topics rt  ON rt.id = lpt.topic_id
  LEFT JOIN recommended_topics_translations rtt
         ON rtt.topic_id = rt.id AND rtt.language_code = p_language
  LEFT JOIN learning_path_translations lpt_tr
         ON lpt_tr.learning_path_id = lp.id AND lpt_tr.lang_code = p_language
  JOIN LATERAL (
    SELECT bp.slug, bp.source_guide_id
      FROM blog_posts bp
     WHERE bp.source_topic_id = rt.id
       AND bp.status = 'published'
       AND bp.locale = p_language
     ORDER BY bp.published_at DESC NULLS LAST
     LIMIT 1
  ) b ON TRUE
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
