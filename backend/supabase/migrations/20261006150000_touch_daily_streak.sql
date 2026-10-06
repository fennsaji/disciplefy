-- One daily streak, counted when the verse of the day is read or a lesson is
-- finished.
--
-- Before: the app computed the streak client-side on every verse load and
-- wrote the result back. Merely opening the app counted, and finishing a
-- lesson did not. Now the app calls touch_daily_streak(p_local_date) when
-- the user actually reads the verse or finishes a lesson.
--
-- Date basis: p_local_date is the device's local calendar day (the same
-- calendar the app has always shown the streak in). The last counted day is
-- stored as a plain date in last_activity_local_date, so comparisons are
-- day arithmetic with no timezone conversion on the server:
--   same day          -> unchanged (idempotent)
--   the day after     -> current_streak + 1
--   later             -> current_streak = 1
--   an earlier day    -> unchanged (clock/timezone moved backwards)
--
-- Security: SECURITY INVOKER. The caller only touches their own row, which
-- the existing RLS policies on daily_verse_streaks already allow (select,
-- insert and update where user_id = auth.uid()), so no privilege escalation
-- is needed.

ALTER TABLE public.daily_verse_streaks
  ADD COLUMN IF NOT EXISTS last_activity_local_date date;

COMMENT ON COLUMN public.daily_verse_streaks.last_activity_local_date IS
  'The user''s local calendar day that last counted toward the streak '
  '(set by touch_daily_streak).';

-- Backfill so existing streaks continue instead of restarting at 1. The
-- local day of the last view uses the user's stored timezone offset
-- (local = UTC + timezone_offset_minutes, as in the streak reminder jobs),
-- falling back to IST (+330) where none is known.
UPDATE public.daily_verse_streaks dvs
SET last_activity_local_date = (
  (dvs.last_viewed_at AT TIME ZONE 'UTC')
  + make_interval(mins => COALESCE(
      (SELECT unp.timezone_offset_minutes
         FROM public.user_notification_preferences unp
        WHERE unp.user_id = dvs.user_id),
      330))
)::date
WHERE dvs.last_activity_local_date IS NULL
  AND dvs.last_viewed_at IS NOT NULL;

CREATE OR REPLACE FUNCTION public.touch_daily_streak(p_local_date date)
RETURNS public.daily_verse_streaks
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_utc_today date := (now() AT TIME ZONE 'UTC')::date;
  r public.daily_verse_streaks;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
  END IF;

  -- Every local calendar day on Earth (UTC-12 .. UTC+14) is within one day
  -- of the UTC date; anything else is a wrong clock or a forged value.
  IF p_local_date IS NULL
     OR p_local_date < v_utc_today - 1
     OR p_local_date > v_utc_today + 1 THEN
    RAISE EXCEPTION 'p_local_date out of range' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.daily_verse_streaks (user_id, current_streak, longest_streak, total_views)
  VALUES (v_user_id, 0, 0, 0)
  ON CONFLICT (user_id) DO NOTHING;

  -- Row lock: two reads arriving together (verse timer + lesson finish)
  -- are serialised, so the day is counted once.
  SELECT * INTO r
  FROM public.daily_verse_streaks
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF r.last_activity_local_date IS NOT NULL
     AND r.last_activity_local_date >= p_local_date THEN
    RETURN r;
  END IF;

  r.current_streak := CASE
    WHEN r.last_activity_local_date = p_local_date - 1 THEN r.current_streak + 1
    ELSE 1
  END;

  UPDATE public.daily_verse_streaks
  SET current_streak = r.current_streak,
      longest_streak = GREATEST(longest_streak, r.current_streak),
      last_viewed_at = now(),
      last_activity_local_date = p_local_date,
      total_views = total_views + 1,
      updated_at = now()
  WHERE user_id = v_user_id
  RETURNING * INTO r;

  RETURN r;
END;
$$;

COMMENT ON FUNCTION public.touch_daily_streak(date) IS
  'Counts the caller''s local day (p_local_date) toward their daily streak. '
  'Idempotent per day; continues from yesterday, otherwise restarts at 1.';

REVOKE ALL ON FUNCTION public.touch_daily_streak(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.touch_daily_streak(date) TO authenticated;
