-- =====================================================
-- Consolidated Migration: Learning Paths System
-- =====================================================
-- Source: Merge of 10 learning path migrations
-- Tables: 5 (learning_paths, learning_path_topics, learning_path_translations,
--            user_learning_path_progress, plus user_preferences modification)
-- Description: Curated learning journeys with topics, progress tracking,
--              multi-language support, and study mode recommendations
-- =====================================================

-- Dependencies: 0001_core_schema.sql (user_profiles, user_preferences)
--               0002_study_guides.sql (user_topic_progress)
--               0011_recommended_topics.sql (recommended_topics)

BEGIN;

-- =====================================================
-- SUMMARY: Migration creates comprehensive learning paths system
-- Features: 8 learning paths, progress tracking, translations, XP system
-- Enhancements applied inline: recommended_mode, disciple_level, input_type
-- =====================================================


-- =====================================================
-- SECTION 1: TABLES
-- =====================================================

-- -----------------------------------------------------
-- Table: user_topic_progress
-- -----------------------------------------------------
-- Tracks user progress on individual study topics for the gamification system
-- Part of Phase 1: Foundation & Progress Tracking

CREATE TABLE IF NOT EXISTS user_topic_progress (
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
CREATE INDEX IF NOT EXISTS idx_user_topic_progress_user_id ON user_topic_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_topic_progress_topic_id ON user_topic_progress(topic_id);
CREATE INDEX IF NOT EXISTS idx_user_topic_progress_completed ON user_topic_progress(user_id, completed_at) WHERE completed_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_topic_progress_in_progress ON user_topic_progress(user_id, started_at) WHERE completed_at IS NULL;

-- Enable RLS
ALTER TABLE user_topic_progress ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own topic progress" ON user_topic_progress
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own topic progress" ON user_topic_progress
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own topic progress" ON user_topic_progress
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role can manage all topic progress" ON user_topic_progress
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- Add comments for documentation
COMMENT ON TABLE user_topic_progress IS 'Tracks user progress on study topics including start time, completion, time spent, and XP earned';
COMMENT ON COLUMN user_topic_progress.started_at IS 'When the user first opened this topic';
COMMENT ON COLUMN user_topic_progress.completed_at IS 'When the user completed this topic (NULL if not completed)';
COMMENT ON COLUMN user_topic_progress.time_spent_seconds IS 'Total time spent studying this topic in seconds';
COMMENT ON COLUMN user_topic_progress.xp_earned IS 'XP earned from completing this topic (only awarded on first completion)';
COMMENT ON COLUMN recommended_topics.xp_value IS 'XP points awarded for completing this topic (default: 50)';

-- -----------------------------------------------------
-- Table: learning_paths
-- -----------------------------------------------------
-- Stores curated learning journey definitions with metadata

CREATE TABLE IF NOT EXISTS learning_paths (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug VARCHAR(100) UNIQUE NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  icon_name VARCHAR(50) DEFAULT 'school',
  color VARCHAR(20) DEFAULT '#6A4FB6',
  total_xp INTEGER DEFAULT 0,
  estimated_days INTEGER DEFAULT 7,
  difficulty_level VARCHAR(20) DEFAULT 'beginner' CHECK (difficulty_level IN ('beginner', 'intermediate', 'advanced')),
  disciple_level VARCHAR(20) DEFAULT 'follower' CHECK (disciple_level IN ('seeker', 'follower', 'disciple', 'leader')),
  recommended_mode TEXT CHECK (recommended_mode IN ('quick', 'standard', 'deep', 'lectio')),
  is_featured BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_learning_paths_active_featured ON learning_paths(is_active, is_featured, display_order);
CREATE INDEX IF NOT EXISTS idx_learning_paths_slug ON learning_paths(slug);
CREATE INDEX IF NOT EXISTS idx_learning_paths_disciple_level ON learning_paths(disciple_level);

-- Add comments for documentation
COMMENT ON TABLE learning_paths IS 'Curated learning journeys with recommended topics for structured Bible study progression';
COMMENT ON COLUMN learning_paths.recommended_mode IS 'Suggested study mode for optimal learning (quick/standard/deep/lectio)';
COMMENT ON COLUMN learning_paths.disciple_level IS 'Target spiritual maturity level (seeker/follower/disciple/leader)';
COMMENT ON COLUMN learning_paths.total_xp IS 'Sum of XP from all topics in this path (auto-calculated)';


-- -----------------------------------------------------
-- Table: learning_path_topics
-- -----------------------------------------------------
-- Maps recommended topics to learning paths with position and milestone markers

CREATE TABLE IF NOT EXISTS learning_path_topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  learning_path_id UUID NOT NULL REFERENCES learning_paths(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES recommended_topics(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  is_milestone BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(learning_path_id, topic_id),
  UNIQUE(learning_path_id, position)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_learning_path_topics_path_position ON learning_path_topics(learning_path_id, position);
CREATE INDEX IF NOT EXISTS idx_learning_path_topics_topic ON learning_path_topics(topic_id);

COMMENT ON TABLE learning_path_topics IS 'Junction table mapping topics to learning paths with sequential ordering';
COMMENT ON COLUMN learning_path_topics.is_milestone IS 'Marks significant progress points within the learning path';


-- -----------------------------------------------------
-- Table: learning_path_translations
-- -----------------------------------------------------
-- Multi-language translations for learning path titles and descriptions

CREATE TABLE IF NOT EXISTS learning_path_translations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  learning_path_id UUID NOT NULL REFERENCES learning_paths(id) ON DELETE CASCADE,
  lang_code VARCHAR(10) NOT NULL CHECK (lang_code IN ('en', 'hi', 'ml')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(learning_path_id, lang_code)
);

-- Add index for lookup by language
CREATE INDEX IF NOT EXISTS idx_learning_path_translations_lang ON learning_path_translations(learning_path_id, lang_code);

COMMENT ON TABLE learning_path_translations IS 'Multi-language translations for learning paths (English, Hindi, Malayalam)';


-- -----------------------------------------------------
-- Table: user_learning_path_progress
-- -----------------------------------------------------
-- Tracks user enrollment and progress through learning paths

CREATE TABLE IF NOT EXISTS user_learning_path_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  learning_path_id UUID NOT NULL REFERENCES learning_paths(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMPTZ DEFAULT NOW(),
  topics_completed INTEGER DEFAULT 0,
  current_topic_position INTEGER DEFAULT 0,
  total_xp_earned INTEGER DEFAULT 0,
  completed_at TIMESTAMPTZ,
  last_activity_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, learning_path_id)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_learning_path_progress_user ON user_learning_path_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_learning_path_progress_path ON user_learning_path_progress(learning_path_id);
CREATE INDEX IF NOT EXISTS idx_user_learning_path_progress_active ON user_learning_path_progress(user_id, completed_at) WHERE completed_at IS NULL;

COMMENT ON TABLE user_learning_path_progress IS 'Tracks user enrollment and completion progress through learning paths';
COMMENT ON COLUMN user_learning_path_progress.current_topic_position IS 'Zero-based position of next topic to study';

-- =====================================================
-- SECTION 2: FUNCTIONS
-- =====================================================

-- -----------------------------------------------------
-- Topic Progress Functions
-- -----------------------------------------------------

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

-- -----------------------------------------------------
-- Function: enroll_in_learning_path
-- -----------------------------------------------------
-- Enrolls a user in a learning path

CREATE OR REPLACE FUNCTION enroll_in_learning_path(
  p_user_id UUID,
  p_learning_path_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_progress_id UUID;
BEGIN
  -- Check if already enrolled
  SELECT id INTO v_progress_id
  FROM user_learning_path_progress
  WHERE user_id = p_user_id AND learning_path_id = p_learning_path_id;

  -- If already enrolled, return existing ID
  IF v_progress_id IS NOT NULL THEN
    RETURN v_progress_id;
  END IF;

  -- Create new enrollment
  INSERT INTO user_learning_path_progress (
    user_id,
    learning_path_id,
    enrolled_at,
    topics_completed,
    current_topic_position,
    total_xp_earned,
    last_activity_at
  )
  VALUES (
    p_user_id,
    p_learning_path_id,
    NOW(),
    0,
    0,
    0,
    NOW()
  )
  RETURNING id INTO v_progress_id;

  RETURN v_progress_id;
END;
$$;

COMMENT ON FUNCTION enroll_in_learning_path IS 'Enrolls user in learning path, returns progress ID (idempotent)';


-- -----------------------------------------------------
-- Function: get_user_learning_paths
-- -----------------------------------------------------
-- Gets all learning paths user is enrolled in

CREATE OR REPLACE FUNCTION get_user_learning_paths(
  p_user_id UUID,
  p_language VARCHAR DEFAULT 'en'
)
RETURNS TABLE(
  path_id UUID,
  slug VARCHAR,
  title TEXT,
  description TEXT,
  icon_name VARCHAR,
  color VARCHAR,
  total_xp INTEGER,
  estimated_days INTEGER,
  disciple_level VARCHAR,
  recommended_mode TEXT,
  progress_percentage INTEGER,
  topics_completed INTEGER,
  total_topics INTEGER,
  enrolled_at TIMESTAMPTZ,
  last_activity_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    lp.id AS path_id,
    lp.slug,
    COALESCE(lpt.title, lp.title) AS title,
    COALESCE(lpt.description, lp.description) AS description,
    lp.icon_name,
    lp.color,
    lp.total_xp,
    lp.estimated_days,
    lp.disciple_level,
    lp.recommended_mode,
    CASE
      WHEN (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id) = 0 THEN 0
      ELSE (ulpp.topics_completed * 100 / (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id))::INTEGER
    END AS progress_percentage,
    ulpp.topics_completed,
    (SELECT COUNT(*)::INTEGER FROM learning_path_topics WHERE learning_path_id = lp.id) AS total_topics,
    ulpp.enrolled_at,
    ulpp.last_activity_at,
    ulpp.completed_at
  FROM user_learning_path_progress ulpp
  JOIN learning_paths lp ON lp.id = ulpp.learning_path_id
  LEFT JOIN learning_path_translations lpt ON lpt.learning_path_id = lp.id AND lpt.lang_code = p_language
  WHERE ulpp.user_id = p_user_id
    AND lp.is_active = true
  ORDER BY ulpp.last_activity_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_user_learning_paths IS 'Returns all learning paths user is enrolled in with progress data';


-- -----------------------------------------------------
-- Function: get_available_learning_paths
-- -----------------------------------------------------
-- Gets all active learning paths available for enrollment

CREATE OR REPLACE FUNCTION get_available_learning_paths(
  p_user_id UUID DEFAULT NULL,
  p_language VARCHAR DEFAULT 'en',
  p_include_enrolled BOOLEAN DEFAULT true
)
RETURNS TABLE(
  path_id UUID,
  slug VARCHAR,
  title TEXT,
  description TEXT,
  icon_name VARCHAR,
  color VARCHAR,
  total_xp INTEGER,
  estimated_days INTEGER,
  disciple_level VARCHAR,
  recommended_mode TEXT,
  is_featured BOOLEAN,
  total_topics INTEGER,
  is_enrolled BOOLEAN,
  progress_percentage INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    lp.id AS path_id,
    lp.slug,
    COALESCE(lpt.title, lp.title) AS title,
    COALESCE(lpt.description, lp.description) AS description,
    lp.icon_name,
    lp.color,
    lp.total_xp,
    lp.estimated_days,
    lp.disciple_level,
    lp.recommended_mode,
    lp.is_featured,
    (SELECT COUNT(*)::INTEGER FROM learning_path_topics WHERE learning_path_id = lp.id) AS total_topics,
    CASE WHEN p_user_id IS NOT NULL THEN
      EXISTS(SELECT 1 FROM user_learning_path_progress WHERE user_id = p_user_id AND learning_path_id = lp.id)
    ELSE false END AS is_enrolled,
    CASE WHEN p_user_id IS NOT NULL THEN
      (SELECT (ulpp.topics_completed * 100 / GREATEST((SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id), 1))::INTEGER
       FROM user_learning_path_progress ulpp
       WHERE ulpp.user_id = p_user_id AND ulpp.learning_path_id = lp.id)
    ELSE 0 END AS progress_percentage
  FROM learning_paths lp
  LEFT JOIN learning_path_translations lpt ON lpt.learning_path_id = lp.id AND lpt.lang_code = p_language
  WHERE lp.is_active = true
    AND (p_include_enrolled OR NOT EXISTS(
      SELECT 1 FROM user_learning_path_progress
      WHERE user_id = p_user_id AND learning_path_id = lp.id
    ))
  ORDER BY lp.is_featured DESC, lp.display_order, lp.title;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_available_learning_paths IS 'Returns active learning paths with enrollment status. Set p_include_enrolled=false to exclude enrolled paths.';


-- -----------------------------------------------------
-- Function: get_learning_path_details (LATEST VERSION)
-- -----------------------------------------------------
-- Gets complete learning path details with topics and progress
-- Latest version includes: recommended_mode, input_type

CREATE OR REPLACE FUNCTION get_learning_path_details(
  p_path_id UUID,
  p_user_id UUID DEFAULT NULL,
  p_language VARCHAR DEFAULT 'en'
)
RETURNS TABLE(
  path_id UUID,
  slug VARCHAR,
  title TEXT,
  description TEXT,
  icon_name VARCHAR,
  color VARCHAR,
  total_xp INTEGER,
  estimated_days INTEGER,
  disciple_level VARCHAR,
  recommended_mode TEXT,
  is_enrolled BOOLEAN,
  progress_percentage INTEGER,
  topics_completed INTEGER,
  enrolled_at TIMESTAMPTZ,
  topics JSON
) AS $$
DECLARE
  v_topics JSON;
  v_is_enrolled BOOLEAN;
  v_progress_percentage INTEGER;
  v_topics_completed INTEGER;
  v_enrolled_at TIMESTAMPTZ;
BEGIN
  -- Get enrollment status
  IF p_user_id IS NOT NULL THEN
    SELECT
      true,
      ulpp.topics_completed,
      ulpp.enrolled_at
    INTO v_is_enrolled, v_topics_completed, v_enrolled_at
    FROM user_learning_path_progress ulpp
    WHERE ulpp.user_id = p_user_id AND ulpp.learning_path_id = p_path_id;
  END IF;

  v_is_enrolled := COALESCE(v_is_enrolled, false);
  v_topics_completed := COALESCE(v_topics_completed, 0);

  -- Get topics with progress (including input_type)
  SELECT json_agg(topic_data ORDER BY topic_data.position)
  INTO v_topics
  FROM (
    SELECT
      lpt.position,
      lpt.is_milestone,
      rt.id AS topic_id,
      COALESCE(rtt.title, rt.title) AS title,
      COALESCE(rtt.description, rt.description) AS description,
      COALESCE(rtt.category, rt.category) AS category,
      COALESCE(rt.input_type, 'topic') AS input_type,
      COALESCE(rt.xp_value, 50) AS xp_value,
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(SELECT 1 FROM user_topic_progress utp WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NOT NULL)
      ELSE false END AS is_completed,
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(SELECT 1 FROM user_topic_progress utp WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NULL)
      ELSE false END AS is_in_progress
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    LEFT JOIN recommended_topics_translations rtt ON rtt.topic_id = rt.id AND rtt.language_code = p_language
    WHERE lpt.learning_path_id = p_path_id
      AND rt.is_active = true
  ) topic_data;

  -- Calculate progress percentage
  v_progress_percentage := CASE
    WHEN (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = p_path_id) = 0 THEN 0
    ELSE (v_topics_completed * 100 / (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = p_path_id))::INTEGER
  END;

  RETURN QUERY
  SELECT
    lp.id AS path_id,
    lp.slug,
    COALESCE(lptt.title, lp.title) AS title,
    COALESCE(lptt.description, lp.description) AS description,
    lp.icon_name,
    lp.color,
    lp.total_xp,
    lp.estimated_days,
    lp.disciple_level,
    lp.recommended_mode,
    v_is_enrolled AS is_enrolled,
    v_progress_percentage AS progress_percentage,
    v_topics_completed AS topics_completed,
    v_enrolled_at AS enrolled_at,
    v_topics AS topics
  FROM learning_paths lp
  LEFT JOIN learning_path_translations lptt ON lptt.learning_path_id = lp.id AND lptt.lang_code = p_language
  WHERE lp.id = p_path_id AND lp.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_learning_path_details IS 'Returns complete learning path details with topics, progress, recommended_mode, and input_type';


-- -----------------------------------------------------
-- Function: update_learning_path_progress_on_topic_complete (TRIGGER FUNCTION)
-- -----------------------------------------------------
-- Automatically updates learning path progress when a topic is completed

CREATE OR REPLACE FUNCTION update_learning_path_progress_on_topic_complete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_learning_path_id UUID;
  v_topic_position INTEGER;
  v_total_topics INTEGER;
  v_topic_xp INTEGER;
BEGIN
  -- Only process when a topic is being marked as completed
  IF NEW.completed_at IS NOT NULL AND (OLD.completed_at IS NULL OR OLD IS NULL) THEN
    -- Find learning paths that include this topic where user is enrolled
    FOR v_learning_path_id IN
      SELECT DISTINCT lpt.learning_path_id
      FROM learning_path_topics lpt
      JOIN user_learning_path_progress ulpp ON ulpp.learning_path_id = lpt.learning_path_id
      WHERE lpt.topic_id = NEW.topic_id
        AND ulpp.user_id = NEW.user_id
        AND ulpp.completed_at IS NULL
    LOOP
      -- Get topic position and XP value
      SELECT lpt.position, COALESCE(rt.xp_value, 50)
      INTO v_topic_position, v_topic_xp
      FROM learning_path_topics lpt
      JOIN recommended_topics rt ON rt.id = lpt.topic_id
      WHERE lpt.learning_path_id = v_learning_path_id
        AND lpt.topic_id = NEW.topic_id;

      -- Get total topics in path
      SELECT COUNT(*) INTO v_total_topics
      FROM learning_path_topics
      WHERE learning_path_id = v_learning_path_id;

      -- Update progress
      UPDATE user_learning_path_progress
      SET
        topics_completed = topics_completed + 1,
        current_topic_position = CASE
          WHEN v_topic_position + 1 >= v_total_topics THEN v_topic_position
          ELSE v_topic_position + 1
        END,
        total_xp_earned = total_xp_earned + v_topic_xp,
        completed_at = CASE
          WHEN topics_completed + 1 >= v_total_topics THEN NOW()
          ELSE NULL
        END,
        last_activity_at = NOW()
      WHERE user_id = NEW.user_id
        AND learning_path_id = v_learning_path_id;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION update_learning_path_progress_on_topic_complete IS 'Trigger function to auto-update learning path progress when topics are completed';

-- Create trigger on user_topic_progress
-- NOTE: Skipped if user_topic_progress table doesn't exist yet
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_topic_progress'
  ) THEN
    DROP TRIGGER IF EXISTS trg_update_learning_path_progress ON user_topic_progress;
    CREATE TRIGGER trg_update_learning_path_progress
      AFTER INSERT OR UPDATE ON user_topic_progress
      FOR EACH ROW
      EXECUTE FUNCTION update_learning_path_progress_on_topic_complete();
  ELSE
    RAISE NOTICE 'Skipping trg_update_learning_path_progress: user_topic_progress table does not exist yet';
  END IF;
END $$;


-- -----------------------------------------------------
-- Function: compute_learning_path_total_xp
-- -----------------------------------------------------
-- Computes and updates total XP for a learning path

CREATE OR REPLACE FUNCTION compute_learning_path_total_xp(p_path_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_xp INTEGER;
BEGIN
  -- Calculate total XP from all topics in the path (50 XP per topic)
  SELECT COALESCE(COUNT(*) * 50, 0)
  INTO v_total_xp
  FROM learning_path_topics lpt
  JOIN recommended_topics rt ON rt.id = lpt.topic_id
  WHERE lpt.learning_path_id = p_path_id;

  -- Update learning path with calculated XP
  UPDATE learning_paths
  SET total_xp = v_total_xp,
      updated_at = NOW()
  WHERE id = p_path_id;

  RETURN v_total_xp;
END;
$$;

COMMENT ON FUNCTION compute_learning_path_total_xp IS 'Calculates and updates total XP for a learning path based on its topics';


-- -----------------------------------------------------
-- Function: get_in_progress_topics (ENHANCED VERSION)
-- -----------------------------------------------------
-- Returns in-progress topics with learning path information

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
  xp_value INTEGER,
  learning_path_id UUID,
  learning_path_name TEXT,
  position_in_path INTEGER,
  total_topics_in_path INTEGER,
  topics_completed_in_path INTEGER
) AS $$
BEGIN
  RETURN QUERY
  WITH in_progress AS (
    -- Get topics user has started but not completed
    SELECT
      rt.id AS topic_id,
      rt.title AS topic_title,
      rt.description AS topic_description,
      rt.category::TEXT AS topic_category,
      utp.started_at,
      utp.time_spent_seconds,
      COALESCE(rt.xp_value, 50) AS xp_value,
      utp.updated_at
    FROM user_topic_progress utp
    JOIN recommended_topics rt ON rt.id = utp.topic_id
    WHERE utp.user_id = p_user_id
      AND utp.completed_at IS NULL
      AND rt.is_active = true
  ),
  next_in_path AS (
    -- Get next topic from learning paths where user completed a topic
    SELECT DISTINCT ON (lp.id)
      rt.id AS topic_id,
      rt.title AS topic_title,
      rt.description AS topic_description,
      rt.category::TEXT AS topic_category,
      ulpp.last_activity_at AS started_at,
      0 AS time_spent_seconds,
      COALESCE(rt.xp_value, 50) AS xp_value,
      ulpp.last_activity_at AS updated_at,
      lp.id AS learning_path_id,
      lp.title AS learning_path_name,
      lpt.position + 1 AS position_in_path,
      (SELECT COUNT(*)::INTEGER FROM learning_path_topics lpt2 WHERE lpt2.learning_path_id = lp.id) AS total_topics_in_path,
      COALESCE(ulpp.topics_completed, 0)::INTEGER AS topics_completed_in_path
    FROM user_learning_path_progress ulpp
    JOIN learning_paths lp ON lp.id = ulpp.learning_path_id
    JOIN learning_path_topics lpt ON lpt.learning_path_id = lp.id
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    WHERE ulpp.user_id = p_user_id
      AND ulpp.completed_at IS NULL
      AND lp.is_active = true
      AND rt.is_active = true
      AND lpt.position = ulpp.current_topic_position
      AND NOT EXISTS (
        SELECT 1 FROM user_topic_progress utp
        WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id
      )
    ORDER BY lp.id, ulpp.last_activity_at DESC
  ),
  in_progress_with_path AS (
    -- Add learning path info to in-progress topics
    SELECT
      ip.topic_id,
      ip.topic_title,
      ip.topic_description,
      ip.topic_category,
      ip.started_at,
      ip.time_spent_seconds,
      ip.xp_value,
      ip.updated_at,
      lp.id AS learning_path_id,
      lp.title AS learning_path_name,
      lpt.position + 1 AS position_in_path,
      (SELECT COUNT(*)::INTEGER FROM learning_path_topics lpt2 WHERE lpt2.learning_path_id = lp.id) AS total_topics_in_path,
      COALESCE(ulpp.topics_completed, 0)::INTEGER AS topics_completed_in_path
    FROM in_progress ip
    LEFT JOIN learning_path_topics lpt ON lpt.topic_id = ip.topic_id
    LEFT JOIN learning_paths lp ON lp.id = lpt.learning_path_id AND lp.is_active = true
    LEFT JOIN user_learning_path_progress ulpp ON ulpp.learning_path_id = lp.id AND ulpp.user_id = p_user_id
    WHERE lp.id IS NULL OR ulpp.id IS NOT NULL
  ),
  combined AS (
    SELECT
      ipwp.topic_id,
      ipwp.topic_title,
      ipwp.topic_description,
      ipwp.topic_category,
      ipwp.started_at,
      ipwp.time_spent_seconds,
      ipwp.xp_value,
      ipwp.updated_at,
      ipwp.learning_path_id,
      ipwp.learning_path_name,
      ipwp.position_in_path,
      ipwp.total_topics_in_path,
      ipwp.topics_completed_in_path,
      1 AS priority
    FROM in_progress_with_path ipwp

    UNION ALL

    SELECT
      nip.topic_id,
      nip.topic_title,
      nip.topic_description,
      nip.topic_category,
      nip.started_at,
      nip.time_spent_seconds,
      nip.xp_value,
      nip.updated_at,
      nip.learning_path_id,
      nip.learning_path_name,
      nip.position_in_path,
      nip.total_topics_in_path,
      nip.topics_completed_in_path,
      2 AS priority
    FROM next_in_path nip
    WHERE NOT EXISTS (
      SELECT 1 FROM in_progress_with_path ipwp
      WHERE ipwp.topic_id = nip.topic_id
    )
  )
  SELECT DISTINCT ON (c.topic_id)
    c.topic_id,
    c.topic_title,
    c.topic_description,
    c.topic_category,
    c.started_at,
    c.time_spent_seconds,
    c.xp_value,
    c.learning_path_id,
    c.learning_path_name,
    c.position_in_path,
    c.total_topics_in_path,
    c.topics_completed_in_path
  FROM combined c
  ORDER BY c.topic_id, c.priority, c.updated_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_in_progress_topics IS 'Returns in-progress topics for Continue Learning with learning path context';


-- -----------------------------------------------------
-- Function: get_next_topic_in_learning_path
-- -----------------------------------------------------
-- Gets the next uncompleted topic in a learning path

CREATE OR REPLACE FUNCTION get_next_topic_in_learning_path(
  p_user_id UUID,
  p_learning_path_id UUID,
  p_language VARCHAR DEFAULT 'en'
)
RETURNS TABLE(
  topic_id UUID,
  title TEXT,
  description TEXT,
  category TEXT,
  xp_value INTEGER,
  topic_position INTEGER,
  total_topics INTEGER,
  is_completed BOOLEAN,
  is_in_progress BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    rt.id AS topic_id,
    COALESCE(rtt.title, rt.title) AS title,
    COALESCE(rtt.description, rt.description) AS description,
    rt.category::TEXT AS category,
    COALESCE(rt.xp_value, 50) AS xp_value,
    lpt.position + 1 AS topic_position,
    (SELECT COUNT(*)::INTEGER FROM learning_path_topics WHERE learning_path_id = p_learning_path_id) AS total_topics,
    EXISTS(
      SELECT 1 FROM user_topic_progress utp
      WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NOT NULL
    ) AS is_completed,
    EXISTS(
      SELECT 1 FROM user_topic_progress utp
      WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NULL
    ) AS is_in_progress
  FROM learning_path_topics lpt
  JOIN recommended_topics rt ON rt.id = lpt.topic_id
  LEFT JOIN recommended_topics_translations rtt ON rtt.topic_id = rt.id AND rtt.language_code = p_language
  WHERE lpt.learning_path_id = p_learning_path_id
    AND rt.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM user_topic_progress utp
      WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NOT NULL
    )
  ORDER BY lpt.position
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION get_next_topic_in_learning_path IS 'Returns the next uncompleted topic in a learning path for user';


-- =====================================================
-- SECTION 3: ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on all learning path tables
ALTER TABLE learning_paths ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_path_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_path_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_learning_path_progress ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------
-- RLS Policies: learning_paths
-- -----------------------------------------------------

-- Anyone can view active learning paths
CREATE POLICY learning_paths_select_active
  ON learning_paths FOR SELECT
  USING (is_active = true);

-- Only service_role can insert/update/delete
CREATE POLICY learning_paths_service_role_all
  ON learning_paths FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);


-- -----------------------------------------------------
-- RLS Policies: learning_path_topics
-- -----------------------------------------------------

-- Anyone can view topic mappings for active paths
CREATE POLICY learning_path_topics_select_all
  ON learning_path_topics FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM learning_paths lp
      WHERE lp.id = learning_path_id AND lp.is_active = true
    )
  );

-- Only service_role can insert/update/delete
CREATE POLICY learning_path_topics_service_role_all
  ON learning_path_topics FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);


-- -----------------------------------------------------
-- RLS Policies: learning_path_translations
-- -----------------------------------------------------

-- Anyone can view translations for active paths
CREATE POLICY learning_path_translations_select_all
  ON learning_path_translations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM learning_paths lp
      WHERE lp.id = learning_path_id AND lp.is_active = true
    )
  );

-- Only service_role can insert/update/delete
CREATE POLICY learning_path_translations_service_role_all
  ON learning_path_translations FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);


-- -----------------------------------------------------
-- RLS Policies: user_learning_path_progress
-- -----------------------------------------------------

-- Users can view their own progress
CREATE POLICY user_learning_path_progress_select_own
  ON user_learning_path_progress FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own progress (enrollment)
CREATE POLICY user_learning_path_progress_insert_own
  ON user_learning_path_progress FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own progress
CREATE POLICY user_learning_path_progress_update_own
  ON user_learning_path_progress FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Service role has full access
CREATE POLICY user_learning_path_progress_service_role_all
  ON user_learning_path_progress FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);


-- =====================================================
-- SECTION 4: SEED DATA (8 Learning Paths)
-- =====================================================

-- -----------------------------------------------------
-- Path 1: New Believer Essentials
-- -----------------------------------------------------

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000001',
  'new-believer-essentials',
  'New Believer Essentials',
  'Begin your faith journey with these foundational topics. Learn about Jesus, the Gospel, and how to grow in your relationship with God.',
  'auto_stories',
  '#4CAF50',
  14,
  'beginner',
  'seeker',
  'standard',
  true,
  1
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Path 1
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440001', 0, false),  -- Who is Jesus Christ?
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440002', 1, false),  -- What is the Gospel?
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440003', 2, true),   -- Assurance of Salvation (Milestone)
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440004', 3, false),  -- Why Read the Bible?
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440005', 4, false),  -- Importance of Prayer
  ('aaa00000-0000-0000-0000-000000000001', '111e8400-e29b-41d4-a716-446655440006', 5, true),   -- The Role of the Holy Spirit (Milestone)
  ('aaa00000-0000-0000-0000-000000000001', '333e8400-e29b-41d4-a716-446655440006', 6, true)    -- Baptism and Communion (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Path 1
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000001', 'hi', 'नए विश्वासी की मूल बातें', 'इन मूलभूत विषयों के साथ अपनी विश्वास यात्रा शुरू करें। यीशु, सुसमाचार और परमेश्वर के साथ अपने रिश्ते को बढ़ाने के बारे में जानें।'),
  ('aaa00000-0000-0000-0000-000000000001', 'ml', 'പുതിയ വിശ്വാസിയുടെ അടിസ്ഥാനങ്ങൾ', 'ഈ അടിസ്ഥാന വിഷയങ്ങളോടെ നിങ്ങളുടെ വിശ്വാസ യാത്ര ആരംഭിക്കുക. യേശുവിനെയും സുവിശേഷവും ദൈവവുമായുള്ള നിങ്ങളുടെ ബന്ധം വളർത്തുന്നതും പഠിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -----------------------------------------------------
-- Path 2: Growing in Discipleship
-- -----------------------------------------------------

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000002',
  'growing-in-discipleship',
  'Growing in Discipleship',
  'Deepen your faith and learn what it means to be a true disciple of Jesus. Explore spiritual disciplines, Christian living, and personal growth.',
  'trending_up',
  '#6A4FB6',
  21,
  'intermediate',
  'follower',
  'standard',
  true,
  2
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Path 2
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000002', '444e8400-e29b-41d4-a716-446655440001', 0, false),  -- What is Discipleship?
  ('aaa00000-0000-0000-0000-000000000002', '222e8400-e29b-41d4-a716-446655440001', 1, false),  -- Walking with God Daily
  ('aaa00000-0000-0000-0000-000000000002', '555e8400-e29b-41d4-a716-446655440001', 2, true),   -- Daily Devotions (Milestone)
  ('aaa00000-0000-0000-0000-000000000002', '444e8400-e29b-41d4-a716-446655440002', 3, false),  -- The Cost of Following Jesus
  ('aaa00000-0000-0000-0000-000000000002', '222e8400-e29b-41d4-a716-446655440002', 4, false),  -- Overcoming Temptation
  ('aaa00000-0000-0000-0000-000000000002', '555e8400-e29b-41d4-a716-446655440002', 5, false),  -- Fasting and Prayer
  ('aaa00000-0000-0000-0000-000000000002', '444e8400-e29b-41d4-a716-446655440003', 6, true),   -- Bearing Fruit (Milestone)
  ('aaa00000-0000-0000-0000-000000000002', '555e8400-e29b-41d4-a716-446655440004', 7, false),  -- Meditation on God''s Word
  ('aaa00000-0000-0000-0000-000000000002', '222e8400-e29b-41d4-a716-446655440006', 8, true),   -- Living a Holy Life (Milestone)
  ('aaa00000-0000-0000-0000-000000000002', '555e8400-e29b-41d4-a716-446655440006', 9, false),  -- How to Study the Bible
  ('aaa00000-0000-0000-0000-000000000002', '555e8400-e29b-41d4-a716-446655440007', 10, true)   -- Discerning God's Will (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Path 2
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000002', 'hi', 'शिष्यता में बढ़ना', 'अपने विश्वास को गहरा करें और जानें कि यीशु का सच्चा शिष्य होने का क्या अर्थ है। आध्यात्मिक अनुशासन, मसीही जीवन और व्यक्तिगत विकास का अन्वेषण करें।'),
  ('aaa00000-0000-0000-0000-000000000002', 'ml', 'ശിഷ്യത്വത്തിൽ വളരുക', 'നിങ്ങളുടെ വിശ്വാസം ആഴത്തിലാക്കുകയും യേശുവിന്റെ യഥാർത്ഥ ശിഷ്യനാകുക എന്നതിന്റെ അർത്ഥം പഠിക്കുകയും ചെയ്യുക. ആത്മീയ അച്ചടക്കം, ക്രിസ്തീയ ജീവിതം, വ്യക്തിഗത വളർച്ച എന്നിവ പര്യവേക്ഷണം ചെയ്യുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -----------------------------------------------------
-- Path 3: Serving & Mission
-- -----------------------------------------------------

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000003',
  'serving-and-mission',
  'Serving & Mission',
  'Discover your calling to serve others and share the Gospel. Learn about church community, spiritual gifts, and reaching the world for Christ.',
  'volunteer_activism',
  '#FF7043',
  18,
  'intermediate',
  'disciple',
  'standard',
  false,
  3
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Path 3
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000003', '333e8400-e29b-41d4-a716-446655440001', 0, false),  -- What is the Church?
  ('aaa00000-0000-0000-0000-000000000003', '333e8400-e29b-41d4-a716-446655440002', 1, false),  -- Why Fellowship Matters
  ('aaa00000-0000-0000-0000-000000000003', '333e8400-e29b-41d4-a716-446655440005', 2, true),   -- Spiritual Gifts (Milestone)
  ('aaa00000-0000-0000-0000-000000000003', '333e8400-e29b-41d4-a716-446655440003', 3, false),  -- Serving in the Church
  ('aaa00000-0000-0000-0000-000000000003', '888e8400-e29b-41d4-a716-446655440001', 4, false),  -- Being the Light
  ('aaa00000-0000-0000-0000-000000000003', '888e8400-e29b-41d4-a716-446655440002', 5, true),   -- Sharing Your Testimony (Milestone)
  ('aaa00000-0000-0000-0000-000000000003', '444e8400-e29b-41d4-a716-446655440004', 6, false),  -- The Great Commission
  ('aaa00000-0000-0000-0000-000000000003', '888e8400-e29b-41d4-a716-446655440004', 7, true),   -- Evangelism Made Simple (Milestone)
  ('aaa00000-0000-0000-0000-000000000003', '888e8400-e29b-41d4-a716-446655440006', 8, false)   -- Workplace as Mission
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Path 3
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000003', 'hi', 'सेवा और मिशन', 'दूसरों की सेवा करने और सुसमाचार साझा करने की अपनी बुलाहट को खोजें। कलीसिया समुदाय, आध्यात्मिक वरदानों और मसीह के लिए दुनिया तक पहुँचने के बारे में जानें।'),
  ('aaa00000-0000-0000-0000-000000000003', 'ml', 'സേവനവും മിഷനും', 'മറ്റുള്ളവരെ സേവിക്കാനും സുവിശേഷം പങ്കുവെക്കാനുമുള്ള നിങ്ങളുടെ വിളി കണ്ടെത്തുക. സഭാ സമൂഹം, ആത്മീയ വരങ്ങൾ, ക്രിസ്തുവിനായി ലോകത്തെ എത്തിച്ചേരൽ എന്നിവയെക്കുറിച്ച് പഠിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -----------------------------------------------------
-- Path 4: Defending Your Faith
-- -----------------------------------------------------

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000004',
  'defending-your-faith',
  'Defending Your Faith',
  'Build confidence in sharing and defending your beliefs with wisdom, grace, and biblical understanding. Learn to respond to tough questions.',
  'shield',
  '#3B82F6',
  21,
  'intermediate',
  'disciple',
  'deep',
  true,
  4
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Path 4
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440001', 0, false),  -- Why We Believe in One God
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440002', 1, false),  -- The Uniqueness of Jesus
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440003', 2, true),   -- Is the Bible Reliable? (Milestone)
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440004', 3, false),  -- Responding to Common Questions
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440005', 4, true),   -- Standing Firm (Milestone)
  ('aaa00000-0000-0000-0000-000000000004', '666e8400-e29b-41d4-a716-446655440006', 5, true)    -- Faith and Science (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Path 4
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000004', 'hi', 'अपने विश्वास की रक्षा करना', 'बुद्धि, अनुग्रह और बाइबिल की समझ के साथ अपने विश्वासों को साझा करने और उनकी रक्षा करने में आत्मविश्वास बनाएं। कठिन प्रश्नों का उत्तर देना सीखें।'),
  ('aaa00000-0000-0000-0000-000000000004', 'ml', 'നിങ്ങളുടെ വിശ്വാസം സംരക്ഷിക്കുക', 'ജ്ഞാനം, കൃപ, ബൈബിൾ ധാരണ എന്നിവയോടെ നിങ്ങളുടെ വിശ്വാസങ്ങൾ പങ്കുവെക്കുന്നതിലും സംരക്ഷിക്കുന്നതിലും ആത്മവിശ്വാസം വളർത്തുക. കഠിനമായ ചോദ്യങ്ങൾക്ക് ഉത്തരം നൽകാൻ പഠിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -----------------------------------------------------
-- Path 5: Faith & Family
-- -----------------------------------------------------

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000005',
  'faith-and-family',
  'Faith & Family',
  'Strengthen your relationships and build a Christ-centered home through biblical principles. Learn God''s design for marriage, parenting, and friendships.',
  'family_restroom',
  '#EC4899',
  25,
  'beginner',
  'follower',
  'standard',
  true,
  5
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Path 5
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440001', 0, false),  -- Marriage and Faith
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440002', 1, true),   -- Raising Children (Milestone)
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440003', 2, false),  -- Honoring Parents
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440004', 3, false),  -- Healthy Friendships
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440005', 4, true),   -- Resolving Conflicts (Milestone)
  ('aaa00000-0000-0000-0000-000000000005', '777e8400-e29b-41d4-a716-446655440006', 5, false)   -- Singleness and Contentment
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Path 5
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000005', 'hi', 'विश्वास और परिवार', 'बाइबिल के सिद्धांतों के माध्यम से अपने रिश्तों को मजबूत करें और मसीह-केंद्रित घर बनाएं। विवाह, पालन-पोषण और मित्रता के लिए परमेश्वर की योजना जानें।'),
  ('aaa00000-0000-0000-0000-000000000005', 'ml', 'വിശ്വാസവും കുടുംബവും', 'ബൈബിൾ തത്വങ്ങളിലൂടെ നിങ്ങളുടെ ബന്ധങ്ങൾ ശക്തിപ്പെടുത്തുകയും ക്രിസ്തു കേന്ദ്രീകൃത ഭവനം കെട്ടിപ്പടുക്കുകയും ചെയ്യുക. വിവാഹം, മാതാപിതൃത്വം, സൗഹൃദം എന്നിവയ്ക്കുള്ള ദൈവത്തിന്റെ രൂപകൽപ്പന പഠിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -----------------------------------------------------
-- Path 6: Deepening Your Walk
-- -----------------------------------------------------

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000006',
  'deepening-your-walk',
  'Deepening Your Walk',
  'Go deeper in your relationship with God through spiritual disciplines, fellowship, and generous living. Transform your daily habits into acts of worship.',
  'self_improvement',
  '#8B5CF6',
  28,
  'intermediate',
  'disciple',
  'deep',
  false,
  6
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Path 6
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000006', '555e8400-e29b-41d4-a716-446655440003', 0, false),  -- Worship as Lifestyle
  ('aaa00000-0000-0000-0000-000000000006', '555e8400-e29b-41d4-a716-446655440005', 1, false),  -- Journaling
  ('aaa00000-0000-0000-0000-000000000006', '222e8400-e29b-41d4-a716-446655440004', 2, true),   -- Fellowship (Milestone)
  ('aaa00000-0000-0000-0000-000000000006', '222e8400-e29b-41d4-a716-446655440003', 3, false),  -- Forgiveness
  ('aaa00000-0000-0000-0000-000000000006', '222e8400-e29b-41d4-a716-446655440005', 4, false),  -- Generosity
  ('aaa00000-0000-0000-0000-000000000006', '333e8400-e29b-41d4-a716-446655440004', 5, true)    -- Unity (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Path 6
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000006', 'hi', 'अपनी चाल को गहरा करना', 'आध्यात्मिक अनुशासन, संगति और उदार जीवन के माध्यम से परमेश्वर के साथ अपने रिश्ते में और गहरे जाएं। अपनी दैनिक आदतों को आराधना के कार्यों में बदलें।'),
  ('aaa00000-0000-0000-0000-000000000006', 'ml', 'നിങ്ങളുടെ നടത്തം ആഴത്തിലാക്കുക', 'ആത്മീയ അച്ചടക്കം, കൂട്ടായ്മ, ഔദാര്യമുള്ള ജീവിതം എന്നിവയിലൂടെ ദൈവവുമായുള്ള നിങ്ങളുടെ ബന്ധത്തിൽ കൂടുതൽ ആഴത്തിൽ പോകുക. നിങ്ങളുടെ ദൈനംദിന ശീലങ്ങളെ ആരാധനയുടെ പ്രവൃത്തികളാക്കി മാറ്റുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -----------------------------------------------------
-- Path 7: Heart for the World
-- -----------------------------------------------------

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000007',
  'heart-for-the-world',
  'Heart for the World',
  'Develop a global perspective on missions and learn to impact your community and the nations for Christ. Become a multiplying disciple.',
  'public',
  '#F59E0B',
  21,
  'intermediate',
  'leader',
  'standard',
  false,
  7
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Path 7
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000007', '888e8400-e29b-41d4-a716-446655440003', 0, false),  -- Serving Poor
  ('aaa00000-0000-0000-0000-000000000007', '888e8400-e29b-41d4-a716-446655440005', 1, true),   -- Praying for Nations (Milestone)
  ('aaa00000-0000-0000-0000-000000000007', '444e8400-e29b-41d4-a716-446655440005', 2, false),  -- Mentoring
  ('aaa00000-0000-0000-0000-000000000007', '444e8400-e29b-41d4-a716-446655440004', 3, true)    -- Great Commission (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Path 7
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000007', 'hi', 'दुनिया के लिए दिल', 'मिशन पर एक वैश्विक दृष्टिकोण विकसित करें और मसीह के लिए अपने समुदाय और राष्ट्रों को प्रभावित करना सीखें। एक गुणा करने वाले शिष्य बनें।'),
  ('aaa00000-0000-0000-0000-000000000007', 'ml', 'ലോകത്തിനായുള്ള ഹൃദയം', 'മിഷനുകളെക്കുറിച്ച് ആഗോള വീക്ഷണം വികസിപ്പിക്കുകയും ക്രിസ്തുവിനായി നിങ്ങളുടെ സമൂഹത്തെയും രാഷ്ട്രങ്ങളെയും സ്വാധീനിക്കാൻ പഠിക്കുകയും ചെയ്യുക. ഒരു ഗുണിക്കുന്ന ശിഷ്യനാകുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -----------------------------------------------------
-- Path 8: Faith & Reason (NEW - from 20260106000002)
-- -----------------------------------------------------

INSERT INTO learning_paths (
  id, slug, title, description, icon_name, color,
  estimated_days, difficulty_level, disciple_level, recommended_mode, is_featured, display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000010',
  'faith-and-reason',
  'Faith & Reason',
  'Explore Christianity''s toughest questions with biblical wisdom and theological depth. Build confidence in your faith through understanding God''s answers to life''s biggest questions.',
  'psychology',
  '#F59E0B',
  28,
  'advanced',
  'disciple',
  'deep',
  true,
  10
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Path 8 (12 topics)
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440001', 0, false),  -- Does God Exist?
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440002', 1, true),   -- Why Evil and Suffering? (Milestone)
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440003', 2, false),  -- Jesus Only Way?
  ('aaa00000-0000-0000-0000-000000000010', '666e8400-e29b-41d4-a716-446655440003', 3, false),  -- Is Bible Reliable?
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440004', 4, false),  -- Those Who Never Hear?
  ('aaa00000-0000-0000-0000-000000000010', '666e8400-e29b-41d4-a716-446655440006', 5, true),   -- Faith and Science (Milestone)
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440005', 6, false),  -- What is Trinity?
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440006', 7, false),  -- Unanswered Prayers?
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440007', 8, true),   -- Predestination vs Free Will (Milestone)
  ('aaa00000-0000-0000-0000-000000000010', '999e8400-e29b-41d4-a716-446655440002', 9, false),  -- Heaven and Eternal Life
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440008', 10, false), -- Many Denominations?
  ('aaa00000-0000-0000-0000-000000000010', 'AAA00000-e29b-41d4-a716-446655440009', 11, true)   -- Purpose in Life? (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Path 8
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000010', 'hi', 'विश्वास और तर्क', 'बाइबिल की बुद्धि और धर्मशास्त्रीय गहराई के साथ ईसाई धर्म के सबसे कठिन सवालों का पता लगाएं। जीवन के सबसे बड़े सवालों के परमेश्वर के उत्तरों को समझकर अपने विश्वास में आत्मविश्वास बनाएं।'),
  ('aaa00000-0000-0000-0000-000000000010', 'ml', 'വിശ്വാസവും യുക്തിയും', 'ബൈബിൾ ജ്ഞാനവും ദൈവശാസ്ത്രപരമായ ആഴവും ഉപയോഗിച്ച് ക്രിസ്തുമതത്തിന്റെ ഏറ്റവും പ്രയാസകരമായ ചോദ്യങ്ങൾ പര്യവേക്ഷണം ചെയ്യുക. ജീവിതത്തിലെ ഏറ്റവും വലിയ ചോദ്യങ്ങൾക്കുള്ള ദൈവത്തിന്റെ ഉത്തരങ്ങൾ മനസ്സിലാക്കി നിങ്ങളുടെ വിശ്വാസത്തിൽ ആത്മവിശ്വാസം വളർത്തുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -----------------------------------------------------
-- Path 8: Rooted in Christ
-- -----------------------------------------------------

INSERT INTO learning_paths (
  id,
  slug,
  title,
  description,
  icon_name,
  color,
  estimated_days,
  difficulty_level,
  disciple_level,
  recommended_mode,
  is_featured,
  display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000008',
  'rooted-in-christ',
  'Rooted in Christ',
  'Establish your foundation by understanding your identity in Christ, living by grace, and building unshakeable faith.',
  'park',
  '#10B981',
  21,
  'beginner',
  'follower',
  'standard',
  true,
  8
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Path 8
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000008', '111e8400-e29b-41d4-a716-446655440007', 0, false),  -- Your Identity in Christ
  ('aaa00000-0000-0000-0000-000000000008', '111e8400-e29b-41d4-a716-446655440008', 1, true),   -- Understanding God's Grace (Milestone)
  ('aaa00000-0000-0000-0000-000000000008', '222e8400-e29b-41d4-a716-446655440008', 2, false),  -- Dealing with Doubt and Fear
  ('aaa00000-0000-0000-0000-000000000008', '444e8400-e29b-41d4-a716-446655440006', 3, false),  -- Living by Faith, Not Feelings
  ('aaa00000-0000-0000-0000-000000000008', '222e8400-e29b-41d4-a716-446655440007', 4, true)    -- Spiritual Warfare (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Path 8
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000008', 'hi', 'मसीह में जड़ित', 'मसीह में अपनी पहचान को समझकर, कृपा से जीकर, और अडिग विश्वास बनाकर अपनी नींव स्थापित करें।'),
  ('aaa00000-0000-0000-0000-000000000008', 'ml', 'ക്രിസ്തുവിൽ വേരൂന്നിയ', 'ക്രിസ്തുവിലുള്ള നിങ്ങളുടെ സ്വത്വം മനസ്സിലാക്കി, കൃപയാൽ ജീവിച്ച്, ഇളക്കമില്ലാത്ത വിശ്വാസം കെട്ടിപ്പടുത്ത് നിങ്ങളുടെ അടിത്തറ സ്ഥാപിക്കുക.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- -----------------------------------------------------
-- Path 9: Eternal Perspective
-- -----------------------------------------------------

INSERT INTO learning_paths (
  id,
  slug,
  title,
  description,
  icon_name,
  color,
  estimated_days,
  difficulty_level,
  disciple_level,
  recommended_mode,
  is_featured,
  display_order
)
VALUES (
  'aaa00000-0000-0000-0000-000000000009',
  'eternal-perspective',
  'Eternal Perspective',
  'Gain hope and purpose by understanding God''s eternal plan - the return of Christ, heaven, and our glorious future.',
  'wb_sunny',
  '#F97316',
  14,
  'intermediate',
  'disciple',
  'standard',
  false,
  9
)
ON CONFLICT (id) DO NOTHING;

-- Topics for Path 9
INSERT INTO learning_path_topics (learning_path_id, topic_id, position, is_milestone)
VALUES
  ('aaa00000-0000-0000-0000-000000000009', '999e8400-e29b-41d4-a716-446655440001', 0, false),  -- The Return of Christ
  ('aaa00000-0000-0000-0000-000000000009', '999e8400-e29b-41d4-a716-446655440002', 1, true),   -- Heaven and Eternal Life (Milestone)
  ('aaa00000-0000-0000-0000-000000000009', '666e8400-e29b-41d4-a716-446655440005', 2, false),  -- Standing Firm in Persecution
  ('aaa00000-0000-0000-0000-000000000009', '444e8400-e29b-41d4-a716-446655440006', 3, true)    -- Living by Faith, Not Feelings (Milestone)
ON CONFLICT (learning_path_id, topic_id) DO NOTHING;

-- Translations for Path 9
INSERT INTO learning_path_translations (learning_path_id, lang_code, title, description)
VALUES
  ('aaa00000-0000-0000-0000-000000000009', 'hi', 'अनंत दृष्टिकोण', 'परमेश्वर की अनंत योजना को समझकर आशा और उद्देश्य प्राप्त करें - मसीह की वापसी, स्वर्ग, और हमारा महिमामय भविष्य।'),
  ('aaa00000-0000-0000-0000-000000000009', 'ml', 'നിത്യ വീക്ഷണം', 'ദൈവത്തിന്റെ നിത്യ പദ്ധതി മനസ്സിലാക്കി പ്രത്യാശയും ഉദ്ദേശ്യവും നേടുക - ക്രിസ്തുവിന്റെ മടങ്ങിവരവ്, സ്വർഗം, നമ്മുടെ മഹത്തായ ഭാവി.')
ON CONFLICT (learning_path_id, lang_code) DO NOTHING;


-- =====================================================
-- SECTION 5: COMPUTE TOTAL XP FOR ALL PATHS
-- =====================================================

-- Calculate and update total XP for all 10 learning paths
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000001');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000002');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000003');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000004');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000005');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000006');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000007');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000008');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000009');
SELECT compute_learning_path_total_xp('aaa00000-0000-0000-0000-000000000010');


-- =====================================================
-- SECTION 6: VERIFICATION
-- =====================================================

DO $$
DECLARE
  total_paths INTEGER;
  total_topics INTEGER;
  total_translations INTEGER;
  paths_with_xp INTEGER;
BEGIN
  -- Count learning paths
  SELECT COUNT(*) INTO total_paths FROM learning_paths WHERE is_active = true;

  -- Count topic mappings
  SELECT COUNT(*) INTO total_topics FROM learning_path_topics;

  -- Count translations
  SELECT COUNT(*) INTO total_translations FROM learning_path_translations;

  -- Count paths with computed XP
  SELECT COUNT(*) INTO paths_with_xp FROM learning_paths WHERE total_xp > 0;

  RAISE NOTICE '';
  RAISE NOTICE '=== Learning Paths Migration Summary ===';
  RAISE NOTICE 'Learning paths created: %', total_paths;
  RAISE NOTICE 'Topic mappings created: %', total_topics;
  RAISE NOTICE 'Translations created: %', total_translations;
  RAISE NOTICE 'Paths with computed XP: %', paths_with_xp;
  RAISE NOTICE '';

  IF total_paths != 10 THEN
    RAISE WARNING 'Expected 10 learning paths, found %', total_paths;
  ELSE
    RAISE NOTICE '✅ All 10 learning paths created successfully';
  END IF;

  IF paths_with_xp != 10 THEN
    RAISE WARNING 'Expected 10 paths with XP, found %', paths_with_xp;
  ELSE
    RAISE NOTICE '✅ Total XP computed for all paths';
  END IF;
END $$;

COMMIT;
