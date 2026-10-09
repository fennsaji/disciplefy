-- Guest-accessible learning paths.
--
-- A guest (Supabase anonymous user) may enrol in ONE learning path, chosen at
-- first run, and only from the few paths flagged here. Every other path needs
-- an account. A reinstall creates a new anonymous user, so this allow-list is
-- what bounds what a guest can ever read and generate.
--
-- Enforced in the learning-paths edge function (enrol) and in
-- study-generate-v2 (a guest may only generate a verified catalogue lesson of
-- an enrolled, guest-accessible path). The column is catalogue data: no RLS
-- change, it is readable wherever learning_paths rows already are.
--
-- The six paths are the first-run goal paths (owner decision 2026-10-07).
-- Idempotent: re-running leaves exactly these six flagged.

ALTER TABLE public.learning_paths
  ADD COLUMN IF NOT EXISTS guest_accessible boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.learning_paths.guest_accessible IS
  'True when a guest (anonymous user) may enrol in and study this path. Every other path needs an account.';

UPDATE public.learning_paths
SET guest_accessible = (slug IN (
  'new-believer-essentials',
  'sin-repentance-and-grace',
  'growing-in-discipleship',
  'theology-of-suffering',
  'gospel-of-mark',
  'romans-gospel-unfolded'
))
WHERE guest_accessible IS DISTINCT FROM (slug IN (
  'new-believer-essentials',
  'sin-repentance-and-grace',
  'growing-in-discipleship',
  'theology-of-suffering',
  'gospel-of-mark',
  'romans-gospel-unfolded'
));

-- Report any goal slug that does not exist (seed data drift), without failing
-- the deploy: a missing path simply stays closed to guests.
DO $$
DECLARE
  missing text;
BEGIN
  SELECT string_agg(s, ', ') INTO missing
  FROM unnest(ARRAY[
    'new-believer-essentials',
    'sin-repentance-and-grace',
    'growing-in-discipleship',
    'theology-of-suffering',
    'gospel-of-mark',
    'romans-gospel-unfolded'
  ]) AS s
  WHERE NOT EXISTS (SELECT 1 FROM public.learning_paths lp WHERE lp.slug = s);
  IF missing IS NOT NULL THEN
    RAISE WARNING 'guest_accessible: learning path slugs not found: %', missing;
  END IF;
END $$;

-- Enrolment goes through the learning-paths edge function only (service
-- role), which applies the guest rules above. enroll_in_learning_path is
-- SECURITY DEFINER and takes the user id as a parameter, so a direct RPC call
-- with the anon or a user key could enrol any user in any path and skip those
-- rules. No client calls it directly.
REVOKE EXECUTE ON FUNCTION public.enroll_in_learning_path(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enroll_in_learning_path(uuid, uuid) TO service_role;
