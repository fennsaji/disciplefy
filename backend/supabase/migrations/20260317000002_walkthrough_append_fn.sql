-- Helper function to safely append a screen to walkthrough_seen
-- Uses array_append with a distinct check to avoid duplicates
CREATE OR REPLACE FUNCTION append_walkthrough_seen(p_user_id uuid, p_screen text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE user_profiles
  SET walkthrough_seen = array_append(
    COALESCE(walkthrough_seen, '{}'),
    p_screen
  )
  WHERE id = p_user_id
    AND NOT (p_screen = ANY(COALESCE(walkthrough_seen, '{}')));
$$;

-- Grant execute to authenticated role (required for RPC calls from Flutter clients)
GRANT EXECUTE ON FUNCTION append_walkthrough_seen(uuid, text) TO authenticated;
