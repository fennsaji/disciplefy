-- Migration: Add learning_path_study_mode to user_preferences
-- Purpose: Store user's preference for how to handle study mode selection in learning paths
-- Related Feature: Recommended Study Modes for Learning Paths with XP Bonuses

-- Add learning_path_study_mode column
ALTER TABLE user_preferences
ADD COLUMN learning_path_study_mode TEXT
CHECK (learning_path_study_mode IN ('ask', 'recommended', 'quick', 'standard', 'deep', 'lectio'));

-- Add column comment for documentation
COMMENT ON COLUMN user_preferences.learning_path_study_mode IS
'Study mode preference for learning path topics:
- ask: Show mode selection sheet each time (default if null)
- recommended: Always use the path''s recommended mode
- quick: Always use Quick mode for all learning path topics
- standard: Always use Standard mode for all learning path topics
- deep: Always use Deep mode for all learning path topics
- lectio: Always use Lectio mode for all learning path topics

Note: This is separate from the general study_mode_preference which applies to custom study guides.
General study guides use study_mode_preference, learning paths use learning_path_study_mode.';

-- No backfill needed - NULL values will be treated as "ask" (show mode selection)
