-- Post the daily lesson in all three languages, to the same channel.
--
-- Two gaps in the first cut:
--   1. The cron sent an empty body, so the job always ran as English. The
--      picker, the teaser cache and the ledger were already keyed by language;
--      nothing ever asked for hi or ml.
--   2. The picker read titles from the base tables, which hold English. A Hindi
--      post would have carried a Hindi teaser under an English heading.
--
-- A missing translation falls back to English rather than skipping the lesson:
-- a partly-translated post still reads; a skipped one leaves the channel silent.

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
    COALESCE(rtt.description, rt.description),
    lp.id,
    COALESCE(lpt_tr.title, lp.title),
    b.slug,
    -- Grounding for the teaser prompt: the same fields the fellowship cron
    -- sends, so whichever surface generates a lesson's teaser first produces
    -- the same quality and the other reuses it.
    g.related_verses[1],
    g.reflection_questions[1]
  FROM learning_path_topics lpt
  JOIN learning_paths lp      ON lp.id = lpt.learning_path_id
  JOIN recommended_topics rt  ON rt.id = lpt.topic_id
  -- Localised copy. English has no rows in these tables, so the COALESCE above
  -- resolves to the base tables for 'en'.
  LEFT JOIN recommended_topics_translations rtt
         ON rtt.topic_id = rt.id AND rtt.language_code = p_language
  LEFT JOIN learning_path_translations lpt_tr
         ON lpt_tr.learning_path_id = lp.id AND lpt_tr.lang_code = p_language
  -- Only lessons with somewhere to send the reader, in this language.
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

-- Three sends a day into the one channel, spaced so they do not arrive as a
-- block: 09:00, 11:00 and 13:00 UTC = 14:30, 16:30 and 18:30 IST.
DO $$
DECLARE
  job RECORD;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')
     OR NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE NOTICE 'pg_cron/pg_net not installed; skipping telegram schedule update.';
    RETURN;
  END IF;

  -- The English-only job is replaced by the three below.
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'telegram-daily-post') THEN
    PERFORM cron.unschedule('telegram-daily-post');
  END IF;

  FOR job IN
    SELECT * FROM (VALUES
      ('telegram-daily-post-en', '0 9 * * *',  'en'),
      ('telegram-daily-post-hi', '0 11 * * *', 'hi'),
      ('telegram-daily-post-ml', '0 13 * * *', 'ml')
    ) AS t(name, schedule, language)
  LOOP
    PERFORM cron.schedule(
      job.name,
      job.schedule,
      format($job$
        SELECT net.http_post(
          url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
                 || '/functions/v1/telegram-daily-post',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' ||
              (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
          ),
          body := jsonb_build_object('language', %L)
        );
      $job$, job.language)
    );
    RAISE NOTICE 'Scheduled cron job: % (%)', job.name, job.schedule;
  END LOOP;
END
$$;

-- To remove:
--   SELECT cron.unschedule('telegram-daily-post-en');
--   SELECT cron.unschedule('telegram-daily-post-hi');
--   SELECT cron.unschedule('telegram-daily-post-ml');
