-- Regression test for merge_guest_progress (20261006170000_merge_guest_progress).
-- Run against LOCAL Supabase only (needs the seeded catalogue: a learning path
-- with >= 4 visible lessons and >= 3 study_guides rows); everything is rolled back:
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f backend/supabase/sql/merge_guest_progress_verify.sql
-- Covers: guest topics moved, same-topic conflict (account wins), path XP = sum
-- of topic XP, cursor recompute, streak combine, idempotent second run returns
-- zeros, other users untouched, non-anonymous / guest-target / same-id sources
-- rejected, anon and authenticated denied. Stops on the first failure.

\set ON_ERROR_STOP on
SET plpgsql.check_asserts = on;
BEGIN;

CREATE TEMP TABLE ids AS SELECT
  '00000000-0000-4000-8000-0000000000a1'::uuid AS g,   -- guest
  '00000000-0000-4000-8000-0000000000b1'::uuid AS u,   -- full account
  '00000000-0000-4000-8000-0000000000c1'::uuid AS o,   -- other full user (must not change)
  '00000000-0000-4000-8000-0000000000d1'::uuid AS g2;  -- another guest, untouched
GRANT SELECT ON ids TO service_role, authenticated, anon;

INSERT INTO auth.users (id, aud, role, email, is_anonymous, created_at, updated_at)
SELECT g, 'authenticated', 'authenticated', NULL, true, now(), now() FROM ids
UNION ALL SELECT u, 'authenticated', 'authenticated', 'merge-test-u@example.invalid', false, now(), now() FROM ids
UNION ALL SELECT o, 'authenticated', 'authenticated', 'merge-test-o@example.invalid', false, now(), now() FROM ids
UNION ALL SELECT g2, 'authenticated', 'authenticated', NULL, true, now(), now() FROM ids;

-- A path with >= 4 visible topics, topics t1..t4 by position.
CREATE TEMP TABLE pt AS
SELECT lpt.learning_path_id AS path_id, lpt.topic_id, lpt.position, row_number() OVER (ORDER BY lpt.position) AS n
FROM learning_path_topics lpt JOIN recommended_topics rt ON rt.id = lpt.topic_id
WHERE lpt.learning_path_id = (
  SELECT lp.id FROM learning_paths lp JOIN learning_path_topics l ON l.learning_path_id = lp.id
  JOIN recommended_topics r ON r.id = l.topic_id WHERE l.is_active AND r.is_active
  GROUP BY lp.id HAVING count(*) >= 4 ORDER BY lp.id LIMIT 1)
  AND lpt.is_active AND rt.is_active;
CREATE TEMP TABLE sg AS SELECT id, row_number() OVER (ORDER BY id) AS n FROM study_guides ORDER BY id LIMIT 3;

-- Guest: enrol, complete t1 and t3, start t4.
INSERT INTO user_learning_path_progress (user_id, learning_path_id, enrolled_at)
SELECT g, (SELECT path_id FROM pt LIMIT 1), now() - interval '2 days' FROM ids;
INSERT INTO user_topic_progress (user_id, topic_id, started_at, completed_at, time_spent_seconds, xp_earned)
SELECT g, topic_id, now() - interval '1 day', now() - interval '1 hour', 300, 50 FROM ids, pt WHERE n IN (1, 3);
INSERT INTO user_topic_progress (user_id, topic_id, started_at, time_spent_seconds)
SELECT g, topic_id, now(), 20 FROM ids, pt WHERE n = 4;

-- Account: completed t1 earlier with 30 XP, started t3 (not completed). Not enrolled.
INSERT INTO user_topic_progress (user_id, topic_id, started_at, completed_at, time_spent_seconds, xp_earned)
SELECT u, topic_id, now() - interval '30 days', now() - interval '29 days', 100, 30 FROM ids, pt WHERE n = 1;
INSERT INTO user_topic_progress (user_id, topic_id, started_at, time_spent_seconds)
SELECT u, topic_id, now() - interval '3 days', 40 FROM ids, pt WHERE n = 3;

-- Other user: same topics, enrolled.
INSERT INTO user_learning_path_progress (user_id, learning_path_id) SELECT o, (SELECT path_id FROM pt LIMIT 1) FROM ids;
INSERT INTO user_topic_progress (user_id, topic_id, completed_at, xp_earned)
SELECT o, topic_id, now(), 50 FROM ids, pt WHERE n = 1;

-- Guides: guest saved guide1, completed guide2; account has guide2 not completed.
INSERT INTO user_study_guides (user_id, study_guide_id, is_saved) SELECT g, id, true FROM ids, sg WHERE n = 1;
INSERT INTO user_study_guides (user_id, study_guide_id, completed_at, time_spent_seconds) SELECT g, id, now(), 200 FROM ids, sg WHERE n = 2;
INSERT INTO user_study_guides (user_id, study_guide_id, time_spent_seconds, personal_notes) SELECT u, id, 50, 'mine' FROM ids, sg WHERE n = 2;
INSERT INTO user_study_guides (user_id, study_guide_id) SELECT o, id FROM ids, sg WHERE n = 1;

-- Memory verses: guest John 3:16 + Psalm 23:1 (with a review); account John 3:16.
INSERT INTO memory_verses (user_id, verse_reference, verse_text, language, source_type)
SELECT g, 'John 3:16', 'x', 'en', 'manual' FROM ids
UNION ALL SELECT g, 'Psalm 23:1', 'x', 'en', 'manual' FROM ids
UNION ALL SELECT u, 'John 3:16', 'x', 'en', 'manual' FROM ids
UNION ALL SELECT o, 'Psalm 23:1', 'x', 'en', 'manual' FROM ids;
INSERT INTO memory_verse_collections (id, user_id, name, category)
SELECT '00000000-0000-4000-8000-0000000000e1', g, 'Guest set', 'custom' FROM ids;
INSERT INTO memory_verse_collection_items (collection_id, memory_verse_id)
SELECT '00000000-0000-4000-8000-0000000000e1', mv.id FROM ids, memory_verses mv WHERE mv.user_id = ids.g;
INSERT INTO review_sessions (user_id, memory_verse_id, practice_mode, quality_rating, time_spent_seconds, new_ease_factor, new_interval_days, new_repetitions)
SELECT g, mv.id, 'flip_card', 4, 10, 2.5, 1, 1 FROM ids, memory_verses mv WHERE mv.user_id = ids.g;

-- Daily streak: account 5 days ending today-2 (longest 10); guest 2 days ending today -> touching -> 7.
INSERT INTO daily_verse_streaks (user_id, current_streak, longest_streak, total_views, last_activity_local_date)
SELECT u, 5, 10, 40, current_date - 2 FROM ids
UNION ALL SELECT g, 2, 2, 3, current_date FROM ids
UNION ALL SELECT o, 9, 9, 9, current_date FROM ids;
-- Study streak: account none -> guest row moves.
INSERT INTO user_study_streaks (user_id, current_streak, longest_streak, last_study_date, total_study_days)
SELECT g, 1, 1, current_date, 1 FROM ids;

-- Achievements: guest first_study + studies_10; account first_study.
INSERT INTO user_achievements (user_id, achievement_id)
SELECT g, 'first_study' FROM ids UNION ALL SELECT g, 'studies_10' FROM ids UNION ALL SELECT u, 'first_study' FROM ids;

-- Personalization: guest completed; account none.
INSERT INTO user_personalization (user_id, faith_stage, questionnaire_completed)
SELECT g, (SELECT faith_stage FROM user_personalization WHERE faith_stage IS NOT NULL LIMIT 1), true FROM ids;
INSERT INTO user_notification_tokens (user_id, fcm_token, platform) SELECT g, 'merge-test-token', 'web' FROM ids;

-- Snapshot of everything belonging to the other users.
CREATE TEMP TABLE before_other AS
SELECT 'utp' t, md5(string_agg(x::text, ',' ORDER BY x::text)) h FROM user_topic_progress x WHERE user_id IN (SELECT o FROM ids UNION SELECT g2 FROM ids)
UNION ALL SELECT 'ulp', md5(string_agg(x::text, ',' ORDER BY x::text)) FROM user_learning_path_progress x WHERE user_id IN (SELECT o FROM ids)
UNION ALL SELECT 'usg', md5(string_agg(x::text, ',' ORDER BY x::text)) FROM user_study_guides x WHERE user_id IN (SELECT o FROM ids)
UNION ALL SELECT 'mv', md5(string_agg(x::text, ',' ORDER BY x::text)) FROM memory_verses x WHERE user_id IN (SELECT o FROM ids)
UNION ALL SELECT 'dvs', md5(string_agg(x::text, ',' ORDER BY x::text)) FROM daily_verse_streaks x WHERE user_id IN (SELECT o FROM ids)
UNION ALL SELECT 'all_counts', md5(string_agg(c::text, ',')) FROM (
  SELECT count(*) c FROM user_topic_progress WHERE user_id NOT IN (SELECT g FROM ids UNION SELECT u FROM ids)
  UNION ALL SELECT count(*) FROM user_study_guides WHERE user_id NOT IN (SELECT g FROM ids UNION SELECT u FROM ids)
  UNION ALL SELECT count(*) FROM memory_verses WHERE user_id NOT IN (SELECT g FROM ids UNION SELECT u FROM ids)
  UNION ALL SELECT count(*) FROM user_achievements WHERE user_id NOT IN (SELECT g FROM ids UNION SELECT u FROM ids)
  UNION ALL SELECT sum(total_xp_earned) FROM user_learning_path_progress WHERE user_id NOT IN (SELECT g FROM ids UNION SELECT u FROM ids)
) s;

-- ── Run the merge as service_role.
SET LOCAL ROLE service_role;
CREATE TEMP TABLE r1 AS SELECT public.merge_guest_progress(g, u) AS res FROM ids;
CREATE TEMP TABLE r2 AS SELECT public.merge_guest_progress(g, u) AS res FROM ids;
RESET ROLE;

SELECT 'first' AS run, res FROM r1 UNION ALL SELECT 'second', res FROM r2;

DO $$
DECLARE i record; r1 jsonb; r2 jsonb; v record; leftover int;
BEGIN
  SELECT * INTO i FROM ids;
  SELECT res INTO r1 FROM r1; SELECT res INTO r2 FROM r2;
  ASSERT r1 = '{"topics":3,"paths":1,"guides":2,"verses":1,"achievements":1}'::jsonb, 'first counts ' || r1;
  ASSERT r2 = '{"topics":0,"paths":0,"guides":0,"verses":0,"achievements":0}'::jsonb, 'second counts ' || r2;

  -- topics
  SELECT xp_earned, completed_at < now() - interval '28 days' AS kept INTO v
  FROM user_topic_progress WHERE user_id = i.u AND topic_id = (SELECT topic_id FROM pt WHERE n = 1);
  ASSERT v.xp_earned = 30 AND v.kept, 't1 keeps the account completion';
  SELECT xp_earned, completed_at IS NOT NULL AS done, time_spent_seconds AS ts INTO v
  FROM user_topic_progress WHERE user_id = i.u AND topic_id = (SELECT topic_id FROM pt WHERE n = 3);
  ASSERT v.done AND v.xp_earned = 50 AND v.ts = 300, 't3 takes the guest completion';
  ASSERT (SELECT count(*) FROM user_topic_progress WHERE user_id = i.u) = 3, 'u has 3 topic rows';
  -- path
  SELECT total_xp_earned, topics_completed INTO v FROM user_learning_path_progress WHERE user_id = i.u;
  ASSERT v.total_xp_earned = 80, 'path xp = sum topic xp (30+50) got ' || v.total_xp_earned;
  ASSERT v.topics_completed >= 2, 'path topics_completed ' || v.topics_completed;
  -- guides
  SELECT completed_at IS NOT NULL AS done, time_spent_seconds AS ts, personal_notes AS pn INTO v
  FROM user_study_guides WHERE user_id = i.u AND study_guide_id = (SELECT id FROM sg WHERE n = 2);
  ASSERT v.done AND v.ts = 200 AND v.pn = 'mine', 'guide2 merged';
  ASSERT (SELECT is_saved FROM user_study_guides WHERE user_id = i.u AND study_guide_id = (SELECT id FROM sg WHERE n = 1)), 'guide1 moved saved';
  -- verses
  ASSERT (SELECT count(*) FROM memory_verses WHERE user_id = i.u) = 2, 'u has 2 verses';
  ASSERT (SELECT count(*) FROM review_sessions rs JOIN memory_verses mv ON mv.id = rs.memory_verse_id
          WHERE rs.user_id = i.u AND mv.user_id = i.u AND mv.verse_reference = 'Psalm 23:1') = 1, 'review moved with verse';
  -- streaks
  SELECT current_streak, longest_streak, total_views, last_activity_local_date INTO v FROM daily_verse_streaks WHERE user_id = i.u;
  ASSERT v.current_streak = 7 AND v.longest_streak = 10 AND v.total_views = 43 AND v.last_activity_local_date = current_date,
    'daily streak combined ' || row_to_json(v)::text;
  ASSERT (SELECT current_streak FROM user_study_streaks WHERE user_id = i.u) = 1, 'study streak moved';
  -- achievements
  ASSERT (SELECT count(*) FROM user_achievements WHERE user_id = i.u) = 2, 'achievements union';
  -- personalization / tokens
  ASSERT (SELECT questionnaire_completed FROM user_personalization WHERE user_id = i.u), 'personalization moved';
  ASSERT NOT EXISTS (SELECT 1 FROM user_notification_tokens WHERE user_id IN (i.g, i.u)), 'guest fcm token dropped, not moved';
  -- guest emptied
  SELECT (SELECT count(*) FROM user_topic_progress WHERE user_id = i.g)
       + (SELECT count(*) FROM user_learning_path_progress WHERE user_id = i.g)
       + (SELECT count(*) FROM user_study_guides WHERE user_id = i.g)
       + (SELECT count(*) FROM memory_verses WHERE user_id = i.g)
       + (SELECT count(*) FROM review_sessions WHERE user_id = i.g)
       + (SELECT count(*) FROM daily_verse_streaks WHERE user_id = i.g)
       + (SELECT count(*) FROM user_study_streaks WHERE user_id = i.g)
       + (SELECT count(*) FROM user_achievements WHERE user_id = i.g)
       + (SELECT count(*) FROM user_personalization WHERE user_id = i.g) INTO leftover;
  ASSERT leftover = 0, 'guest rows left: ' || leftover;
  -- the auth user itself is not deleted
  ASSERT EXISTS (SELECT 1 FROM auth.users WHERE id = i.g), 'guest auth user kept';
  -- cursor: account done t1, guest done t1,t3 -> first incomplete is t2
  ASSERT (SELECT current_topic_position FROM user_learning_path_progress WHERE user_id = i.u)
       = (SELECT position FROM pt WHERE n = 2), 'cursor at t2';
  -- collection moved and still holds both verses (duplicate re-pointed to the account copy)
  ASSERT (SELECT user_id FROM memory_verse_collections WHERE id = '00000000-0000-4000-8000-0000000000e1') = i.u, 'collection moved';
  ASSERT (SELECT count(*) FROM memory_verse_collection_items ci JOIN memory_verses mv ON mv.id = ci.memory_verse_id
          WHERE ci.collection_id = '00000000-0000-4000-8000-0000000000e1' AND mv.user_id = i.u) = 2, 'collection keeps 2 verses';
  ASSERT (SELECT verse_count FROM memory_verse_collections WHERE id = '00000000-0000-4000-8000-0000000000e1') = 2, 'verse_count 2';
  RAISE NOTICE 'ALL MERGE ASSERTIONS PASSED';
END $$;

-- Other users unchanged.
CREATE TEMP TABLE after_other AS
SELECT 'utp' t, md5(string_agg(x::text, ',' ORDER BY x::text)) h FROM user_topic_progress x WHERE user_id IN (SELECT o FROM ids UNION SELECT g2 FROM ids)
UNION ALL SELECT 'ulp', md5(string_agg(x::text, ',' ORDER BY x::text)) FROM user_learning_path_progress x WHERE user_id IN (SELECT o FROM ids)
UNION ALL SELECT 'usg', md5(string_agg(x::text, ',' ORDER BY x::text)) FROM user_study_guides x WHERE user_id IN (SELECT o FROM ids)
UNION ALL SELECT 'mv', md5(string_agg(x::text, ',' ORDER BY x::text)) FROM memory_verses x WHERE user_id IN (SELECT o FROM ids)
UNION ALL SELECT 'dvs', md5(string_agg(x::text, ',' ORDER BY x::text)) FROM daily_verse_streaks x WHERE user_id IN (SELECT o FROM ids)
UNION ALL SELECT 'all_counts', md5(string_agg(c::text, ',')) FROM (
  SELECT count(*) c FROM user_topic_progress WHERE user_id NOT IN (SELECT g FROM ids UNION SELECT u FROM ids)
  UNION ALL SELECT count(*) FROM user_study_guides WHERE user_id NOT IN (SELECT g FROM ids UNION SELECT u FROM ids)
  UNION ALL SELECT count(*) FROM memory_verses WHERE user_id NOT IN (SELECT g FROM ids UNION SELECT u FROM ids)
  UNION ALL SELECT count(*) FROM user_achievements WHERE user_id NOT IN (SELECT g FROM ids UNION SELECT u FROM ids)
  UNION ALL SELECT sum(total_xp_earned) FROM user_learning_path_progress WHERE user_id NOT IN (SELECT g FROM ids UNION SELECT u FROM ids)
) s;
SELECT b.t, b.h = a.h AS unchanged FROM before_other b JOIN after_other a USING (t) ORDER BY 1;

-- Scenario 2: both enrolled in the same path (trigger + conflict path).
INSERT INTO auth.users (id, aud, role, email, is_anonymous, created_at, updated_at) VALUES
 ('00000000-0000-4000-8000-0000000000a2', 'authenticated', 'authenticated', NULL, true, now(), now()),
 ('00000000-0000-4000-8000-0000000000b2', 'authenticated', 'authenticated', 'merge-test-u2@example.invalid', false, now(), now());
INSERT INTO user_learning_path_progress (user_id, learning_path_id)
SELECT x, (SELECT path_id FROM pt LIMIT 1) FROM unnest(ARRAY['00000000-0000-4000-8000-0000000000a2','00000000-0000-4000-8000-0000000000b2']::uuid[]) x;
INSERT INTO user_topic_progress (user_id, topic_id, completed_at, xp_earned)
SELECT '00000000-0000-4000-8000-0000000000b2', topic_id, now() - interval '5 days', 50 FROM pt WHERE n = 1;
INSERT INTO user_topic_progress (user_id, topic_id, completed_at, xp_earned)
SELECT '00000000-0000-4000-8000-0000000000a2', topic_id, now(), 50 FROM pt WHERE n IN (1, 2);
SELECT 'before' s, user_id, topics_completed, total_xp_earned FROM user_learning_path_progress
WHERE user_id IN ('00000000-0000-4000-8000-0000000000a2','00000000-0000-4000-8000-0000000000b2');
SET LOCAL ROLE service_role;
SELECT public.merge_guest_progress('00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000b2') AS scenario2;
RESET ROLE;
DO $$ DECLARE v record; BEGIN
  SELECT topics_completed, total_xp_earned INTO v FROM user_learning_path_progress
  WHERE user_id = '00000000-0000-4000-8000-0000000000b2';
  ASSERT v.topics_completed = 2 AND v.total_xp_earned = 100, 'scenario2 path ' || row_to_json(v)::text;
  ASSERT (SELECT count(*) FROM user_learning_path_progress WHERE user_id = '00000000-0000-4000-8000-0000000000b2') = 1;
  ASSERT (SELECT current_topic_position FROM user_learning_path_progress WHERE user_id = '00000000-0000-4000-8000-0000000000b2')
       = (SELECT position FROM pt WHERE n = 3), 'scenario2 cursor at t3';
  RAISE NOTICE 'SCENARIO 2 PASSED';
END $$;
CREATE TEMP TABLE s2_before AS SELECT md5(string_agg(x::text, ',' ORDER BY x::text)) h FROM (
  SELECT ulp::text x FROM user_learning_path_progress ulp WHERE user_id = '00000000-0000-4000-8000-0000000000b2'
  UNION ALL SELECT utp::text FROM user_topic_progress utp WHERE user_id = '00000000-0000-4000-8000-0000000000b2') q;
SET LOCAL ROLE service_role;
SELECT public.merge_guest_progress('00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000b2') AS scenario2_rerun;
RESET ROLE;
SELECT (SELECT h FROM s2_before) = md5(string_agg(x::text, ',' ORDER BY x::text)) AS scenario2_rerun_unchanged FROM (
  SELECT ulp::text x FROM user_learning_path_progress ulp WHERE user_id = '00000000-0000-4000-8000-0000000000b2'
  UNION ALL SELECT utp::text FROM user_topic_progress utp WHERE user_id = '00000000-0000-4000-8000-0000000000b2') q;

-- Scenario 3: guest completes every visible topic of the path; account has nothing.
INSERT INTO auth.users (id, aud, role, email, is_anonymous, created_at, updated_at) VALUES
 ('00000000-0000-4000-8000-0000000000a3', 'authenticated', 'authenticated', NULL, true, now(), now()),
 ('00000000-0000-4000-8000-0000000000b3', 'authenticated', 'authenticated', 'merge-test-u3@example.invalid', false, now(), now());
INSERT INTO user_learning_path_progress (user_id, learning_path_id)
SELECT '00000000-0000-4000-8000-0000000000a3', (SELECT path_id FROM pt LIMIT 1);
INSERT INTO user_topic_progress (user_id, topic_id, completed_at, xp_earned)
SELECT '00000000-0000-4000-8000-0000000000a3', topic_id, now(), 50 FROM pt;
SET LOCAL ROLE service_role;
SELECT public.merge_guest_progress('00000000-0000-4000-8000-0000000000a3', '00000000-0000-4000-8000-0000000000b3') AS scenario3;
RESET ROLE;
DO $$ DECLARE v record; BEGIN
  SELECT current_topic_position, completed_at, total_xp_earned INTO v FROM user_learning_path_progress
  WHERE user_id = '00000000-0000-4000-8000-0000000000b3';
  ASSERT v.current_topic_position = (SELECT max(position) FROM pt), 'scenario3 cursor at last position';
  ASSERT v.completed_at IS NOT NULL, 'scenario3 path completed';
  ASSERT v.total_xp_earned = 50 * (SELECT count(*) FROM pt), 'scenario3 xp';
  RAISE NOTICE 'SCENARIO 3 PASSED';
END $$;
SHOW plpgsql.check_asserts;

-- Rejections (each in a savepoint).
SET LOCAL ROLE service_role;
SAVEPOINT s1;
DO $$ BEGIN PERFORM public.merge_guest_progress((SELECT u FROM ids), (SELECT o FROM ids));
  RAISE EXCEPTION 'FAIL: full account accepted as guest'; EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM = 'merge_guest:not_anonymous'; RAISE NOTICE 'ok: non-guest source rejected'; END $$;
DO $$ BEGIN PERFORM public.merge_guest_progress((SELECT g2 FROM ids), (SELECT g FROM ids));
  RAISE EXCEPTION 'FAIL: guest accepted as target'; EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM = 'merge_guest:target_not_full'; RAISE NOTICE 'ok: guest target rejected'; END $$;
DO $$ BEGIN PERFORM public.merge_guest_progress((SELECT g FROM ids), (SELECT g FROM ids));
  RAISE EXCEPTION 'FAIL: same id accepted'; EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM = 'merge_guest:invalid_pair'; RAISE NOTICE 'ok: same id rejected'; END $$;
DO $$ BEGIN PERFORM public.merge_guest_progress(gen_random_uuid(), (SELECT u FROM ids));
  RAISE EXCEPTION 'FAIL: unknown guest accepted'; EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM = 'merge_guest:not_anonymous'; RAISE NOTICE 'ok: unknown guest rejected'; END $$;
RESET ROLE;
-- A guest upgraded to a full account (is_anonymous=false) is rejected.
UPDATE auth.users SET is_anonymous = false WHERE id = (SELECT g2 FROM ids);
SET LOCAL ROLE service_role;
DO $$ BEGIN PERFORM public.merge_guest_progress((SELECT g2 FROM ids), (SELECT u FROM ids));
  RAISE EXCEPTION 'FAIL: upgraded guest accepted'; EXCEPTION WHEN raise_exception THEN ASSERT SQLERRM = 'merge_guest:not_anonymous'; RAISE NOTICE 'ok: upgraded guest rejected'; END $$;
RESET ROLE;

-- anon / authenticated cannot call it.
DO $$ BEGIN
  ASSERT NOT has_function_privilege('anon', 'public.merge_guest_progress(uuid, uuid)', 'EXECUTE'), 'anon can execute';
  ASSERT NOT has_function_privilege('authenticated', 'public.merge_guest_progress(uuid, uuid)', 'EXECUTE'), 'authenticated can execute';
  ASSERT NOT has_function_privilege('authenticated', 'public.merged_streak_length(integer, date, integer, date)', 'EXECUTE'), 'authenticated can execute streak helper';
END $$;
SET LOCAL ROLE authenticated;
DO $$ BEGIN PERFORM public.merge_guest_progress((SELECT g FROM ids), (SELECT u FROM ids));
  RAISE EXCEPTION 'FAIL: authenticated could execute'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok: authenticated denied'; END $$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $$ BEGIN PERFORM public.merge_guest_progress((SELECT g FROM ids), (SELECT u FROM ids));
  RAISE EXCEPTION 'FAIL: anon could execute'; EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'ok: anon denied'; END $$;
RESET ROLE;

-- Streak helper cases.
SELECT public.merged_streak_length(5, current_date - 2, 2, current_date) = 7 AS touch,
       public.merged_streak_length(5, current_date - 3, 2, current_date) = 2 AS gap,
       public.merged_streak_length(5, current_date, 3, current_date - 1) = 5 AS overlap_inside,
       public.merged_streak_length(3, current_date - 1, 3, current_date) = 4 AS overlap,
       public.merged_streak_length(0, NULL, 4, current_date) = 4 AS one_empty,
       public.merged_streak_length(0, NULL, 0, NULL) = 0 AS both_empty,
       public.merged_streak_length(6, NULL, 2, NULL) = 6 AS no_dates;

ROLLBACK;
