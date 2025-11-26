-- ============================================================================
-- MIGRATION: Add User Profile Language Fallback to Voice Preferences
-- Date: 2025-11-24
-- Description: Updates get_voice_preferences() to fall back to user profile
--              language_preference when voice preferences don't exist
-- ============================================================================

DROP FUNCTION IF EXISTS get_voice_preferences();

CREATE OR REPLACE FUNCTION get_voice_preferences()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID;
  v_prefs RECORD;
  v_user_lang TEXT;
  v_full_lang_code TEXT;
BEGIN
  -- Get current user ID from auth context
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'error', 'User not authenticated'
    );
  END IF;

  -- Try to get existing voice preferences
  SELECT * INTO v_prefs
  FROM voice_preferences
  WHERE user_id = v_user_id;

  -- If voice preferences exist, return them
  IF v_prefs IS NOT NULL THEN
    RETURN to_jsonb(v_prefs) - 'id' - 'created_at' - 'updated_at';
  END IF;

  -- Voice preferences don't exist, get language from user profile
  SELECT language_preference INTO v_user_lang
  FROM user_profiles
  WHERE id = v_user_id;

  -- Convert short language codes to full voice codes
  v_full_lang_code := CASE
    WHEN v_user_lang = 'en' THEN 'en-US'
    WHEN v_user_lang = 'hi' THEN 'hi-IN'
    WHEN v_user_lang = 'ml' THEN 'ml-IN'
    ELSE 'en-US'  -- Default to English if unknown
  END;

  -- Return defaults with user's profile language
  RETURN jsonb_build_object(
    'user_id', v_user_id,
    'preferred_language', v_full_lang_code,
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_voice_preferences() IS 'Returns voice preferences for authenticated user with fallback to user profile language if not set';
