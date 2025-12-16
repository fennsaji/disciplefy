-- Add 'default' as an allowed language option for voice preferences
-- When 'default' is selected, the app uses the user's preferred app language

-- Step 1: Drop the existing constraint
ALTER TABLE voice_preferences
DROP CONSTRAINT IF EXISTS voice_preferences_preferred_language_check;

-- Step 2: Add new constraint with 'default' option
ALTER TABLE voice_preferences
ADD CONSTRAINT voice_preferences_preferred_language_check
CHECK (preferred_language IN ('default', 'en-US', 'hi-IN', 'ml-IN'));

-- Step 3: Change the default value to 'default'
ALTER TABLE voice_preferences
ALTER COLUMN preferred_language SET DEFAULT 'default';

-- Step 4: Update ALL existing rows to use 'default'
-- This ensures all existing users will use their app language preference
UPDATE voice_preferences
SET preferred_language = 'default';

-- Step 5: Update the get_voice_preferences function to return 'default' as default
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

  -- If no preferences exist, return defaults
  IF v_prefs IS NULL THEN
    RETURN jsonb_build_object(
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
