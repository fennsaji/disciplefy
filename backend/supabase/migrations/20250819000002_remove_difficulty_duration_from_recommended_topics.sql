-- Remove difficulty_level and estimated_duration from recommended_topics

ALTER TABLE recommended_topics DROP COLUMN IF EXISTS difficulty_level;
ALTER TABLE recommended_topics DROP COLUMN IF EXISTS estimated_duration;