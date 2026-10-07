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
--                                  completed count, and a path whose visible
--                                  topics are all done is marked completed.
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
--                                  history.
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
-- Atomic: one function call = one transaction. Two merges for the same guest
-- or into the same account are serialised with transaction advisory locks.
--
-- Security: SECURITY DEFINER (writes rows of two users, bypassing RLS),
-- search_path = '' with schema-qualified names, EXECUTE for service_role only.
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
SET search_path = ''
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
    RAISE EXCEPTION 'merge_guest_progress: invalid guest/user pair' USING ERRCODE = '22023';
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
    RAISE EXCEPTION 'merge_guest_progress: source is not a guest' USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = p_user AND u.is_anonymous IS NOT TRUE AND u.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'merge_guest_progress: target is not a full account' USING ERRCODE = '22023';
  END IF;

  SELECT COALESCE(array_agg(t.topic_id), '{}') INTO v_topic_ids
  FROM public.user_topic_progress t WHERE t.user_id = p_guest;
  SELECT COALESCE(array_agg(p.learning_path_id), '{}') INTO v_path_ids
  FROM public.user_learning_path_progress p WHERE p.user_id = p_guest;

  -- ── Topic progress (before paths: the completion trigger then credits the
  --    account's existing enrolments exactly as a normal completion would).
  INSERT INTO public.user_topic_progress AS a
    (user_id, topic_id, started_at, completed_at, time_spent_seconds, xp_earned)
  SELECT p_user, g.topic_id, g.started_at, g.completed_at, g.time_spent_seconds, g.xp_earned
  FROM public.user_topic_progress g
  WHERE g.user_id = p_guest
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
  DELETE FROM public.user_topic_progress WHERE user_id = p_guest;

  -- ── Path enrolments.
  INSERT INTO public.user_learning_path_progress AS a
    (user_id, learning_path_id, enrolled_at, topics_completed, current_topic_position,
     total_xp_earned, completed_at, last_activity_at)
  SELECT p_user, g.learning_path_id, g.enrolled_at, g.topics_completed, g.current_topic_position,
         g.total_xp_earned, g.completed_at, g.last_activity_at
  FROM public.user_learning_path_progress g
  WHERE g.user_id = p_guest
  ON CONFLICT (user_id, learning_path_id) DO UPDATE SET
    enrolled_at = LEAST(a.enrolled_at, EXCLUDED.enrolled_at),
    topics_completed = GREATEST(a.topics_completed, EXCLUDED.topics_completed),
    current_topic_position = GREATEST(a.current_topic_position, EXCLUDED.current_topic_position),
    completed_at = LEAST(a.completed_at, EXCLUDED.completed_at),
    last_activity_at = GREATEST(a.last_activity_at, EXCLUDED.last_activity_at);
  GET DIAGNOSTICS v_paths = ROW_COUNT;
  DELETE FROM public.user_learning_path_progress WHERE user_id = p_guest;

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
           COUNT(*) FILTER (WHERE lpt.is_active AND rt.is_active)::integer AS visible_total
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
      completed_at = CASE
        WHEN s.visible_total > 0 AND s.visible_done >= s.visible_total
          THEN COALESCE(ulp.completed_at, now())
        ELSE ulp.completed_at
      END
  FROM stats s
  WHERE s.id = ulp.id
    AND (ulp.total_xp_earned IS DISTINCT FROM s.xp
         OR ulp.topics_completed < s.visible_done
         OR (ulp.completed_at IS NULL AND s.visible_total > 0 AND s.visible_done >= s.visible_total));

  -- ── Study guides.
  INSERT INTO public.user_study_guides AS a
    (user_id, study_guide_id, is_saved, completed_at, time_spent_seconds, scrolled_to_bottom,
     personal_notes, created_at, continue_reminder_count, last_continue_reminder_at)
  SELECT p_user, g.study_guide_id, g.is_saved, g.completed_at, g.time_spent_seconds,
         g.scrolled_to_bottom, g.personal_notes, g.created_at, g.continue_reminder_count,
         g.last_continue_reminder_at
  FROM public.user_study_guides g
  WHERE g.user_id = p_guest
  ON CONFLICT (user_id, study_guide_id) DO UPDATE SET
    is_saved = a.is_saved OR EXCLUDED.is_saved,
    completed_at = LEAST(a.completed_at, EXCLUDED.completed_at),
    time_spent_seconds = GREATEST(a.time_spent_seconds, EXCLUDED.time_spent_seconds),
    scrolled_to_bottom = a.scrolled_to_bottom OR EXCLUDED.scrolled_to_bottom,
    personal_notes = COALESCE(a.personal_notes, EXCLUDED.personal_notes),
    updated_at = now();
  GET DIAGNOSTICS v_guides = ROW_COUNT;
  DELETE FROM public.user_study_guides WHERE user_id = p_guest;

  UPDATE public.study_reflections SET user_id = p_user WHERE user_id = p_guest;
  UPDATE public.recommended_guide_sessions SET user_id = p_user WHERE user_id = p_guest;

  UPDATE public.study_guide_conversations c SET user_id = p_user
  WHERE c.user_id = p_guest
    AND NOT EXISTS (SELECT 1 FROM public.study_guide_conversations x
                    WHERE x.user_id = p_user AND x.study_guide_id = c.study_guide_id);
  DELETE FROM public.study_guide_conversations WHERE user_id = p_guest;

  UPDATE public.study_guides SET creator_user_id = p_user WHERE creator_user_id = p_guest;

  -- ── Memory verses: drop the guest's duplicates, then move the rest with
  --    their per-verse history.
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

  INSERT INTO public.memory_daily_goals AS a
    (user_id, goal_date, target_reviews, completed_reviews, target_new_verses,
     added_new_verses, goal_achieved, bonus_xp_awarded, created_at)
  SELECT p_user, g.goal_date, g.target_reviews, g.completed_reviews, g.target_new_verses,
         g.added_new_verses, g.goal_achieved, g.bonus_xp_awarded, g.created_at
  FROM public.memory_daily_goals g
  WHERE g.user_id = p_guest
  ON CONFLICT (user_id, goal_date) DO UPDATE SET
    completed_reviews = a.completed_reviews + EXCLUDED.completed_reviews,
    added_new_verses = a.added_new_verses + EXCLUDED.added_new_verses,
    goal_achieved = a.goal_achieved OR EXCLUDED.goal_achieved,
    bonus_xp_awarded = GREATEST(a.bonus_xp_awarded, EXCLUDED.bonus_xp_awarded);
  DELETE FROM public.memory_daily_goals WHERE user_id = p_guest;

  INSERT INTO public.user_challenge_progress AS a
    (user_id, challenge_id, current_progress, is_completed, completed_at, xp_claimed)
  SELECT p_user, g.challenge_id, g.current_progress, g.is_completed, g.completed_at, g.xp_claimed
  FROM public.user_challenge_progress g
  WHERE g.user_id = p_guest
  ON CONFLICT (user_id, challenge_id) DO UPDATE SET
    current_progress = GREATEST(a.current_progress, EXCLUDED.current_progress),
    is_completed = a.is_completed OR EXCLUDED.is_completed,
    completed_at = LEAST(a.completed_at, EXCLUDED.completed_at),
    xp_claimed = a.xp_claimed OR EXCLUDED.xp_claimed;
  DELETE FROM public.user_challenge_progress WHERE user_id = p_guest;

  -- ── Streaks: move when the account has none, otherwise combine.
  UPDATE public.daily_verse_streaks g SET user_id = p_user
  WHERE g.user_id = p_guest
    AND NOT EXISTS (SELECT 1 FROM public.daily_verse_streaks a WHERE a.user_id = p_user);
  UPDATE public.daily_verse_streaks a SET
    current_streak = g.cur,
    longest_streak = GREATEST(a.longest_streak, g.longest_streak, g.cur),
    total_views = a.total_views + g.total_views,
    last_viewed_at = GREATEST(a.last_viewed_at, g.last_viewed_at),
    last_activity_local_date = GREATEST(a.last_activity_local_date, g.last_activity_local_date),
    updated_at = now()
  FROM (
    SELECT g0.*, public.merged_streak_length(
             a0.current_streak, COALESCE(a0.last_activity_local_date, a0.last_viewed_at::date),
             g0.current_streak, COALESCE(g0.last_activity_local_date, g0.last_viewed_at::date)) AS cur
    FROM public.daily_verse_streaks g0
    JOIN public.daily_verse_streaks a0 ON a0.user_id = p_user
    WHERE g0.user_id = p_guest
  ) g
  WHERE a.user_id = p_user;
  DELETE FROM public.daily_verse_streaks WHERE user_id = p_guest;

  UPDATE public.user_study_streaks g SET user_id = p_user
  WHERE g.user_id = p_guest
    AND NOT EXISTS (SELECT 1 FROM public.user_study_streaks a WHERE a.user_id = p_user);
  UPDATE public.user_study_streaks a SET
    current_streak = g.cur,
    longest_streak = GREATEST(a.longest_streak, g.longest_streak, g.cur),
    last_study_date = GREATEST(a.last_study_date, g.last_study_date),
    total_study_days = GREATEST(a.total_study_days, g.total_study_days)
  FROM (
    SELECT g0.*, public.merged_streak_length(
             a0.current_streak, a0.last_study_date, g0.current_streak, g0.last_study_date) AS cur
    FROM public.user_study_streaks g0
    JOIN public.user_study_streaks a0 ON a0.user_id = p_user
    WHERE g0.user_id = p_guest
  ) g
  WHERE a.user_id = p_user;
  DELETE FROM public.user_study_streaks WHERE user_id = p_guest;

  UPDATE public.memory_verse_streaks g SET user_id = p_user
  WHERE g.user_id = p_guest
    AND NOT EXISTS (SELECT 1 FROM public.memory_verse_streaks a WHERE a.user_id = p_user);
  UPDATE public.memory_verse_streaks a SET
    current_streak = g.cur,
    longest_streak = GREATEST(a.longest_streak, g.longest_streak, g.cur),
    last_practice_date = GREATEST(a.last_practice_date, g.last_practice_date),
    total_practice_days = GREATEST(a.total_practice_days, g.total_practice_days),
    milestone_10_date = LEAST(a.milestone_10_date, g.milestone_10_date),
    milestone_30_date = LEAST(a.milestone_30_date, g.milestone_30_date),
    milestone_100_date = LEAST(a.milestone_100_date, g.milestone_100_date),
    milestone_365_date = LEAST(a.milestone_365_date, g.milestone_365_date),
    updated_at = now()
  FROM (
    SELECT g0.*, public.merged_streak_length(
             a0.current_streak, a0.last_practice_date, g0.current_streak, g0.last_practice_date) AS cur
    FROM public.memory_verse_streaks g0
    JOIN public.memory_verse_streaks a0 ON a0.user_id = p_user
    WHERE g0.user_id = p_guest
  ) g
  WHERE a.user_id = p_user;
  DELETE FROM public.memory_verse_streaks WHERE user_id = p_guest;

  -- ── Achievements.
  INSERT INTO public.user_achievements (user_id, achievement_id, unlocked_at, notified)
  SELECT p_user, g.achievement_id, g.unlocked_at, g.notified
  FROM public.user_achievements g
  WHERE g.user_id = p_guest
  ON CONFLICT ON CONSTRAINT unique_user_achievement DO NOTHING;
  GET DIAGNOSTICS v_achievements = ROW_COUNT;
  DELETE FROM public.user_achievements WHERE user_id = p_guest;

  -- ── Questionnaire and preferences.
  UPDATE public.user_personalization a SET
    faith_stage = g.faith_stage,
    spiritual_goals = g.spiritual_goals,
    time_availability = g.time_availability,
    learning_style = g.learning_style,
    life_stage_focus = g.life_stage_focus,
    biggest_challenge = g.biggest_challenge,
    questionnaire_completed = g.questionnaire_completed,
    questionnaire_skipped = g.questionnaire_skipped,
    scoring_results = g.scoring_results,
    updated_at = now()
  FROM public.user_personalization g
  WHERE a.user_id = p_user AND g.user_id = p_guest
    AND a.questionnaire_completed IS NOT TRUE AND g.questionnaire_completed IS TRUE;
  UPDATE public.user_personalization g SET user_id = p_user
  WHERE g.user_id = p_guest
    AND NOT EXISTS (SELECT 1 FROM public.user_personalization a WHERE a.user_id = p_user);
  DELETE FROM public.user_personalization WHERE user_id = p_guest;

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
