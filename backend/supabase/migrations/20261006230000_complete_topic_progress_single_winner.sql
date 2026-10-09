-- complete_topic_progress: exactly one caller sees the first completion.
--
-- A path lesson is completed through two endpoints at almost the same moment
-- (mark-study-guide-complete and topic-progress `complete`). The old body
-- read completed_at, then wrote, so two concurrent calls could both report
-- is_first_completion = true, and the follow-up work keyed on it (score
-- recalculation) ran twice. Now the write itself decides: the upsert only
-- completes a row whose completed_at is still NULL, so under the row lock a
-- single statement wins and every other caller gets a repeat completion (no
-- XP, time added). Same signature, return shape and XP rules as
-- 20260119001000. CREATE OR REPLACE keeps the grants (service_role only, see
-- 20261006210000).

CREATE OR REPLACE FUNCTION public.complete_topic_progress(
  p_user_id UUID,
  p_topic_id UUID,
  p_time_spent_seconds INTEGER DEFAULT 0
)
RETURNS TABLE(
  progress_id UUID,
  xp_earned INTEGER,
  is_first_completion BOOLEAN,
  topic_title TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_progress_id UUID;
  v_xp_value INTEGER;
  v_topic_title TEXT;
  v_time INTEGER := COALESCE(p_time_spent_seconds, 0);
BEGIN
  SELECT rt.xp_value, rt.title INTO v_xp_value, v_topic_title
  FROM public.recommended_topics rt
  WHERE rt.id = p_topic_id;

  v_xp_value := COALESCE(v_xp_value, 50);

  -- First completion: insert a completed row, or complete a started one. The
  -- WHERE on DO UPDATE leaves an already-completed row alone and returns no
  -- row, which is how a repeat (or the losing concurrent call) is detected.
  INSERT INTO public.user_topic_progress AS utp (
    user_id, topic_id, started_at, completed_at, time_spent_seconds, xp_earned
  )
  VALUES (p_user_id, p_topic_id, NOW(), NOW(), v_time, v_xp_value)
  ON CONFLICT (user_id, topic_id) DO UPDATE
  SET
    completed_at = NOW(),
    time_spent_seconds = utp.time_spent_seconds + EXCLUDED.time_spent_seconds,
    xp_earned = EXCLUDED.xp_earned,
    updated_at = NOW()
  WHERE utp.completed_at IS NULL
  RETURNING utp.id INTO v_progress_id;

  IF v_progress_id IS NOT NULL THEN
    RETURN QUERY SELECT v_progress_id, v_xp_value, TRUE, v_topic_title;
    RETURN;
  END IF;

  -- Already completed: only add the time, no XP.
  UPDATE public.user_topic_progress utp
  SET
    time_spent_seconds = utp.time_spent_seconds + v_time,
    updated_at = NOW()
  WHERE utp.user_id = p_user_id
    AND utp.topic_id = p_topic_id
  RETURNING utp.id INTO v_progress_id;

  RETURN QUERY SELECT v_progress_id, 0, FALSE, v_topic_title;
END;
$$;
