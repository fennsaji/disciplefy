-- ============================================================================
-- Study Guide Completion Tracking Migration
-- ============================================================================
-- Adds completion tracking to user_study_guides table to track when users
-- complete reading a study guide (time spent + scrolled to bottom).
-- Completed guides are excluded from recommended topic notifications.

-- ============================================================================
-- Add Completion Tracking Columns
-- ============================================================================

-- Add completed_at column (timestamp when both conditions were met)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_study_guides'
        AND column_name = 'completed_at'
    ) THEN
        ALTER TABLE user_study_guides
        ADD COLUMN completed_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- Add time_spent_seconds column (tracks actual reading time)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_study_guides'
        AND column_name = 'time_spent_seconds'
    ) THEN
        ALTER TABLE user_study_guides
        ADD COLUMN time_spent_seconds INTEGER DEFAULT 0;
    END IF;
END $$;

-- Add scrolled_to_bottom column (tracks if user saw all content)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_study_guides'
        AND column_name = 'scrolled_to_bottom'
    ) THEN
        ALTER TABLE user_study_guides
        ADD COLUMN scrolled_to_bottom BOOLEAN DEFAULT false;
    END IF;
END $$;

-- ============================================================================
-- Add Indexes for Query Performance
-- ============================================================================

-- Index on completed_at for filtering completed guides
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_user_study_guides_completed_at'
    ) THEN
        CREATE INDEX idx_user_study_guides_completed_at
        ON user_study_guides(completed_at)
        WHERE completed_at IS NOT NULL;
    END IF;
END $$;

-- Composite index on (user_id, completed_at) for user-specific completed guide queries
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE indexname = 'idx_user_study_guides_user_completion'
    ) THEN
        CREATE INDEX idx_user_study_guides_user_completion
        ON user_study_guides(user_id, completed_at)
        WHERE completed_at IS NOT NULL;
    END IF;
END $$;

-- ============================================================================
-- Add Column Comments for Documentation
-- ============================================================================

COMMENT ON COLUMN user_study_guides.completed_at IS 'Timestamp when user completed the study guide (both time and scroll conditions met). NULL if not completed yet.';
COMMENT ON COLUMN user_study_guides.time_spent_seconds IS 'Total time user spent reading the study guide in seconds. Updated when completion conditions are met.';
COMMENT ON COLUMN user_study_guides.scrolled_to_bottom IS 'Whether user scrolled to the bottom of the study guide. Required for completion along with minimum time.';

-- ============================================================================
-- Validation
-- ============================================================================

-- Verify columns were added successfully
DO $$
DECLARE
    missing_columns TEXT[];
BEGIN
    SELECT ARRAY_AGG(column_name)
    INTO missing_columns
    FROM (
        SELECT 'completed_at' AS column_name
        UNION SELECT 'time_spent_seconds'
        UNION SELECT 'scrolled_to_bottom'
    ) expected
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_study_guides'
        AND column_name = expected.column_name
    );

    IF array_length(missing_columns, 1) > 0 THEN
        RAISE EXCEPTION 'Migration failed: Missing columns: %', array_to_string(missing_columns, ', ');
    ELSE
        RAISE NOTICE '✅ Migration successful: All completion tracking columns added to user_study_guides table';
    END IF;
END $$;
