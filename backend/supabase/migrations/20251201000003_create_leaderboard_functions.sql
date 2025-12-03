-- Create leaderboard functions for XP ranking system
-- Version: 1.0.0

-- Function to get top leaderboard entries (users with 200+ XP)
-- Returns anonymized data: first name + last initial only
CREATE OR REPLACE FUNCTION get_leaderboard(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  total_xp BIGINT,
  rank BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    up.id AS user_id,
    COALESCE(up.first_name || ' ' || LEFT(up.last_name, 1) || '.', 'Anonymous') AS display_name,
    COALESCE(SUM(utp.xp_earned), 0)::BIGINT AS total_xp,
    ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(utp.xp_earned), 0) DESC)::BIGINT AS rank
  FROM user_profiles up
  LEFT JOIN user_topic_progress utp ON up.id = utp.user_id
  GROUP BY up.id, up.first_name, up.last_name
  HAVING COALESCE(SUM(utp.xp_earned), 0) >= 200
  ORDER BY total_xp DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user's XP and rank
-- Returns null rank if user has less than 200 XP (not on leaderboard)
CREATE OR REPLACE FUNCTION get_user_xp_rank(p_user_id UUID)
RETURNS TABLE (
  total_xp BIGINT,
  rank BIGINT
) AS $$
BEGIN
  RETURN QUERY
  WITH user_xp_totals AS (
    SELECT
      up.id,
      COALESCE(SUM(utp.xp_earned), 0)::BIGINT AS xp
    FROM user_profiles up
    LEFT JOIN user_topic_progress utp ON up.id = utp.user_id
    GROUP BY up.id
  ),
  ranked AS (
    SELECT
      uxt.id,
      uxt.xp,
      ROW_NUMBER() OVER (ORDER BY uxt.xp DESC)::BIGINT AS user_rank
    FROM user_xp_totals uxt
    WHERE uxt.xp >= 200
  )
  SELECT
    COALESCE((SELECT uxt2.xp FROM user_xp_totals uxt2 WHERE uxt2.id = p_user_id), 0) AS total_xp,
    (SELECT r.user_rank FROM ranked r WHERE r.id = p_user_id) AS rank;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_leaderboard(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_xp_rank(UUID) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION get_leaderboard IS 'Returns top N users with 200+ XP for leaderboard display. Uses SECURITY DEFINER to bypass RLS while only exposing anonymized data.';
COMMENT ON FUNCTION get_user_xp_rank IS 'Returns current user total XP and rank. Rank is NULL if user has less than 200 XP.';
