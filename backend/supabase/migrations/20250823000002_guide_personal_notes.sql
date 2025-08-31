-- Migration: Add personal_notes column to user_study_guides table
-- Date: 2025-08-23
-- Description: Add TEXT column for storing personal notes with length constraint

-- Up Migration: Add personal_notes column with TEXT type and CHECK constraint
ALTER TABLE user_study_guides 
ADD COLUMN personal_notes TEXT 
CONSTRAINT personal_notes_length_check 
CHECK (personal_notes IS NULL OR char_length(personal_notes) <= 2048);

-- Add comment for documentation
COMMENT ON COLUMN user_study_guides.personal_notes IS 'Personal notes for study guide (max 2048 characters)';

-- Note: Existing RLS policies on user_study_guides already restrict access to auth.uid()
-- The following policies apply to the new personal_notes column:
-- - "Users can read their own study guides" (SELECT using user_id = auth.uid())
-- - "Users can update their own study guides" (UPDATE using user_id = auth.uid())
-- - "Users can insert their own study guides" (INSERT with check user_id = auth.uid())
-- - "Users can delete their own study guides" (DELETE using user_id = auth.uid())

-- Down Migration (for rollback): Drop personal_notes column
-- Uncomment the following lines to create a down migration:
/*
ALTER TABLE user_study_guides 
DROP COLUMN IF EXISTS personal_notes;
*/