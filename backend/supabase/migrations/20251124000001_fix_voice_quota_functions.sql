-- ============================================================================
-- Migration: Fix Voice Quota Functions for RPC Calls
-- Version: 1.1
-- Date: 2025-11-24
-- Description: Updates voice quota functions to work without explicit parameters
--              by using auth.uid() and fetching tier from user subscriptions
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. CREATE HELPER FUNCTION TO GET USER TIER
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_subscription_tier(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_tier TEXT;
BEGIN
  -- Check if user has premium subscription
  SELECT
    CASE
      WHEN s.plan_type = 'premium' AND s.status = 'active' AND
           (s.current_period_end IS NULL OR s.current_period_end > NOW()) THEN 'premium'
      WHEN s.plan_type = 'standard' AND s.status = 'active' AND
           (s.current_period_end IS NULL OR s.current_period_end > NOW()) THEN 'standard'
      ELSE 'free'
    END INTO v_tier
  FROM subscriptions s
  WHERE s.user_id = p_user_id
  ORDER BY
    CASE
      WHEN s.plan_type = 'premium' THEN 1
      WHEN s.plan_type = 'standard' THEN 2
      ELSE 3
    END,
    s.created_at DESC
  LIMIT 1;

  -- Default to free if no subscription found
  IF v_tier IS NULL THEN
    v_tier := 'free';
  END IF;

  RETURN v_tier;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_subscription_tier IS 'Gets the current subscription tier for a user';

-- ============================================================================
-- 2. CREATE PARAMETERLESS CHECK_VOICE_QUOTA FUNCTION
-- ============================================================================

-- Drop the old function with parameters first (if it exists)
DROP FUNCTION IF EXISTS check_voice_quota();

-- Create new parameterless version that uses auth.uid()
CREATE OR REPLACE FUNCTION check_voice_quota()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_tier TEXT;
  v_usage RECORD;
  v_quota_limit INTEGER;
  v_can_start BOOLEAN;
BEGIN
  -- Get current user ID from auth context
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'User not authenticated',
      'can_start', false,
      'quota_limit', 0,
      'quota_used', 0,
      'quota_remaining', 0
    );
  END IF;

  -- Get user's subscription tier
  v_tier := get_user_subscription_tier(v_user_id);

  -- Determine quota based on tier
  v_quota_limit := CASE
    WHEN v_tier = 'free' THEN 3
    WHEN v_tier = 'standard' THEN 10
    WHEN v_tier = 'premium' THEN 999999 -- Unlimited
    ELSE 0
  END;

  -- Get today's usage
  SELECT * INTO v_usage
  FROM voice_usage_tracking
  WHERE user_id = v_user_id
    AND usage_date = CURRENT_DATE;

  -- If no record, create one
  IF v_usage IS NULL THEN
    INSERT INTO voice_usage_tracking (user_id, tier_at_time, daily_quota_limit)
    VALUES (v_user_id, v_tier, v_quota_limit)
    RETURNING * INTO v_usage;
  END IF;

  -- Check if can start new conversation
  v_can_start := v_usage.daily_quota_used < v_quota_limit;

  RETURN jsonb_build_object(
    'can_start', v_can_start,
    'quota_limit', v_quota_limit,
    'quota_used', v_usage.daily_quota_used,
    'quota_remaining', GREATEST(0, v_quota_limit - v_usage.daily_quota_used),
    'tier', v_tier
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION check_voice_quota() IS 'Checks if authenticated user can start a new voice conversation based on tier quota';

-- ============================================================================
-- 3. CREATE PARAMETERLESS INCREMENT_VOICE_USAGE FUNCTION
-- ============================================================================

-- Create new parameterless version
CREATE OR REPLACE FUNCTION increment_voice_usage()
RETURNS VOID AS $$
DECLARE
  v_user_id UUID;
  v_tier TEXT;
  v_language TEXT;
BEGIN
  -- Get current user ID from auth context
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  -- Get user's subscription tier
  v_tier := get_user_subscription_tier(v_user_id);

  -- Default language (will be updated when conversation is created)
  v_language := 'en-US';

  INSERT INTO voice_usage_tracking (
    user_id,
    usage_date,
    tier_at_time,
    daily_quota_limit,
    daily_quota_used,
    conversations_started,
    language_usage
  )
  VALUES (
    v_user_id,
    CURRENT_DATE,
    v_tier,
    CASE
      WHEN v_tier = 'free' THEN 3
      WHEN v_tier = 'standard' THEN 10
      WHEN v_tier = 'premium' THEN 999999
    END,
    1,
    1,
    jsonb_build_object(v_language, 1)
  )
  ON CONFLICT (user_id, usage_date)
  DO UPDATE SET
    daily_quota_used = voice_usage_tracking.daily_quota_used + 1,
    conversations_started = voice_usage_tracking.conversations_started + 1,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION increment_voice_usage() IS 'Increments daily voice usage count when authenticated user starts a conversation';

-- ============================================================================
-- 4. UPDATE GET_VOICE_PREFERENCES TO USE AUTH.UID()
-- ============================================================================

-- Drop the old function and recreate without parameter
DROP FUNCTION IF EXISTS get_voice_preferences();

CREATE OR REPLACE FUNCTION get_voice_preferences()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_prefs RECORD;
BEGIN
  -- Get current user ID from auth context
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'User not authenticated'
    );
  END IF;

  SELECT * INTO v_prefs
  FROM voice_preferences
  WHERE user_id = v_user_id;

  -- Return defaults if no preferences exist
  IF v_prefs IS NULL THEN
    RETURN jsonb_build_object(
      'preferred_language', 'en-US',
      'auto_detect_language', true,
      'tts_voice_gender', 'female',
      'speaking_rate', 0.95,
      'pitch', 0.0,
      'auto_play_response', true,
      'show_transcription', true,
      'continuous_mode', false,
      'use_study_context', true,
      'cite_scripture_references', true,
      'notify_daily_quota_reached', true
    );
  END IF;

  RETURN to_jsonb(v_prefs) - 'id' - 'user_id' - 'created_at' - 'updated_at';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_voice_preferences() IS 'Returns voice preferences for authenticated user with sensible defaults if not set';

-- ============================================================================
-- 5. UPDATE GET_VOICE_CONVERSATION_HISTORY TO USE AUTH.UID()
-- ============================================================================

-- Drop old function and recreate
DROP FUNCTION IF EXISTS get_voice_conversation_history(UUID, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION get_voice_conversation_history(
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_conversations JSONB;
  v_total_count INTEGER;
BEGIN
  -- Get current user ID from auth context
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'User not authenticated',
      'conversations', '[]'::jsonb,
      'total_count', 0
    );
  END IF;

  -- Get total count
  SELECT COUNT(*) INTO v_total_count
  FROM voice_conversations
  WHERE user_id = v_user_id;

  -- Get conversations with messages
  SELECT jsonb_agg(conv_data ORDER BY started_at DESC)
  INTO v_conversations
  FROM (
    SELECT
      jsonb_build_object(
        'id', vc.id,
        'session_id', vc.session_id,
        'language_code', vc.language_code,
        'conversation_type', vc.conversation_type,
        'total_messages', vc.total_messages,
        'total_duration_seconds', vc.total_duration_seconds,
        'status', vc.status,
        'rating', vc.rating,
        'started_at', vc.started_at,
        'ended_at', vc.ended_at,
        'messages', COALESCE(
          (SELECT jsonb_agg(
            jsonb_build_object(
              'id', cm.id,
              'role', cm.role,
              'content_text', cm.content_text,
              'scripture_references', cm.scripture_references,
              'created_at', cm.created_at
            ) ORDER BY cm.message_order
          )
          FROM voice_conversation_messages cm
          WHERE cm.conversation_id = vc.id
          ), '[]'::jsonb
        )
      ) as conv_data,
      vc.started_at
    FROM voice_conversations vc
    WHERE vc.user_id = v_user_id
    ORDER BY vc.started_at DESC
    LIMIT p_limit
    OFFSET p_offset
  ) sub;

  RETURN jsonb_build_object(
    'conversations', COALESCE(v_conversations, '[]'::jsonb),
    'total_count', v_total_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_voice_conversation_history IS 'Returns paginated conversation history with messages for authenticated user';

COMMIT;
