-- Saved Study Guides Enhancement Migration
-- Version: 1.0.1
-- Add interpretation field to study_guides table if not exists

-- Add interpretation column to study_guides table (may already exist)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'study_guides' 
        AND column_name = 'interpretation'
    ) THEN
        ALTER TABLE study_guides 
        ADD COLUMN interpretation TEXT;
    END IF;
END $$;

-- Add interpretation column to anonymous_study_guides table (may already exist)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'anonymous_study_guides' 
        AND column_name = 'interpretation'
    ) THEN
        ALTER TABLE anonymous_study_guides 
        ADD COLUMN interpretation TEXT NOT NULL DEFAULT '';
    END IF;
END $$;

-- Create indexes for saved guides queries
CREATE INDEX IF NOT EXISTS idx_study_guides_saved ON study_guides(user_id, is_saved, created_at DESC) WHERE is_saved = true;
CREATE INDEX IF NOT EXISTS idx_anonymous_guides_session_created ON anonymous_study_guides(session_id, created_at DESC);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for study_guides updated_at
DROP TRIGGER IF EXISTS update_study_guides_updated_at ON study_guides;
CREATE TRIGGER update_study_guides_updated_at
    BEFORE UPDATE ON study_guides
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();