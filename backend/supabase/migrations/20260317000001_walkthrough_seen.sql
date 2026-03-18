-- Add walkthrough_seen column to user_profiles table
-- Tracks which walkthrough screens the user has completed (per-user, cross-device)
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS walkthrough_seen text[] DEFAULT '{}';
