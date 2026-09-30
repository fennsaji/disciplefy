-- Batched lookups for the fellowship list endpoint.
--
-- The list used to call auth.admin.getUserById once per mentor and run a
-- member-count query per fellowship. These two functions answer both for all
-- fellowships in one round trip each. Service role only: the display metadata
-- comes from auth.users.

CREATE OR REPLACE FUNCTION public.get_user_display_meta(p_user_ids UUID[])
RETURNS TABLE (user_id UUID, display_name TEXT, avatar_url TEXT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    u.id,
    COALESCE(
      u.raw_user_meta_data->>'full_name',
      u.raw_user_meta_data->>'name',
      u.raw_user_meta_data->>'display_name'
    ),
    u.raw_user_meta_data->>'avatar_url'
  FROM auth.users u
  WHERE u.id = ANY(p_user_ids);
$$;

COMMENT ON FUNCTION public.get_user_display_meta(UUID[]) IS
  'Name/avatar from auth user metadata for many users (full_name, name, display_name; avatar_url). Service role only.';

CREATE OR REPLACE FUNCTION public.get_fellowship_member_counts(p_fellowship_ids UUID[])
RETURNS TABLE (fellowship_id UUID, member_count BIGINT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT fm.fellowship_id, COUNT(*)
  FROM public.fellowship_members fm
  WHERE fm.fellowship_id = ANY(p_fellowship_ids)
    AND fm.is_active = true
  GROUP BY fm.fellowship_id;
$$;

COMMENT ON FUNCTION public.get_fellowship_member_counts(UUID[]) IS
  'Active member count per fellowship. Fellowships with no active members are absent. Service role only.';

REVOKE ALL ON FUNCTION public.get_user_display_meta(UUID[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_fellowship_member_counts(UUID[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_display_meta(UUID[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_fellowship_member_counts(UUID[]) TO service_role;
