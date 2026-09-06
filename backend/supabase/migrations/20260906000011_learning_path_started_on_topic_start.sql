-- Starting a study guide that belongs to a learning path must mark that path
-- as "started" for the user, even when the user never individually enrolled
-- in it. The motivating case: a fellowship member opens a lesson from inside
-- their group's shared study. The group's `fellowship_study` row already
-- tracks progress through the path, but nothing wrote a
-- `user_learning_path_progress` row for the individual member, so the path
-- never showed up in their own "my learning paths" view.
--
-- This function is called (best-effort) from topic-progress (start + complete)
-- and from mark-study-guide-complete's title-resolved completion path, so the
-- guarantee holds no matter where the guide was opened from.

CREATE OR REPLACE FUNCTION public.ensure_learning_path_started(
  p_user_id UUID,
  p_topic_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_path_id UUID;
BEGIN
  IF p_user_id IS NULL OR p_topic_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Preference order:
  --   1. A path an active fellowship of this user is currently studying.
  --      Fellowship membership wins over display_order because the member
  --      did not choose this path individually -- they are following the
  --      group's shared study, so that specific path is the one that must
  --      light up as "started" for them, not whichever containing path
  --      happens to be listed first.
  --   2. Otherwise, the containing active path with the lowest
  --      display_order (tie-broken by id for determinism).
  SELECT lpt.learning_path_id INTO v_path_id
  FROM learning_path_topics lpt
  JOIN recommended_topics rt ON rt.id = lpt.topic_id
  JOIN learning_paths lp ON lp.id = lpt.learning_path_id
  JOIN fellowship_study fs ON fs.learning_path_id = lpt.learning_path_id
  JOIN fellowship_members fm
    ON fm.fellowship_id = fs.fellowship_id
   AND fm.user_id = p_user_id
   AND fm.is_active
  WHERE lpt.topic_id = p_topic_id
    AND lpt.is_active
    AND rt.is_active
    AND lp.is_active
    AND fs.completed_at IS NULL
  LIMIT 1;

  IF v_path_id IS NULL THEN
    SELECT lpt.learning_path_id INTO v_path_id
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    JOIN learning_paths lp ON lp.id = lpt.learning_path_id
    WHERE lpt.topic_id = p_topic_id
      AND lpt.is_active
      AND rt.is_active
      AND lp.is_active
    ORDER BY lp.display_order ASC, lp.id ASC
    LIMIT 1;
  END IF;

  IF v_path_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Upsert enrollment: never touch enrolled_at / completed_at / counters on
  -- an existing row, only bump last_activity_at.
  INSERT INTO user_learning_path_progress (user_id, learning_path_id, enrolled_at, last_activity_at)
  VALUES (p_user_id, v_path_id, NOW(), NOW())
  ON CONFLICT (user_id, learning_path_id) DO UPDATE
    SET last_activity_at = NOW();

  RETURN v_path_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_learning_path_started(UUID, UUID)
  TO service_role, authenticated;

COMMENT ON FUNCTION public.ensure_learning_path_started(UUID, UUID) IS
  'Best-effort: when a user starts/completes a topic that belongs to a visible learning path, ensures a user_learning_path_progress row exists for that path. Prefers a path their active fellowship is currently studying over display_order, since a fellowship member never individually enrolls. Never touches enrolled_at/completed_at/counters on an existing row.';
