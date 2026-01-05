-- Migration: Add generation_mode to user_topic_progress
-- Purpose: Track which study mode was actually used when completing each topic
-- Related Feature: Recommended Study Modes for Learning Paths with XP Bonuses
-- Analytics: Enables analysis of mode preferences and completion patterns

-- Add generation_mode column
ALTER TABLE user_topic_progress
ADD COLUMN generation_mode TEXT
CHECK (generation_mode IN ('quick', 'standard', 'deep', 'lectio'));

-- Add column comment for documentation
COMMENT ON COLUMN user_topic_progress.generation_mode IS
'Study mode used when generating/completing this topic:
- quick: 3-5 min sessions
- standard: 10-15 min sessions
- deep: 20-30 min sessions
- lectio: 15-20 min sessions

Used for:
1. Analytics: Track which modes users prefer
2. XP Bonuses: Award bonus XP when generation_mode matches learning_path.recommended_mode
3. Streak Tracking: Maintain recommended mode streaks for path completion bonuses';

-- Add index for analytics queries
CREATE INDEX idx_user_topic_progress_generation_mode
ON user_topic_progress(generation_mode)
WHERE generation_mode IS NOT NULL;

-- Add compound index for bonus XP calculations
CREATE INDEX idx_user_topic_progress_user_mode
ON user_topic_progress(user_id, generation_mode)
WHERE generation_mode IS NOT NULL;

-- No backfill needed - existing completed topics will have NULL generation_mode
-- Future completions will track the mode used
