-- Notification selection fixes.
--
-- 1. "Continue Your Study — Pick up where you left off: Romans 1" was pushed to
--    a user who had finished every lesson of the Romans path.
--
--    user_learning_path_progress (cursor, topics_completed, completed_at) is
--    only advanced by update_learning_path_progress_on_topic_complete(), which
--    fires when a topic is completed and only touches paths the user is
--    enrolled in at that moment. A progress row created AFTER the lessons
--    were done -- enroll_in_learning_path (the app auto-enrols when "Review"
--    is tapped on a finished path), ensure_learning_path_started (starting a
--    lesson), the fellowship-study member upsert -- starts at cursor 0,
--    completed_at NULL. The app shows the path as 100% (it computes progress
--    from user_topic_progress), but the push selector read the stored cursor
--    and named lesson 1.
--
--    Fix: a BEFORE INSERT trigger seeds every new progress row from the
--    lessons already completed (cursor -> first unfinished visible lesson,
--    topics_completed, XP, completed_at when every visible lesson is done),
--    and a one-off backfill repairs existing rows. The push selector itself
--    now reads completion from the lessons too (unified-notification-selector).
--
-- 2. Streak reminder ("Don't break your N-day streak") compared the UTC date
--    of last_viewed_at with the UTC CURRENT_DATE. The streak is counted on the
--    user's LOCAL day (touch_daily_streak / last_activity_local_date). For a
--    UTC-5 user the 8 PM reminder runs at 01:00 UTC the next UTC day, so a
--    verse read that morning looked like "not today" and the reminder went out
--    anyway; for UTC+ users a read just after local midnight did the same.
--    It also reported a streak that had already broken as still alive.
--    Fix: compare local calendar days, prefer last_activity_local_date, and
--    report 0 when the last counted day was not yesterday.
--
-- 3. Streak lost uses the same local-day source (last_activity_local_date),
--    so a lesson-only day (which touch_daily_streak counts) is respected.
--
-- 4. Quiet-hours push queue: the flush route read pending rows, sent them,
--    then marked them sent. Two overlapping runs (a run longer than the
--    one-minute tick, or a retried call) both sent the same row.
--    claim_due_push_queue_rows() takes rows with FOR UPDATE SKIP LOCKED and
--    leases them by pushing not_before forward, so a concurrent run cannot see
--    them; a run that dies leaves them due again once the lease expires.
--
-- Idempotent: CREATE OR REPLACE, DROP TRIGGER IF EXISTS, and the backfill only
-- touches rows that still disagree with the lesson rows.

BEGIN;

-- ============================================================================
-- 1a. Seed new path-progress rows from lessons already completed
-- ============================================================================

CREATE OR REPLACE FUNCTION public.seed_learning_path_progress_from_topics()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total     INTEGER;
  v_done      INTEGER;
  v_next_pos  INTEGER;
  v_last_pos  INTEGER;
  v_xp        INTEGER;
  v_last_done TIMESTAMPTZ;
BEGIN
  SELECT
    COUNT(*)::INTEGER,
    COUNT(utp.completed_at)::INTEGER,
    MIN(lpt.position) FILTER (WHERE utp.completed_at IS NULL),
    MAX(lpt.position),
    COALESCE(SUM(utp.xp_earned) FILTER (WHERE utp.completed_at IS NOT NULL), 0)::INTEGER,
    MAX(utp.completed_at)
  INTO v_total, v_done, v_next_pos, v_last_pos, v_xp, v_last_done
  FROM public.learning_path_topics lpt
  JOIN public.recommended_topics rt ON rt.id = lpt.topic_id
  LEFT JOIN public.user_topic_progress utp
    ON utp.topic_id = lpt.topic_id
   AND utp.user_id  = NEW.user_id
   AND utp.completed_at IS NOT NULL
  WHERE lpt.learning_path_id = NEW.learning_path_id
    AND lpt.is_active = true
    AND rt.is_active  = true;

  IF COALESCE(v_done, 0) = 0 THEN
    RETURN NEW;
  END IF;

  NEW.topics_completed       := GREATEST(COALESCE(NEW.topics_completed, 0), v_done);
  NEW.total_xp_earned        := GREATEST(COALESCE(NEW.total_xp_earned, 0), v_xp);
  NEW.current_topic_position := COALESCE(v_next_pos, v_last_pos, NEW.current_topic_position);

  IF NEW.completed_at IS NULL AND v_total > 0 AND v_done >= v_total THEN
    NEW.completed_at := COALESCE(v_last_done, NOW());
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.seed_learning_path_progress_from_topics() IS
  'BEFORE INSERT on user_learning_path_progress: a path enrolled after some of its '
  'visible lessons were completed starts at the first unfinished lesson, with those '
  'lessons counted, and is marked complete when none are left.';

REVOKE EXECUTE ON FUNCTION public.seed_learning_path_progress_from_topics() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_seed_learning_path_progress_from_topics ON public.user_learning_path_progress;
CREATE TRIGGER trg_seed_learning_path_progress_from_topics
  BEFORE INSERT ON public.user_learning_path_progress
  FOR EACH ROW
  EXECUTE FUNCTION public.seed_learning_path_progress_from_topics();

-- ============================================================================
-- 1b. Backfill existing rows
-- ============================================================================
-- Only rows not yet marked complete. Marks finished paths complete (dated at
-- the last lesson finished) and moves a cursor that sits on a completed (or
-- hidden) lesson to the first unfinished one.

WITH s AS (
  SELECT
    ulp.id,
    COUNT(*)::INTEGER                                                   AS visible_total,
    COUNT(utp.completed_at)::INTEGER                                    AS visible_done,
    MIN(lpt.position) FILTER (WHERE utp.completed_at IS NULL)           AS next_pos,
    MAX(lpt.position)                                                   AS last_pos,
    MAX(utp.completed_at)                                               AS last_done,
    COALESCE(BOOL_OR(lpt.position = ulp.current_topic_position AND utp.completed_at IS NULL), false) AS cursor_on_unfinished
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
  topics_completed = GREATEST(ulp.topics_completed, s.visible_done)
FROM s
WHERE s.id = ulp.id
  AND s.visible_done > 0
  AND (
    s.visible_done >= s.visible_total
    OR NOT s.cursor_on_unfinished
  );

-- ============================================================================
-- 2. Streak reminder: local calendar day, live streak only
-- ============================================================================

CREATE OR REPLACE FUNCTION get_streak_reminder_notification_users(
    target_hour INTEGER,
    target_minute INTEGER
)
RETURNS TABLE (
    user_id UUID,
    fcm_token TEXT,
    current_streak INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
    catch_up_minutes CONSTANT INTEGER := 360;
    target_total_minutes INTEGER;
BEGIN
    target_total_minutes := target_hour * 60 + target_minute;

    RETURN QUERY
    WITH candidates AS (
        SELECT
            unp.user_id,
            unp.streak_reminder_time,
            COALESCE(unp.timezone_offset_minutes, 0) AS tz,
            dvs.current_streak,
            COALESCE(
                dvs.last_activity_local_date,
                ((dvs.last_viewed_at AT TIME ZONE 'UTC')
                  + make_interval(mins => COALESCE(unp.timezone_offset_minutes, 0)))::date
            ) AS last_local_day,
            ((NOW() AT TIME ZONE 'UTC')
              + make_interval(mins => COALESCE(unp.timezone_offset_minutes, 0)))::date AS local_today
        FROM user_notification_preferences unp
        LEFT JOIN daily_verse_streaks dvs ON dvs.user_id = unp.user_id
        WHERE unp.streak_reminder_enabled = true
    )
    SELECT DISTINCT ON (unt.user_id)
        unt.user_id,
        unt.fcm_token,
        (CASE
            WHEN c.last_local_day = c.local_today - 1 THEN COALESCE(c.current_streak, 0)
            ELSE 0
        END)::INTEGER AS current_streak
    FROM candidates c
    INNER JOIN user_notification_tokens unt ON unt.user_id = c.user_id
    WHERE
        (target_total_minutes + c.tz + 1440) % 1440
            BETWEEN
                (EXTRACT(HOUR FROM c.streak_reminder_time)::INTEGER * 60
                  + EXTRACT(MINUTE FROM c.streak_reminder_time)::INTEGER)
            AND
                LEAST(
                    EXTRACT(HOUR FROM c.streak_reminder_time)::INTEGER * 60
                      + EXTRACT(MINUTE FROM c.streak_reminder_time)::INTEGER
                      + catch_up_minutes - 1,
                    1439
                )
        -- Nothing counted yet on the user's local today.
        AND (c.last_local_day IS NULL OR c.last_local_day < c.local_today)
    ORDER BY unt.user_id, unt.token_updated_at DESC;
END;
$$;

-- ============================================================================
-- 3. Streak lost: same local-day source
-- ============================================================================

CREATE OR REPLACE FUNCTION get_streak_lost_notification_users(
    target_hour INTEGER,
    target_minute INTEGER
)
RETURNS TABLE (
    user_id UUID,
    fcm_token TEXT,
    current_streak INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
    target_local_minutes CONSTANT INTEGER := 10 * 60;
    catch_up_minutes CONSTANT INTEGER := 360;
    min_streak_worth_saving CONSTANT INTEGER := 2;
    target_total_minutes INTEGER;
BEGIN
    target_total_minutes := target_hour * 60 + target_minute;

    RETURN QUERY
    SELECT DISTINCT ON (unt.user_id)
        unt.user_id,
        unt.fcm_token,
        dvs.current_streak
    FROM user_notification_preferences unp
    INNER JOIN user_notification_tokens unt
        ON unt.user_id = unp.user_id
    INNER JOIN daily_verse_streaks dvs
        ON dvs.user_id = unp.user_id
    WHERE
        unp.streak_lost_enabled = true
        AND (
            (target_total_minutes + COALESCE(unp.timezone_offset_minutes, 0) + 1440) % 1440
            BETWEEN target_local_minutes
            AND LEAST(target_local_minutes + catch_up_minutes - 1, 1439)
        )
        AND dvs.current_streak >= min_streak_worth_saving
        -- Equality, not "older than": current_streak is only reset when the
        -- user next counts a day, so a churned user keeps a stale non-zero
        -- streak and a ">" comparison would re-send every day forever.
        AND COALESCE(
                dvs.last_activity_local_date,
                ((dvs.last_viewed_at AT TIME ZONE 'UTC')
                  + make_interval(mins => COALESCE(unp.timezone_offset_minutes, 0)))::date
            )
            = ((NOW() AT TIME ZONE 'UTC')
                + make_interval(mins => COALESCE(unp.timezone_offset_minutes, 0)))::date - 2
    ORDER BY unt.user_id, unt.token_updated_at DESC;
END;
$$;

-- ============================================================================
-- 4. Atomic claim for the quiet-hours push queue
-- ============================================================================

CREATE OR REPLACE FUNCTION public.claim_due_push_queue_rows(
  p_limit INTEGER,
  p_lease_seconds INTEGER DEFAULT 300
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  kind TEXT,
  title TEXT,
  body TEXT,
  data JSONB
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.notification_push_queue q
  SET not_before = NOW() + make_interval(secs => p_lease_seconds)
  WHERE q.id IN (
    SELECT d.id
    FROM public.notification_push_queue d
    WHERE d.status = 'pending'
      AND d.not_before <= NOW()
    ORDER BY d.not_before
    LIMIT p_limit
    FOR UPDATE SKIP LOCKED
  )
  RETURNING q.id, q.user_id, q.kind, q.title, q.body, q.data;
$$;

REVOKE EXECUTE ON FUNCTION public.claim_due_push_queue_rows(INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_due_push_queue_rows(INTEGER, INTEGER) TO service_role;

COMMENT ON FUNCTION public.claim_due_push_queue_rows(INTEGER, INTEGER) IS
  'Claims up to p_limit due pending push-queue rows for one flush run, leasing them for p_lease_seconds so overlapping runs never send the same row twice.';

COMMIT;
