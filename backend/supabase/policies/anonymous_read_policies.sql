-- Enhanced RLS Policies for Anonymous Users (Read Access)
-- These policies allow anonymous sessions to read public data

-- First, create tables for public data that anonymous users can read
-- NOTE: difficulty_level removed to match recommended_topics table structure
CREATE TABLE IF NOT EXISTS topics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  category VARCHAR(100),
  -- difficulty_level VARCHAR(20) DEFAULT 'beginner', -- Removed in migration 20250819000002
  estimated_reading_time INTEGER DEFAULT 10,
  tags TEXT[],
  is_featured BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS daily_verse (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  verse_reference VARCHAR(255) NOT NULL,
  verse_text TEXT NOT NULL,
  reflection TEXT,
  date DATE NOT NULL UNIQUE,
  language VARCHAR(5) DEFAULT 'en',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on new tables
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_verse ENABLE ROW LEVEL SECURITY;

-- Anonymous users can read topics (no authentication required)
CREATE POLICY "Anonymous users can read topics" ON topics
  FOR SELECT USING (true);

-- Anonymous users can read daily verse (no authentication required)
CREATE POLICY "Anonymous users can read daily verse" ON daily_verse
  FOR SELECT USING (true);

-- Only authenticated users can insert/update/delete topics
CREATE POLICY "Only authenticated users can manage topics" ON topics
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Only authenticated users can insert/update/delete daily verse
CREATE POLICY "Only authenticated users can manage daily verse" ON daily_verse
  FOR ALL USING (auth.uid() IS NOT NULL);

-- Anonymous session policies removed - table dropped in migration 20250818000001
-- DROP POLICY IF EXISTS "Anonymous sessions are session-scoped" ON anonymous_sessions;
-- CREATE POLICY "Anonymous sessions read/write by session" ON anonymous_sessions
--   FOR ALL USING (
--     -- Allow session creation without authentication
--     auth.uid() IS NULL OR 
--     -- Allow authenticated users to manage their own sessions
--     auth.uid() IS NOT NULL
--   );

-- Enhanced anonymous study guides policies
DROP POLICY IF EXISTS "Anonymous guides are session-scoped" ON anonymous_study_guides;
CREATE POLICY "Anonymous guides session-based access" ON anonymous_study_guides
  FOR ALL USING (
    -- Allow access based on session_id (handled at application level)
    true
  );

-- Create a function to validate anonymous session access
CREATE OR REPLACE FUNCTION validate_anonymous_session(session_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if session exists and hasn't expired
  RETURN EXISTS (
    SELECT 1 FROM anonymous_sessions 
    WHERE session_id = session_uuid 
    AND expires_at > NOW()
    AND is_migrated = false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enhanced feedback policies for anonymous users
DROP POLICY IF EXISTS "Users can view own feedback" ON feedback;
DROP POLICY IF EXISTS "Users can insert own feedback" ON feedback;

CREATE POLICY "Users can view own feedback" ON feedback
  FOR SELECT USING (
    auth.uid() = user_id OR 
    (auth.uid() IS NULL AND user_id IS NULL)
  );

CREATE POLICY "Authenticated users can insert feedback" ON feedback
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND auth.uid() IS NOT NULL
  );

-- Allow anonymous feedback insertion for specific cases
CREATE POLICY "Anonymous users can insert limited feedback" ON feedback
  FOR INSERT WITH CHECK (
    auth.uid() IS NULL AND 
    user_id IS NULL AND 
    study_guide_id IS NULL AND 
    recommended_guide_session_id IS NULL AND
    category IN ('bug_report', 'feature_request', 'general')
  );

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_topics_featured ON topics(is_featured);
CREATE INDEX IF NOT EXISTS idx_topics_category ON topics(category);
CREATE INDEX IF NOT EXISTS idx_daily_verse_date ON daily_verse(date);
CREATE INDEX IF NOT EXISTS idx_daily_verse_language ON daily_verse(language);

-- Insert sample data for testing
INSERT INTO topics (title, description, category, is_featured) VALUES
  ('Faith', 'Understanding biblical faith and trust in God', 'foundations', true),
  ('Love', 'Exploring God''s love and how to love others', 'relationships', true),
  ('Prayer', 'Learning to communicate with God effectively', 'spiritual_disciplines', false),
  ('Forgiveness', 'The power and necessity of forgiveness', 'relationships', false),
  ('Hope', 'Finding hope in difficult circumstances', 'encouragement', true)
ON CONFLICT DO NOTHING;

INSERT INTO daily_verse (verse_reference, verse_text, reflection, date, language) VALUES
  ('John 3:16', 'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.', 'This verse reminds us of God''s incredible love and sacrifice for humanity.', CURRENT_DATE, 'en'),
  ('Philippians 4:13', 'I can do all this through him who gives me strength.', 'We find our strength not in ourselves, but in Christ who empowers us.', CURRENT_DATE + INTERVAL '1 day', 'en'),
  ('Romans 8:28', 'And we know that in all things God works for the good of those who love him, who have been called according to his purpose.', 'Even in difficult times, God is working for our good.', CURRENT_DATE + INTERVAL '2 days', 'en')
ON CONFLICT (date) DO NOTHING;