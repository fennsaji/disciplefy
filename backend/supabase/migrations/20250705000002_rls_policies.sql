-- Row Level Security Policies for Disciplefy Bible Study App
-- Based on Security Design Plan and Data Model specifications

-- Enable RLS on all tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_guides ENABLE ROW LEVEL SECURITY;
ALTER TABLE recommended_guide_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;
-- anonymous_sessions table removed in migration 20250818000001
-- ALTER TABLE anonymous_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE anonymous_study_guides ENABLE ROW LEVEL SECURITY;
ALTER TABLE donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE llm_security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- User Profiles RLS Policies
CREATE POLICY "Users can view own profile" ON user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON user_profiles
  FOR UPDATE USING (auth.uid() = id);

-- Study Guides RLS Policies
CREATE POLICY "Users can view own study guides" ON study_guides
  FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can insert own study guides" ON study_guides
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can update own study guides" ON study_guides
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own study guides" ON study_guides
  FOR DELETE USING (auth.uid() = user_id);

-- Recommended Guide Sessions RLS Policies
CREATE POLICY "Users can view own recommended guide sessions" ON recommended_guide_sessions
  FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can insert own recommended guide sessions" ON recommended_guide_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can update own recommended guide sessions" ON recommended_guide_sessions
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own recommended guide sessions" ON recommended_guide_sessions
  FOR DELETE USING (auth.uid() = user_id);

-- Feedback RLS Policies
CREATE POLICY "Users can view own feedback" ON feedback
  FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can insert own feedback" ON feedback
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can update own feedback" ON feedback
  FOR UPDATE USING (auth.uid() = user_id);

-- Anonymous Sessions RLS Policies (session-based access)
-- anonymous_sessions table removed in migration 20250818000001
-- CREATE POLICY "Anonymous sessions are session-scoped" ON anonymous_sessions
--   FOR ALL USING (true); -- Handled at application level via session_id

CREATE POLICY "Anonymous guides are session-scoped" ON anonymous_study_guides
  FOR ALL USING (true); -- Handled at application level via session_id

-- Donations RLS Policies
CREATE POLICY "Users can view own donations" ON donations
  FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "Users can insert donations" ON donations
  FOR INSERT WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Admin-only policies for sensitive tables
CREATE POLICY "Only admins can view security events" ON llm_security_events
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE auth.uid() = id AND is_admin = true
    )
  );

CREATE POLICY "System can insert security events" ON llm_security_events
  FOR INSERT WITH CHECK (true); -- Handled at application level

CREATE POLICY "Only admins can view admin logs" ON admin_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE auth.uid() = id AND is_admin = true
    )
  );

CREATE POLICY "System can insert admin logs" ON admin_logs
  FOR INSERT WITH CHECK (true); -- Handled at application level

-- Analytics events policies
CREATE POLICY "Users can view own analytics" ON analytics_events
  FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "System can insert analytics" ON analytics_events
  FOR INSERT WITH CHECK (true); -- Handled at application level

-- Admin access policies (can access all data)
CREATE POLICY "Admins can view all study guides" ON study_guides
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE auth.uid() = id AND is_admin = true
    )
  );

CREATE POLICY "Admins can view all recommended guide sessions" ON recommended_guide_sessions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE auth.uid() = id AND is_admin = true
    )
  );

CREATE POLICY "Admins can view all feedback" ON feedback
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE auth.uid() = id AND is_admin = true
    )
  );

CREATE POLICY "Admins can view all donations" ON donations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE auth.uid() = id AND is_admin = true
    )
  );

-- Function to check admin status
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_profiles 
    WHERE id = auth.uid() AND is_admin = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;