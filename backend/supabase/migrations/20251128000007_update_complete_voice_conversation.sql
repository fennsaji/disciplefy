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
  v_started_at TIMESTAMPTZ;
  v_duration_seconds INTEGER;
BEGIN
  -- Get user_id and started_at from conversation
  SELECT user_id, started_at INTO v_user_id, v_started_at
  FROM voice_conversations
  WHERE id = p_conversation_id;

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

  -- Update daily usage tracking
  UPDATE voice_usage_tracking
  SET
    conversations_completed = conversations_completed + 1,
    total_conversation_seconds = total_conversation_seconds + v_duration_seconds,
    updated_at = NOW()
  WHERE user_id = v_user_id
    AND usage_date = CURRENT_DATE;
END;
$$;

COMMENT ON FUNCTION complete_voice_conversation IS 
'Completes a voice conversation with optional user feedback (rating, feedback text, was_helpful).
Duration is calculated automatically from started_at timestamp.';
