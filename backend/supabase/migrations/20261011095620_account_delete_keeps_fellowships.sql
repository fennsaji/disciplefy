-- Deleting an account never deletes a fellowship.
--
-- delete-account used to delete every fellowship the person created (the
-- fellowships.mentor_user_id FK was ON DELETE RESTRICT), then delete the auth
-- user. On 2026-10-09 the user delete then failed on another FK
-- (iap_webhook_events -> subscriptions), so the account survived but its 7
-- fellowships, with their members and posts, were already gone.
--
-- Now:
--   1. hand_over_fellowships(p_user) gives each fellowship the person owns to
--      another active mentor, else promotes the longest-standing active
--      member. With nobody left, the fellowship is deactivated, never deleted.
--   2. Every FK that blocked deleting an account is ON DELETE SET NULL, so
--      the auth user delete succeeds and nothing else needs clean-up first.

-- ---------------------------------------------------------------------------
-- 1. Foreign keys
-- ---------------------------------------------------------------------------

ALTER TABLE public.fellowships ALTER COLUMN mentor_user_id DROP NOT NULL;
ALTER TABLE public.fellowships DROP CONSTRAINT IF EXISTS fellowships_mentor_user_id_fkey;
ALTER TABLE public.fellowships
  ADD CONSTRAINT fellowships_mentor_user_id_fkey
  FOREIGN KEY (mentor_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.fellowship_invites DROP CONSTRAINT IF EXISTS fellowship_invites_used_by_fkey;
ALTER TABLE public.fellowship_invites
  ADD CONSTRAINT fellowship_invites_used_by_fkey
  FOREIGN KEY (used_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.iap_webhook_events DROP CONSTRAINT IF EXISTS iap_webhook_events_subscription_id_fkey;
ALTER TABLE public.iap_webhook_events
  ADD CONSTRAINT iap_webhook_events_subscription_id_fkey
  FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id) ON DELETE SET NULL;

ALTER TABLE public.iap_verification_logs DROP CONSTRAINT IF EXISTS iap_verification_logs_verified_by_fkey;
ALTER TABLE public.iap_verification_logs
  ADD CONSTRAINT iap_verification_logs_verified_by_fkey
  FOREIGN KEY (verified_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.purchase_issue_reports DROP CONSTRAINT IF EXISTS purchase_issue_reports_resolved_by_fkey;
ALTER TABLE public.purchase_issue_reports
  ADD CONSTRAINT purchase_issue_reports_resolved_by_fkey
  FOREIGN KEY (resolved_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- 2. Hand fellowships over before an account is deleted
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.hand_over_fellowships(p_user UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fellowship RECORD;
  v_next UUID;
  v_count INTEGER := 0;
BEGIN
  FOR v_fellowship IN
    SELECT id FROM public.fellowships WHERE mentor_user_id = p_user FOR UPDATE
  LOOP
    -- Another active mentor first, then the longest-standing active member.
    SELECT user_id INTO v_next
      FROM public.fellowship_members
     WHERE fellowship_id = v_fellowship.id
       AND user_id <> p_user
       AND is_active
     ORDER BY (role = 'mentor') DESC, joined_at ASC
     LIMIT 1;

    IF v_next IS NULL THEN
      -- Nobody left: keep the fellowship, just switch it off.
      UPDATE public.fellowships
         SET mentor_user_id = NULL, is_active = false, updated_at = NOW()
       WHERE id = v_fellowship.id;
    ELSE
      UPDATE public.fellowship_members
         SET role = 'mentor'
       WHERE fellowship_id = v_fellowship.id AND user_id = v_next;
      UPDATE public.fellowships
         SET mentor_user_id = v_next, updated_at = NOW()
       WHERE id = v_fellowship.id;
    END IF;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.hand_over_fellowships(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.hand_over_fellowships(UUID) TO service_role;

COMMENT ON FUNCTION public.hand_over_fellowships(UUID) IS
  'Before deleting an account: gives each fellowship it owns to another mentor or the longest-standing member, or deactivates it when nobody is left. Never deletes a fellowship.';
