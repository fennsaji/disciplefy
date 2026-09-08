-- A path the user finished reads as 0% and gets recommended again.
--
-- Progress was computed only from user_topic_progress rows. Completion can
-- also be recorded at path level, in user_learning_path_progress.completed_at
-- — which is what a path finished through a fellowship, or before per-topic
-- rows were written, leaves behind. Those paths reported 0%, so nothing
-- treated them as complete and the For You section kept suggesting them.
--
-- The stored completion now floors the computed value: whichever says
-- "finished" wins, and a partially-done path still reports its real progress.

CREATE OR REPLACE FUNCTION public.get_available_learning_paths(p_user_id uuid DEFAULT NULL::uuid, p_language character varying DEFAULT 'en'::character varying, p_include_enrolled boolean DEFAULT true, p_limit integer DEFAULT 10, p_offset integer DEFAULT 0, p_category character varying DEFAULT NULL::character varying, p_search character varying DEFAULT NULL::character varying)
 RETURNS TABLE(path_id uuid, slug character varying, title text, description text, icon_name character varying, color character varying, total_xp integer, estimated_days integer, disciple_level character varying, recommended_mode text, is_featured boolean, total_topics integer, is_enrolled boolean, progress_percentage integer, category character varying)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
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
                 FROM learning_path_topics lpt_d
                 JOIN recommended_topics rt_d ON rt_d.id = lpt_d.topic_id
                WHERE lpt_d.learning_path_id = lp.id
                  AND lpt_d.is_active = true
                  AND rt_d.is_active  = true),
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
      OR COALESCE(lpt.title, lp.title) ILIKE '%' || p_search || '%'
      OR COALESCE(lpt.description, lp.description) ILIKE '%' || p_search || '%'
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
