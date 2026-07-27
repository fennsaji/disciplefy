-- =====================================================
-- Reset User Progress
-- =====================================================
-- Two SECURITY DEFINER functions that let a user wipe their own progress
-- for one feature area at a time. Each runs all of its deletes inside the
-- calling transaction, so a failure leaves no partial-reset state.
--
-- Callable by service_role only. The reset-progress Edge Function is the
-- sole caller and supplies p_user_id from a validated JWT.

-- -----------------------------------------------------
-- Function: reset_user_learning_progress
-- -----------------------------------------------------
-- Clears learning path enrollments, topic progress, study streak, and the
-- study/streak-category achievements.
--
-- XP is never stored directly; leaderboard XP is derived from two sources
-- (see migration 20260415000001_fix_leaderboard_include_achievement_xp.sql):
-- SUM(user_topic_progress.xp_earned) plus SUM of all achievement XP (no category
-- filter). Deleting only study/streak achievements leaves voice/saved badge XP
-- intact, so XP drops sharply but may not reach zero.

CREATE OR REPLACE FUNCTION reset_user_learning_progress(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_paths_reset INTEGER;
  v_topics_reset INTEGER;
  v_achievements_reset INTEGER;
  v_streak_reset INTEGER;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  DELETE FROM user_learning_path_progress WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_paths_reset = ROW_COUNT;

  DELETE FROM user_topic_progress WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_topics_reset = ROW_COUNT;

  DELETE FROM user_achievements
  WHERE user_id = p_user_id
    AND achievement_id IN (
      SELECT id FROM achievements WHERE category IN ('study', 'streak')
    );
  GET DIAGNOSTICS v_achievements_reset = ROW_COUNT;

  DELETE FROM user_study_streaks WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_streak_reset = ROW_COUNT;

  RETURN jsonb_build_object(
    'paths_reset', v_paths_reset,
    'topics_reset', v_topics_reset,
    'achievements_reset', v_achievements_reset,
    'streak_reset', v_streak_reset > 0
  );
END;
$$;

COMMENT ON FUNCTION reset_user_learning_progress(UUID) IS
  'Deletes all learning path enrollments, topic progress, study streak, and study/streak achievements for one user. Irreversible. Reduces leaderboard XP (computed from topic XP plus all-category achievement XP per 20260415000001) by removing topic and study/streak achievement XP, but any voice/saved badge XP survives.';

-- -----------------------------------------------------
-- Function: reset_user_memory_progress
-- -----------------------------------------------------
-- Deletes the user's entire memory verse deck and all derived progress.
--
-- Deleting memory_verses cascades to review_sessions, review_history,
-- daily_unlocked_modes, memory_verse_collection_items,
-- memory_practice_modes, and memory_verse_mastery — all six declare
-- memory_verse_id ... ON DELETE CASCADE.
--
-- daily_unlocked_modes is also deleted explicitly. That is redundant given
-- the cascade, but keeps this function correct if that FK is ever relaxed.

CREATE OR REPLACE FUNCTION reset_user_memory_progress(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_verses_deleted INTEGER;
  v_collections_deleted INTEGER;
  v_challenges_reset INTEGER;
  v_achievements_reset INTEGER;
  v_streak_reset INTEGER;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'p_user_id is required';
  END IF;

  DELETE FROM memory_verses WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_verses_deleted = ROW_COUNT;

  DELETE FROM daily_unlocked_modes WHERE user_id = p_user_id;

  DELETE FROM memory_verse_collections WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_collections_deleted = ROW_COUNT;

  DELETE FROM memory_daily_goals WHERE user_id = p_user_id;

  DELETE FROM user_challenge_progress WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_challenges_reset = ROW_COUNT;

  DELETE FROM user_achievements
  WHERE user_id = p_user_id
    AND achievement_id IN (
      SELECT id FROM achievements WHERE category = 'memory'
    );
  GET DIAGNOSTICS v_achievements_reset = ROW_COUNT;

  DELETE FROM memory_verse_streaks WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_streak_reset = ROW_COUNT;

  RETURN jsonb_build_object(
    'verses_deleted', v_verses_deleted,
    'collections_deleted', v_collections_deleted,
    'challenges_reset', v_challenges_reset,
    'achievements_reset', v_achievements_reset,
    'streak_reset', v_streak_reset > 0
  );
END;
$$;

COMMENT ON FUNCTION reset_user_memory_progress(UUID) IS
  'Deletes a user entire memory verse deck plus collections, daily goals, unlocked modes, memory challenge progress, memory achievements, and memory streak. Irreversible.';

-- -----------------------------------------------------
-- Grants
-- -----------------------------------------------------
-- service_role only. Not granted to anon/authenticated: the reset-progress
-- Edge Function is the sole caller, so a leaked anon/authenticated key
-- cannot trigger a reset via PostgREST's /rest/v1/rpc/ endpoint.
--
-- REVOKE FROM PUBLIC alone is not sufficient here: this project's public
-- schema has default privileges (set at provisioning, see
-- 20260703000007_revoke_token_rpc_public_access.sql for the same issue on
-- earlier RPCs) that grant EXECUTE on newly created functions to anon and
-- authenticated explicitly, not just via the PUBLIC pseudo-role. Each of
-- those roles must be revoked by name.

REVOKE ALL ON FUNCTION reset_user_learning_progress(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION reset_user_memory_progress(UUID) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION reset_user_learning_progress(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION reset_user_memory_progress(UUID) TO service_role;
