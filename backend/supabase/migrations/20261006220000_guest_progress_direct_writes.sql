-- Guests write lesson and path progress only through edge functions.
--
-- The own-row INSERT/UPDATE policies on user_learning_path_progress and
-- user_topic_progress (20260119001000) let any signed-in user write their own
-- rows through PostgREST. For a guest (Supabase anonymous user) that skips
-- the server rules: enrolling a second or non-guest path directly, or
-- inserting completed topic rows with any xp_earned (which the completion
-- trigger then credits to the path). Edge functions write these tables with
-- the service-role client, which bypasses RLS, so guests keep full use of the
-- app.
--
-- RESTRICTIVE policies are ANDed with the existing permissive ones, so this
-- holds whatever the permissive policies are named. Full users are not
-- affected: a token without the claim counts as not anonymous.
-- Idempotent: DROP POLICY IF EXISTS + CREATE POLICY.

DROP POLICY IF EXISTS user_learning_path_progress_no_guest_insert ON public.user_learning_path_progress;
CREATE POLICY user_learning_path_progress_no_guest_insert
  ON public.user_learning_path_progress
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (COALESCE(((SELECT auth.jwt()) ->> 'is_anonymous')::boolean, false) = false);

DROP POLICY IF EXISTS user_learning_path_progress_no_guest_update ON public.user_learning_path_progress;
CREATE POLICY user_learning_path_progress_no_guest_update
  ON public.user_learning_path_progress
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (COALESCE(((SELECT auth.jwt()) ->> 'is_anonymous')::boolean, false) = false)
  WITH CHECK (COALESCE(((SELECT auth.jwt()) ->> 'is_anonymous')::boolean, false) = false);

DROP POLICY IF EXISTS user_topic_progress_no_guest_insert ON public.user_topic_progress;
CREATE POLICY user_topic_progress_no_guest_insert
  ON public.user_topic_progress
  AS RESTRICTIVE
  FOR INSERT
  TO authenticated
  WITH CHECK (COALESCE(((SELECT auth.jwt()) ->> 'is_anonymous')::boolean, false) = false);

DROP POLICY IF EXISTS user_topic_progress_no_guest_update ON public.user_topic_progress;
CREATE POLICY user_topic_progress_no_guest_update
  ON public.user_topic_progress
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (COALESCE(((SELECT auth.jwt()) ->> 'is_anonymous')::boolean, false) = false)
  WITH CHECK (COALESCE(((SELECT auth.jwt()) ->> 'is_anonymous')::boolean, false) = false);
