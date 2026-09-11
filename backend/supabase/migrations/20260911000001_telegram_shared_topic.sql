-- All three languages post the same topic on Telegram, not their own cursor.
--
-- Each language previously picked the earliest topic it personally hadn't
-- posted, gated only by having a published blog article in that language. If
-- Hindi's blog lagged a day behind English, the channel showed two different
-- topics on the same day in different languages — confusing for anyone
-- following more than one language.
--
-- The catalogue's shared topic is now the earliest one not yet sent in ALL
-- THREE languages. A language whose blog article for that topic isn't ready,
-- or that has already sent it (from before this fix, or a retry), gets no
-- row today and is skipped, exactly like "no topic with a published article"
-- already was. The topic only advances once every language has sent it.

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
     WHERE bp.source_topic_id = rt.id
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
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.next_telegram_topic(TEXT) TO service_role;
