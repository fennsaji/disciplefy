-- Create user_topic_progress table
-- Tracks user progress on individual study topics for the gamification system
-- Part of Phase 1: Foundation & Progress Tracking

BEGIN;

-- =============================================================================
-- TABLE: user_topic_progress
-- =============================================================================
-- Tracks when users start and complete topics, time spent, and XP earned

CREATE TABLE user_topic_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES recommended_topics(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  time_spent_seconds INTEGER DEFAULT 0,
  xp_earned INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Each user can only have one progress record per topic
  CONSTRAINT unique_user_topic_progress UNIQUE(user_id, topic_id)
);

-- Create indexes for performance
CREATE INDEX idx_user_topic_progress_user_id ON user_topic_progress(user_id);
CREATE INDEX idx_user_topic_progress_topic_id ON user_topic_progress(topic_id);
CREATE INDEX idx_user_topic_progress_completed ON user_topic_progress(user_id, completed_at) WHERE completed_at IS NOT NULL;
CREATE INDEX idx_user_topic_progress_in_progress ON user_topic_progress(user_id, started_at) WHERE completed_at IS NULL;

-- Enable RLS
ALTER TABLE user_topic_progress ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can only view their own progress
CREATE POLICY "Users can view own topic progress" ON user_topic_progress
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- Users can insert their own progress
CREATE POLICY "Users can insert own topic progress" ON user_topic_progress
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own progress
CREATE POLICY "Users can update own topic progress" ON user_topic_progress
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Service role has full access
CREATE POLICY "Service role can manage all topic progress" ON user_topic_progress
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- =============================================================================
-- MODIFY: recommended_topics - Add xp_value column
-- =============================================================================

ALTER TABLE recommended_topics
ADD COLUMN IF NOT EXISTS xp_value INTEGER DEFAULT 50;

-- Update existing topics to have default XP value
UPDATE recommended_topics SET xp_value = 50 WHERE xp_value IS NULL;

-- Add comment for documentation
COMMENT ON COLUMN recommended_topics.xp_value IS 'XP points awarded for completing this topic (default: 50)';

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Function to start tracking a topic (called when user opens a topic)
CREATE OR REPLACE FUNCTION start_topic_progress(
  p_user_id UUID,
  p_topic_id UUID
)
RETURNS user_topic_progress AS $$
DECLARE
  result user_topic_progress;
BEGIN
  -- Insert or update (if already exists, just return existing)
  INSERT INTO user_topic_progress (user_id, topic_id, started_at)
  VALUES (p_user_id, p_topic_id, NOW())
  ON CONFLICT (user_id, topic_id) DO UPDATE
  SET updated_at = NOW()
  RETURNING * INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to complete a topic (called when user finishes a study guide)
CREATE OR REPLACE FUNCTION complete_topic_progress(
  p_user_id UUID,
  p_topic_id UUID,
  p_time_spent_seconds INTEGER DEFAULT 0
)
RETURNS TABLE(
  progress_id UUID,
  xp_earned INTEGER,
  is_first_completion BOOLEAN,
  topic_title TEXT
) AS $$
DECLARE
  v_progress_id UUID;
  v_xp_value INTEGER;
  v_is_first_completion BOOLEAN;
  v_topic_title TEXT;
  v_existing_completed_at TIMESTAMPTZ;
BEGIN
  -- Get topic XP value and title
  SELECT rt.xp_value, rt.title INTO v_xp_value, v_topic_title
  FROM recommended_topics rt
  WHERE rt.id = p_topic_id;

  IF v_xp_value IS NULL THEN
    v_xp_value := 50; -- Default XP
  END IF;

  -- Check if already completed
  SELECT utp.id, utp.completed_at INTO v_progress_id, v_existing_completed_at
  FROM user_topic_progress utp
  WHERE utp.user_id = p_user_id AND utp.topic_id = p_topic_id;

  -- Determine if this is first completion
  v_is_first_completion := v_existing_completed_at IS NULL;

  -- Only award XP on first completion
  IF v_is_first_completion THEN
    -- Upsert progress record
    INSERT INTO user_topic_progress (
      user_id,
      topic_id,
      started_at,
      completed_at,
      time_spent_seconds,
      xp_earned
    )
    VALUES (
      p_user_id,
      p_topic_id,
      COALESCE((SELECT started_at FROM user_topic_progress WHERE user_id = p_user_id AND topic_id = p_topic_id), NOW()),
      NOW(),
      p_time_spent_seconds,
      v_xp_value
    )
    ON CONFLICT (user_id, topic_id) DO UPDATE
    SET
      completed_at = NOW(),
      time_spent_seconds = user_topic_progress.time_spent_seconds + EXCLUDED.time_spent_seconds,
      xp_earned = v_xp_value,
      updated_at = NOW()
    RETURNING id INTO v_progress_id;
  ELSE
    -- Already completed - just update time spent, no additional XP
    UPDATE user_topic_progress
    SET
      time_spent_seconds = time_spent_seconds + p_time_spent_seconds,
      updated_at = NOW()
    WHERE user_id = p_user_id AND topic_id = p_topic_id
    RETURNING id INTO v_progress_id;

    v_xp_value := 0; -- No XP for repeat completions
  END IF;

  RETURN QUERY SELECT v_progress_id, v_xp_value, v_is_first_completion, v_topic_title;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's topic progress (for loading progress on topics list)
CREATE OR REPLACE FUNCTION get_user_topic_progress(
  p_user_id UUID,
  p_topic_ids UUID[] DEFAULT NULL
)
RETURNS TABLE(
  topic_id UUID,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  time_spent_seconds INTEGER,
  xp_earned INTEGER,
  is_completed BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    utp.topic_id,
    utp.started_at,
    utp.completed_at,
    utp.time_spent_seconds,
    utp.xp_earned,
    (utp.completed_at IS NOT NULL) AS is_completed
  FROM user_topic_progress utp
  WHERE utp.user_id = p_user_id
    AND (p_topic_ids IS NULL OR utp.topic_id = ANY(p_topic_ids));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get in-progress topics (for "Continue Learning" section)
CREATE OR REPLACE FUNCTION get_in_progress_topics(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 5
)
RETURNS TABLE(
  topic_id UUID,
  topic_title TEXT,
  topic_description TEXT,
  topic_category TEXT,
  started_at TIMESTAMPTZ,
  time_spent_seconds INTEGER,
  xp_value INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    rt.id AS topic_id,
    rt.title AS topic_title,
    rt.description AS topic_description,
    rt.category::TEXT AS topic_category,
    utp.started_at,
    utp.time_spent_seconds,
    COALESCE(rt.xp_value, 50) AS xp_value
  FROM user_topic_progress utp
  JOIN recommended_topics rt ON rt.id = utp.topic_id
  WHERE utp.user_id = p_user_id
    AND utp.completed_at IS NULL
    AND rt.is_active = true
  ORDER BY utp.updated_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get completed topics count by category
CREATE OR REPLACE FUNCTION get_user_completed_topics_by_category(
  p_user_id UUID
)
RETURNS TABLE(
  category TEXT,
  completed_count BIGINT,
  total_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    rt.category::TEXT,
    COUNT(CASE WHEN utp.completed_at IS NOT NULL THEN 1 END) AS completed_count,
    COUNT(rt.id) AS total_count
  FROM recommended_topics rt
  LEFT JOIN user_topic_progress utp ON utp.topic_id = rt.id AND utp.user_id = p_user_id
  WHERE rt.is_active = true
  GROUP BY rt.category
  ORDER BY rt.category;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comments for documentation
COMMENT ON TABLE user_topic_progress IS 'Tracks user progress on study topics including start time, completion, time spent, and XP earned';
COMMENT ON COLUMN user_topic_progress.started_at IS 'When the user first opened this topic';
COMMENT ON COLUMN user_topic_progress.completed_at IS 'When the user completed this topic (NULL if not completed)';
COMMENT ON COLUMN user_topic_progress.time_spent_seconds IS 'Total time spent studying this topic in seconds';
COMMENT ON COLUMN user_topic_progress.xp_earned IS 'XP earned from completing this topic (only awarded on first completion)';

COMMIT;
