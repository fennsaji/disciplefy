-- New-user (nux.*) activation analytics: index, metric views, retention exception.
--
-- Events are inserted by the app into public.analytics_events with event_type
-- 'nux.<name>' and created_at = the client time (queued events keep their
-- original time). Cohort dates are IST calendar days (Asia/Kolkata, +05:30).
--
-- Every view filters on event_type LIKE 'nux.%' (sometimes redundantly) so the
-- planner can prove the partial index predicate and use idx_analytics_events_nux.
-- lesson_number is compared as text ('1') so a malformed value cannot make the
-- views error on an int cast.
--
-- Production safety: everything is idempotent (IF NOT EXISTS / CREATE OR
-- REPLACE / unschedule-then-schedule). The index build takes a SHARE lock
-- (blocks inserts, not reads) for one scan of a 90-day table; lock_timeout
-- makes the migration fail fast instead of queueing behind a long transaction
-- and stalling every analytics insert behind it.

SET LOCAL lock_timeout = '10s';

CREATE INDEX IF NOT EXISTS idx_analytics_events_nux
  ON public.analytics_events (event_type, user_id, created_at)
  WHERE event_type LIKE 'nux.%';

-- First time each user reached each milestone.
CREATE OR REPLACE VIEW public.nux_user_firsts
WITH (security_invoker = true) AS
SELECT user_id,
  MIN(created_at) FILTER (WHERE event_type = 'nux.first_open') AS first_open_at,
  MIN(created_at) FILTER (WHERE event_type = 'nux.verse_viewed') AS first_verse_at,
  MIN(created_at) FILTER (WHERE event_type = 'nux.lesson_completed'
                            AND event_data->>'lesson_number' = '1') AS first_lesson1_done_at,
  MIN(created_at) FILTER (WHERE event_type = 'nux.signup_completed') AS signup_at,
  (ARRAY_AGG(event_data->>'language' ORDER BY created_at)
     FILTER (WHERE event_type = 'nux.language_selected'))[1] AS language
FROM public.analytics_events
WHERE event_type LIKE 'nux.%' AND user_id IS NOT NULL
GROUP BY user_id;

-- Activated = verse viewed and lesson 1 completed, both within 24h of first open.
CREATE OR REPLACE VIEW public.nux_activation_daily
WITH (security_invoker = true) AS
SELECT (first_open_at AT TIME ZONE 'Asia/Kolkata')::date AS cohort_date,
  COUNT(*) AS new_users,
  COUNT(*) FILTER (WHERE first_verse_at < first_open_at + interval '24 hours'
                     AND first_lesson1_done_at < first_open_at + interval '24 hours') AS activated,
  ROUND(100.0 * COUNT(*) FILTER (WHERE first_verse_at < first_open_at + interval '24 hours'
                     AND first_lesson1_done_at < first_open_at + interval '24 hours')
        / NULLIF(COUNT(*), 0), 1) AS activation_rate
FROM public.nux_user_firsts
WHERE first_open_at IS NOT NULL
GROUP BY 1;

-- Of the activated users, who came back (verse viewed or lesson completed) on
-- IST day cohort+1 and cohort+7. Cohorts younger than N days show 0 for dN.
CREATE OR REPLACE VIEW public.nux_retention_daily
WITH (security_invoker = true) AS
WITH act AS (
  SELECT user_id, (first_open_at AT TIME ZONE 'Asia/Kolkata')::date AS d0
  FROM public.nux_user_firsts
  WHERE first_verse_at < first_open_at + interval '24 hours'
    AND first_lesson1_done_at < first_open_at + interval '24 hours'
),
days AS (
  SELECT DISTINCT user_id, (created_at AT TIME ZONE 'Asia/Kolkata')::date AS d
  FROM public.analytics_events
  WHERE event_type LIKE 'nux.%'
    AND event_type IN ('nux.verse_viewed', 'nux.lesson_completed')
    AND user_id IS NOT NULL
),
per_user AS (
  SELECT a.user_id, a.d0,
    COALESCE(bool_or(x.d = a.d0 + 1), false) AS d1,
    COALESCE(bool_or(x.d = a.d0 + 7), false) AS d7
  FROM act a
  LEFT JOIN days x ON x.user_id = a.user_id AND x.d IN (a.d0 + 1, a.d0 + 7)
  GROUP BY a.user_id, a.d0
)
SELECT d0 AS cohort_date,
  COUNT(*) AS activated,
  COUNT(*) FILTER (WHERE d1) AS d1_returned,
  COUNT(*) FILTER (WHERE d7) AS d7_returned
FROM per_user
GROUP BY 1;

CREATE OR REPLACE VIEW public.nux_time_to_first_lesson
WITH (security_invoker = true) AS
SELECT (first_open_at AT TIME ZONE 'Asia/Kolkata')::date AS cohort_date,
  PERCENTILE_CONT(0.5) WITHIN GROUP (
    ORDER BY EXTRACT(EPOCH FROM first_lesson1_done_at - first_open_at)) AS median_seconds
FROM public.nux_user_firsts
WHERE first_lesson1_done_at IS NOT NULL AND first_open_at IS NOT NULL
GROUP BY 1;

-- Distinct users per onboarding step, by first-open cohort. lesson_completed
-- counts any lesson (the activation views are the lesson-1 measure).
CREATE OR REPLACE VIEW public.nux_funnel_daily
WITH (security_invoker = true) AS
SELECT (f.first_open_at AT TIME ZONE 'Asia/Kolkata')::date AS cohort_date,
  replace(e.event_type, 'nux.', '') AS step,
  COUNT(DISTINCT e.user_id) AS users
FROM public.nux_user_firsts f
JOIN public.analytics_events e ON e.user_id = f.user_id
WHERE f.first_open_at IS NOT NULL
  AND e.event_type LIKE 'nux.%'
  AND e.event_type IN ('nux.first_open', 'nux.language_selected', 'nux.goal_selected',
                       'nux.lesson_started', 'nux.lesson_completed',
                       'nux.signup_completed', 'nux.guest_continued')
GROUP BY 1, 2;

CREATE OR REPLACE VIEW public.nux_new_for_you_daily
WITH (security_invoker = true) AS
SELECT (created_at AT TIME ZONE 'Asia/Kolkata')::date AS day,
  event_data->>'kind' AS kind,
  COUNT(*) FILTER (WHERE event_type = 'nux.nfy_impression') AS impressions,
  COUNT(*) FILTER (WHERE event_type = 'nux.nfy_tap') AS taps,
  COUNT(*) FILTER (WHERE event_type = 'nux.nfy_dismiss') AS dismissals
FROM public.analytics_events
WHERE event_type LIKE 'nux.%'
  AND event_type IN ('nux.nfy_impression', 'nux.nfy_tap', 'nux.nfy_dismiss')
GROUP BY 1, 2;

-- Server-side only (service_role / admin functions). Supabase's default
-- privileges grant new public views to anon and authenticated: take that back.
REVOKE ALL ON public.nux_user_firsts, public.nux_activation_daily, public.nux_retention_daily,
  public.nux_time_to_first_lesson, public.nux_funnel_daily, public.nux_new_for_you_daily
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.nux_user_firsts, public.nux_activation_daily, public.nux_retention_daily,
  public.nux_time_to_first_lesson, public.nux_funnel_daily, public.nux_new_for_you_daily
  TO service_role;

-- Retention: keep nux.* events 400 days (a full year of cohorts plus a month,
-- for year-over-year comparison); everything else keeps the 90-day rule.
-- Re-defines the job from 20261001083635 in place (unschedule, then schedule).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE NOTICE 'pg_cron not installed; skipping cleanup-old-analytics-events reschedule.';
    RETURN;
  END IF;

  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'cleanup-old-analytics-events';
  PERFORM cron.schedule(
    'cleanup-old-analytics-events',
    '30 3 * * *',
    $job$DELETE FROM public.analytics_events
         WHERE (event_type NOT LIKE 'nux.%' AND created_at < now() - interval '90 days')
            OR (event_type LIKE 'nux.%' AND created_at < now() - interval '400 days')$job$
  );
  RAISE NOTICE 'Scheduled cron job: cleanup-old-analytics-events (nux.* kept 400 days)';
END
$$;
