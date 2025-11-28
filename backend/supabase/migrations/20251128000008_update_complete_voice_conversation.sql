-- ============================================================================
-- Migration: Update complete_voice_conversation Function
-- Version: 1.0
-- Date: 2025-11-28
-- Description: Adds rating, feedback_text, and was_helpful parameters to
--              the complete_voice_conversation function to support user
--              feedback on voice conversations.
-- ============================================================================

-- Drop the existing function first
DROP FUNCTION IF EXISTS complete_voice_conversation(UUID, INTEGER);

-- Create updated function with feedback parameters
CREATE OR REPLACE FUNCTION complete_voice_conversation(
  p_conversation_id UUID,
  p_rating INTEGER DEFAULT NULL,
  p_feedback_text TEXT DEFAULT NULL,
  p_was_helpful BOOLEAN DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_caller_id UUID;
  v_started_at TIMESTAMPTZ;
  v_duration_seconds INTEGER;
BEGIN
  -- Get caller's user ID from auth context
  v_caller_id := auth.uid();
  
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get user_id and started_at from conversation
  SELECT user_id, started_at INTO v_user_id, v_started_at
  FROM voice_conversations
  WHERE id = p_conversation_id;
  
  -- Verify conversation exists and has required data
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Conversation not found: %', p_conversation_id;
  END IF;
  
  IF v_started_at IS NULL THEN
    RAISE EXCEPTION 'Conversation % has no started_at timestamp', p_conversation_id;
  END IF;
  
  -- Verify caller owns this conversation
  IF v_user_id != v_caller_id THEN
    RAISE EXCEPTION 'Not authorized to complete this conversation';
  END IF;

  -- Calculate duration from started_at to now
  v_duration_seconds := EXTRACT(EPOCH FROM (NOW() - v_started_at))::INTEGER;

  -- Update conversation status with feedback
  UPDATE voice_conversations
  SET
    status = 'completed',
    ended_at = NOW(),
    total_duration_seconds = v_duration_seconds,
    user_rating = p_rating,
    feedback_text = p_feedback_text,
    was_helpful = p_was_helpful,
    updated_at = NOW()
  WHERE id = p_conversation_id;

  -- Upsert daily usage tracking (insert if missing, update if exists)
  INSERT INTO voice_usage_tracking (
    user_id,
    usage_date,
    conversations_completed,
    total_conversation_seconds,
    updated_at
  ) VALUES (
    v_user_id,
    CURRENT_DATE,
    1,
    v_duration_seconds,
    NOW()
  )
  ON CONFLICT (user_id, usage_date) DO UPDATE SET
    conversations_completed = voice_usage_tracking.conversations_completed + 1,
    total_conversation_seconds = voice_usage_tracking.total_conversation_seconds + EXCLUDED.total_conversation_seconds,
    updated_at = NOW();
END;
$$;

COMMENT ON FUNCTION complete_voice_conversation IS 
'Completes a voice conversation with optional user feedback (rating, feedback text, was_helpful).
Duration is calculated automatically from started_at timestamp.';
