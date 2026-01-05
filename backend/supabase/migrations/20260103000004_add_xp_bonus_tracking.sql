-- Migration: Add XP bonus tracking to user_learning_path_progress
-- Purpose: Track bonus XP earned and streaks for completing topics in recommended mode
-- Related Feature: Recommended Study Modes for Learning Paths with XP Bonuses

-- Add bonus tracking columns
ALTER TABLE user_learning_path_progress
ADD COLUMN recommended_mode_streak INTEGER DEFAULT 0,
ADD COLUMN completed_in_recommended_mode BOOLEAN DEFAULT false,
ADD COLUMN bonus_xp_awarded INTEGER DEFAULT 0;

-- Add column comments for documentation
COMMENT ON COLUMN user_learning_path_progress.recommended_mode_streak IS
'Current streak of consecutive topics completed in the path''s recommended mode.
- Increments by 1 when topic completed in recommended mode
- Resets to 0 when topic completed in non-recommended mode
- Used to determine if user qualifies for 50% path completion bonus';

COMMENT ON COLUMN user_learning_path_progress.completed_in_recommended_mode IS
'Whether ALL topics in the learning path were completed using the recommended mode.
- Set to true only if recommended_mode_streak equals total number of topics at completion
- Used to award 50% completion bonus XP
- Example: 6-topic path with all topics in recommended mode → true, qualifies for bonus';

COMMENT ON COLUMN user_learning_path_progress.bonus_xp_awarded IS
'Total bonus XP awarded for this learning path.
Includes:
- Per-topic bonuses: 25% of base XP for regular topics
- Milestone bonuses: 50% of base XP for milestone topics
- Completion bonus: 50% of total path XP (only if all topics in recommended mode)

Example: 6-topic path (300 base XP, 1 milestone)
- Per-topic: 5 × 12.5 XP + 1 × 25 XP = 87.5 XP
- Completion: 150 XP (if all in recommended mode)
- Total bonus: 237.5 XP';

-- Backfill existing records with default values
UPDATE user_learning_path_progress
SET recommended_mode_streak = 0,
    completed_in_recommended_mode = false,
    bonus_xp_awarded = 0
WHERE recommended_mode_streak IS NULL;

-- Add index for leaderboard and analytics queries
CREATE INDEX idx_user_learning_path_progress_bonus_xp
ON user_learning_path_progress(bonus_xp_awarded DESC)
WHERE bonus_xp_awarded > 0;

-- Add index for streak tracking
CREATE INDEX idx_user_learning_path_progress_streak
ON user_learning_path_progress(user_id, recommended_mode_streak)
WHERE recommended_mode_streak > 0;
