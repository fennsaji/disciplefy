-- Create profile pictures storage bucket with proper RLS policies
-- Migration: 20250825000001_setup_profile_pictures_storage.sql

-- Insert the profile-pictures bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'profile-pictures',
    'profile-pictures',
    true, -- Public read access
    5242880, -- 5MB file size limit
    ARRAY['image/jpeg', 'image/png', 'image/webp']
);

-- Create RLS policy for profile pictures - users can only upload to their own folder
CREATE POLICY "Users can upload their own profile pictures"
ON storage.objects
FOR INSERT
WITH CHECK (
    bucket_id = 'profile-pictures' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Create RLS policy for profile pictures - users can view any public profile picture
CREATE POLICY "Public profile pictures are viewable by everyone"
ON storage.objects
FOR SELECT
USING (bucket_id = 'profile-pictures');

-- Create RLS policy for profile pictures - users can update their own profile pictures
CREATE POLICY "Users can update their own profile pictures"
ON storage.objects
FOR UPDATE
USING (
    bucket_id = 'profile-pictures' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Create RLS policy for profile pictures - users can delete their own profile pictures
CREATE POLICY "Users can delete their own profile pictures"
ON storage.objects
FOR DELETE
USING (
    bucket_id = 'profile-pictures' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Update user_profiles table to ensure profile_picture column exists and has proper constraints
-- Note: This column should already exist from user_profile_entity.dart but ensuring it's configured correctly
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS profile_picture TEXT;

-- Add comment to profile_picture column
COMMENT ON COLUMN user_profiles.profile_picture IS 'URL to user profile picture in Supabase Storage';

-- Create function to generate profile picture path
CREATE OR REPLACE FUNCTION get_profile_picture_path(user_id UUID, file_extension TEXT DEFAULT 'jpg')
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN user_id::text || '/profile.' || file_extension;
END;
$$;

-- Create function to clean up orphaned profile pictures (for cron job)
CREATE OR REPLACE FUNCTION cleanup_orphaned_profile_pictures()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    cleanup_count INTEGER := 0;
    obj_record RECORD;
BEGIN
    -- Find profile pictures that don't have corresponding user profiles
    FOR obj_record IN
        SELECT so.name
        FROM storage.objects so
        WHERE so.bucket_id = 'profile-pictures'
        AND NOT EXISTS (
            SELECT 1 
            FROM user_profiles up 
            WHERE up.id::text = (storage.foldername(so.name))[1]
        )
        -- Only clean up files older than 24 hours to avoid race conditions
        AND so.created_at < NOW() - INTERVAL '24 hours'
    LOOP
        DELETE FROM storage.objects 
        WHERE bucket_id = 'profile-pictures' 
        AND name = obj_record.name;
        
        cleanup_count := cleanup_count + 1;
    END LOOP;
    
    RETURN cleanup_count;
END;
$$;

-- Create helper function to get full profile picture URL
CREATE OR REPLACE FUNCTION get_profile_picture_url(profile_picture_path TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    IF profile_picture_path IS NULL OR profile_picture_path = '' THEN
        RETURN NULL;
    END IF;
    
    -- Return the full Supabase Storage URL
    -- Note: This should be adjusted based on your Supabase project URL
    RETURN 'https://your-project-id.supabase.co/storage/v1/object/public/profile-pictures/' || profile_picture_path;
END;
$$;

-- Add index on profile_picture column for better performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_profile_picture 
ON user_profiles(profile_picture) 
WHERE profile_picture IS NOT NULL;