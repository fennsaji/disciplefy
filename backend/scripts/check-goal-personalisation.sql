-- Checks for migration 20261010200000_goal_based_personalisation.sql.
-- Local only:  psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f scripts/check-goal-personalisation.sql
-- Read-only: everything that writes runs in a transaction that is rolled back.
\set ON_ERROR_STOP 1

DO $$
DECLARE
  v_missing TEXT;
  v_bad_first TEXT;
BEGIN
  -- Every active path is reachable from at least one goal list.
  SELECT string_agg(lp.slug, ', ') INTO v_missing
  FROM public.learning_paths lp
  WHERE lp.is_active
    AND NOT EXISTS (SELECT 1 FROM public.growth_goal_paths g WHERE g.path_slug = lp.slug);
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'active paths missing from growth_goal_paths: %', v_missing;
  END IF;

  -- Each list starts with its first-run path.
  SELECT string_agg(f.goal || '->' || COALESCE(first.path_slug, 'none'), ', ') INTO v_bad_first
  FROM (VALUES
    ('new_to_faith', 'new-believer-essentials'),
    ('fresh_start', 'sin-repentance-and-grace'),
    ('walk_with_god', 'growing-in-discipleship'),
    ('hope_hard_times', 'theology-of-suffering'),
    ('read_gospel', 'gospel-of-mark'),
    ('understand_gospel', 'romans-gospel-unfolded')
  ) AS f(goal, slug)
  LEFT JOIN LATERAL (
    SELECT g.path_slug FROM public.growth_goal_paths g
    WHERE g.goal = f.goal ORDER BY g.position, g.path_slug LIMIT 1
  ) first ON true
  WHERE first.path_slug IS DISTINCT FROM f.slug;
  IF v_bad_first IS NOT NULL THEN
    RAISE EXCEPTION 'goal lists not starting with their first-run path: %', v_bad_first;
  END IF;

  -- The six first-run paths are the guest paths.
  IF EXISTS (
    SELECT 1 FROM public.learning_paths
    WHERE guest_accessible AND slug NOT IN (
      'new-believer-essentials', 'sin-repentance-and-grace', 'growing-in-discipleship',
      'theology-of-suffering', 'gospel-of-mark', 'romans-gospel-unfolded')
  ) THEN
    RAISE EXCEPTION 'unexpected guest-accessible path';
  END IF;

  -- Answer mapping.
  IF public.growth_goal_from_answers('new_believer', '{apologetics}', NULL, NULL) <> 'new_to_faith'
    OR public.growth_goal_from_answers('growing_believer', '{relationships}', NULL, 'starting_basics') <> 'new_to_faith'
    OR public.growth_goal_from_answers('committed_disciple', '{apologetics}', NULL, NULL) <> 'understand_gospel'
    OR public.growth_goal_from_answers('growing_believer', '{spiritual_depth}', NULL, 'handling_doubts') <> 'understand_gospel'
    OR public.growth_goal_from_answers('growing_believer', '{service}', 'intellectual_growth', NULL) <> 'understand_gospel'
    OR public.growth_goal_from_answers('growing_believer', '{foundational_faith}', NULL, NULL) <> 'new_to_faith'
    OR public.growth_goal_from_answers('committed_disciple', '{service,relationships}', 'community_impact', 'sharing_faith') <> 'walk_with_god'
    OR public.growth_goal_from_answers('growing_believer', '{}', NULL, NULL) <> 'walk_with_god'
    OR public.growth_goal_from_answers(NULL, '{}', NULL, NULL) IS NOT NULL
    OR public.growth_goal_from_answers(NULL, NULL, NULL, NULL) IS NOT NULL
  THEN
    RAISE EXCEPTION 'growth_goal_from_answers mapping is wrong';
  END IF;

  -- Back-fill done: every finished questionnaire with answers has a goal.
  IF EXISTS (
    SELECT 1 FROM public.user_personalization p
    JOIN auth.users u ON u.id = p.user_id
    WHERE p.questionnaire_completed IS TRUE
      AND public.growth_goal_from_answers(p.faith_stage, p.spiritual_goals,
                                          p.life_stage_focus, p.biggest_challenge) IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM public.user_growth_goals g WHERE g.user_id = p.user_id)
  ) THEN
    RAISE EXCEPTION 'finished questionnaire without a growth goal';
  END IF;
END $$;

-- Writes (rolled back): set_my_growth_goal and the guest merge.
BEGIN;
DO $$
DECLARE
  v_guest UUID := gen_random_uuid();
  v_user UUID := gen_random_uuid();
  v_goal TEXT;
BEGIN
  INSERT INTO auth.users (id, is_anonymous) VALUES (v_guest, true), (v_user, false);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_guest)::text, true);
  PERFORM public.set_my_growth_goal('read_gospel', 'first_run');
  PERFORM public.set_my_growth_goal('hope_hard_times', 'settings');
  SELECT goal INTO v_goal FROM public.user_growth_goals WHERE user_id = v_guest;
  IF v_goal <> 'hope_hard_times' THEN RAISE EXCEPTION 'set_my_growth_goal did not update'; END IF;

  BEGIN
    PERFORM public.set_my_growth_goal('not_a_goal');
    RAISE EXCEPTION 'invalid goal accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- Account without a goal: the guest's moves.
  PERFORM public.merge_guest_growth_goal(v_guest, v_user);
  SELECT goal INTO v_goal FROM public.user_growth_goals WHERE user_id = v_user;
  IF v_goal IS DISTINCT FROM 'hope_hard_times' THEN RAISE EXCEPTION 'guest goal not moved'; END IF;
  IF EXISTS (SELECT 1 FROM public.user_growth_goals WHERE user_id = v_guest) THEN
    RAISE EXCEPTION 'guest goal row left behind';
  END IF;

  -- Older guest goal does not replace a newer account goal.
  INSERT INTO public.user_growth_goals (user_id, goal, source, updated_at)
    VALUES (v_guest, 'fresh_start', 'first_run', now() - interval '1 day');
  PERFORM public.merge_guest_growth_goal(v_guest, v_user);
  SELECT goal INTO v_goal FROM public.user_growth_goals WHERE user_id = v_user;
  IF v_goal <> 'hope_hard_times' THEN RAISE EXCEPTION 'older guest goal replaced the account goal'; END IF;

  -- Second merge is a no-op.
  PERFORM public.merge_guest_growth_goal(v_guest, v_user);
END $$;
ROLLBACK;

SELECT 'goal personalisation checks passed' AS result;
