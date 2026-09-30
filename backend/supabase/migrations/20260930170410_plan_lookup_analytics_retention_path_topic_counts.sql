-- Phase 3.5 database performance.
--
-- 1. get_user_plan_with_subscription: the four per-tier EXISTS probes on
--    subscriptions (premium, plus, standard, free) become one query that picks the
--    highest-ranked matching tier. Same status set, period guard and tier matching,
--    so results are identical. Plus a (user_id, status) index for the lookup; the
--    single-column user_id index is a prefix of it and is dropped.
-- 2. analytics_events: 90-day retention via pg_cron (skipped with a NOTICE when
--    pg_cron is missing, as in other cron migrations) and drop the session_id index
--    (nothing filters on session_id; admin reads filter by created_at/event_type,
--    user_id is kept for the ON DELETE CASCADE foreign key).
-- 3. get_available_learning_paths: visible-topic counts are computed once per call
--    in a grouped CTE instead of two correlated subqueries per path. Same output.

CREATE OR REPLACE FUNCTION public.get_user_plan_with_subscription(p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_is_admin BOOLEAN;
  v_best_rank INTEGER;
BEGIN
  -- 1. Admin users always get premium access
  SELECT COALESCE(is_admin, FALSE) INTO v_is_admin FROM user_profiles WHERE id = p_user_id;
  IF v_is_admin THEN RETURN 'premium'; END IF;

  -- 2. Active premium trial (7-day new-user trial)
  IF is_in_premium_trial(p_user_id) THEN RETURN 'premium'; END IF;

  -- 3-6. Best live subscription tier: premium > plus > standard > explicit free.
  -- Live statuses:
  --   active / trial / authenticated (Razorpay mandate, awaiting first payment) /
  --   in_progress (billing cycle) / pending_cancellation (still in paid period).
  -- current_period_end guard prevents granting access to expired subscriptions
  -- whose status hasn't been updated yet by webhooks.
  SELECT MIN(
           CASE
             WHEN sp.plan_code = 'premium'  OR s.plan_type LIKE 'premium%'  THEN 1
             WHEN sp.plan_code = 'plus'     OR s.plan_type LIKE 'plus%'     THEN 2
             WHEN sp.plan_code = 'standard' OR s.plan_type LIKE 'standard%' THEN 3
             WHEN sp.plan_code = 'free'     OR s.plan_type LIKE 'free%'     THEN 4
           END)
    INTO v_best_rank
    FROM subscriptions s
    LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
   WHERE s.user_id = p_user_id
     AND s.status IN ('active', 'trial', 'authenticated', 'in_progress', 'pending_cancellation')
     AND (s.current_period_end IS NULL OR s.current_period_end > NOW());

  IF v_best_rank = 1 THEN RETURN 'premium'; END IF;
  IF v_best_rank = 2 THEN RETURN 'plus'; END IF;
  IF v_best_rank = 3 THEN RETURN 'standard'; END IF;
  -- Explicit free subscription (admin override) skips the global trial.
  IF v_best_rank = 4 THEN RETURN 'free'; END IF;

  -- 7. Global standard trial (all users get standard during app launch period)
  IF is_standard_trial_active() THEN RETURN 'standard'; END IF;

  -- 8. Grace period after global trial ends
  IF was_eligible_for_trial(p_user_id) THEN
    IF is_in_grace_period() THEN RETURN 'standard'; END IF;
    RETURN 'free';
  END IF;

  RETURN 'free';
END;
$function$;

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status
  ON public.subscriptions (user_id, status);
DROP INDEX IF EXISTS public.idx_subscriptions_user_id;

DROP INDEX IF EXISTS public.idx_analytics_events_session;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed; skipping analytics_events retention job. Enable pg_cron, then re-run this migration.';
    RETURN;
  END IF;

  -- Daily at 03:30 UTC: delete analytics events older than 90 days
  -- (uses idx_analytics_events_created_at).
  PERFORM cron.schedule(
    'cleanup-old-analytics-events',
    '30 3 * * *',
    $job$DELETE FROM public.analytics_events WHERE created_at < now() - interval '90 days'$job$
  );
  RAISE NOTICE 'Scheduled cron job: cleanup-old-analytics-events';
END $$;

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
$function$;
