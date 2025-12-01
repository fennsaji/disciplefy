-- Add atomic upsert_topic_time function for race-condition-free time updates
-- Fixes incorrect RPC usage and TOCTOU race condition in topic-progress Edge Function

BEGIN;

-- =============================================================================
-- FUNCTION: upsert_topic_time
-- =============================================================================
-- Atomically upserts time spent on a topic with proper increment handling
-- Prevents race conditions by using a single atomic database operation

CREATE OR REPLACE FUNCTION upsert_topic_time(
  p_user_id UUID,
  p_topic_id UUID,
  p_time_spent_seconds INTEGER
)
RETURNS TABLE(
  id UUID,
  topic_id UUID,
  time_spent_seconds INTEGER,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  INSERT INTO user_topic_progress (
    user_id,
    topic_id,
    time_spent_seconds,
    started_at,
    updated_at
  )
  VALUES (
    p_user_id,
    p_topic_id,
    p_time_spent_seconds,
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id, topic_id) DO UPDATE
  SET
    time_spent_seconds = user_topic_progress.time_spent_seconds + EXCLUDED.time_spent_seconds,
    updated_at = NOW()
  RETURNING
    user_topic_progress.id,
    user_topic_progress.topic_id,
    user_topic_progress.time_spent_seconds,
    user_topic_progress.updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comment for documentation
COMMENT ON FUNCTION upsert_topic_time IS 'Atomically upserts time spent on a topic. Creates record if not exists, otherwise increments existing time_spent_seconds.';

COMMIT;
