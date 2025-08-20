-- Migration: Rename user_study_guides_new table to user_study_guides
-- Date: 2025-08-19
-- Description: Rename the user_study_guides_new table to user_study_guides

BEGIN;

-- Rename the table
ALTER TABLE user_study_guides_new RENAME TO user_study_guides;

COMMIT;