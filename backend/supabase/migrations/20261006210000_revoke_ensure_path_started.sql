-- Progress RPCs that take a user id are for edge functions only.
--
-- ensure_learning_path_started(p_user_id, p_topic_id), complete_topic_progress
-- and start_topic_progress are SECURITY DEFINER and act on whatever user id
-- they are given. Executable by `authenticated` (or PUBLIC), any signed-in
-- user, guests included, could call them through /rest/v1/rpc to enrol any
-- user in any path or complete topics (and award XP) for any user, skipping
-- the guest one-path rule. Every caller in the repo is an edge function using
-- the service-role client (topic-progress, mark-study-guide-complete), so
-- execution is limited to service_role.
--
-- Idempotent: REVOKE/GRANT can be repeated; a function that does not exist
-- is skipped.

DO $$
DECLARE
  fn text;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'public.ensure_learning_path_started(uuid, uuid)',
    'public.complete_topic_progress(uuid, uuid, integer)',
    'public.start_topic_progress(uuid, uuid)'
  ]
  LOOP
    IF to_regprocedure(fn) IS NOT NULL THEN
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', fn);
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', fn);
    END IF;
  END LOOP;
END
$$;
