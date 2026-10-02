-- A fellowship's current lesson index belongs to the learning path it was
-- reached on. When a group moved to another path the index could travel with
-- it (a group at lesson 8 of 8 landed on a 5-lesson path past its end, so the
-- app showed the new path as already finished). This keeps the index tied to
-- its path for every writer — edge functions, the admin dashboard and the
-- daily-post worker alike:
--   * changing learning_path_id without also choosing an index starts the
--     group at the new path's first lesson;
--   * an index past the path's last active lesson is pulled back — to the
--     first lesson when the path just changed, otherwise to the last lesson.
-- Then it repairs rows already stored with an index beyond their path.
-- Idempotent: safe to run more than once.

CREATE OR REPLACE FUNCTION public.fellowship_study_guide_index_follows_path()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_last_position integer;
  v_path_changed boolean :=
    TG_OP = 'UPDATE' AND NEW.learning_path_id IS DISTINCT FROM OLD.learning_path_id;
BEGIN
  IF v_path_changed AND NEW.current_guide_index = OLD.current_guide_index THEN
    NEW.current_guide_index := 0;
  END IF;

  SELECT max(position) INTO v_last_position
  FROM public.learning_path_topics
  WHERE learning_path_id = NEW.learning_path_id
    AND is_active = true;

  IF v_last_position IS NOT NULL AND NEW.current_guide_index > v_last_position THEN
    NEW.current_guide_index := CASE WHEN v_path_changed THEN 0 ELSE v_last_position END;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS fellowship_study_guide_index_follows_path ON public.fellowship_study;
CREATE TRIGGER fellowship_study_guide_index_follows_path
  BEFORE INSERT OR UPDATE OF learning_path_id, current_guide_index
  ON public.fellowship_study
  FOR EACH ROW
  EXECUTE FUNCTION public.fellowship_study_guide_index_follows_path();

-- Existing groups whose index runs past their path's end carried it over from
-- a previous path: start them at the first lesson of the path they are on.
UPDATE public.fellowship_study fs
SET current_guide_index = 0,
    updated_at = now()
FROM (
  SELECT learning_path_id, max(position) AS last_position
  FROM public.learning_path_topics
  WHERE is_active = true
  GROUP BY learning_path_id
) lp
WHERE lp.learning_path_id = fs.learning_path_id
  AND fs.completed_at IS NULL
  AND fs.current_guide_index > lp.last_position;
