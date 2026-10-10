-- ============================================================================
-- Goal-based personalisation (owner decision 2026-10-10, "option A").
--
-- The first-run goal ("What would you like to grow in?") is the only
-- personalisation question. It is stored per user on the server (guests too)
-- and drives one "what next" engine (_shared/personalization/next-paths.ts).
--
--   user_growth_goals      one row per user: the goal and where it came from.
--                          Read own row (RLS); written by set_my_growth_goal.
--   growth_goal_paths      goal -> ordered learning path slugs. Every active
--                          path is in at least one list; each list starts with
--                          the goal's first-run path. FK to learning_paths.slug
--                          (cascade), so a retired path never leaves a stale
--                          slug. Editable from the dashboard; read by the
--                          engine with the service role.
--   growth_goal_from_answers(...)  maps old questionnaire answers to a goal.
--                          Used by the back-fill below and by the old
--                          save-personalization `save` action (older apps).
--   set_my_growth_goal(p_goal, p_source)  upserts the caller's goal.
--   merge_guest_growth_goal(p_guest, p_user)  guest -> account on sign-up
--                          (user-profile?action=merge_guest). Latest goal wins.
--
-- Back-fill: users who finished the old questionnaire and have no goal yet get
-- the mapped goal (source 'questionnaire'). Users with neither get no row and
-- fall back to the featured paths.
--
-- Deprecated, kept for older apps (cleanup later): user_personalization and
-- its answer columns, questionnaire_* flags and scoring_results (no longer
-- written).
--
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Goals
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_growth_goals (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  goal TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'app',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_growth_goals_goal CHECK (goal IN (
    'new_to_faith', 'fresh_start', 'walk_with_god',
    'hope_hard_times', 'read_gospel', 'understand_gospel'
  )),
  CONSTRAINT user_growth_goals_source CHECK (source IN (
    'app', 'first_run', 'settings', 'questionnaire', 'migration'
  ))
);

COMMENT ON TABLE public.user_growth_goals IS
  'What the person wants to grow in (first-run goal screen / Settings > Change '
  'my goal). Drives the next-path engine. Written through set_my_growth_goal.';

ALTER TABLE public.user_growth_goals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own growth goal" ON public.user_growth_goals;
CREATE POLICY "Users read own growth goal" ON public.user_growth_goals
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

REVOKE ALL ON public.user_growth_goals FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_growth_goals TO authenticated;
GRANT ALL ON public.user_growth_goals TO service_role;

-- ----------------------------------------------------------------------------
-- Goal -> ordered paths
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.growth_goal_paths (
  goal TEXT NOT NULL,
  path_slug VARCHAR(100) NOT NULL
    REFERENCES public.learning_paths(slug) ON UPDATE CASCADE ON DELETE CASCADE,
  position INTEGER NOT NULL,
  PRIMARY KEY (goal, path_slug),
  CONSTRAINT growth_goal_paths_goal CHECK (goal IN (
    'new_to_faith', 'fresh_start', 'walk_with_god',
    'hope_hard_times', 'read_gospel', 'understand_gospel'
  )),
  CONSTRAINT growth_goal_paths_position CHECK (position > 0)
);

COMMENT ON TABLE public.growth_goal_paths IS
  'Ordered learning paths recommended for each growth goal (lowest position '
  'first). The first row of each goal is the path its first-run screen starts.';

CREATE INDEX IF NOT EXISTS idx_growth_goal_paths_goal_position
  ON public.growth_goal_paths (goal, position);

ALTER TABLE public.growth_goal_paths ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.growth_goal_paths FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.growth_goal_paths TO service_role;

-- Seed. Slugs that do not exist in this database are skipped (join), and a
-- re-run only moves positions.
INSERT INTO public.growth_goal_paths (goal, path_slug, position)
SELECT v.goal, lp.slug, v.position
FROM (VALUES
  ('new_to_faith', 'new-believer-essentials', 1),
  ('new_to_faith', 'rooted-in-christ', 2),
  ('new_to_faith', 'understanding-the-bible', 3),
  ('new_to_faith', 'gospel-of-mark', 4),
  ('new_to_faith', 'baptism-and-lords-supper', 5),
  ('new_to_faith', 'the-local-church', 6),
  ('new_to_faith', 'who-is-the-holy-spirit', 7),
  ('new_to_faith', 'sin-repentance-and-grace', 8),
  ('new_to_faith', 'gospel-of-john', 9),
  ('new_to_faith', 'crucifixion-and-resurrection', 10),
  ('new_to_faith', 'growing-in-discipleship', 11),
  ('new_to_faith', 'friendship-and-christian-community', 12),
  ('new_to_faith', 'attributes-of-god', 13),
  ('new_to_faith', 'defending-your-faith', 14),
  ('fresh_start', 'sin-repentance-and-grace', 1),
  ('fresh_start', 'crucifixion-and-resurrection', 2),
  ('fresh_start', 'galatians-gospel-freedom', 3),
  ('fresh_start', 'romans-gospel-unfolded', 4),
  ('fresh_start', 'philemon-forgiveness-and-reconciliation', 5),
  ('fresh_start', 'gospel-of-luke', 6),
  ('fresh_start', 'jesus-parables', 7),
  ('fresh_start', 'rooted-in-christ', 8),
  ('fresh_start', 'law-grace-and-covenants', 9),
  ('fresh_start', 'mental-health-emotions-gospel', 10),
  ('fresh_start', 'baptism-and-lords-supper', 11),
  ('fresh_start', 'new-believer-essentials', 12),
  ('fresh_start', 'hebrews-jesus-our-high-priest', 13),
  ('walk_with_god', 'growing-in-discipleship', 1),
  ('walk_with_god', 'deepening-your-walk', 2),
  ('walk_with_god', 'philippians-joy-in-christ', 3),
  ('walk_with_god', 'sermon-on-the-mount', 4),
  ('walk_with_god', 'james-faith-that-works', 5),
  ('walk_with_god', 'who-is-the-holy-spirit', 6),
  ('walk_with_god', 'the-local-church', 7),
  ('walk_with_god', 'friendship-and-christian-community', 8),
  ('walk_with_god', 'faith-and-family', 9),
  ('walk_with_god', 'money-generosity-gospel', 10),
  ('walk_with_god', 'work-and-vocation-as-worship', 11),
  ('walk_with_god', 'spiritual-warfare', 12),
  ('walk_with_god', 'evangelism-everyday-life', 13),
  ('walk_with_god', '1-thessalonians-living-ready', 14),
  ('walk_with_god', '1-timothy-household-of-god', 15),
  ('walk_with_god', 'titus-sound-doctrine-sound-living', 16),
  ('walk_with_god', 'heart-for-the-world', 17),
  ('walk_with_god', 'christianity-and-culture', 18),
  ('hope_hard_times', 'theology-of-suffering', 1),
  ('hope_hard_times', 'mental-health-emotions-gospel', 2),
  ('hope_hard_times', 'peters-letters-hope-and-endurance', 3),
  ('hope_hard_times', 'philippians-joy-in-christ', 4),
  ('hope_hard_times', 'attributes-of-god', 5),
  ('hope_hard_times', 'eternal-perspective', 6),
  ('hope_hard_times', '2-thessalonians-standing-firm', 7),
  ('hope_hard_times', 'hebrews-jesus-our-high-priest', 8),
  ('hope_hard_times', 'spiritual-warfare', 9),
  ('hope_hard_times', 'revelation-the-lamb-who-reigns', 10),
  ('hope_hard_times', '2-timothy-guard-the-good-deposit', 11),
  ('hope_hard_times', 'gospel-of-john', 12),
  ('hope_hard_times', 'faith-and-family', 13),
  ('read_gospel', 'gospel-of-mark', 1),
  ('read_gospel', 'gospel-of-john', 2),
  ('read_gospel', 'gospel-of-luke', 3),
  ('read_gospel', 'gospel-of-matthew', 4),
  ('read_gospel', 'sermon-on-the-mount', 5),
  ('read_gospel', 'jesus-parables', 6),
  ('read_gospel', 'crucifixion-and-resurrection', 7),
  ('read_gospel', 'understanding-the-bible', 8),
  ('read_gospel', 'historical-reliability-bible', 9),
  ('read_gospel', 'johns-letters-light-love-truth', 10),
  ('read_gospel', 'revelation-the-lamb-who-reigns', 11),
  ('read_gospel', 'peters-letters-hope-and-endurance', 12),
  ('read_gospel', 'james-faith-that-works', 13),
  ('understand_gospel', 'romans-gospel-unfolded', 1),
  ('understand_gospel', 'galatians-gospel-freedom', 2),
  ('understand_gospel', 'ephesians-riches-in-christ', 3),
  ('understand_gospel', 'colossians-supremacy-of-christ', 4),
  ('understand_gospel', 'sin-repentance-and-grace', 5),
  ('understand_gospel', 'law-grace-and-covenants', 6),
  ('understand_gospel', 'hebrews-jesus-our-high-priest', 7),
  ('understand_gospel', 'attributes-of-god', 8),
  ('understand_gospel', 'corinthians-christ-and-his-church', 9),
  ('understand_gospel', 'johns-letters-light-love-truth', 10),
  ('understand_gospel', 'defending-your-faith', 11),
  ('understand_gospel', 'faith-and-reason', 12),
  ('understand_gospel', 'historical-reliability-bible', 13),
  ('understand_gospel', 'christianity-and-culture', 14),
  ('understand_gospel', '1-timothy-household-of-god', 15),
  ('understand_gospel', '2-timothy-guard-the-good-deposit', 16),
  ('understand_gospel', 'titus-sound-doctrine-sound-living', 17),
  ('understand_gospel', 'jude-contend-for-the-faith', 18),
  ('understand_gospel', '1-thessalonians-living-ready', 19),
  ('understand_gospel', '2-thessalonians-standing-firm', 20),
  ('understand_gospel', 'revelation-the-lamb-who-reigns', 21),
  ('understand_gospel', 'eternal-perspective', 22)
) AS v(goal, path_slug, position)
JOIN public.learning_paths lp ON lp.slug = v.path_slug
ON CONFLICT (goal, path_slug) DO UPDATE SET position = EXCLUDED.position;

-- ----------------------------------------------------------------------------
-- Old questionnaire answers -> goal
--   1. new believer, or "I'm new and don't know where to start" -> new_to_faith
--   2. apologetics / theology goals, doubts, or big questions  -> understand_gospel
--   3. foundational faith goal                                 -> new_to_faith
--   4. any other answers                                       -> walk_with_god
--   5. nothing answered                                        -> NULL (no goal)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.growth_goal_from_answers(
  p_faith_stage TEXT,
  p_spiritual_goals TEXT[],
  p_life_stage_focus TEXT,
  p_biggest_challenge TEXT
)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN p_faith_stage = 'new_believer' OR p_biggest_challenge = 'starting_basics'
      THEN 'new_to_faith'
    WHEN COALESCE(p_spiritual_goals, '{}') && ARRAY['apologetics', 'theology']::TEXT[]
      OR p_biggest_challenge = 'handling_doubts'
      OR p_life_stage_focus = 'intellectual_growth'
      THEN 'understand_gospel'
    WHEN COALESCE(p_spiritual_goals, '{}') @> ARRAY['foundational_faith']::TEXT[]
      THEN 'new_to_faith'
    WHEN p_faith_stage IS NOT NULL
      OR COALESCE(cardinality(p_spiritual_goals), 0) > 0
      OR p_life_stage_focus IS NOT NULL
      OR p_biggest_challenge IS NOT NULL
      THEN 'walk_with_god'
    ELSE NULL
  END;
$$;

COMMENT ON FUNCTION public.growth_goal_from_answers(TEXT, TEXT[], TEXT, TEXT) IS
  'Closest growth goal for answers of the retired 6-step questionnaire; NULL '
  'when nothing was answered.';

REVOKE ALL ON FUNCTION public.growth_goal_from_answers(TEXT, TEXT[], TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.growth_goal_from_answers(TEXT, TEXT[], TEXT, TEXT)
  TO authenticated, service_role;

-- Back-fill: finished questionnaires without a goal. A goal already set is
-- never replaced, so a re-run changes nothing.
INSERT INTO public.user_growth_goals (user_id, goal, source)
SELECT p.user_id,
       public.growth_goal_from_answers(p.faith_stage, p.spiritual_goals,
                                       p.life_stage_focus, p.biggest_challenge),
       'migration'
FROM public.user_personalization p
JOIN auth.users u ON u.id = p.user_id
WHERE p.questionnaire_completed IS TRUE
  AND public.growth_goal_from_answers(p.faith_stage, p.spiritual_goals,
                                      p.life_stage_focus, p.biggest_challenge) IS NOT NULL
ON CONFLICT (user_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- set_my_growth_goal: the caller's goal (guests too). Returns the row.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_my_growth_goal(p_goal TEXT, p_source TEXT DEFAULT 'app')
RETURNS public.user_growth_goals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_source TEXT := COALESCE(NULLIF(p_source, ''), 'app');
  v_row public.user_growth_goals;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'growth_goal:not_signed_in' USING ERRCODE = '42501';
  END IF;
  IF v_source NOT IN ('app', 'first_run', 'settings', 'questionnaire') THEN
    v_source := 'app';
  END IF;
  INSERT INTO public.user_growth_goals AS g (user_id, goal, source)
  VALUES (v_user, p_goal, v_source)
  ON CONFLICT (user_id) DO UPDATE
    SET goal = EXCLUDED.goal, source = EXCLUDED.source, updated_at = now()
  RETURNING g.* INTO v_row;
  RETURN v_row;
END;
$$;

COMMENT ON FUNCTION public.set_my_growth_goal(TEXT, TEXT) IS
  'Saves the caller''s growth goal (auth.uid() only). Invalid goals fail the '
  'table check (23514).';

REVOKE ALL ON FUNCTION public.set_my_growth_goal(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_my_growth_goal(TEXT, TEXT) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- merge_guest_growth_goal: guest -> account. The latest goal wins (the guest
-- usually picked it minutes ago on this device). Service role only; called by
-- user-profile?action=merge_guest after merge_guest_progress checked the pair.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.merge_guest_growth_goal(p_guest UUID, p_user UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_guest public.user_growth_goals;
BEGIN
  IF p_guest IS NULL OR p_user IS NULL OR p_guest = p_user THEN
    RETURN;
  END IF;
  DELETE FROM public.user_growth_goals WHERE user_id = p_guest
  RETURNING * INTO v_guest;
  IF v_guest.user_id IS NULL THEN
    RETURN;
  END IF;
  INSERT INTO public.user_growth_goals AS a (user_id, goal, source, created_at, updated_at)
  VALUES (p_user, v_guest.goal, v_guest.source, v_guest.created_at, v_guest.updated_at)
  ON CONFLICT (user_id) DO UPDATE
    SET goal = EXCLUDED.goal, source = EXCLUDED.source, updated_at = EXCLUDED.updated_at
    WHERE EXCLUDED.updated_at > a.updated_at;
END;
$$;

COMMENT ON FUNCTION public.merge_guest_growth_goal(UUID, UUID) IS
  'Moves a guest''s growth goal into the account (latest wins). Service role only.';

REVOKE ALL ON FUNCTION public.merge_guest_growth_goal(UUID, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.merge_guest_growth_goal(UUID, UUID) TO service_role;

-- ----------------------------------------------------------------------------
-- Deprecated questionnaire storage (older apps still read and write it).
-- ----------------------------------------------------------------------------
COMMENT ON TABLE public.user_personalization IS
  'DEPRECATED (2026-10-10): answers of the retired 6-step questionnaire. Older '
  'apps still save and read it through save-personalization; the goal in '
  'user_growth_goals drives recommendations. Drop once those apps are gone.';
COMMENT ON COLUMN public.user_personalization.scoring_results IS
  'DEPRECATED (2026-10-10): no longer written or read. Drop with the table.';

COMMIT;
