-- Path progress read from the lessons, everywhere it decides "next" or "done".
--
-- Follow-up to 20261009000000. The stored row in user_learning_path_progress
-- (current_topic_position, completed_at) went stale in two more ways:
--
-- 1. update_learning_path_progress_on_topic_complete() moved the cursor to the
--    position right after the lesson just completed, without checking whether
--    that lesson was already done. Finishing lesson 2 and then lesson 1 left
--    the cursor on lesson 2. topics_completed was a running "+1" counter that
--    drifted from the lesson rows.
--    Fix: the cursor moves to the first UNFINISHED visible lesson after the one
--    just completed (else the earliest unfinished; else the last lesson), and
--    topics_completed is recomputed from the lesson rows.
--
-- 2. get_in_progress_topics() (Continue Learning, continue-learning edge
--    function) matched the cursor exactly, so a cursor on a finished lesson
--    silently dropped that path's real next lesson.
--    Fix: next_in_path takes the first unfinished visible lesson (at or after
--    the cursor first), and a path with none yields nothing.
--
-- 3. get_available_learning_paths() sorted a path finished lesson by lesson
--    (stored completed_at still NULL, or never enrolled) among unfinished
--    paths. Progress already floored by lesson rows; the "completed last" sort
--    now uses the same rule.
--
-- 4. get_finished_path_ids(user): stored completion OR every visible lesson
--    done. Used by the edge functions that exclude finished paths from
--    recommendations and scoring (they read completed_at alone).
--
-- Lesson "done" = user_topic_progress.completed_at. Completed study guides
-- are already folded into it (mark-study-guide-complete resolves the topic and
-- completes it; 20260906000009 backfilled older guides).
--
-- Idempotent: CREATE OR REPLACE throughout; the repair UPDATE only touches
-- rows that still disagree with the lesson rows.

BEGIN;

-- ============================================================================
-- 1. Completion trigger: cursor to the next unfinished lesson
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_learning_path_progress_on_topic_complete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_learning_path_id UUID;
  v_topic_position INTEGER;
  v_next_position INTEGER;
  v_last_position INTEGER;
  v_total_topics INTEGER;
  v_topic_xp INTEGER;
  v_visible_completed INTEGER;
BEGIN
  IF NEW.completed_at IS NOT NULL AND (OLD.completed_at IS NULL OR OLD IS NULL) THEN
    v_topic_xp := COALESCE(NEW.xp_earned, 0);

    FOR v_learning_path_id IN
      SELECT DISTINCT lpt.learning_path_id
      FROM public.learning_path_topics lpt
      JOIN public.recommended_topics rt ON rt.id = lpt.topic_id
      JOIN public.user_learning_path_progress ulpp ON ulpp.learning_path_id = lpt.learning_path_id
      WHERE lpt.topic_id = NEW.topic_id
        AND lpt.is_active = true
        AND rt.is_active  = true
        AND ulpp.user_id = NEW.user_id
        AND ulpp.completed_at IS NULL
    LOOP
      SELECT lpt.position
      INTO v_topic_position
      FROM public.learning_path_topics lpt
      JOIN public.recommended_topics rt ON rt.id = lpt.topic_id
      WHERE lpt.learning_path_id = v_learning_path_id
        AND lpt.topic_id = NEW.topic_id
        AND lpt.is_active = true
        AND rt.is_active  = true;

      -- One pass over the visible lessons (AFTER trigger: NEW is counted).
      SELECT
        COUNT(*)::INTEGER,
        COUNT(utp.topic_id)::INTEGER,
        COALESCE(
          MIN(lpt.position) FILTER (WHERE utp.topic_id IS NULL AND lpt.position > v_topic_position),
          MIN(lpt.position) FILTER (WHERE utp.topic_id IS NULL)
        ),
        MAX(lpt.position)
      INTO v_total_topics, v_visible_completed, v_next_position, v_last_position
      FROM public.learning_path_topics lpt
      JOIN public.recommended_topics rt ON rt.id = lpt.topic_id
      LEFT JOIN public.user_topic_progress utp
        ON utp.topic_id = lpt.topic_id
       AND utp.user_id  = NEW.user_id
       AND utp.completed_at IS NOT NULL
      WHERE lpt.learning_path_id = v_learning_path_id
        AND lpt.is_active = true
        AND rt.is_active  = true;

      UPDATE public.user_learning_path_progress
      SET
        topics_completed = v_visible_completed,
        current_topic_position = COALESCE(v_next_position, v_last_position, v_topic_position),
        total_xp_earned = total_xp_earned + v_topic_xp,
        completed_at = CASE
          WHEN v_visible_completed >= v_total_topics THEN NOW()
          ELSE NULL
        END,
        last_activity_at = NOW()
      WHERE user_id = NEW.user_id
        AND learning_path_id = v_learning_path_id;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.update_learning_path_progress_on_topic_complete() IS 'Trigger function to auto-update learning path progress when topics are completed. Adds the XP the completion actually awarded (NEW.xp_earned). Counts and the cursor come from the visible lesson rows: the cursor moves to the first unfinished visible lesson after the one completed (else the earliest unfinished).';

-- Repair rows whose cursor sits on a finished (or hidden) lesson, or whose
-- counter drifted, from the lesson rows. Finished paths are marked complete.
WITH s AS (
  SELECT
    ulp.id,
    COUNT(*)::INTEGER                                         AS visible_total,
    COUNT(utp.topic_id)::INTEGER                              AS visible_done,
    MIN(lpt.position) FILTER (WHERE utp.topic_id IS NULL)     AS next_pos,
    MAX(lpt.position)                                         AS last_pos,
    MAX(utp.completed_at)                                     AS last_done,
    COALESCE(BOOL_OR(lpt.position = ulp.current_topic_position AND utp.topic_id IS NULL), false) AS cursor_on_unfinished
  FROM public.user_learning_path_progress ulp
  JOIN public.learning_path_topics lpt
    ON lpt.learning_path_id = ulp.learning_path_id
   AND lpt.is_active = true
  JOIN public.recommended_topics rt
    ON rt.id = lpt.topic_id
   AND rt.is_active = true
  LEFT JOIN public.user_topic_progress utp
    ON utp.topic_id = lpt.topic_id
   AND utp.user_id  = ulp.user_id
   AND utp.completed_at IS NOT NULL
  WHERE ulp.completed_at IS NULL
  GROUP BY ulp.id
)
UPDATE public.user_learning_path_progress ulp
SET
  completed_at = CASE
    WHEN s.visible_done >= s.visible_total THEN COALESCE(s.last_done, NOW())
    ELSE NULL
  END,
  current_topic_position = CASE
    WHEN s.visible_done >= s.visible_total THEN s.last_pos
    WHEN s.cursor_on_unfinished THEN ulp.current_topic_position
    ELSE s.next_pos
  END,
  topics_completed = s.visible_done
FROM s
WHERE s.id = ulp.id
  AND (
    (s.visible_done > 0 AND s.visible_done >= s.visible_total)
    OR (s.visible_done > 0 AND NOT s.cursor_on_unfinished)
    OR ulp.topics_completed IS DISTINCT FROM s.visible_done
  );

-- ============================================================================
-- 2. Continue Learning: next lesson = first unfinished visible lesson
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_in_progress_topics(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 5
)
RETURNS TABLE(
  topic_id UUID,
  topic_title TEXT,
  topic_description TEXT,
  topic_category TEXT,
  started_at TIMESTAMPTZ,
  time_spent_seconds INTEGER,
  xp_value INTEGER,
  learning_path_id UUID,
  learning_path_name TEXT,
  position_in_path INTEGER,
  total_topics_in_path INTEGER,
  topics_completed_in_path INTEGER
) AS $$
BEGIN
  RETURN QUERY
  WITH visible_path_topics AS (
    -- Rule A + Rule C: the visible rows of the join table, each carrying its
    -- 1-based ordinal and its path's visible total.
    SELECT
      lpt.learning_path_id,
      lpt.topic_id,
      lpt.position,
      (ROW_NUMBER() OVER (PARTITION BY lpt.learning_path_id ORDER BY lpt.position))::INTEGER AS visible_ordinal,
      (COUNT(*)     OVER (PARTITION BY lpt.learning_path_id))::INTEGER                       AS visible_total
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    WHERE lpt.is_active = true
      AND rt.is_active  = true
  ),
  visible_completed AS (
    -- Rule A (numerator): this user's completed topics that are still VISIBLE
    -- in the path. The stored ulpp.topics_completed is an all-time counter and
    -- would be paired with the visible-only visible_total below, which can
    -- render as "9 of 6" on the client. Computed here so the numerator and the
    -- denominator come from the same visible set.
    SELECT
      vpt.learning_path_id,
      COUNT(*)::INTEGER AS completed_total
    FROM visible_path_topics vpt
    JOIN user_topic_progress utp
      ON utp.topic_id = vpt.topic_id
     AND utp.user_id  = p_user_id
     AND utp.completed_at IS NOT NULL
    GROUP BY vpt.learning_path_id
  ),
  in_progress AS (
    -- Get topics user has started but not completed
    SELECT
      rt.id AS topic_id,
      rt.title AS topic_title,
      rt.description AS topic_description,
      rt.category::TEXT AS topic_category,
      utp.started_at,
      utp.time_spent_seconds,
      COALESCE(rt.xp_value, 50) AS xp_value,
      utp.updated_at
    FROM user_topic_progress utp
    JOIN recommended_topics rt ON rt.id = utp.topic_id
    WHERE utp.user_id = p_user_id
      AND utp.completed_at IS NULL
      AND rt.is_active = true
  ),
  next_in_path AS (
    -- Get next topic from learning paths where user completed a topic
    SELECT DISTINCT ON (lp.id)
      rt.id AS topic_id,
      -- Rule B: path override wins over the base title.
      COALESCE(lptt.title, rt.title) AS topic_title,
      rt.description AS topic_description,
      rt.category::TEXT AS topic_category,
      ulpp.last_activity_at AS started_at,
      0 AS time_spent_seconds,
      COALESCE(rt.xp_value, 50) AS xp_value,
      ulpp.last_activity_at AS updated_at,
      lp.id AS learning_path_id,
      lp.title AS learning_path_name,
      vpt.visible_ordinal AS position_in_path,
      vpt.visible_total   AS total_topics_in_path,
      COALESCE(vc.completed_total, 0)::INTEGER AS topics_completed_in_path
    FROM user_learning_path_progress ulpp
    JOIN learning_paths lp ON lp.id = ulpp.learning_path_id
    JOIN visible_path_topics vpt ON vpt.learning_path_id = lp.id
    JOIN recommended_topics rt ON rt.id = vpt.topic_id
    LEFT JOIN visible_completed vc ON vc.learning_path_id = lp.id
    LEFT JOIN learning_path_topic_titles lptt
           ON lptt.learning_path_id = vpt.learning_path_id
          AND lptt.topic_id         = vpt.topic_id
          AND lptt.language_code    = 'en'
    WHERE ulpp.user_id = p_user_id
      AND ulpp.completed_at IS NULL
      AND lp.is_active = true
      AND rt.is_active = true
      -- The path's next lesson is its first UNFINISHED visible lesson, read
      -- from the lesson rows -- not the stored cursor, which can sit on a
      -- lesson already done (out-of-order completion, or a row enrolled after
      -- the lessons were finished). At or after the cursor first, so a user
      -- who skipped ahead keeps their place; otherwise the earliest unfinished.
      -- A path with no unfinished lesson yields no row at all.
      AND NOT EXISTS (
        SELECT 1 FROM user_topic_progress utp
        WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id
          AND utp.completed_at IS NOT NULL
      )
    ORDER BY lp.id,
             (vpt.position < COALESCE(ulpp.current_topic_position, 0)),
             vpt.position
  ),
  in_progress_with_path AS (
    -- Add learning path info to in-progress topics
    SELECT
      ip.topic_id,
      -- Rule B: override applies only when this topic is reached through a path.
      COALESCE(lptt.title, ip.topic_title) AS topic_title,
      ip.topic_description,
      ip.topic_category,
      ip.started_at,
      ip.time_spent_seconds,
      ip.xp_value,
      ip.updated_at,
      lp.id AS learning_path_id,
      lp.title AS learning_path_name,
      vpt.visible_ordinal AS position_in_path,
      vpt.visible_total   AS total_topics_in_path,
      COALESCE(vc.completed_total, 0)::INTEGER AS topics_completed_in_path
    FROM in_progress ip
    LEFT JOIN visible_path_topics vpt ON vpt.topic_id = ip.topic_id
    LEFT JOIN learning_paths lp ON lp.id = vpt.learning_path_id AND lp.is_active = true
    LEFT JOIN user_learning_path_progress ulpp ON ulpp.learning_path_id = lp.id AND ulpp.user_id = p_user_id
    LEFT JOIN visible_completed vc ON vc.learning_path_id = lp.id
    LEFT JOIN learning_path_topic_titles lptt
           ON lptt.learning_path_id = vpt.learning_path_id
          AND lptt.topic_id         = vpt.topic_id
          AND lptt.language_code    = 'en'
    WHERE lp.id IS NULL OR ulpp.id IS NOT NULL
  ),
  combined AS (
    SELECT
      ipwp.topic_id,
      ipwp.topic_title,
      ipwp.topic_description,
      ipwp.topic_category,
      ipwp.started_at,
      ipwp.time_spent_seconds,
      ipwp.xp_value,
      ipwp.updated_at,
      ipwp.learning_path_id,
      ipwp.learning_path_name,
      ipwp.position_in_path,
      ipwp.total_topics_in_path,
      ipwp.topics_completed_in_path,
      1 AS priority
    FROM in_progress_with_path ipwp

    UNION ALL

    SELECT
      nip.topic_id,
      nip.topic_title,
      nip.topic_description,
      nip.topic_category,
      nip.started_at,
      nip.time_spent_seconds,
      nip.xp_value,
      nip.updated_at,
      nip.learning_path_id,
      nip.learning_path_name,
      nip.position_in_path,
      nip.total_topics_in_path,
      nip.topics_completed_in_path,
      2 AS priority
    FROM next_in_path nip
    WHERE NOT EXISTS (
      SELECT 1 FROM in_progress_with_path ipwp
      WHERE ipwp.topic_id = nip.topic_id
    )
  )
  SELECT DISTINCT ON (c.topic_id)
    c.topic_id,
    c.topic_title,
    c.topic_description,
    c.topic_category,
    c.started_at,
    c.time_spent_seconds,
    c.xp_value,
    c.learning_path_id,
    c.learning_path_name,
    c.position_in_path,
    c.total_topics_in_path,
    c.topics_completed_in_path
  FROM combined c
  ORDER BY c.topic_id, c.priority, c.updated_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.get_in_progress_topics(UUID, INTEGER) IS 'Returns in-progress topics for Continue Learning with learning path context. Hidden topics are excluded and position_in_path is an ordinal over visible topics. A path''s next lesson is its first unfinished visible lesson (at or after the stored cursor first); finished paths contribute nothing.';

-- ============================================================================
-- 3. Path listing: "completed last" uses the lesson rows too
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_available_learning_paths(p_user_id uuid DEFAULT NULL::uuid, p_language character varying DEFAULT 'en'::character varying, p_include_enrolled boolean DEFAULT true, p_limit integer DEFAULT 10, p_offset integer DEFAULT 0, p_category character varying DEFAULT NULL::character varying, p_search character varying DEFAULT NULL::character varying)
 RETURNS TABLE(path_id uuid, slug character varying, title text, description text, icon_name character varying, color character varying, total_xp integer, estimated_days integer, disciple_level character varying, recommended_mode text, is_featured boolean, total_topics integer, is_enrolled boolean, progress_percentage integer, category character varying, display_order integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  -- Paths matching the search by their own name, in either language.
  --
  -- The same category and enrolled filters as the main query apply here, so
  -- "nothing matched" means nothing the reader would have been shown — a path
  -- hidden by the category filter must not suppress the topic fallback.
  -- Visible topic count per path, computed once instead of twice per row.
  WITH path_topic_counts AS (
    SELECT lpt_c.learning_path_id, COUNT(*) AS n
      FROM learning_path_topics lpt_c
      JOIN recommended_topics rt_c ON rt_c.id = lpt_c.topic_id
     WHERE lpt_c.is_active = true
       AND rt_c.is_active  = true
     GROUP BY lpt_c.learning_path_id
  ),
  direct_hits AS (
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
    COALESCE(ptc.n, 0)::INTEGER               AS total_topics,
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
              COALESCE(ptc.n, 0),
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
    lp.category,
    lp.display_order::INTEGER                   AS display_order
  FROM learning_paths lp
  LEFT JOIN learning_path_translations lpt
         ON lpt.learning_path_id = lp.id AND lpt.lang_code = p_language
  LEFT JOIN path_topic_counts ptc ON ptc.learning_path_id = lp.id
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
    -- Completed paths always last: a stored completion, or every visible
    -- lesson done (a path finished lesson by lesson whose stored row never
    -- caught up -- or that was never enrolled -- is still finished).
    CASE WHEN p_user_id IS NOT NULL AND (
      EXISTS(
        SELECT 1 FROM user_learning_path_progress ulpp_c
         WHERE ulpp_c.user_id          = p_user_id
           AND ulpp_c.learning_path_id = lp.id
           AND ulpp_c.completed_at     IS NOT NULL
      )
      OR (
        COALESCE(ptc.n, 0) > 0
        AND NOT EXISTS (
          SELECT 1
            FROM learning_path_topics lpt_u
            JOIN recommended_topics rt_u ON rt_u.id = lpt_u.topic_id
            LEFT JOIN user_topic_progress utp_u
                   ON utp_u.topic_id = lpt_u.topic_id
                  AND utp_u.user_id  = p_user_id
                  AND utp_u.completed_at IS NOT NULL
           WHERE lpt_u.learning_path_id = lp.id
             AND lpt_u.is_active = true
             AND rt_u.is_active  = true
             AND utp_u.topic_id IS NULL
        )
      )
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
$function$;

-- ============================================================================
-- 4. Finished paths for a user (stored completion OR every visible lesson done)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_finished_path_ids(p_user_id UUID)
RETURNS TABLE (learning_path_id UUID)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT ulpp.learning_path_id
  FROM public.user_learning_path_progress ulpp
  WHERE ulpp.user_id = p_user_id
    AND ulpp.completed_at IS NOT NULL
  UNION
  SELECT lpt.learning_path_id
  FROM public.learning_path_topics lpt
  JOIN public.recommended_topics rt ON rt.id = lpt.topic_id AND rt.is_active = true
  LEFT JOIN public.user_topic_progress utp
    ON utp.topic_id = lpt.topic_id
   AND utp.user_id  = p_user_id
   AND utp.completed_at IS NOT NULL
  WHERE lpt.is_active = true
  GROUP BY lpt.learning_path_id
  HAVING COUNT(*) > 0 AND COUNT(utp.topic_id) = COUNT(*);
$$;

COMMENT ON FUNCTION public.get_finished_path_ids(UUID) IS
  'Learning paths this user has finished: a stored completion, or every visible lesson completed. Edge functions only (service role).';

REVOKE EXECUTE ON FUNCTION public.get_finished_path_ids(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_finished_path_ids(UUID) TO service_role;

COMMIT;
