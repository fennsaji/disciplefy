-- Create Learning Paths System
-- Part of Phase 3: Study Topics Page Revamp
-- Learning paths are curated collections of topics for structured learning journeys

BEGIN;

-- =============================================================================
-- TABLE: learning_paths
-- =============================================================================
-- Main table for learning paths (curated collections of topics)

CREATE TABLE learning_paths (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug VARCHAR(100) UNIQUE NOT NULL, -- URL-friendly identifier
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  icon_name VARCHAR(50) DEFAULT 'school', -- Material icon name
  color VARCHAR(20) DEFAULT '#6A4FB6', -- Primary color for UI
  total_xp INTEGER DEFAULT 0, -- Total XP available in this path (computed)
  estimated_days INTEGER DEFAULT 7, -- Estimated days to complete
  difficulty_level VARCHAR(20) DEFAULT 'beginner' CHECK (difficulty_level IN ('beginner', 'intermediate', 'advanced')),
  is_featured BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_learning_paths_slug ON learning_paths(slug);
CREATE INDEX idx_learning_paths_active ON learning_paths(is_active) WHERE is_active = true;
CREATE INDEX idx_learning_paths_featured ON learning_paths(is_featured) WHERE is_featured = true;
CREATE INDEX idx_learning_paths_display_order ON learning_paths(display_order);

-- Enable RLS
ALTER TABLE learning_paths ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Anyone can read active learning paths" ON learning_paths
  FOR SELECT USING (is_active = true);

CREATE POLICY "Service role can manage learning paths" ON learning_paths
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- =============================================================================
-- TABLE: learning_path_topics
-- =============================================================================
-- Junction table linking learning paths to topics with ordering

CREATE TABLE learning_path_topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  learning_path_id UUID NOT NULL REFERENCES learning_paths(id) ON DELETE CASCADE,
  topic_id UUID NOT NULL REFERENCES recommended_topics(id) ON DELETE CASCADE,
  position INTEGER NOT NULL DEFAULT 0, -- Order within the path
  is_milestone BOOLEAN DEFAULT false, -- Marks important checkpoints
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Each topic can only appear once in a path
  CONSTRAINT unique_path_topic UNIQUE(learning_path_id, topic_id)
);

-- Create indexes for performance
CREATE INDEX idx_learning_path_topics_path ON learning_path_topics(learning_path_id);
CREATE INDEX idx_learning_path_topics_topic ON learning_path_topics(topic_id);
CREATE INDEX idx_learning_path_topics_position ON learning_path_topics(learning_path_id, position);

-- Enable RLS
ALTER TABLE learning_path_topics ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Anyone can read learning path topics" ON learning_path_topics
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage learning path topics" ON learning_path_topics
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- =============================================================================
-- TABLE: learning_path_translations
-- =============================================================================
-- Translations for learning paths

CREATE TABLE learning_path_translations (
  learning_path_id UUID NOT NULL REFERENCES learning_paths(id) ON DELETE CASCADE,
  lang_code VARCHAR(10) NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (learning_path_id, lang_code)
);

-- Create index on lang_code for faster lookups
CREATE INDEX idx_learning_path_translations_lang ON learning_path_translations(lang_code);

-- Enable RLS
ALTER TABLE learning_path_translations ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Anyone can read learning path translations" ON learning_path_translations
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage learning path translations" ON learning_path_translations
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- =============================================================================
-- TABLE: user_learning_path_progress
-- =============================================================================
-- Tracks user enrollment and progress through learning paths

CREATE TABLE user_learning_path_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  learning_path_id UUID NOT NULL REFERENCES learning_paths(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMPTZ DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  current_topic_position INTEGER DEFAULT 0, -- Current position in the path
  topics_completed INTEGER DEFAULT 0,
  total_xp_earned INTEGER DEFAULT 0,
  last_activity_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Each user can only enroll in a path once
  CONSTRAINT unique_user_learning_path UNIQUE(user_id, learning_path_id)
);

-- Create indexes for performance
CREATE INDEX idx_user_learning_path_user ON user_learning_path_progress(user_id);
CREATE INDEX idx_user_learning_path_path ON user_learning_path_progress(learning_path_id);
CREATE INDEX idx_user_learning_path_active ON user_learning_path_progress(user_id, started_at) WHERE completed_at IS NULL;
CREATE INDEX idx_user_learning_path_completed ON user_learning_path_progress(user_id, completed_at) WHERE completed_at IS NOT NULL;

-- Enable RLS
ALTER TABLE user_learning_path_progress ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own learning path progress" ON user_learning_path_progress
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own learning path progress" ON user_learning_path_progress
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own learning path progress" ON user_learning_path_progress
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role can manage all learning path progress" ON user_learning_path_progress
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Function to enroll a user in a learning path
CREATE OR REPLACE FUNCTION enroll_in_learning_path(
  p_user_id UUID,
  p_learning_path_id UUID
)
RETURNS user_learning_path_progress AS $$
DECLARE
  result user_learning_path_progress;
  v_path_exists BOOLEAN;
BEGIN
  -- Check if path exists and is active
  SELECT EXISTS(
    SELECT 1 FROM learning_paths WHERE id = p_learning_path_id AND is_active = true
  ) INTO v_path_exists;

  IF NOT v_path_exists THEN
    RAISE EXCEPTION 'Learning path not found or inactive';
  END IF;

  -- Insert or update enrollment
  INSERT INTO user_learning_path_progress (
    user_id,
    learning_path_id,
    enrolled_at,
    started_at
  )
  VALUES (
    p_user_id,
    p_learning_path_id,
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id, learning_path_id) DO UPDATE
  SET
    started_at = COALESCE(user_learning_path_progress.started_at, NOW()),
    last_activity_at = NOW(),
    updated_at = NOW()
  RETURNING * INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's enrolled learning paths with progress
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
  difficulty_level VARCHAR,
  is_featured BOOLEAN,
  topics_count INTEGER,
  topics_completed INTEGER,
  progress_percentage INTEGER,
  enrolled_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  current_topic_position INTEGER
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
    lp.difficulty_level,
    lp.is_featured,
    (SELECT COUNT(*)::INTEGER FROM learning_path_topics WHERE learning_path_id = lp.id) AS topics_count,
    COALESCE(ulpp.topics_completed, 0) AS topics_completed,
    CASE
      WHEN (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id) = 0 THEN 0
      ELSE (COALESCE(ulpp.topics_completed, 0) * 100 / (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id))::INTEGER
    END AS progress_percentage,
    ulpp.enrolled_at,
    ulpp.started_at,
    ulpp.completed_at,
    COALESCE(ulpp.current_topic_position, 0) AS current_topic_position
  FROM user_learning_path_progress ulpp
  JOIN learning_paths lp ON lp.id = ulpp.learning_path_id
  LEFT JOIN learning_path_translations lpt ON lpt.learning_path_id = lp.id AND lpt.lang_code = p_language
  WHERE ulpp.user_id = p_user_id
    AND lp.is_active = true
  ORDER BY ulpp.last_activity_at DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all available learning paths (for discovery)
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
  difficulty_level VARCHAR,
  is_featured BOOLEAN,
  topics_count INTEGER,
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
    lp.difficulty_level,
    lp.is_featured,
    (SELECT COUNT(*)::INTEGER FROM learning_path_topics WHERE learning_path_id = lp.id) AS topics_count,
    CASE WHEN p_user_id IS NULL THEN false
         ELSE EXISTS(SELECT 1 FROM user_learning_path_progress WHERE user_id = p_user_id AND learning_path_id = lp.id)
    END AS is_enrolled,
    CASE
      WHEN p_user_id IS NULL THEN 0
      WHEN (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id) = 0 THEN 0
      ELSE COALESCE(
        (SELECT (ulpp.topics_completed * 100 / (SELECT COUNT(*) FROM learning_path_topics WHERE learning_path_id = lp.id))::INTEGER
         FROM user_learning_path_progress ulpp
         WHERE ulpp.user_id = p_user_id AND ulpp.learning_path_id = lp.id),
        0
      )
    END AS progress_percentage
  FROM learning_paths lp
  LEFT JOIN learning_path_translations lpt ON lpt.learning_path_id = lp.id AND lpt.lang_code = p_language
  WHERE lp.is_active = true
    AND (p_include_enrolled OR p_user_id IS NULL OR NOT EXISTS(
      SELECT 1 FROM user_learning_path_progress WHERE user_id = p_user_id AND learning_path_id = lp.id
    ))
  ORDER BY lp.is_featured DESC, lp.display_order ASC, lp.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get learning path details with topics
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
  difficulty_level VARCHAR,
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

  -- Get topics with progress
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
      COALESCE(rt.xp_value, 50) AS xp_value,
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(SELECT 1 FROM user_topic_progress utp WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NOT NULL)
      ELSE false END AS is_completed,
      CASE WHEN p_user_id IS NOT NULL THEN
        EXISTS(SELECT 1 FROM user_topic_progress utp WHERE utp.user_id = p_user_id AND utp.topic_id = rt.id AND utp.completed_at IS NULL)
      ELSE false END AS is_in_progress
    FROM learning_path_topics lpt
    JOIN recommended_topics rt ON rt.id = lpt.topic_id
    LEFT JOIN recommended_topics_translations rtt ON rtt.topic_id = rt.id AND rtt.lang_code = p_language
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
    lp.difficulty_level,
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

-- Function to update learning path progress when a topic is completed
CREATE OR REPLACE FUNCTION update_learning_path_progress_on_topic_complete()
RETURNS TRIGGER AS $$
DECLARE
  v_path_id UUID;
  v_path_position INTEGER;
  v_total_topics INTEGER;
  v_completed_in_path INTEGER;
BEGIN
  -- Only process on completion (when completed_at changes from NULL to non-NULL)
  IF OLD.completed_at IS NULL AND NEW.completed_at IS NOT NULL THEN
    -- Find all learning paths that contain this topic
    FOR v_path_id, v_path_position IN
      SELECT learning_path_id, position
      FROM learning_path_topics
      WHERE topic_id = NEW.topic_id
    LOOP
      -- Count total topics in path
      SELECT COUNT(*) INTO v_total_topics
      FROM learning_path_topics
      WHERE learning_path_id = v_path_id;

      -- Count completed topics in path for this user
      SELECT COUNT(*) INTO v_completed_in_path
      FROM learning_path_topics lpt
      JOIN user_topic_progress utp ON utp.topic_id = lpt.topic_id
      WHERE lpt.learning_path_id = v_path_id
        AND utp.user_id = NEW.user_id
        AND utp.completed_at IS NOT NULL;

      -- Update user's learning path progress
      UPDATE user_learning_path_progress
      SET
        topics_completed = v_completed_in_path,
        total_xp_earned = total_xp_earned + COALESCE(NEW.xp_earned, 0),
        current_topic_position = GREATEST(current_topic_position, v_path_position + 1),
        completed_at = CASE WHEN v_completed_in_path >= v_total_topics THEN NOW() ELSE NULL END,
        last_activity_at = NOW(),
        updated_at = NOW()
      WHERE user_id = NEW.user_id AND learning_path_id = v_path_id;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update learning path progress
CREATE TRIGGER trigger_update_learning_path_on_topic_complete
  AFTER UPDATE ON user_topic_progress
  FOR EACH ROW
  EXECUTE FUNCTION update_learning_path_progress_on_topic_complete();

-- Function to compute and update total_xp for a learning path
CREATE OR REPLACE FUNCTION compute_learning_path_total_xp(p_path_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_total_xp INTEGER;
BEGIN
  SELECT COALESCE(SUM(COALESCE(rt.xp_value, 50)), 0)::INTEGER
  INTO v_total_xp
  FROM learning_path_topics lpt
  JOIN recommended_topics rt ON rt.id = lpt.topic_id
  WHERE lpt.learning_path_id = p_path_id;

  UPDATE learning_paths SET total_xp = v_total_xp, updated_at = NOW()
  WHERE id = p_path_id;

  RETURN v_total_xp;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comments for documentation
COMMENT ON TABLE learning_paths IS 'Curated learning paths that group related topics for structured learning journeys';
COMMENT ON TABLE learning_path_topics IS 'Junction table linking learning paths to topics with ordering';
COMMENT ON TABLE learning_path_translations IS 'Multilingual translations for learning paths';
COMMENT ON TABLE user_learning_path_progress IS 'Tracks user enrollment and progress through learning paths';

COMMIT;
