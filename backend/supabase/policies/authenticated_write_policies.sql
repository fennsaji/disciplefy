-- Enhanced RLS Policies for Authenticated Users (Write Access)
-- These policies ensure authenticated users can only access their own data

-- Enhanced study guides policies with better security
DROP POLICY IF EXISTS "Users can view own study guides" ON study_guides;
DROP POLICY IF EXISTS "Users can insert own study guides" ON study_guides;
DROP POLICY IF EXISTS "Users can update own study guides" ON study_guides;
DROP POLICY IF EXISTS "Users can delete own study guides" ON study_guides;

CREATE POLICY "Authenticated users can view own study guides" ON study_guides
  FOR SELECT USING (
    auth.uid() = user_id AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Authenticated users can insert own study guides" ON study_guides
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Authenticated users can update own study guides" ON study_guides
  FOR UPDATE USING (
    auth.uid() = user_id AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Authenticated users can delete own study guides" ON study_guides
  FOR DELETE USING (
    auth.uid() = user_id AND auth.uid() IS NOT NULL
  );

-- Enhanced user profiles policies
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;

CREATE POLICY "Users can view own profile" ON user_profiles
  FOR SELECT USING (
    auth.uid() = id AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Users can insert own profile" ON user_profiles
  FOR INSERT WITH CHECK (
    auth.uid() = id AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Users can update own profile" ON user_profiles
  FOR UPDATE USING (
    auth.uid() = id AND auth.uid() IS NOT NULL
  );

-- Enhanced recommended guide sessions policies
DROP POLICY IF EXISTS "Users can view own recommended guide sessions" ON recommended_guide_sessions;
DROP POLICY IF EXISTS "Users can insert own recommended guide sessions" ON recommended_guide_sessions;
DROP POLICY IF EXISTS "Users can update own recommended guide sessions" ON recommended_guide_sessions;
DROP POLICY IF EXISTS "Users can delete own recommended guide sessions" ON recommended_guide_sessions;

CREATE POLICY "Authenticated users can view own recommended guide sessions" ON recommended_guide_sessions
  FOR SELECT USING (
    auth.uid() = user_id AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Authenticated users can insert own recommended guide sessions" ON recommended_guide_sessions
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Authenticated users can update own recommended guide sessions" ON recommended_guide_sessions
  FOR UPDATE USING (
    auth.uid() = user_id AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Authenticated users can delete own recommended guide sessions" ON recommended_guide_sessions
  FOR DELETE USING (
    auth.uid() = user_id AND auth.uid() IS NOT NULL
  );

-- Enhanced donations policies
DROP POLICY IF EXISTS "Users can view own donations" ON donations;
DROP POLICY IF EXISTS "Users can insert donations" ON donations;

CREATE POLICY "Authenticated users can view own donations" ON donations
  FOR SELECT USING (
    auth.uid() = user_id AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Authenticated users can insert own donations" ON donations
  FOR INSERT WITH CHECK (
    auth.uid() = user_id AND auth.uid() IS NOT NULL
  );

-- Function to create user profile automatically after signup
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (id, language_preference, theme_preference, is_admin)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'language_preference', 'en'),
    COALESCE(NEW.raw_user_meta_data->>'theme_preference', 'light'),
    false
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create user profile on signup
DROP TRIGGER IF EXISTS create_user_profile_trigger ON auth.users;
CREATE TRIGGER create_user_profile_trigger
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_profile();

-- Function to update user profile timestamp
CREATE OR REPLACE FUNCTION update_user_profile_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update timestamp on profile changes
DROP TRIGGER IF EXISTS update_user_profile_timestamp_trigger ON user_profiles;
CREATE TRIGGER update_user_profile_timestamp_trigger
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_user_profile_timestamp();

-- Function to update study guide timestamp
CREATE OR REPLACE FUNCTION update_study_guide_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update timestamp on study guide changes
DROP TRIGGER IF EXISTS update_study_guide_timestamp_trigger ON study_guides;
CREATE TRIGGER update_study_guide_timestamp_trigger
  BEFORE UPDATE ON study_guides
  FOR EACH ROW
  EXECUTE FUNCTION update_study_guide_timestamp();

-- Function to check if user can access study guide
CREATE OR REPLACE FUNCTION can_access_study_guide(guide_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  guide_user_id UUID;
BEGIN
  SELECT user_id INTO guide_user_id FROM study_guides WHERE id = guide_id;
  RETURN (guide_user_id = auth.uid()) OR (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND is_admin = true
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate donation amount
CREATE OR REPLACE FUNCTION validate_donation_amount(amount_value INTEGER)
RETURNS BOOLEAN AS $$
BEGIN
  -- Minimum donation: 100 INR (1 USD equivalent)
  -- Maximum donation: 1000000 INR (10,000 USD equivalent)
  RETURN amount_value >= 100 AND amount_value <= 1000000;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Add constraint to donations table
ALTER TABLE donations ADD CONSTRAINT valid_donation_amount 
  CHECK (validate_donation_amount(amount));