-- Per-path XP comes from the XP actually awarded for the topic.
--
-- update_learning_path_progress_on_topic_complete() added
-- COALESCE(recommended_topics.xp_value, 50) to user_learning_path_progress
-- .total_xp_earned on every first completion, regardless of what was written to
-- user_topic_progress.xp_earned. complete_topic_progress() writes the same value,
-- but any completion that awards a different amount does not: the
-- 20260906000009 backfill inserted completed rows with xp_earned = 0 on purpose,
-- and the trigger still credited 50 XP per topic to every enrolled path. The
-- path counter then disagreed with the topic rows (and with every other XP
-- total, which sums user_topic_progress.xp_earned).
--
-- Fix: the trigger adds NEW.xp_earned, the value the completing statement
-- actually wrote. complete_topic_progress() sets completed_at and xp_earned in
-- the same statement, so NEW carries the awarded XP. The NULL -> NOT NULL guard
-- on completed_at is unchanged, so re-completing a topic (which
-- complete_topic_progress turns into a time_spent-only update that leaves
-- completed_at set) still adds nothing.
--
-- Body otherwise identical to 20260721000003 (visible-topic denominator and
-- cursor logic untouched); tables are now schema-qualified and search_path is
-- pinned, as this is SECURITY DEFINER.

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
  v_total_topics INTEGER;
  v_topic_xp INTEGER;
  v_visible_completed INTEGER;
BEGIN
  -- Only process when a topic is being marked as completed
  IF NEW.completed_at IS NOT NULL AND (OLD.completed_at IS NULL OR OLD IS NULL) THEN
    -- The XP this completion actually awarded (0 for backfilled/no-XP rows).
    v_topic_xp := COALESCE(NEW.xp_earned, 0);

    -- Find learning paths that include this topic AS A VISIBLE ENTRY and where
    -- the user is enrolled and not yet finished.
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
      -- Get topic position
      SELECT lpt.position
      INTO v_topic_position
      FROM public.learning_path_topics lpt
      JOIN public.recommended_topics rt ON rt.id = lpt.topic_id
      WHERE lpt.learning_path_id = v_learning_path_id
        AND lpt.topic_id = NEW.topic_id
        AND lpt.is_active = true
        AND rt.is_active  = true;

      -- Get total VISIBLE topics in path (denominator for completion).
      SELECT COUNT(*) INTO v_total_topics
      FROM public.learning_path_topics lpt
      JOIN public.recommended_topics rt ON rt.id = lpt.topic_id
      WHERE lpt.learning_path_id = v_learning_path_id
        AND lpt.is_active = true
        AND rt.is_active  = true;

      -- Position of the next VISIBLE topic after this one; NULL when this was
      -- the last visible topic in the path.
      SELECT MIN(lpt.position) INTO v_next_position
      FROM public.learning_path_topics lpt
      JOIN public.recommended_topics rt ON rt.id = lpt.topic_id
      WHERE lpt.learning_path_id = v_learning_path_id
        AND lpt.is_active = true
        AND rt.is_active  = true
        AND lpt.position > v_topic_position;

      -- Completion numerator, recomputed from the source of truth (see
      -- 20260721000003). AFTER trigger, so NEW is already counted.
      SELECT COUNT(*)
      INTO v_visible_completed
      FROM public.learning_path_topics lpt
      JOIN public.recommended_topics rt ON rt.id = lpt.topic_id
      JOIN public.user_topic_progress utp
        ON utp.topic_id = lpt.topic_id
       AND utp.user_id  = NEW.user_id
       AND utp.completed_at IS NOT NULL
      WHERE lpt.learning_path_id = v_learning_path_id
        AND lpt.is_active = true
        AND rt.is_active  = true;

      -- Update progress
      UPDATE public.user_learning_path_progress
      SET
        topics_completed = topics_completed + 1,
        current_topic_position = COALESCE(v_next_position, v_topic_position),
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

COMMENT ON FUNCTION public.update_learning_path_progress_on_topic_complete() IS 'Trigger function to auto-update learning path progress when topics are completed. Adds the XP the completion actually awarded (NEW.xp_earned). Only visible topics count toward progress, and the position cursor advances to the next visible topic.';

-- Backfill: per-path XP = sum of XP awarded for that path's completed topics.
-- Set-based and idempotent (touches only rows that still disagree). Rows the
-- old trigger over-credited (e.g. topics backfilled with xp_earned = 0) come
-- down; paths enrolled after a topic was already completed come up to the XP
-- that topic actually awarded. Rows that already agree are untouched.
-- user_learning_path_progress has no updated_at column.
UPDATE public.user_learning_path_progress ulp
SET total_xp_earned = s.topic_xp
FROM (
  SELECT ulp2.id, COALESCE(SUM(utp.xp_earned), 0) AS topic_xp
  FROM public.user_learning_path_progress ulp2
  JOIN public.learning_path_topics lpt ON lpt.learning_path_id = ulp2.learning_path_id
  LEFT JOIN public.user_topic_progress utp
    ON utp.topic_id = lpt.topic_id
   AND utp.user_id = ulp2.user_id
   AND utp.completed_at IS NOT NULL
  GROUP BY ulp2.id
) s
WHERE s.id = ulp.id
  AND ulp.total_xp_earned IS DISTINCT FROM s.topic_xp;
