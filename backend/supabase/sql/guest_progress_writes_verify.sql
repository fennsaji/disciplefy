-- Verification for 20261006210000_revoke_ensure_path_started,
-- 20261006220000_guest_progress_direct_writes and
-- 20261006230000_complete_topic_progress_single_winner.
-- Run against LOCAL Supabase only; everything is rolled back:
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f backend/supabase/sql/guest_progress_writes_verify.sql
-- Stops on the first failed assertion (ON_ERROR_STOP).

\set ON_ERROR_STOP on
SET plpgsql.check_asserts = on;
BEGIN;

CREATE TEMP TABLE ids AS SELECT
  '00000000-0000-4000-8000-00000000f0a1'::uuid AS guest,
  '00000000-0000-4000-8000-00000000f0b1'::uuid AS member,
  (SELECT id FROM public.recommended_topics ORDER BY id LIMIT 1) AS t1,
  (SELECT id FROM public.recommended_topics ORDER BY id OFFSET 1 LIMIT 1) AS t2,
  (SELECT id FROM public.learning_paths ORDER BY id LIMIT 1) AS p1;
GRANT SELECT ON ids TO anon, authenticated, service_role;

INSERT INTO auth.users (id, aud, role, email, is_anonymous, created_at, updated_at)
SELECT guest, 'authenticated', 'authenticated', NULL, true, now(), now() FROM ids
UNION ALL
SELECT member, 'authenticated', 'authenticated', 'progress-verify@example.invalid', false, now(), now() FROM ids;

-- 1. Progress RPCs: service_role only.
DO $$
DECLARE fn text; r text;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'public.ensure_learning_path_started(uuid, uuid)',
    'public.complete_topic_progress(uuid, uuid, integer)',
    'public.start_topic_progress(uuid, uuid)'
  ] LOOP
    FOREACH r IN ARRAY ARRAY['anon', 'authenticated'] LOOP
      ASSERT NOT has_function_privilege(r, fn, 'EXECUTE'), r || ' can execute ' || fn;
    END LOOP;
    ASSERT has_function_privilege('service_role', fn, 'EXECUTE'), 'service_role cannot execute ' || fn;
  END LOOP;
  RAISE NOTICE 'ok: progress RPCs are service_role only';
END $$;

-- 2. Direct writes: a guest is refused, a full user is not.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT guest FROM ids), 'role', 'authenticated', 'is_anonymous', true)::text, true);
DO $$ BEGIN
  INSERT INTO public.user_learning_path_progress (user_id, learning_path_id) SELECT guest, p1 FROM ids;
  RAISE EXCEPTION 'FAIL: guest inserted an enrolment';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok: guest enrolment insert refused'; END $$;
DO $$ BEGIN
  INSERT INTO public.user_topic_progress (user_id, topic_id, completed_at, xp_earned) SELECT guest, t1, now(), 9999 FROM ids;
  RAISE EXCEPTION 'FAIL: guest inserted a completed topic';
EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok: guest topic insert refused'; END $$;

SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT member FROM ids), 'role', 'authenticated', 'is_anonymous', false)::text, true);
INSERT INTO public.user_topic_progress (user_id, topic_id, started_at) SELECT member, t2, now() FROM ids;
UPDATE public.user_topic_progress SET time_spent_seconds = 5 WHERE user_id = (SELECT member FROM ids);
-- A token without the claim still counts as a full user.
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT member FROM ids), 'role', 'authenticated')::text, true);
INSERT INTO public.user_learning_path_progress (user_id, learning_path_id) SELECT member, p1 FROM ids;
RESET ROLE;
DO $$ BEGIN
  ASSERT (SELECT count(*) FROM public.user_topic_progress WHERE user_id = (SELECT member FROM ids)) = 1, 'member topic row';
  ASSERT (SELECT count(*) FROM public.user_learning_path_progress WHERE user_id = (SELECT member FROM ids)) = 1, 'member path row';
  ASSERT (SELECT count(*) FROM public.user_topic_progress WHERE user_id = (SELECT guest FROM ids)) = 0, 'no guest topic rows';
  RAISE NOTICE 'ok: full user writes unchanged';
END $$;

-- 3. complete_topic_progress: first call wins, repeat adds time without XP.
SET LOCAL ROLE service_role;
CREATE TEMP TABLE c1 AS SELECT * FROM public.complete_topic_progress((SELECT guest FROM ids), (SELECT t1 FROM ids), 30);
CREATE TEMP TABLE c2 AS SELECT * FROM public.complete_topic_progress((SELECT guest FROM ids), (SELECT t1 FROM ids), 20);
-- A started (not completed) row is completed on the first call.
CREATE TEMP TABLE c3 AS SELECT * FROM public.complete_topic_progress((SELECT member FROM ids), (SELECT t2 FROM ids), 10);
RESET ROLE;
DO $$ DECLARE a record; b record; c record; row record; BEGIN
  SELECT * INTO a FROM c1; SELECT * INTO b FROM c2; SELECT * INTO c FROM c3;
  ASSERT a.is_first_completion AND a.xp_earned > 0, 'first call is the first completion';
  ASSERT NOT b.is_first_completion AND b.xp_earned = 0, 'repeat earns nothing';
  ASSERT a.progress_id = b.progress_id, 'same row';
  SELECT * INTO row FROM public.user_topic_progress WHERE id = a.progress_id;
  ASSERT row.time_spent_seconds = 50 AND row.xp_earned = a.xp_earned AND row.completed_at IS NOT NULL, 'stored row';
  ASSERT c.is_first_completion AND c.xp_earned > 0, 'started row completed';
  SELECT * INTO row FROM public.user_topic_progress WHERE id = c.progress_id;
  ASSERT row.time_spent_seconds = 15, 'started row keeps its time and adds the new time';
  RAISE NOTICE 'ok: complete_topic_progress first/repeat';
END $$;

ROLLBACK;
