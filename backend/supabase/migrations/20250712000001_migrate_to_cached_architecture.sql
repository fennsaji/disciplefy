-- Fixed Migration: Content-Centric Study Guide Architecture
-- This migration separates content storage from user ownership
-- for improved caching and deduplication

BEGIN;

-- ================================
-- STEP 1: Create New Tables
-- ================================

-- Content cache table (no user context)
CREATE TABLE IF NOT EXISTS study_guides_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  input_type VARCHAR(20) NOT NULL,
  input_value_hash VARCHAR(64) NOT NULL,
  language VARCHAR(5) NOT NULL,
  summary TEXT NOT NULL,
  interpretation TEXT NOT NULL,
  context TEXT NOT NULL,
  related_verses TEXT[] NOT NULL,
  reflection_questions TEXT[] NOT NULL,
  prayer_points TEXT[] NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure content deduplication
  CONSTRAINT unique_cached_content UNIQUE(input_type, input_value_hash, language)
);

-- Authenticated user ownership
CREATE TABLE IF NOT EXISTS user_study_guides_new (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  study_guide_id UUID NOT NULL REFERENCES study_guides_cache(id),
  is_saved BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Prevent duplicate user-guide relationships
  CONSTRAINT unique_user_guide_new UNIQUE(user_id, study_guide_id)
);

-- Anonymous user ownership (updated to reference cache)
CREATE TABLE IF NOT EXISTS anonymous_study_guides_new (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL,
  study_guide_id UUID NOT NULL REFERENCES study_guides_cache(id),
  is_saved BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days'),
  
  -- Prevent duplicate session-guide relationships
  CONSTRAINT unique_session_guide_new UNIQUE(session_id, study_guide_id)
);

-- ================================
-- STEP 2: Create Performance Indexes
-- ================================

-- Cache table indexes
CREATE INDEX IF NOT EXISTS idx_study_guides_cache_lookup 
ON study_guides_cache(input_type, input_value_hash, language);

CREATE INDEX IF NOT EXISTS idx_study_guides_cache_created_at 
ON study_guides_cache(created_at DESC);

-- User ownership indexes
CREATE INDEX IF NOT EXISTS idx_user_study_guides_user_id 
ON user_study_guides_new(user_id);

CREATE INDEX IF NOT EXISTS idx_user_study_guides_saved 
ON user_study_guides_new(user_id, is_saved) WHERE is_saved = true;

CREATE INDEX IF NOT EXISTS idx_user_study_guides_created_at 
ON user_study_guides_new(user_id, created_at DESC);

-- Anonymous ownership indexes
CREATE INDEX IF NOT EXISTS idx_anonymous_study_guides_session_id 
ON anonymous_study_guides_new(session_id);

CREATE INDEX IF NOT EXISTS idx_anonymous_study_guides_saved 
ON anonymous_study_guides_new(session_id, is_saved) WHERE is_saved = true;

CREATE INDEX IF NOT EXISTS idx_anonymous_study_guides_created_at 
ON anonymous_study_guides_new(session_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_anonymous_study_guides_expires_at 
ON anonymous_study_guides_new(expires_at);

-- ================================
-- STEP 3: Migration Functions
-- ================================

-- Function to generate consistent hash for input values
CREATE OR REPLACE FUNCTION generate_input_hash(input_value TEXT)
RETURNS VARCHAR(64) AS $$
BEGIN
  RETURN encode(digest(lower(trim(input_value)), 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql;

-- Function to migrate authenticated user data
CREATE OR REPLACE FUNCTION migrate_authenticated_data()
RETURNS INTEGER AS $$
DECLARE
  study_guide_record RECORD;
  cache_id UUID;
  migrated_count INTEGER := 0;
BEGIN
  -- Process each study guide
  FOR study_guide_record IN 
    SELECT * FROM study_guides 
    WHERE user_id IS NOT NULL
    ORDER BY created_at ASC
  LOOP
    -- Generate hash for input value
    DECLARE
      input_hash VARCHAR(64) := generate_input_hash(study_guide_record.input_value);
    BEGIN
      -- Check if content already exists in cache
      SELECT id INTO cache_id
      FROM study_guides_cache
      WHERE input_type = study_guide_record.input_type
        AND input_value_hash = input_hash
        AND language = study_guide_record.language;
      
      -- If not found, create cached content
      IF cache_id IS NULL THEN
        INSERT INTO study_guides_cache (
          input_type,
          input_value_hash,
          language,
          summary,
          interpretation,
          context,
          related_verses,
          reflection_questions,
          prayer_points,
          created_at,
          updated_at
        ) VALUES (
          study_guide_record.input_type,
          input_hash,
          study_guide_record.language,
          study_guide_record.summary,
          study_guide_record.interpretation,
          study_guide_record.context,
          study_guide_record.related_verses,
          study_guide_record.reflection_questions,
          study_guide_record.prayer_points,
          study_guide_record.created_at,
          study_guide_record.updated_at
        ) RETURNING id INTO cache_id;
      END IF;
      
      -- Create user ownership record
      INSERT INTO user_study_guides_new (
        user_id,
        study_guide_id,
        is_saved,
        created_at,
        updated_at
      ) VALUES (
        study_guide_record.user_id,
        cache_id,
        study_guide_record.is_saved,
        study_guide_record.created_at,
        study_guide_record.updated_at
      ) ON CONFLICT (user_id, study_guide_id) DO NOTHING;
      
      migrated_count := migrated_count + 1;
    END;
  END LOOP;
  
  RETURN migrated_count;
END;
$$ LANGUAGE plpgsql;

-- Function to migrate anonymous user data
CREATE OR REPLACE FUNCTION migrate_anonymous_data()
RETURNS INTEGER AS $$
DECLARE
  study_guide_record RECORD;
  cache_id UUID;
  migrated_count INTEGER := 0;
BEGIN
  -- Process each anonymous study guide
  FOR study_guide_record IN 
    SELECT 
      id,
      session_id,
      input_type,
      input_value_hash,
      summary,
      interpretation,
      context,
      related_verses,
      reflection_questions,
      prayer_points,
      language,
      created_at,
      expires_at,
      false as is_saved -- Default to false since original table doesn't have this
    FROM anonymous_study_guides 
    ORDER BY created_at ASC
  LOOP
    -- Check if content already exists in cache
    SELECT id INTO cache_id
    FROM study_guides_cache
    WHERE input_type = study_guide_record.input_type
      AND input_value_hash = study_guide_record.input_value_hash
      AND language = study_guide_record.language;
    
    -- If not found, create cached content
    IF cache_id IS NULL THEN
      INSERT INTO study_guides_cache (
        input_type,
        input_value_hash,
        language,
        summary,
        interpretation,
        context,
        related_verses,
        reflection_questions,
        prayer_points,
        created_at,
        updated_at
      ) VALUES (
        study_guide_record.input_type,
        study_guide_record.input_value_hash,
        study_guide_record.language,
        study_guide_record.summary,
        study_guide_record.interpretation,
        study_guide_record.context,
        study_guide_record.related_verses,
        study_guide_record.reflection_questions,
        study_guide_record.prayer_points,
        study_guide_record.created_at,
        study_guide_record.created_at -- Use created_at as updated_at
      ) RETURNING id INTO cache_id;
    END IF;
    
    -- Create anonymous ownership record
    INSERT INTO anonymous_study_guides_new (
      session_id,
      study_guide_id,
      is_saved,
      created_at,
      updated_at,
      expires_at
    ) VALUES (
      study_guide_record.session_id,
      cache_id,
      study_guide_record.is_saved,
      study_guide_record.created_at,
      study_guide_record.created_at,
      study_guide_record.expires_at
    ) ON CONFLICT (session_id, study_guide_id) DO NOTHING;
    
    migrated_count := migrated_count + 1;
  END LOOP;
  
  RETURN migrated_count;
END;
$$ LANGUAGE plpgsql;

-- ================================
-- STEP 4: Execute Migration
-- ================================

-- Migrate authenticated user data
DO $$
DECLARE
  auth_migrated INTEGER;
  anon_migrated INTEGER;
BEGIN
  -- Migrate authenticated users
  SELECT migrate_authenticated_data() INTO auth_migrated;
  RAISE NOTICE 'Migrated % authenticated user study guides', auth_migrated;
  
  -- Migrate anonymous users
  SELECT migrate_anonymous_data() INTO anon_migrated;
  RAISE NOTICE 'Migrated % anonymous user study guides', anon_migrated;
END $$;

-- ================================
-- STEP 5: Create RLS Policies
-- ================================

-- Enable RLS on new tables
ALTER TABLE study_guides_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_study_guides_new ENABLE ROW LEVEL SECURITY;
ALTER TABLE anonymous_study_guides_new ENABLE ROW LEVEL SECURITY;

-- Cache table policies (read-only access to cached content)
CREATE POLICY "Anyone can read cached content" ON study_guides_cache
  FOR SELECT USING (true);

-- User ownership policies
CREATE POLICY "Users can read their own study guides" ON user_study_guides_new
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own study guides" ON user_study_guides_new
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own study guides" ON user_study_guides_new
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users can delete their own study guides" ON user_study_guides_new
  FOR DELETE USING (user_id = auth.uid());

-- Anonymous ownership policies (no RLS - handled by application logic)
CREATE POLICY "Anonymous access controlled by application" ON anonymous_study_guides_new
  FOR ALL USING (true);

-- ================================
-- STEP 6: Create Views for Backward Compatibility
-- ================================

-- View for authenticated users (mimics old study_guides table)
CREATE OR REPLACE VIEW authenticated_study_guides AS
SELECT 
  sg.id,
  usg.user_id,
  sg.input_type,
  '[REDACTED]' as input_value, -- Don't expose raw input
  sg.input_value_hash,
  sg.summary,
  sg.interpretation,
  sg.context,
  sg.related_verses,
  sg.reflection_questions,
  sg.prayer_points,
  sg.language,
  usg.is_saved,
  usg.created_at,
  usg.updated_at
FROM study_guides_cache sg
JOIN user_study_guides_new usg ON sg.id = usg.study_guide_id;

-- View for anonymous users (mimics old anonymous_study_guides table)
CREATE OR REPLACE VIEW anonymous_study_guides_view AS
SELECT 
  sg.id,
  asg.session_id,
  sg.input_type,
  sg.input_value_hash,
  sg.summary,
  sg.interpretation,
  sg.context,
  sg.related_verses,
  sg.reflection_questions,
  sg.prayer_points,
  sg.language,
  asg.is_saved,
  asg.created_at,
  asg.updated_at,
  asg.expires_at
FROM study_guides_cache sg
JOIN anonymous_study_guides_new asg ON sg.id = asg.study_guide_id;

-- ================================
-- STEP 7: Validation Queries
-- ================================

-- Check migration results
DO $$
DECLARE
  old_auth_count INTEGER;
  new_auth_count INTEGER;
  old_anon_count INTEGER;
  new_anon_count INTEGER;
  cache_count INTEGER;
BEGIN
  -- Count records
  SELECT COUNT(*) INTO old_auth_count FROM study_guides WHERE user_id IS NOT NULL;
  SELECT COUNT(*) INTO new_auth_count FROM user_study_guides_new;
  SELECT COUNT(*) INTO old_anon_count FROM anonymous_study_guides;
  SELECT COUNT(*) INTO new_anon_count FROM anonymous_study_guides_new;
  SELECT COUNT(*) INTO cache_count FROM study_guides_cache;
  
  -- Report results
  RAISE NOTICE 'Migration Validation:';
  RAISE NOTICE 'Old authenticated records: %', old_auth_count;
  RAISE NOTICE 'New authenticated records: %', new_auth_count;
  RAISE NOTICE 'Old anonymous records: %', old_anon_count;
  RAISE NOTICE 'New anonymous records: %', new_anon_count;
  RAISE NOTICE 'Cached content records: %', cache_count;
  
  -- Calculate deduplication effectiveness
  IF (old_auth_count + old_anon_count) > 0 THEN
    RAISE NOTICE 'Deduplication ratio: %.2f%%', 
      (100.0 * cache_count / (old_auth_count + old_anon_count));
  END IF;
END $$;

-- ================================
-- STEP 8: Performance Analysis
-- ================================

-- Analyze table statistics
ANALYZE study_guides_cache;
ANALYZE user_study_guides_new;
ANALYZE anonymous_study_guides_new;

-- ================================
-- STEP 9: Management Functions
-- ================================

-- Function to finalize migration after validation
CREATE OR REPLACE FUNCTION finalize_migration()
RETURNS BOOLEAN AS $$
BEGIN
  -- Rename old tables for backup
  ALTER TABLE study_guides RENAME TO study_guides_old;
  ALTER TABLE anonymous_study_guides RENAME TO anonymous_study_guides_old;
  
  -- Rename new tables to production names
  ALTER TABLE study_guides_cache RENAME TO study_guides;
  ALTER TABLE user_study_guides_new RENAME TO user_study_guides;
  ALTER TABLE anonymous_study_guides_new RENAME TO anonymous_study_guides;
  
  -- Update views to use new table names
  DROP VIEW IF EXISTS authenticated_study_guides;
  DROP VIEW IF EXISTS anonymous_study_guides_view;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function to rollback migration if needed
CREATE OR REPLACE FUNCTION rollback_migration()
RETURNS BOOLEAN AS $$
BEGIN
  -- Drop new tables
  DROP TABLE IF EXISTS study_guides_cache CASCADE;
  DROP TABLE IF EXISTS user_study_guides_new CASCADE;
  DROP TABLE IF EXISTS anonymous_study_guides_new CASCADE;
  
  -- Drop views
  DROP VIEW IF EXISTS authenticated_study_guides CASCADE;
  DROP VIEW IF EXISTS anonymous_study_guides_view CASCADE;
  
  -- Drop functions
  DROP FUNCTION IF EXISTS generate_input_hash(TEXT);
  DROP FUNCTION IF EXISTS migrate_authenticated_data();
  DROP FUNCTION IF EXISTS migrate_anonymous_data();
  DROP FUNCTION IF EXISTS finalize_migration();
  
  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ================================
-- STEP 10: Comments and Documentation
-- ================================

COMMENT ON TABLE study_guides_cache IS 'Content cache table for deduplicated study guide content';
COMMENT ON TABLE user_study_guides_new IS 'User ownership and relationship table for authenticated users';
COMMENT ON TABLE anonymous_study_guides_new IS 'User ownership and relationship table for anonymous users';

COMMENT ON COLUMN study_guides_cache.input_value_hash IS 'SHA-256 hash of the input value for content deduplication';
COMMENT ON COLUMN user_study_guides_new.is_saved IS 'Whether the user has explicitly saved this study guide';
COMMENT ON COLUMN anonymous_study_guides_new.expires_at IS 'Expiration time for anonymous user data retention';

COMMIT;

-- ================================
-- MIGRATION COMPLETE
-- ================================

-- To finalize the migration (after testing), run:
-- SELECT finalize_migration();

-- To rollback the migration (if needed), run:
-- SELECT rollback_migration();