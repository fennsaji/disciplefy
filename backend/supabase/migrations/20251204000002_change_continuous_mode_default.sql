-- ============================================================================
-- Migration: Change Continuous Mode Default to TRUE
-- Version: 1.0
-- Date: 2025-12-04
--
-- Description: Changes the default value for continuous_mode in voice_preferences
--              from FALSE to TRUE. This makes continuous conversation mode the
--              default behavior for the AI Study Buddy Voice feature.
--
--              Continuous mode keeps the microphone open after the AI response,
--              allowing for a more natural, flowing conversation experience.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ALTER TABLE DEFAULT VALUE
-- ============================================================================

-- Change the default value for continuous_mode column
ALTER TABLE voice_preferences 
ALTER COLUMN continuous_mode SET DEFAULT TRUE;

COMMENT ON COLUMN voice_preferences.continuous_mode IS 
'Keep microphone open for continuous conversation (default: TRUE for natural conversation flow)';

-- ============================================================================
-- 2. UPDATE GET_VOICE_PREFERENCES FUNCTION
-- ============================================================================

-- Drop and recreate the function with updated default
CREATE OR REPLACE FUNCTION get_voice_preferences(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_prefs RECORD;
BEGIN
  SELECT * INTO v_prefs
  FROM voice_preferences
  WHERE user_id = p_user_id;

  -- Return defaults if no preferences exist (continuous_mode now defaults to true)
  IF v_prefs IS NULL THEN
    RETURN jsonb_build_object(
      'preferred_language', 'en-US',
      'auto_detect_language', true,
      'tts_voice_gender', 'female',
      'speaking_rate', 0.95,
      'pitch', 0.0,
      'auto_play_response', true,
      'show_transcription', true,
      'continuous_mode', true,  -- Changed from false to true
      'use_study_context', true,
      'cite_scripture_references', true,
      'notify_daily_quota_reached', true
    );
  END IF;

  RETURN to_jsonb(v_prefs) - 'id' - 'user_id' - 'created_at' - 'updated_at';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_voice_preferences(UUID) IS 
'Returns user voice preferences with sensible defaults if not set. Continuous mode defaults to TRUE for natural conversation flow.';

COMMIT;
