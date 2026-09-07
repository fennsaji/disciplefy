-- Consistent naming: the assistant is "Discipler", never "AI Discipler".
--
-- `feature_flags.ai_discipler` gates the paid VOICE conversation feature and
-- is shown in the admin Feature Flags list as "AI Discipler". That name is
-- both off-brand and easy to mistake for the fellowship Discipler, whose
-- kill switch lives in system_config.discipler_global_enabled — a collision
-- that has already cost debugging time. "Talk to Discipler" keeps the brand
-- name and says which surface it controls.
--
-- The feature_key stays `ai_discipler`: it is referenced in code
-- (voice-conversation/index.ts) and renaming it would break the gate.

UPDATE public.feature_flags
SET feature_name = 'Talk to Discipler',
    description = 'Voice conversation with Discipler for Bible study discussions',
    updated_at = now()
WHERE feature_key = 'ai_discipler';
