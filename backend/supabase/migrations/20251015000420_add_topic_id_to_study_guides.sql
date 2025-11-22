-- Add topic_id column to study_guides table
-- This allows proper tracking of which recommended topic was used to generate a study guide

-- Add column if it doesn't exist (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'study_guides'
        AND column_name = 'topic_id'
    ) THEN
        ALTER TABLE study_guides ADD COLUMN topic_id UUID;
    END IF;
END $$;

-- Add foreign key constraint if it doesn't exist (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'study_guides_topic_id_fkey'
        AND table_name = 'study_guides'
    ) THEN
        ALTER TABLE study_guides
        ADD CONSTRAINT study_guides_topic_id_fkey
        FOREIGN KEY (topic_id)
        REFERENCES recommended_topics(id)
        ON DELETE SET NULL;
    END IF;
END $$;

-- Add index if it doesn't exist (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_study_guides_topic_id'
    ) THEN
        CREATE INDEX idx_study_guides_topic_id ON study_guides(topic_id);
    END IF;
END $$;

-- Comment for documentation
COMMENT ON COLUMN study_guides.topic_id IS 'References recommended_topics.id when the study guide was generated from a recommended topic';
