-- Add Google profile fields to user_profiles table

ALTER TABLE user_profiles ADD COLUMN first_name TEXT;
ALTER TABLE user_profiles ADD COLUMN last_name TEXT;
ALTER TABLE user_profiles ADD COLUMN profile_picture TEXT;