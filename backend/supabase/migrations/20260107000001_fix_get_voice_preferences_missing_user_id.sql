-- ============================================================================
-- MIGRATION: Fix get_voice_preferences to include user_id in default return
-- Date: 2026-01-07
-- Description: Adds missing user_id field to the default preferences object
--              when no voice preferences exist for a user.
--              This fixes the "Unable to fetch voice preferences" error.
-- ============================================================================

CREATE OR REPLACE FUNCTION get_voice_preferences()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_prefs RECORD;
BEGIN
  -- Get the user's voice preferences
  SELECT * INTO v_prefs
  FROM voice_preferences
  WHERE user_id = v_user_id;

  -- If no preferences exist, return defaults WITH user_id
  IF v_prefs IS NULL THEN
    RETURN jsonb_build_object(
      'user_id', v_user_id,  -- FIXED: Added user_id field
      'preferred_language', 'default',
      'auto_detect_language', true,
      'tts_voice_gender', 'female',
      'speaking_rate', 0.95,
      'pitch', 0,
      'auto_play_response', true,
      'show_transcription', true,
      'continuous_mode', true,
      'use_study_context', true,
      'cite_scripture_references', true,
      'notify_daily_quota_reached', true
    );
  END IF;

  -- Return the user's preferences
  RETURN jsonb_build_object(
    'id', v_prefs.id,
    'user_id', v_prefs.user_id,
    'preferred_language', v_prefs.preferred_language,
    'auto_detect_language', v_prefs.auto_detect_language,
    'tts_voice_gender', v_prefs.tts_voice_gender,
    'speaking_rate', v_prefs.speaking_rate,
    'pitch', v_prefs.pitch,
    'auto_play_response', v_prefs.auto_play_response,
    'show_transcription', v_prefs.show_transcription,
    'continuous_mode', v_prefs.continuous_mode,
    'use_study_context', v_prefs.use_study_context,
    'cite_scripture_references', v_prefs.cite_scripture_references,
    'notify_daily_quota_reached', v_prefs.notify_daily_quota_reached,
    'created_at', v_prefs.created_at,
    'updated_at', v_prefs.updated_at
  );
END;
$$;

COMMENT ON FUNCTION get_voice_preferences() IS 'Returns voice preferences for authenticated user with user_id field in defaults';
