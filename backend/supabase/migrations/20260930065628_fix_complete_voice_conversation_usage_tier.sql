-- Ending a Discipler conversation failed whenever the user had no
-- voice_usage_tracking row for today yet: the upsert left out tier_at_time,
-- which is NOT NULL, so the whole RPC raised and the app showed
-- "An error occurred". Record the caller's current tier on insert.
--
-- Also clamp the duration at zero: conversations started with a client
-- timestamp in the future (local time sent without an offset) produced
-- negative durations.

CREATE OR REPLACE FUNCTION complete_voice_conversation(
  p_conversation_id UUID,
  p_rating INTEGER DEFAULT NULL,
  p_feedback_text TEXT DEFAULT NULL,
  p_was_helpful BOOLEAN DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, pg_catalog
AS $$
DECLARE
  v_user_id UUID;
  v_caller_id UUID;
  v_started_at TIMESTAMPTZ;
  v_duration_seconds INTEGER;
BEGIN
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT user_id, started_at INTO v_user_id, v_started_at
  FROM voice_conversations
  WHERE id = p_conversation_id;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Conversation not found: %', p_conversation_id;
  END IF;

  IF v_started_at IS NULL THEN
    RAISE EXCEPTION 'Conversation % has no started_at timestamp', p_conversation_id;
  END IF;

  IF v_user_id != v_caller_id THEN
    RAISE EXCEPTION 'Not authorized to complete this conversation';
  END IF;

  v_duration_seconds := GREATEST(0, EXTRACT(EPOCH FROM (NOW() - v_started_at))::INTEGER);

  UPDATE voice_conversations
  SET
    status = 'completed',
    ended_at = NOW(),
    total_duration_seconds = v_duration_seconds,
    user_rating = p_rating,
    rating = p_rating, -- Also set legacy column
    feedback_text = p_feedback_text,
    was_helpful = p_was_helpful,
    updated_at = NOW()
  WHERE id = p_conversation_id;

  INSERT INTO voice_usage_tracking (
    user_id,
    usage_date,
    tier_at_time,
    conversations_completed,
    monthly_conversations_completed,
    total_conversation_seconds,
    updated_at
  ) VALUES (
    v_user_id,
    CURRENT_DATE,
    get_user_subscription_tier(v_user_id),
    1,
    1,
    v_duration_seconds,
    NOW()
  )
  ON CONFLICT (user_id, usage_date) DO UPDATE SET
    conversations_completed = voice_usage_tracking.conversations_completed + 1,
    monthly_conversations_completed = voice_usage_tracking.monthly_conversations_completed + 1,
    total_conversation_seconds = voice_usage_tracking.total_conversation_seconds + EXCLUDED.total_conversation_seconds,
    updated_at = NOW();
END;
$$;

COMMENT ON FUNCTION complete_voice_conversation IS
  'Marks a voice conversation completed with optional feedback and records daily usage (with the caller''s tier).';

GRANT EXECUTE ON FUNCTION complete_voice_conversation TO authenticated, anon, service_role;
