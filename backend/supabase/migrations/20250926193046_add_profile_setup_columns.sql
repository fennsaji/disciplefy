-- Add missing columns for profile setup functionality

-- Add age group column
ALTER TABLE user_profiles ADD COLUMN age_group VARCHAR(10) CHECK (age_group IN ('13-17', '18-25', '26-35', '36-50', '51+'));

-- Add interests column (array of text)
ALTER TABLE user_profiles ADD COLUMN interests TEXT[] DEFAULT '{}';

-- Add profile image URL column (alias for profile_picture for API compatibility)
ALTER TABLE user_profiles ADD COLUMN profile_image_url TEXT;

-- Update existing records to sync profile_picture and profile_image_url
UPDATE user_profiles SET profile_image_url = profile_picture WHERE profile_picture IS NOT NULL;

-- Create trigger to keep profile_picture and profile_image_url in sync
CREATE OR REPLACE FUNCTION sync_profile_image_fields()
RETURNS TRIGGER AS $$
BEGIN
  -- When profile_image_url is updated, sync to profile_picture
  IF NEW.profile_image_url IS DISTINCT FROM OLD.profile_image_url THEN
    NEW.profile_picture = NEW.profile_image_url;
  END IF;

  -- When profile_picture is updated, sync to profile_image_url
  IF NEW.profile_picture IS DISTINCT FROM OLD.profile_picture THEN
    NEW.profile_image_url = NEW.profile_picture;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_profile_image_trigger
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_profile_image_fields();