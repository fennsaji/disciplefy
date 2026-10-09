-- Merge a guest's progress into an existing full account.
--
-- A guest (Supabase anonymous user) who later signs in to an account that
-- already exists gets a different auth user id. The user-profile edge
-- function (action=merge_guest) verifies the guest's access token and then
-- calls merge_guest_progress(guest, account) with the service role.
--
-- Per table (everything a guest can create in a first run):
--   MOVE / MERGE
--     user_topic_progress          union; same topic: the account's completion
--                                  stays as is; an account row that is not yet
--                                  completed takes the guest's completion and
--                                  its xp_earned; started_at earliest,
--                                  time_spent the larger.
--     user_learning_path_progress  union; same path: the more advanced values
--                                  (GREATEST counters/cursor, earliest
--                                  enrolled/completed, latest activity).
--                                  Afterwards total_xp_earned is recomputed
--                                  as the sum of the topic XP of the path's
--                                  completed topics (rule of 20261006160000),
--                                  topics_completed is floored at the visible
--                                  completed count, the cursor moves to the
--                                  first visible topic not yet completed (the
--                                  last visible one when all are done), and a
--                                  path whose visible topics are all done is
--                                  marked completed.
--     user_study_guides            union; same guide: saved/scrolled OR,
--                                  earliest completion, larger time, the
--                                  account's notes win.
--     study_reflections, recommended_guide_sessions   moved.
--     study_guide_conversations    moved unless the account already has a
--                                  conversation on that guide (then the
--                                  guest's is dropped).
--     study_guides.creator_user_id re-attributed to the account.
--     memory_verses (+ review_sessions, review_history, memory_verse_mastery,
--       memory_practice_modes, daily_unlocked_modes)  moved; a verse the
--                                  account already has (same reference and
--                                  language) keeps the account's copy and the
--                                  guest's duplicate is dropped with its
--                                  history (guest collections holding it are
--                                  re-pointed to the account's copy).
--     memory_verse_collections     moved (items follow their collection).
--     memory_daily_goals, user_challenge_progress     union; same key: counters
--                                  summed / GREATEST, flags OR.
--     daily_verse_streaks, user_study_streaks, memory_verse_streaks
--                                  moved if the account has none; otherwise the
--                                  two streak runs are combined (see
--                                  merged_streak_length), longest = max.
--     user_achievements            union (XP = topic XP + achievement XP, so
--                                  each achievement counts once).
--     user_personalization         moved if the account has none, or replaces
--                                  an account questionnaire that was not
--                                  completed.
--     user_preferences, user_notification_preferences  moved if the account has
--                                  none; otherwise the account's are kept.
--   DROP (guest rows deleted, nothing moved)
--     user_notification_tokens     the device registers its token for the
--                                  signed-in account; pushes for the guest stop.
--   IGNORED (stay with the guest id; removed when the anonymous auth user is
--   deleted, which is not done here)
--     user_profiles; credits/tokens, subscriptions and purchases (never
--     transferred); analytics_events, usage_logs, token_usage_history,
--     llm_security_events, notification_logs, notification_push_queue,
--     feedback, study_guides_in_progress (transient); voice_*, fellowship_*,
--     user_blocks, discipler_* (closed to guests).
--
-- Idempotent: every guest row that is merged is deleted or re-owned in the
-- same transaction, so a second call finds nothing and returns zero counts.
-- Merged tables are drained with DELETE ... RETURNING feeding the INSERT in a
-- single statement, so a guest row written concurrently is never deleted
-- without being carried over.
-- Errors: P0001 with message 'merge_guest:not_anonymous' (guest unknown,
-- deleted or upgraded: the edge function's GUEST_TOKEN_INVALID),
-- 'merge_guest:invalid_pair', 'merge_guest:target_not_full'.
-- Atomic: one function call = one transaction. Two merges for the same guest
-- or into the same account are serialised with transaction advisory locks.
--
-- Security: SECURITY DEFINER (writes rows of two users, bypassing RLS),
-- search_path = public, pg_temp (trigger functions it fires need public) with
-- schema-qualified names in the body, EXECUTE for service_role only.
-- The function itself re-checks in auth.users that p_guest is a live anonymous
-- user and p_user a live full account, so a guest token whose user has since
-- been upgraded to a full account cannot be merged away.

CREATE OR REPLACE FUNCTION public.merged_streak_length(
  p_a_current integer, p_a_last date,
  p_b_current integer, p_b_last date
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  -- Each streak is a run of consecutive days ending on its last day. The
  -- merged current streak is the most recent run, extended by the other run
  -- when the two touch or overlap.
  WITH runs AS (
    SELECT COALESCE(p_a_current, 0) AS cur, p_a_last AS last_day
    UNION ALL
    SELECT COALESCE(p_b_current, 0), p_b_last
  ),
  live AS (
    SELECT cur, last_day, last_day - cur + 1 AS first_day
    FROM runs
    WHERE cur > 0 AND last_day IS NOT NULL
  ),
  recent AS (
    SELECT * FROM live ORDER BY last_day DESC, cur DESC LIMIT 1
  )
  SELECT COALESCE(
    (SELECT r.last_day - LEAST(
              r.first_day,
              COALESCE((SELECT MIN(o.first_day) FROM live o
                         WHERE o.last_day >= r.first_day - 1), r.first_day)
            ) + 1
       FROM recent r),
    GREATEST(COALESCE(p_a_current, 0), COALESCE(p_b_current, 0))
  );
$$;

COMMENT ON FUNCTION public.merged_streak_length(integer, date, integer, date) IS
  'Current streak after combining two streak runs (current length + last day '
  'each): the most recent run, extended by the other when they touch.';

REVOKE ALL ON FUNCTION public.merged_streak_length(integer, date, integer, date) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.merged_streak_length(integer, date, integer, date) TO service_role;

CREATE OR REPLACE FUNCTION public.merge_guest_progress(p_guest uuid, p_user uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
-- Not '': row triggers fired by these writes (e.g. update_collection_verse_count)
-- use unqualified names and inherit this setting. pg_temp is listed last so
-- temporary objects can never shadow public ones.
SET search_path = public, pg_temp
AS $$
DECLARE
  v_topics integer := 0;
  v_paths integer := 0;
  v_guides integer := 0;
  v_verses integer := 0;
  v_achievements integer := 0;
  v_topic_ids uuid[];
  v_path_ids uuid[];
BEGIN
  IF p_guest IS NULL OR p_user IS NULL OR p_guest = p_user THEN
    RAISE EXCEPTION 'merge_guest:invalid_pair' USING ERRCODE = 'P0001';
  END IF;

  -- Serialise merges touching either user (consistent order: no deadlock).
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('merge_guest_progress:' || LEAST(p_guest, p_user)::text, 0));
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('merge_guest_progress:' || GREATEST(p_guest, p_user)::text, 0));

  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = p_guest AND u.is_anonymous IS TRUE AND u.deleted_at IS NULL
  ) THEN
    -- The one error the edge function reports to the client (400
    -- GUEST_TOKEN_INVALID): unknown, deleted or since-upgraded guest.
    RAISE EXCEPTION 'merge_guest:not_anonymous' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = p_user AND u.is_anonymous IS NOT TRUE AND u.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'merge_guest:target_not_full' USING ERRCODE = 'P0001';
  END IF;

  SELECT COALESCE(array_agg(t.topic_id), '{}') INTO v_topic_ids
  FROM public.user_topic_progress t WHERE t.user_id = p_guest;
  SELECT COALESCE(array_agg(p.learning_path_id), '{}') INTO v_path_ids
  FROM public.user_learning_path_progress p WHERE p.user_id = p_guest;

  -- ── Topic progress (before paths: the completion trigger then credits the
  --    account's existing enrolments exactly as a normal completion would).
  --    Each guest table is drained with DELETE ... RETURNING feeding the
  --    INSERT in one statement, so a guest row committed meanwhile is either
  --    carried over or left for the next run, never deleted unmerged.
  WITH g AS (DELETE FROM public.user_topic_progress WHERE user_id = p_guest RETURNING *)
  INSERT INTO public.user_topic_progress AS a
    (user_id, topic_id, started_at, completed_at, time_spent_seconds, xp_earned)
  SELECT p_user, g.topic_id, g.started_at, g.completed_at, g.time_spent_seconds, g.xp_earned
  FROM g
  ON CONFLICT (user_id, topic_id) DO UPDATE SET
    started_at = LEAST(a.started_at, EXCLUDED.started_at),
    completed_at = COALESCE(a.completed_at, EXCLUDED.completed_at),
    xp_earned = CASE
      WHEN a.completed_at IS NULL AND EXCLUDED.completed_at IS NOT NULL THEN EXCLUDED.xp_earned
      ELSE a.xp_earned
    END,
    time_spent_seconds = GREATEST(a.time_spent_seconds, EXCLUDED.time_spent_seconds),
    updated_at = now();
  GET DIAGNOSTICS v_topics = ROW_COUNT;

  -- ── Path enrolments.
  WITH g AS (DELETE FROM public.user_learning_path_progress WHERE user_id = p_guest RETURNING *)
  INSERT INTO public.user_learning_path_progress AS a
    (user_id, learning_path_id, enrolled_at, topics_completed, current_topic_position,
     total_xp_earned, completed_at, last_activity_at)
  SELECT p_user, g.learning_path_id, g.enrolled_at, g.topics_completed, g.current_topic_position,
         g.total_xp_earned, g.completed_at, g.last_activity_at
  FROM g
  ON CONFLICT (user_id, learning_path_id) DO UPDATE SET
    enrolled_at = LEAST(a.enrolled_at, EXCLUDED.enrolled_at),
    topics_completed = GREATEST(a.topics_completed, EXCLUDED.topics_completed),
    current_topic_position = GREATEST(a.current_topic_position, EXCLUDED.current_topic_position),
    completed_at = LEAST(a.completed_at, EXCLUDED.completed_at),
    last_activity_at = GREATEST(a.last_activity_at, EXCLUDED.last_activity_at);
  GET DIAGNOSTICS v_paths = ROW_COUNT;

  -- Recompute the account's affected path rows from its topic rows.
  WITH affected AS (
    SELECT ulp.id, ulp.learning_path_id
    FROM public.user_learning_path_progress ulp
    WHERE ulp.user_id = p_user
      AND (ulp.learning_path_id = ANY (v_path_ids)
           OR EXISTS (SELECT 1 FROM public.learning_path_topics l
                      WHERE l.learning_path_id = ulp.learning_path_id
                        AND l.topic_id = ANY (v_topic_ids)))
  ),
  stats AS (
    SELECT af.id,
           COALESCE(SUM(utp.xp_earned) FILTER (WHERE utp.completed_at IS NOT NULL), 0)::integer AS xp,
           COUNT(*) FILTER (WHERE lpt.is_active AND rt.is_active AND utp.completed_at IS NOT NULL)::integer AS visible_done,
           COUNT(*) FILTER (WHERE lpt.is_active AND rt.is_active)::integer AS visible_total,
           -- Resume cursor: first visible topic not completed (never-started
           -- topics come through the LEFT JOIN as incomplete); when all are
           -- done it stays on the last visible topic, as the trigger leaves it.
           MIN(lpt.position) FILTER (WHERE lpt.is_active AND rt.is_active AND utp.completed_at IS NULL) AS next_pos,
           MAX(lpt.position) FILTER (WHERE lpt.is_active AND rt.is_active) AS last_pos
    FROM affected af
    JOIN public.learning_path_topics lpt ON lpt.learning_path_id = af.learning_path_id
    JOIN public.recommended_topics rt ON rt.id = lpt.topic_id
    LEFT JOIN public.user_topic_progress utp
      ON utp.topic_id = lpt.topic_id AND utp.user_id = p_user
    GROUP BY af.id
  )
  UPDATE public.user_learning_path_progress ulp
  SET total_xp_earned = s.xp,
      topics_completed = GREATEST(ulp.topics_completed, s.visible_done),
      current_topic_position = COALESCE(s.next_pos, s.last_pos, ulp.current_topic_position),
      completed_at = CASE
        WHEN s.visible_total > 0 AND s.visible_done >= s.visible_total
          THEN COALESCE(ulp.completed_at, now())
        ELSE ulp.completed_at
      END
  FROM stats s
  WHERE s.id = ulp.id
    AND (ulp.total_xp_earned IS DISTINCT FROM s.xp
         OR ulp.topics_completed < s.visible_done
         OR ulp.current_topic_position IS DISTINCT FROM COALESCE(s.next_pos, s.last_pos, ulp.current_topic_position)
         OR (ulp.completed_at IS NULL AND s.visible_total > 0 AND s.visible_done >= s.visible_total));

  -- ── Study guides.
  WITH g AS (DELETE FROM public.user_study_guides WHERE user_id = p_guest RETURNING *)
  INSERT INTO public.user_study_guides AS a
    (user_id, study_guide_id, is_saved, completed_at, time_spent_seconds, scrolled_to_bottom,
     personal_notes, created_at, continue_reminder_count, last_continue_reminder_at)
  SELECT p_user, g.study_guide_id, g.is_saved, g.completed_at, g.time_spent_seconds,
         g.scrolled_to_bottom, g.personal_notes, g.created_at, g.continue_reminder_count,
         g.last_continue_reminder_at
  FROM g
  ON CONFLICT (user_id, study_guide_id) DO UPDATE SET
    is_saved = a.is_saved OR EXCLUDED.is_saved,
    completed_at = LEAST(a.completed_at, EXCLUDED.completed_at),
    time_spent_seconds = GREATEST(a.time_spent_seconds, EXCLUDED.time_spent_seconds),
    scrolled_to_bottom = a.scrolled_to_bottom OR EXCLUDED.scrolled_to_bottom,
    personal_notes = COALESCE(a.personal_notes, EXCLUDED.personal_notes),
    updated_at = now();
  GET DIAGNOSTICS v_guides = ROW_COUNT;

  UPDATE public.study_reflections SET user_id = p_user WHERE user_id = p_guest;
  UPDATE public.recommended_guide_sessions SET user_id = p_user WHERE user_id = p_guest;

  UPDATE public.study_guide_conversations c SET user_id = p_user
  WHERE c.user_id = p_guest
    AND NOT EXISTS (SELECT 1 FROM public.study_guide_conversations x
                    WHERE x.user_id = p_user AND x.study_guide_id = c.study_guide_id);
  DELETE FROM public.study_guide_conversations c
  WHERE c.user_id = p_guest
    AND EXISTS (SELECT 1 FROM public.study_guide_conversations x
                WHERE x.user_id = p_user AND x.study_guide_id = c.study_guide_id);

  UPDATE public.study_guides SET creator_user_id = p_user WHERE creator_user_id = p_guest;

  -- ── Memory verses: drop the guest's duplicates, then move the rest with
  --    their per-verse history. A guest collection that holds a duplicate is
  --    pointed at the account's copy first, so it keeps the verse.
  INSERT INTO public.memory_verse_collection_items (collection_id, memory_verse_id, added_at)
  SELECT ci.collection_id, a.id, ci.added_at
  FROM public.memory_verse_collection_items ci
  JOIN public.memory_verses g ON g.id = ci.memory_verse_id AND g.user_id = p_guest
  JOIN public.memory_verses a
    ON a.user_id = p_user AND a.verse_reference = g.verse_reference AND a.language = g.language
  ON CONFLICT DO NOTHING;
  DELETE FROM public.memory_verses g
  WHERE g.user_id = p_guest
    AND EXISTS (SELECT 1 FROM public.memory_verses a
                WHERE a.user_id = p_user
                  AND a.verse_reference = g.verse_reference
                  AND a.language = g.language);
  UPDATE public.memory_verses SET user_id = p_user WHERE user_id = p_guest;
  GET DIAGNOSTICS v_verses = ROW_COUNT;

  UPDATE public.review_sessions SET user_id = p_user WHERE user_id = p_guest;
  UPDATE public.review_history SET user_id = p_user WHERE user_id = p_guest;
  UPDATE public.memory_verse_mastery SET user_id = p_user WHERE user_id = p_guest;
  UPDATE public.memory_practice_modes SET user_id = p_user WHERE user_id = p_guest;
  UPDATE public.daily_unlocked_modes SET user_id = p_user WHERE user_id = p_guest;
  UPDATE public.memory_verse_collections SET user_id = p_user WHERE user_id = p_guest;

  WITH g AS (DELETE FROM public.memory_daily_goals WHERE user_id = p_guest RETURNING *)
  INSERT INTO public.memory_daily_goals AS a
    (user_id, goal_date, target_reviews, completed_reviews, target_new_verses,
     added_new_verses, goal_achieved, bonus_xp_awarded, created_at)
  SELECT p_user, g.goal_date, g.target_reviews, g.completed_reviews, g.target_new_verses,
         g.added_new_verses, g.goal_achieved, g.bonus_xp_awarded, g.created_at
  FROM g
  ON CONFLICT (user_id, goal_date) DO UPDATE SET
    completed_reviews = a.completed_reviews + EXCLUDED.completed_reviews,
    added_new_verses = a.added_new_verses + EXCLUDED.added_new_verses,
    goal_achieved = a.goal_achieved OR EXCLUDED.goal_achieved,
    bonus_xp_awarded = GREATEST(a.bonus_xp_awarded, EXCLUDED.bonus_xp_awarded);

  WITH g AS (DELETE FROM public.user_challenge_progress WHERE user_id = p_guest RETURNING *)
  INSERT INTO public.user_challenge_progress AS a
    (user_id, challenge_id, current_progress, is_completed, completed_at, xp_claimed)
  SELECT p_user, g.challenge_id, g.current_progress, g.is_completed, g.completed_at, g.xp_claimed
  FROM g
  ON CONFLICT (user_id, challenge_id) DO UPDATE SET
    current_progress = GREATEST(a.current_progress, EXCLUDED.current_progress),
    is_completed = a.is_completed OR EXCLUDED.is_completed,
    completed_at = LEAST(a.completed_at, EXCLUDED.completed_at),
    xp_claimed = a.xp_claimed OR EXCLUDED.xp_claimed;

  -- ── Streaks: moved when the account has none, otherwise combined.
  WITH g AS (DELETE FROM public.daily_verse_streaks WHERE user_id = p_guest RETURNING *)
  INSERT INTO public.daily_verse_streaks AS a
    (user_id, current_streak, longest_streak, last_viewed_at, total_views, created_at,
     last_activity_local_date)
  SELECT p_user, g.current_streak, g.longest_streak, g.last_viewed_at, g.total_views, g.created_at,
         g.last_activity_local_date
  FROM g
  ON CONFLICT (user_id) DO UPDATE SET
    current_streak = public.merged_streak_length(
      a.current_streak, COALESCE(a.last_activity_local_date, a.last_viewed_at::date),
      EXCLUDED.current_streak, COALESCE(EXCLUDED.last_activity_local_date, EXCLUDED.last_viewed_at::date)),
    longest_streak = GREATEST(a.longest_streak, EXCLUDED.longest_streak, public.merged_streak_length(
      a.current_streak, COALESCE(a.last_activity_local_date, a.last_viewed_at::date),
      EXCLUDED.current_streak, COALESCE(EXCLUDED.last_activity_local_date, EXCLUDED.last_viewed_at::date))),
    total_views = a.total_views + EXCLUDED.total_views,
    last_viewed_at = GREATEST(a.last_viewed_at, EXCLUDED.last_viewed_at),
    last_activity_local_date = GREATEST(a.last_activity_local_date, EXCLUDED.last_activity_local_date),
    updated_at = now();

  WITH g AS (DELETE FROM public.user_study_streaks WHERE user_id = p_guest RETURNING *)
  INSERT INTO public.user_study_streaks AS a
    (user_id, current_streak, longest_streak, last_study_date, total_study_days, created_at)
  SELECT p_user, g.current_streak, g.longest_streak, g.last_study_date, g.total_study_days, g.created_at
  FROM g
  ON CONFLICT (user_id) DO UPDATE SET
    current_streak = public.merged_streak_length(
      a.current_streak, a.last_study_date, EXCLUDED.current_streak, EXCLUDED.last_study_date),
    longest_streak = GREATEST(a.longest_streak, EXCLUDED.longest_streak, public.merged_streak_length(
      a.current_streak, a.last_study_date, EXCLUDED.current_streak, EXCLUDED.last_study_date)),
    last_study_date = GREATEST(a.last_study_date, EXCLUDED.last_study_date),
    total_study_days = GREATEST(a.total_study_days, EXCLUDED.total_study_days);

  WITH g AS (DELETE FROM public.memory_verse_streaks WHERE user_id = p_guest RETURNING *)
  INSERT INTO public.memory_verse_streaks AS a
    (user_id, current_streak, longest_streak, last_practice_date, total_practice_days,
     freeze_days_available, freeze_days_used, milestone_10_date, milestone_30_date,
     milestone_100_date, milestone_365_date, created_at)
  SELECT p_user, g.current_streak, g.longest_streak, g.last_practice_date, g.total_practice_days,
         g.freeze_days_available, g.freeze_days_used, g.milestone_10_date, g.milestone_30_date,
         g.milestone_100_date, g.milestone_365_date, g.created_at
  FROM g
  ON CONFLICT (user_id) DO UPDATE SET
    current_streak = public.merged_streak_length(
      a.current_streak, a.last_practice_date, EXCLUDED.current_streak, EXCLUDED.last_practice_date),
    longest_streak = GREATEST(a.longest_streak, EXCLUDED.longest_streak, public.merged_streak_length(
      a.current_streak, a.last_practice_date, EXCLUDED.current_streak, EXCLUDED.last_practice_date)),
    last_practice_date = GREATEST(a.last_practice_date, EXCLUDED.last_practice_date),
    total_practice_days = GREATEST(a.total_practice_days, EXCLUDED.total_practice_days),
    milestone_10_date = LEAST(a.milestone_10_date, EXCLUDED.milestone_10_date),
    milestone_30_date = LEAST(a.milestone_30_date, EXCLUDED.milestone_30_date),
    milestone_100_date = LEAST(a.milestone_100_date, EXCLUDED.milestone_100_date),
    milestone_365_date = LEAST(a.milestone_365_date, EXCLUDED.milestone_365_date),
    updated_at = now();

  -- ── Achievements.
  WITH g AS (DELETE FROM public.user_achievements WHERE user_id = p_guest RETURNING *)
  INSERT INTO public.user_achievements (user_id, achievement_id, unlocked_at, notified)
  SELECT p_user, g.achievement_id, g.unlocked_at, g.notified
  FROM g
  ON CONFLICT ON CONSTRAINT unique_user_achievement DO NOTHING;
  GET DIAGNOSTICS v_achievements = ROW_COUNT;

  -- ── Questionnaire and preferences.
  WITH g AS (DELETE FROM public.user_personalization WHERE user_id = p_guest RETURNING *)
  INSERT INTO public.user_personalization AS a
    (user_id, faith_stage, spiritual_goals, time_availability, learning_style, life_stage_focus,
     biggest_challenge, questionnaire_completed, questionnaire_skipped, scoring_results, created_at)
  SELECT p_user, g.faith_stage, g.spiritual_goals, g.time_availability, g.learning_style,
         g.life_stage_focus, g.biggest_challenge, g.questionnaire_completed,
         g.questionnaire_skipped, g.scoring_results, g.created_at
  FROM g
  ON CONFLICT (user_id) DO UPDATE SET
    faith_stage = EXCLUDED.faith_stage,
    spiritual_goals = EXCLUDED.spiritual_goals,
    time_availability = EXCLUDED.time_availability,
    learning_style = EXCLUDED.learning_style,
    life_stage_focus = EXCLUDED.life_stage_focus,
    biggest_challenge = EXCLUDED.biggest_challenge,
    questionnaire_completed = EXCLUDED.questionnaire_completed,
    questionnaire_skipped = EXCLUDED.questionnaire_skipped,
    scoring_results = EXCLUDED.scoring_results,
    updated_at = now()
  WHERE a.questionnaire_completed IS NOT TRUE AND EXCLUDED.questionnaire_completed IS TRUE;

  -- Preferences: the account's win; a guest row is moved only when the account
  -- has none (so deleting what is left drops only rows the account overrides).
  UPDATE public.user_preferences g SET user_id = p_user
  WHERE g.user_id = p_guest
    AND NOT EXISTS (SELECT 1 FROM public.user_preferences a WHERE a.user_id = p_user);
  DELETE FROM public.user_preferences WHERE user_id = p_guest;

  UPDATE public.user_notification_preferences g SET user_id = p_user
  WHERE g.user_id = p_guest
    AND NOT EXISTS (SELECT 1 FROM public.user_notification_preferences a WHERE a.user_id = p_user);
  DELETE FROM public.user_notification_preferences WHERE user_id = p_guest;

  DELETE FROM public.user_notification_tokens WHERE user_id = p_guest;

  RETURN jsonb_build_object(
    'topics', v_topics,
    'paths', v_paths,
    'guides', v_guides,
    'verses', v_verses,
    'achievements', v_achievements
  );
END;
$$;

COMMENT ON FUNCTION public.merge_guest_progress(uuid, uuid) IS
  'Moves/merges an anonymous guest''s progress into a full account. Idempotent '
  '(guest rows are re-owned or deleted). Returns counts of guest rows carried '
  'over: {topics, paths, guides, verses, achievements}. Service role only.';

REVOKE ALL ON FUNCTION public.merge_guest_progress(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.merge_guest_progress(uuid, uuid) TO service_role;
