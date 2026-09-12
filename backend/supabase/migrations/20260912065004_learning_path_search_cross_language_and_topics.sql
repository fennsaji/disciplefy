-- Searching learning paths in one language could not find a path named in another.
--
-- The predicate matched COALESCE(translated, base): once a path had a
-- translation for the reader's language, the base title stopped being searched
-- at all. With full Malayalam coverage, searching "Faith" as a Malayalam reader
-- returned nothing while the same search in English returned eleven paths —
-- the English titles were there, just unreachable. The COALESCE fallback only
-- ever rescued a query when a translation was MISSING, which is backwards.
--
-- Both texts are now searched: a path is found by its translated wording or by
-- its original one, and what gets displayed is unchanged (still the reader's
-- language, falling back to the base text).
--
-- Second change: a search that matches no path at all now looks inside the
-- paths' topics and returns the paths containing a matching topic. Someone
-- searching for a subject ("baptism") usually wants the path that teaches it,
-- not an empty screen. Topic matching is a fallback, not an addition — when
-- paths match by name, those are the answer and topic hits stay out of the way.

CREATE OR REPLACE FUNCTION public.get_available_learning_paths(p_user_id uuid DEFAULT NULL::uuid, p_language character varying DEFAULT 'en'::character varying, p_include_enrolled boolean DEFAULT true, p_limit integer DEFAULT 10, p_offset integer DEFAULT 0, p_category character varying DEFAULT NULL::character varying, p_search character varying DEFAULT NULL::character varying)
 RETURNS TABLE(path_id uuid, slug character varying, title text, description text, icon_name character varying, color character varying, total_xp integer, estimated_days integer, disciple_level character varying, recommended_mode text, is_featured boolean, total_topics integer, is_enrolled boolean, progress_percentage integer, category character varying)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
  -- Paths matching the search by their own name, in either language.
  --
  -- The same category and enrolled filters as the main query apply here, so
  -- "nothing matched" means nothing the reader would have been shown — a path
  -- hidden by the category filter must not suppress the topic fallback.
  WITH direct_hits AS (
    SELECT lp_d.id
      FROM learning_paths lp_d
      LEFT JOIN learning_path_translations lpt_d
             ON lpt_d.learning_path_id = lp_d.id AND lpt_d.lang_code = p_language
     WHERE p_search IS NOT NULL
       AND lp_d.is_active = true
       AND (p_include_enrolled OR NOT EXISTS(
         SELECT 1 FROM user_learning_path_progress
          WHERE user_id = p_user_id AND learning_path_id = lp_d.id
       ))
       AND (p_category IS NULL OR lp_d.category = p_category)
       AND (
            lp_d.title        ILIKE '%' || p_search || '%'
         OR lp_d.description  ILIKE '%' || p_search || '%'
         OR lpt_d.title       ILIKE '%' || p_search || '%'
         OR lpt_d.description ILIKE '%' || p_search || '%'
       )
  )
  SELECT
    lp.id                                     AS path_id,
    lp.slug,
    COALESCE(lpt.title, lp.title)             AS title,
    COALESCE(lpt.description, lp.description) AS description,
    lp.icon_name,
    lp.color,
    lp.total_xp,
    lp.estimated_days,
    lp.disciple_level,
    lp.recommended_mode,
    lp.is_featured,
    -- Rule A: only visible topics are counted.
    (SELECT COUNT(*)
       FROM learning_path_topics lpt_t
       JOIN recommended_topics rt_t ON rt_t.id = lpt_t.topic_id
      WHERE lpt_t.learning_path_id = lp.id
        AND lpt_t.is_active = true
        AND rt_t.is_active  = true)::INTEGER  AS total_topics,
    CASE WHEN p_user_id IS NOT NULL THEN
      EXISTS(
        SELECT 1 FROM user_learning_path_progress
         WHERE user_id = p_user_id AND learning_path_id = lp.id
      )
    ELSE false END                              AS is_enrolled,
    -- Compute progress from actual user_topic_progress records (not stale counter).
    -- Rule A: numerator and denominator both range over visible topics only, so
    -- completing every visible topic yields exactly 100 and never more.
    CASE WHEN p_user_id IS NOT NULL THEN
      GREATEST(
      CASE WHEN EXISTS (
        SELECT 1 FROM user_learning_path_progress ulpp_done
         WHERE ulpp_done.user_id          = p_user_id
           AND ulpp_done.learning_path_id = lp.id
           AND ulpp_done.completed_at     IS NOT NULL
      ) THEN 100 ELSE 0 END,
      COALESCE(
        (SELECT (
          COUNT(CASE WHEN utp.completed_at IS NOT NULL THEN 1 END) * 100
          / GREATEST(
              (SELECT COUNT(*)
                 FROM learning_path_topics lpt_d2
                 JOIN recommended_topics rt_d2 ON rt_d2.id = lpt_d2.topic_id
                WHERE lpt_d2.learning_path_id = lp.id
                  AND lpt_d2.is_active = true
                  AND rt_d2.is_active  = true),
              1)
        )::INTEGER
        FROM learning_path_topics lpt_inner
        JOIN recommended_topics rt_inner ON rt_inner.id = lpt_inner.topic_id
        LEFT JOIN user_topic_progress utp
               ON utp.topic_id = lpt_inner.topic_id AND utp.user_id = p_user_id
        WHERE lpt_inner.learning_path_id = lp.id
          AND lpt_inner.is_active = true
          AND rt_inner.is_active  = true
        ),
        0
      ))
    ELSE 0 END                                  AS progress_percentage,
    lp.category
  FROM learning_paths lp
  LEFT JOIN learning_path_translations lpt
         ON lpt.learning_path_id = lp.id AND lpt.lang_code = p_language
  WHERE lp.is_active = true
    AND (p_include_enrolled OR NOT EXISTS(
      SELECT 1 FROM user_learning_path_progress
       WHERE user_id = p_user_id AND learning_path_id = lp.id
    ))
    AND (p_category IS NULL OR lp.category = p_category)
    AND (
      p_search IS NULL
      OR lp.id IN (SELECT id FROM direct_hits)
      -- Nothing matched by name: fall back to what the paths teach, so a
      -- subject the reader typed still leads them to the path covering it.
      OR (
        NOT EXISTS (SELECT 1 FROM direct_hits)
        AND EXISTS (
          SELECT 1
            FROM learning_path_topics lpt_s
            JOIN recommended_topics rt_s ON rt_s.id = lpt_s.topic_id
            LEFT JOIN recommended_topics_translations rtt_s
                   ON rtt_s.topic_id = rt_s.id AND rtt_s.language_code = p_language
           WHERE lpt_s.learning_path_id = lp.id
             AND lpt_s.is_active = true
             AND rt_s.is_active  = true
             AND (
                  rt_s.title        ILIKE '%' || p_search || '%'
               OR rt_s.description  ILIKE '%' || p_search || '%'
               OR rtt_s.title       ILIKE '%' || p_search || '%'
               OR rtt_s.description ILIKE '%' || p_search || '%'
             )
        )
      )
    )
  ORDER BY
    -- Completed paths always last
    CASE WHEN p_user_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM user_learning_path_progress ulpp_c
       WHERE ulpp_c.user_id          = p_user_id
         AND ulpp_c.learning_path_id = lp.id
         AND ulpp_c.completed_at     IS NOT NULL
    ) THEN 1 ELSE 0 END,
    -- In-progress first (enrolled + has some completions + not finished)
    CASE WHEN p_user_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM user_learning_path_progress ulpp2
       WHERE ulpp2.user_id           = p_user_id
         AND ulpp2.learning_path_id  = lp.id
         AND ulpp2.completed_at      IS NULL
    ) AND EXISTS(
      SELECT 1 FROM learning_path_topics lpt2
      JOIN recommended_topics rt2 ON rt2.id = lpt2.topic_id
      JOIN user_topic_progress utp2 ON utp2.topic_id = lpt2.topic_id AND utp2.user_id = p_user_id
      WHERE lpt2.learning_path_id = lp.id
        AND lpt2.is_active = true
        AND rt2.is_active  = true
        AND utp2.completed_at IS NOT NULL
    ) THEN 0 ELSE 1 END,
    -- Enrolled-incomplete next
    CASE WHEN p_user_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM user_learning_path_progress ulpp3
       WHERE ulpp3.user_id          = p_user_id
         AND ulpp3.learning_path_id = lp.id
         AND ulpp3.completed_at     IS NULL
    ) THEN 0 ELSE 1 END,
    -- Featured next
    CASE WHEN lp.is_featured THEN 0 ELSE 1 END,
    lp.display_order,
    lp.title
  LIMIT p_limit
  OFFSET p_offset;
$function$
