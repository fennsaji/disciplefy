-- One name for the study-guide narration feature.
--
-- `feature_flags.voice_buddy` gates text-to-speech playback of study guides.
-- It was stored as "Voice Buddy" but surfaced to users as "Voice Listener" in
-- the upgrade sheet, while the control itself is labelled "Listen" — three
-- names for one feature, and "Voice Buddy" is close enough to the Discipler
-- voice conversation (feature_key `ai_discipler`, now "Talk to Discipler") to
-- be mistaken for it. That collision has already cost debugging time once.
--
-- "Listen" matches what the button says. The feature_key stays `voice_buddy`:
-- it is referenced in Flutter and Edge Function code.

UPDATE public.feature_flags
SET feature_name = 'Listen',
    description = 'Listen to study guides with AI-powered text-to-speech',
    updated_at = now()
WHERE feature_key = 'voice_buddy';
