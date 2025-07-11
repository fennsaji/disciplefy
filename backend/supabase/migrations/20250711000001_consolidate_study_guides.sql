-- Migration: Consolidate study_guides and anonymous_study_guides tables
-- Date: 2025-07-11
-- Purpose: Merge separate tables to improve performance and reduce complexity

-- Begin transaction
BEGIN;

-- Step 1: Create a new consolidated study_guides table with all fields
CREATE TABLE study_guides_new (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id UUID REFERENCES anonymous_sessions(session_id) ON DELETE CASCADE,
  input_type VARCHAR(20) NOT NULL CHECK (input_type IN ('scripture', 'topic')),
  input_value VARCHAR(255), -- For authenticated users
  input_value_hash VARCHAR(64), -- For anonymous users
  summary TEXT NOT NULL,
  interpretation TEXT NOT NULL,
  context TEXT NOT NULL,
  related_verses TEXT[] NOT NULL,
  reflection_questions TEXT[] NOT NULL,
  prayer_points TEXT[] NOT NULL,
  language VARCHAR(5) DEFAULT 'en',
  is_saved BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE, -- For anonymous guides
  
  -- Constraints
  CONSTRAINT study_guides_user_or_session_check 
    CHECK ((user_id IS NOT NULL AND session_id IS NULL) OR 
           (user_id IS NULL AND session_id IS NOT NULL)),
  
  CONSTRAINT study_guides_input_value_check 
    CHECK ((user_id IS NOT NULL AND input_value IS NOT NULL AND input_value_hash IS NULL) OR 
           (user_id IS NULL AND input_value IS NULL AND input_value_hash IS NOT NULL))
);

-- Step 2: Migrate data from study_guides table (authenticated users)
INSERT INTO study_guides_new (
  id, user_id, session_id, input_type, input_value, input_value_hash,
  summary, interpretation, context, related_verses, reflection_questions, 
  prayer_points, language, is_saved, created_at, updated_at, expires_at
)
SELECT 
  id, user_id, NULL, input_type, input_value, NULL,
  summary, interpretation, context, related_verses, reflection_questions,
  prayer_points, language, is_saved, created_at, updated_at, NULL
FROM study_guides;

-- Step 3: Migrate data from anonymous_study_guides table (anonymous users)
INSERT INTO study_guides_new (
  id, user_id, session_id, input_type, input_value, input_value_hash,
  summary, interpretation, context, related_verses, reflection_questions, 
  prayer_points, language, is_saved, created_at, updated_at, expires_at
)
SELECT 
  id, NULL, session_id, input_type, NULL, input_value_hash,
  summary, interpretation, context, related_verses, reflection_questions,
  prayer_points, language, false, created_at, created_at, expires_at
FROM anonymous_study_guides;

-- Step 4: Drop old tables
DROP TABLE study_guides CASCADE;
DROP TABLE anonymous_study_guides CASCADE;

-- Step 5: Rename new table to study_guides
ALTER TABLE study_guides_new RENAME TO study_guides;

-- Step 6: Create indexes for performance
CREATE INDEX idx_study_guides_user_id ON study_guides(user_id);
CREATE INDEX idx_study_guides_session_id ON study_guides(session_id);
CREATE INDEX idx_study_guides_created_at ON study_guides(created_at DESC);
CREATE INDEX idx_study_guides_input_type ON study_guides(input_type);
CREATE INDEX idx_study_guides_language ON study_guides(language);
CREATE INDEX idx_study_guides_expires_at ON study_guides(expires_at);

-- Create unique index for duplicate detection (authenticated users)
CREATE UNIQUE INDEX idx_study_guides_auth_unique 
ON study_guides(user_id, input_type, input_value, language) 
WHERE user_id IS NOT NULL;

-- Create unique index for duplicate detection (anonymous users)
CREATE UNIQUE INDEX idx_study_guides_anon_unique 
ON study_guides(session_id, input_type, input_value_hash, language) 
WHERE session_id IS NOT NULL;

-- Step 7: Update feedback table foreign key constraint
ALTER TABLE feedback 
DROP CONSTRAINT IF EXISTS feedback_study_guide_id_fkey;

ALTER TABLE feedback 
ADD CONSTRAINT feedback_study_guide_id_fkey 
FOREIGN KEY (study_guide_id) REFERENCES study_guides(id) ON DELETE CASCADE;

-- Step 8: Add comments for documentation
COMMENT ON TABLE study_guides IS 'Consolidated study guides for both authenticated and anonymous users';
COMMENT ON COLUMN study_guides.user_id IS 'User ID for authenticated users (NULL for anonymous)';
COMMENT ON COLUMN study_guides.session_id IS 'Session ID for anonymous users (NULL for authenticated)';
COMMENT ON COLUMN study_guides.input_value IS 'Plain text input for authenticated users';
COMMENT ON COLUMN study_guides.input_value_hash IS 'Hashed input for anonymous users (privacy protection)';
COMMENT ON COLUMN study_guides.expires_at IS 'Expiration time for anonymous study guides';

-- Commit transaction
COMMIT;