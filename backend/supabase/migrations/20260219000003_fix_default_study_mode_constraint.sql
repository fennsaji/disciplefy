-- Fix default_study_mode CHECK constraint on user_profiles.
--
-- 'ask' is a valid explicit user choice meaning "always show the mode selection
-- sheet before starting a study guide". It is distinct from NULL (no preference
-- set yet). The edge function validation is updated separately to accept 'ask'.

ALTER TABLE user_profiles
  DROP CONSTRAINT IF EXISTS user_profiles_default_study_mode_check;

ALTER TABLE user_profiles
  ADD CONSTRAINT user_profiles_default_study_mode_check
  CHECK (default_study_mode IN ('quick', 'standard', 'deep', 'lectio', 'sermon', 'recommended', 'ask'));
