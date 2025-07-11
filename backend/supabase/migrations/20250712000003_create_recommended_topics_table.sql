-- Create recommended_topics table
-- This table references the study_guides table to provide recommended topics

BEGIN;

-- Create the recommended_topics table
CREATE TABLE recommended_topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  study_guide_id UUID REFERENCES study_guides(id) ON DELETE CASCADE,
  category VARCHAR(100) NOT NULL,
  difficulty_level VARCHAR(20) NOT NULL CHECK (difficulty_level IN ('beginner', 'intermediate', 'advanced')),
  estimated_duration VARCHAR(50) NOT NULL,
  tags TEXT[] NOT NULL DEFAULT '{}',
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure unique study guide per recommendation (only when study_guide_id is not null)
  CONSTRAINT unique_study_guide_recommendation UNIQUE(study_guide_id)
);

-- Create indexes for performance
CREATE INDEX idx_recommended_topics_category ON recommended_topics(category);
CREATE INDEX idx_recommended_topics_difficulty ON recommended_topics(difficulty_level);
CREATE INDEX idx_recommended_topics_active ON recommended_topics(is_active) WHERE is_active = true;
CREATE INDEX idx_recommended_topics_order ON recommended_topics(display_order, created_at);
CREATE INDEX idx_recommended_topics_study_guide ON recommended_topics(study_guide_id);

-- Enable RLS on recommended_topics
ALTER TABLE recommended_topics ENABLE ROW LEVEL SECURITY;

-- Create RLS policy for public read access (anyone can read recommended topics)
CREATE POLICY "Anyone can read recommended topics" ON recommended_topics
  FOR SELECT USING (is_active = true);

-- Create RLS policy for admin management (service role can manage)
CREATE POLICY "Service role can manage recommended topics" ON recommended_topics
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- Add comments for documentation
COMMENT ON TABLE recommended_topics IS 'Curated recommended topics that reference study guides from the cache';
COMMENT ON COLUMN recommended_topics.study_guide_id IS 'References a study guide in the study_guides table';
COMMENT ON COLUMN recommended_topics.category IS 'Topic category for filtering and organization';
COMMENT ON COLUMN recommended_topics.difficulty_level IS 'Difficulty level: beginner, intermediate, or advanced';
COMMENT ON COLUMN recommended_topics.estimated_duration IS 'Estimated time to complete the study';
COMMENT ON COLUMN recommended_topics.tags IS 'Array of tags for enhanced filtering and search';
COMMENT ON COLUMN recommended_topics.display_order IS 'Order for displaying topics (lower numbers first)';
COMMENT ON COLUMN recommended_topics.is_active IS 'Whether this topic is currently active/visible';

-- Add title column to recommended_topics table
ALTER TABLE recommended_topics ADD COLUMN title TEXT;
ALTER TABLE recommended_topics ADD COLUMN description TEXT;

-- Create a function to get recommended topics with study guide data
CREATE OR REPLACE FUNCTION get_recommended_topics(
  p_category TEXT DEFAULT NULL,
  p_difficulty TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
  id UUID,
  title TEXT,
  description TEXT,
  category VARCHAR(100),
  difficulty_level VARCHAR(20),
  estimated_duration VARCHAR(50),
  tags TEXT[],
  display_order INTEGER,
  created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    rt.id,
    rt.title,
    rt.description,
    rt.category,
    rt.difficulty_level,
    rt.estimated_duration,
    rt.tags,
    rt.display_order,
    rt.created_at
  FROM recommended_topics rt
  WHERE rt.is_active = true
    AND (p_category IS NULL OR rt.category = p_category)
    AND (p_difficulty IS NULL OR rt.difficulty_level = p_difficulty)
  ORDER BY rt.display_order ASC, rt.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to get all available categories
CREATE OR REPLACE FUNCTION get_recommended_topics_categories()
RETURNS TABLE(category VARCHAR(100)) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT rt.category
  FROM recommended_topics rt
  WHERE rt.is_active = true
  ORDER BY rt.category;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to get total count for pagination
CREATE OR REPLACE FUNCTION get_recommended_topics_count(
  p_category TEXT DEFAULT NULL,
  p_difficulty TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  topic_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO topic_count
  FROM recommended_topics rt
  WHERE rt.is_active = true
    AND (p_category IS NULL OR rt.category = p_category)
    AND (p_difficulty IS NULL OR rt.difficulty_level = p_difficulty);
    
  RETURN topic_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;