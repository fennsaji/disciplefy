-- Add interpretation column to study guides tables
-- This column was missing from the original schema but is required for the complete study guide structure

-- Add interpretation column to study_guides table
ALTER TABLE study_guides 
ADD COLUMN interpretation TEXT NOT NULL DEFAULT '';

-- Add interpretation column to anonymous_study_guides table  
ALTER TABLE anonymous_study_guides 
ADD COLUMN interpretation TEXT NOT NULL DEFAULT '';

-- Update the default value to empty string for existing records (if any)
UPDATE study_guides SET interpretation = '' WHERE interpretation IS NULL;
UPDATE anonymous_study_guides SET interpretation = '' WHERE interpretation IS NULL;